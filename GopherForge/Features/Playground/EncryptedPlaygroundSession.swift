import Foundation

struct EncryptedPlaygroundLink: Codable {
    let room: String
    let capability: String
    let secret: String
    init(_ url: URL) throws {
        let trusted = (url.scheme == "https" && url.host == "gopherforge.app" && url.path == "/playground") || (url.scheme == "gopherforge" && url.host == "playground")
        let items = URLComponents(string: "?" + (url.fragment ?? ""))?.queryItems ?? []
        let fields = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        guard trusted, let room = fields["room"], room.range(of: "^[a-f0-9]{24}$", options: .regularExpression) != nil,
              let cap = fields["cap"], cap.range(of: "^\(room)\\.[A-Za-z0-9_-]{32}$", options: .regularExpression) != nil,
              let key = fields["key"], try PlaygroundCipher.decode(key, maximum: 32).count == 32 else { throw PlaygroundCRDT.Failure("Use a valid encrypted GopherForge room link.") }
        self.room = room; capability = cap; secret = key
    }
    init(room: String, capability: String, secret: String) { self.room = room; self.capability = capability; self.secret = secret }
    var url: URL {
        var url = URLComponents(string: "https://gopherforge.app/playground")!
        var fragment = URLComponents(); fragment.queryItems = [URLQueryItem(name: "room", value: room), URLQueryItem(name: "cap", value: capability), URLQueryItem(name: "key", value: secret)]
        url.percentEncodedFragment = fragment.percentEncodedQuery
        return url.url!
    }
}

/// The same encrypted/Yjs wire format as the web editor. No operation here starts a compiler.
@MainActor @Observable final class EncryptedPlaygroundSession {
    struct Saved: Codable {
        let link: EncryptedPlaygroundLink; let owner: String?; let edit: String?; let view: String?
        let name: String; let state: String; let role: String; let expiresAt: Double
    }
    private struct Reply: Decodable {
        struct Event: Decodable { let sequence: Int; let packet: PlaygroundCipherPacket }
        struct Participant: Decodable { let id: String; let packet: PlaygroundCipherPacket? }
        struct Capabilities: Decodable { let owner: String; let edit: String; let view: String }
        let id: String?; let role: String?; let peer: String?; let head: Int?; let expiresAt: Double?
        let snapshot: PlaygroundCipherPacket?; let snapshotSequence: Int?; let events: [Event]?
        let participants: [Participant]?; let participantCapability: String?; let capabilities: Capabilities?
    }
    private struct Pending { let id: String; let update: String; let packet: PlaygroundCipherPacket }
    private let engine: PlaygroundCRDT
    private let transport: PlaygroundTransport
    private var link: EncryptedPlaygroundLink?
    private var token: String?
    private var peer: String?
    private var owner: String?
    private var edit: String?
    private var viewCapability: String?
    private var head = 0
    private var pending: Pending?
    private var lastSnapshot = Date.distantPast
    private var syncing = false
    private(set) var state: PlaygroundCRDT.View
    private(set) var role = "edit"
    private(set) var expiresAt: Double = 0
    private(set) var connected = false
    private(set) var name: String
    private(set) var status = "Encrypted local draft."
    var canClose: Bool { owner != nil }
    var hasPendingChanges: Bool { (try? engine.export().pending) == true }
    var shareURL: URL? { guard let link else { return nil }; return EncryptedPlaygroundLink(room: link.room, capability: edit ?? link.capability, secret: link.secret).url }
    var viewURL: URL? { guard let link, let viewCapability else { return nil }; return EncryptedPlaygroundLink(room: link.room, capability: viewCapability, secret: link.secret).url }

    init(transport: PlaygroundTransport, name: String, files: [String: String]? = nil, saved: Saved? = nil) throws {
        self.transport = PlaygroundTransport(endpoint: transport.endpoint.appending(path: "secure"), session: transport.session)
        let normalizedName = try PlaygroundIdentity.nickname(saved?.name ?? name)
        self.name = normalizedName
        engine = try PlaygroundCRDT()
        var input: [String: Any] = ["op": "init"]
        if let saved { input["saved"] = saved.state; link = saved.link; owner = saved.owner; edit = saved.edit; viewCapability = saved.view; role = saved.role; expiresAt = saved.expiresAt }
        else if let files { input["files"] = files }
        try engine.command(input)
        try engine.command(["op": "identity", "name": normalizedName, "color": PlaygroundIdentity.color(normalizedName)])
        state = try engine.view()
    }
    func saved() throws -> Saved? {
        guard let link else { return nil }
        return Saved(link: link, owner: owner, edit: edit, view: viewCapability, name: name, state: try engine.export().state, role: role, expiresAt: expiresAt)
    }
    private func call(_ input: [String: Any], capability: String? = nil) async throws -> Reply {
        try await transport.call(input, token: capability ?? token, as: Reply.self)
    }
    private func encoded(_ packet: PlaygroundCipherPacket) -> [String: String] { ["iv": packet.iv, "data": packet.data] }
    func create() async throws {
        let secret = PlaygroundCipher.secret(), bytes = try PlaygroundCipher.decode(engine.export().state)
        let created = try await call(["op": "create", "ttlSeconds": 3600, "snapshot": encoded(PlaygroundCipher.encrypt(bytes, secret: secret))])
        guard let caps = created.capabilities, let id = created.id else { throw PlaygroundCRDT.Failure("The room was not created.") }
        owner = caps.owner; edit = caps.edit; viewCapability = caps.view
        link = EncryptedPlaygroundLink(room: id, capability: caps.edit, secret: secret)
        try await reconnect()
    }
    func join(_ url: URL) async throws { link = try EncryptedPlaygroundLink(url); try await reconnect() }
    private func reconnect() async throws {
        guard let link else { return }
        let joined = try await call(["op": "join"], capability: link.capability)
        guard let seat = joined.participantCapability, let role = joined.role else { throw PlaygroundCRDT.Failure("The room could not be joined.") }
        token = seat; self.role = role; peer = joined.peer
        if edit == nil && role != "view" { edit = link.capability }
        if role == "view" { viewCapability = link.capability }
        try apply(joined)
        connected = true; status = "Encrypted room connected. Remote changes never execute code."
    }
    private func apply(_ response: Reply) throws {
        guard let link else { return }
        var input: [String: Any] = ["op": "apply"]
        if let snapshot = response.snapshot { input["snapshot"] = PlaygroundCipher.encode(try PlaygroundCipher.decrypt(snapshot, secret: link.secret)) }
        input["updates"] = try (response.events ?? []).map { PlaygroundCipher.encode(try PlaygroundCipher.decrypt($0.packet, secret: link.secret)) }
        input["presence"] = (response.participants ?? []).compactMap { participant -> String? in
            guard participant.id != peer, let packet = participant.packet, let bytes = try? PlaygroundCipher.decrypt(packet, secret: link.secret, channel: "presence") else { return nil }
            return PlaygroundCipher.encode(bytes)
        }
        try engine.command(input)
        head = response.head ?? head; expiresAt = response.expiresAt ?? expiresAt
        state = try engine.view()
    }
    func sync() async {
        guard !syncing, let link else { return }
        syncing = true; defer { syncing = false }
        do {
            if token == nil { try await reconnect() }
            let read = try await call(["op": "sync", "after": head]); try apply(read)
            if role != "view", head > 0, Date().timeIntervalSince(lastSnapshot) > 5 {
                let bytes = try PlaygroundCipher.decode(engine.export().base)
                do { _ = try await call(["op": "compact", "head": head, "snapshot": encoded(PlaygroundCipher.encrypt(bytes, secret: link.secret))]); lastSnapshot = Date() }
                catch { /* A concurrent writer advanced the room; next poll retries. */ }
            }
            let exported = try engine.export(), delta = try PlaygroundCipher.decode(exported.delta)
            if pending == nil, delta.count > 2, role != "view" {
                pending = Pending(id: UUID().uuidString, update: exported.delta, packet: try PlaygroundCipher.encrypt(delta, secret: link.secret))
            }
            let raw = try engine.command(["op": "presence"]), object = try JSONSerialization.jsonObject(with: raw) as? [String: String]
            let presence = try PlaygroundCipher.encrypt(PlaygroundCipher.decode(object?["bytes"] ?? ""), secret: link.secret, channel: "presence")
            if let pending, try PlaygroundCipher.decode(pending.update).count > 256 * 1024 {
                let full = try PlaygroundCipher.decode(exported.state)
                let result = try await call(["op": "publish", "head": head, "snapshot": encoded(PlaygroundCipher.encrypt(full, secret: link.secret))])
                head = result.head ?? head; self.pending = nil
                try apply(await call(["op": "sync"]))
            } else {
                let updates: [[String: Any]] = pending.map { [["id": $0.id, "packet": encoded($0.packet)]] } ?? []
                let result = try await call(["op": "sync", "after": head, "updates": updates, "presence": encoded(presence)])
                try apply(result); pending = nil
            }
            connected = true; status = "Encrypted source is up to date."
        } catch {
            connected = false
            if (error as? PlaygroundTransport.ServiceFailure)?.statusCode == 401 { token = nil }
            status = "\(error.localizedDescription) Your local edits are kept."
        }
    }
    func change(_ input: [String: Any]) throws {
        guard role != "view" else { throw PlaygroundCRDT.Failure("This room is read-only.") }
        try engine.command(input); state = try engine.view()
    }
    func updateIdentity(_ value: String) throws {
        name = try PlaygroundIdentity.nickname(value)
        try engine.command(["op": "identity", "name": name, "color": PlaygroundIdentity.color(name)]); state = try engine.view()
    }
    func cursor(path: String, anchor: Int, head: Int) {
        _ = try? engine.command(["op": "cursor", "path": path, "anchor": anchor, "head": head])
    }
    private static func boundedOutput(_ text: String) -> String {
        // Bound wire UTF-16 units, including a single very long grapheme cluster.
        String(decoding: text.utf16.prefix(12000), as: UTF16.self)
    }
    func publishResult(files: [String: String], phase: String, stdout: String, stderr: String, succeeded: Bool) throws {
        try change(["op": "run", "result": ["id": UUID().uuidString, "name": name, "phase": phase, "sourceHash": PlaygroundCRDT.sourceHash(files), "stdout": Self.boundedOutput(stdout), "stderr": Self.boundedOutput(stderr), "succeeded": succeeded, "at": Date().timeIntervalSince1970 * 1000]])
    }
    func close() async throws {
        guard let owner else { throw PlaygroundCRDT.Failure("Only the owner can close this room.") }
        struct Closed: Decodable { let closed: Bool }
        let _: Closed = try await transport.call(["op": "close"], token: owner)
    }
}
