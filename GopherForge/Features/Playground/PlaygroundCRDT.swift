import Foundation
import JavaScriptCore
import CryptoKit
import Security

struct PlaygroundPeerCursor: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let color: String
    let path: String
    let anchor: Int
    let head: Int
}

enum PlaygroundIdentity {
    static func nickname(_ value: String) throws -> String {
        let name = value.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        guard !name.isEmpty, name.utf16.count <= 32, name.unicodeScalars.allSatisfy({ scalar in
            let n = scalar.value
            return n > 31 && !(127...159).contains(n) && !(0x202a...0x202e).contains(n) && !(0x2066...0x2069).contains(n)
        }) else {
            throw PlaygroundCRDT.Failure("Use 1–32 characters without control characters.")
        }
        return name
    }
    static func color(_ id: String) -> String {
        ["#63b8c4", "#f1b46b", "#a799ef", "#8bce93"][id.utf16.reduce(0, { $0 + Int($1) }) % 4]
    }
}

struct PlaygroundCipherPacket: Codable, Sendable {
    let iv: String
    let data: String
}

enum PlaygroundCipher {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func decode(_ text: String, maximum: Int = 2 * 1024 * 1024) throws -> Data {
        guard text.utf8.count <= (maximum * 4 + 2) / 3 + 4,
              text.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw PlaygroundCRDT.Failure("Invalid encrypted room data.") }
        var raw = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        raw += String(repeating: "=", count: (4 - raw.count % 4) % 4)
        guard let bytes = Data(base64Encoded: raw), bytes.count <= maximum else { throw PlaygroundCRDT.Failure("Encrypted room data exceeds its limit.") }
        return bytes
    }
    static func secret() -> String { encode(SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }) }
    static func encrypt(_ bytes: Data, secret: String, channel: String = "doc") throws -> PlaygroundCipherPacket {
        let raw = try decode(secret, maximum: 32)
        guard raw.count == 32 else { throw PlaygroundCRDT.Failure("Invalid room encryption key.") }
        let sealed = try AES.GCM.seal(bytes, using: SymmetricKey(data: raw), authenticating: Data("gopherforge-browser-v2:\(channel)".utf8))
        return PlaygroundCipherPacket(iv: encode(sealed.nonce.withUnsafeBytes { Data($0) }), data: encode(sealed.ciphertext + sealed.tag))
    }
    static func decrypt(_ packet: PlaygroundCipherPacket, secret: String, channel: String = "doc") throws -> Data {
        let raw = try decode(secret, maximum: 32), nonce = try decode(packet.iv, maximum: 12), bytes = try decode(packet.data, maximum: 1536 * 1024 + 16)
        guard raw.count == 32, nonce.count == 12, bytes.count >= 16 else { throw PlaygroundCRDT.Failure("Invalid encrypted packet.") }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: bytes.dropLast(16), tag: bytes.suffix(16))
        return try AES.GCM.open(box, using: SymmetricKey(data: raw), authenticating: Data("gopherforge-browser-v2:\(channel)".utf8))
    }
}

/// One trusted, bundled Yjs engine per room. Network input is data, never JavaScript.
@MainActor final class PlaygroundCRDT {
    struct Failure: LocalizedError { let message: String; init(_ message: String) { self.message = message }; var errorDescription: String? { message } }
    struct Peer: Codable, Identifiable { let id: String; let name: String; let color: String }
    struct Deleted: Codable, Identifiable { let id: String; let path: String }
    struct Run: Codable, Identifiable {
        let id: String; let name: String; let phase: String; let sourceHash: String
        let stdout: String; let stderr: String; let succeeded: Bool; let at: Double
    }
    struct Change: Codable, Identifiable { let id: String; let name: String; let at: Double; let paths: [String]; let kind: String }
    struct View: Codable {
        let changes: [Change]
        let files: [String: String]; let identities: [String: String]; let deleted: [Deleted]
        let runs: [Run]; let conflicts: Int; let cursors: [PlaygroundPeerCursor]; let peers: [Peer]
    }
    struct Export: Codable { let state: String; let base: String; let delta: String; let pending: Bool }
    private let context: JSContext
    init() throws {
        guard let context = JSContext() else { throw Failure("Could not prepare collaborative editing.") }
        self.context = context
        let random: @convention(block) (Int) -> NSArray = { count in
            var bytes = [UInt8](repeating: 0, count: min(65536, max(0, count)))
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return [] }
            return bytes.map { NSNumber(value: $0) } as NSArray
        }
        let uuid: @convention(block) () -> String = { UUID().uuidString.lowercased() }
        let encode: @convention(block) (String) -> NSArray = { Array($0.utf8).map { NSNumber(value: $0) } as NSArray }
        let decode: @convention(block) (NSArray) -> String = { value in String(decoding: value.compactMap { ($0 as? NSNumber)?.uint8Value }, as: UTF8.self) }
        let to64: @convention(block) (String) -> String = { Data($0.utf16.map { UInt8(truncatingIfNeeded: $0) }).base64EncodedString() }
        let from64: @convention(block) (String) -> String = { text in
            var padded = text; padded += String(repeating: "=", count: (4 - text.count % 4) % 4)
            return (Data(base64Encoded: padded) ?? Data()).map { String(UnicodeScalar($0)) }.joined()
        }
        for (name, block) in [("__randomBytes", random as Any), ("__uuid", uuid as Any), ("__utf8Encode", encode as Any), ("__utf8Decode", decode as Any), ("__to64", to64 as Any), ("__from64", from64 as Any)] {
            context.setObject(block, forKeyedSubscript: name as NSString)
        }
        context.evaluateScript("""
        globalThis.crypto={getRandomValues:a=>{const bytes=__randomBytes(a.byteLength);if(bytes.length!==a.byteLength)throw new Error("Secure random unavailable");new Uint8Array(a.buffer,a.byteOffset,a.byteLength).set(bytes);return a},randomUUID:()=>__uuid()};
        globalThis.TextEncoder=class{encode(s){return Uint8Array.from(__utf8Encode(String(s)))}};
        globalThis.TextDecoder=class{decode(a){return __utf8Decode(Array.from(a||[]))}};
        globalThis.btoa=s=>__to64(s);globalThis.atob=s=>__from64(s);
        globalThis.setInterval=()=>0;globalThis.clearInterval=()=>{};
        globalThis.setTimeout=()=>0;globalThis.clearTimeout=()=>{};
        """)
        guard let url = Bundle.main.url(forResource: "PlaygroundCRDT", withExtension: "js") else { throw Failure("The collaborative editor resource is missing.") }
        context.evaluateScript(try String(contentsOf: url, encoding: .utf8))
        if let exception = context.exception { throw Failure(exception.toString() ?? "Could not prepare collaborative editing.") }
    }
    @discardableResult func command(_ input: [String: Any]) throws -> Data {
        context.exception = nil
        let data = try JSONSerialization.data(withJSONObject: input)
        guard let output = context.objectForKeyedSubscript("GopherForgeCRDT")?.invokeMethod("command", withArguments: [String(decoding: data, as: UTF8.self)])?.toString(),
              let raw = output.data(using: .utf8), let reply = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { throw Failure("Invalid collaborative editor response.") }
        guard reply["ok"] as? Bool == true else { throw Failure(reply["error"] as? String ?? "Invalid shared source.") }
        return try JSONSerialization.data(withJSONObject: reply["value"] ?? [:])
    }
    func view() throws -> View { try JSONDecoder().decode(View.self, from: command(["op": "view"])) }
    func export() throws -> Export { try JSONDecoder().decode(Export.self, from: command(["op": "export"])) }
    static func sourceHash(_ files: [String: String]) throws -> String {
        let pairs = files.keys.sorted().map { [$0, files[$0]!] }
        let data = try JSONSerialization.data(withJSONObject: pairs, options: [.withoutEscapingSlashes, .fragmentsAllowed])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
