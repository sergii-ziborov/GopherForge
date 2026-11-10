import XCTest
@testable import GopherForge

@MainActor final class EncryptedPlaygroundTests: XCTestCase {
    private struct BrowserFixture: Decodable {
        let files: [String: String]; let secret: String; let state: String; let sourceHash: String
        let packet: PlaygroundCipherPacket; let presence: PlaygroundCipherPacket
    }
    private func fixture() throws -> BrowserFixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "browser-room-fixture", withExtension: "json"))
        return try JSONDecoder().decode(BrowserFixture.self, from: Data(contentsOf: url))
    }
    func testBrowserEncryptedYjsSnapshotAndFingerprintLoadInTheActualNativeEngine() throws {
        let f = try fixture(), bytes = try PlaygroundCipher.decrypt(f.packet, secret: f.secret)
        XCTAssertEqual(PlaygroundCipher.encode(bytes), f.state)
        XCTAssertEqual(try PlaygroundCRDT.sourceHash(f.files), f.sourceHash)
        let engine = try PlaygroundCRDT()
        try engine.command(["op": "init"])
        try engine.command(["op": "apply", "snapshot": PlaygroundCipher.encode(bytes)])
        let view = try engine.view()
        XCTAssertEqual(view.files.keys.sorted(), f.files.keys.sorted())
        for (path, source) in f.files { XCTAssertTrue(view.files[path]!.utf8.elementsEqual(source.utf8)) }
        XCTAssertThrowsError(try PlaygroundCipher.decrypt(f.packet, secret: PlaygroundCipher.secret()))
        XCTAssertThrowsError(try PlaygroundCipher.decrypt(f.presence, secret: f.secret))
        XCTAssertEqual(String(decoding: try PlaygroundCipher.decrypt(f.presence, secret: f.secret, channel: "presence"), as: UTF8.self), "public presence fixture")
    }
    func testNativeConcurrentEditsRenameRecoveryAndInvalidUpdates() throws {
        let f = try fixture(), a = try PlaygroundCRDT(), b = try PlaygroundCRDT()
        for engine in [a, b] {
            try engine.command(["op": "init"])
            try engine.command(["op": "apply", "snapshot": f.state])
        }
        try a.command(["op": "edit", "path": "main.go", "text": "// writer A\n" + f.files["main.go"]!])
        try b.command(["op": "edit", "path": "main.go", "text": f.files["main.go"]! + "// writer B\n"])
        try a.command(["op": "rename", "path": "main.go", "target": "renamed.go"])
        try a.command(["op": "apply", "updates": [b.export().delta]])
        try b.command(["op": "apply", "updates": [a.export().delta]])
        XCTAssertEqual(try a.view().files, try b.view().files)
        XCTAssertTrue(try a.view().files["renamed.go"]!.contains("writer A"))
        XCTAssertTrue(try a.view().files["renamed.go"]!.contains("writer B"))
        let id = try XCTUnwrap(a.view().identities["renamed.go"])
        try a.command(["op": "delete", "path": "renamed.go"])
        XCTAssertEqual(try a.view().deleted.first?.id, id)
        try a.command(["op": "restore", "id": id])
        XCTAssertNotNil(try a.view().files["renamed.go"])
        let before = try a.view().files
        XCTAssertThrowsError(try a.command(["op": "apply", "updates": ["invalid_packet"]]))
        XCTAssertEqual(try a.view().files, before)
    }
    func testNamesAndEncryptedLinksAreBoundedAndOriginChecked() throws {
        XCTAssertEqual(try PlaygroundIdentity.nickname("  Ａlex  Go  "), "Alex Go")
        XCTAssertEqual(try PlaygroundIdentity.nickname("Zoë 👩‍💻"), "Zoë 👩‍💻")
        for value in ["", String(repeating: "a", count: 33), "Alex\nAdmin", "Alex\u{202e}Admin"] { XCTAssertThrowsError(try PlaygroundIdentity.nickname(value)) }
        let room = String(repeating: "a", count: 24), cap = String(repeating: "a", count: 24) + "." + String(repeating: "B", count: 32)
        let link = EncryptedPlaygroundLink(room: room, capability: cap, secret: PlaygroundCipher.secret())
        XCTAssertEqual(try EncryptedPlaygroundLink(link.url).secret, link.secret)
        XCTAssertThrowsError(try EncryptedPlaygroundLink(URL(string: link.url.absoluteString.replacingOccurrences(of: "gopherforge.app", with: "evil.example"))!))
        XCTAssertThrowsError(try EncryptedPlaygroundLink(URL(string: "https://gopherforge.app/playground#room=bad&cap=bad&key=bad")!))
    }
}
