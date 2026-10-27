import XCTest
import WebKit
@testable import GopherForge

final class OfflineFrontendTests: XCTestCase {
    func testBundledWASIBuildsTypeScriptWithoutANetworkOrNodeRuntime() async throws {
        let builder = OfflineFrontendBuilder()
        var files = [
            "package.json": "{\"dependencies\":{}}",
            "gopherforge.frontend.json": "{\"entry\":\"web/src/main.ts\",\"html\":\"web/index.html\",\"output\":\"web/dist\",\"minify\":true}",
            "web/index.html": "<!doctype html><div id=\"root\"></div><!-- gopherforge:assets -->",
            "web/src/main.ts": "const value: number = 42; document.getElementById('root')!.textContent = String(value);"
        ]
        files[OfflineFrontendRecipe.lockPath] = try await builder.plan(files: files).lock
        let result = try await builder.build(files: files)
        XCTAssertTrue(result.stdout.contains("Offline browser build completed"))
        XCTAssertTrue(result.generated["web/dist/assets/app.js"]?.contains("42") == true)
        XCTAssertTrue(result.generated["web/dist/index.html"]?.contains("/assets/app.js") == true)
        XCTAssertFalse(result.generated.keys.contains { $0.contains("node_modules") })
    }

    @MainActor
    func testReactBuildRendersAndInteractsInsideTheOfflinePreview() async throws {
        let builder = OfflineFrontendBuilder()
        var files = GoExampleProjectReactStudy.board.files
        files[OfflineFrontendRecipe.lockPath] = try await builder.plan(files: files).lock
        let build = try await builder.build(files: files)
        files.merge(build.generated) { _, generated in generated }
        XCTAssertTrue(OfflineFrontendPlan.previewReady(files: files))
        XCTAssertGreaterThan(files["web/dist/assets/app.js"]?.utf8.count ?? 0, 50_000)
        XCTAssertNotNil(files["web/dist/assets/app.css"])

        let url = URL(string: "gopherforge-preview://react-test/")!
        let coordinator = OfflineFrontendWebView.Coordinator(url: url, generation: 0, files: files)
        let view = try await OfflineFrontendWebView.makeWebView(coordinator: coordinator)
        view.load(URLRequest(url: url))
        defer { view.stopLoading() }

        var ready = false
        for _ in 0..<80 {
            ready = (try? await view.evaluateJavaScript("document.querySelectorAll('#tasks li').length === 2 && document.querySelector('#topics').textContent.includes('Sandbox')")) as? Bool ?? false
            if ready { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let body = (try? await view.evaluateJavaScript("document.body.innerText")) as? String ?? "no body"
        XCTAssertTrue(ready, "React components or local JSON did not load: \(body)")
        guard ready else { return }
        let background = try await view.evaluateJavaScript("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(background, "rgb(245, 243, 235)")

        _ = try await view.evaluateJavaScript("""
            const field = document.querySelector('#task');
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(field,'A local React task');
            field.dispatchEvent(new Event('input',{bubbles:true}));
            """)
        _ = try await view.evaluateJavaScript("document.querySelector('form').requestSubmit()")
        for _ in 0..<30 {
            if (try await view.evaluateJavaScript("document.querySelectorAll('#tasks li').length") as? Int) == 3 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let addedCount = try await view.evaluateJavaScript("document.querySelectorAll('#tasks li').length") as? Int
        XCTAssertEqual(addedCount, 3)
        _ = try await view.evaluateJavaScript("document.querySelectorAll('#tasks input')[1].click()")
        _ = try await view.evaluateJavaScript("document.querySelectorAll('nav button')[2].click()")
        try await Task.sleep(for: .milliseconds(100))
        let doneCount = try await view.evaluateJavaScript("document.querySelectorAll('#tasks li').length") as? Int
        XCTAssertEqual(doneCount, 2)

        let count = RequestCounter()
        let probe = LocalSiteServer(onRequest: { _ in count.increment() })
        try probe.publish(["web/index.html": "network probe"])
        defer { probe.stop() }
        let probeURL = try XCTUnwrap(probe.url)
        _ = try await URLSession.shared.data(from: probeURL)
        XCTAssertEqual(count.value, 1, "the probe must be reachable from the host test")
        let encodedURL = String(decoding: try JSONEncoder().encode(probeURL.absoluteString), as: UTF8.self)
        let blocked = try await view.callAsyncJavaScript("""
            try { await fetch(\(encodedURL)); return false; } catch { return true; }
            """, in: nil, contentWorld: .page) as? Bool
        XCTAssertEqual(blocked, true)
        _ = try await view.evaluateJavaScript("const image = new Image(); image.src = \(encodedURL) + '?image'; document.body.append(image);")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(count.value, 1, "project fetch and image loads must not reach even a loopback TCP listener")
        let disabledAPIs = try await view.evaluateJavaScript("typeof WebSocket + ',' + typeof RTCPeerConnection + ',' + typeof Worker") as? String
        let popupBlocked = try await view.evaluateJavaScript("window.open('https://example.invalid')===null") as? Bool
        XCTAssertEqual(disabledAPIs, "undefined,undefined,undefined")
        XCTAssertEqual(popupBlocked, true)
        XCTAssertNil(coordinator.handler.resources.resource(for: URL(string: "gopherforge-preview://another-project/api/summary")!))
        XCTAssertNil(coordinator.handler.resources.resource(for: URL(string: "gopherforge-preview://react-test/main.go")!))
        files["web/src/model.ts"]! += "\n// changed"
        XCTAssertFalse(OfflineFrontendPlan.previewReady(files: files), "a stale bundle must not appear current")
    }

    func testPlansRejectUnknownPackagesAndEscapingOrOwnedOutputPaths() async throws {
        let builder = OfflineFrontendBuilder()
        var files = GoExampleProjectReactStudy.board.files
        files["package.json"] = "{\"dependencies\":{\"not-in-offline-catalog\":\"1.0.0\"}}"
        do { _ = try await builder.plan(files: files); XCTFail("unknown package accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("No download was attempted")) }
        files = GoExampleProjectReactStudy.board.files
        files[OfflineFrontendRecipe.path] = "{\"entry\":\"../main.tsx\",\"html\":\"web/index.html\",\"output\":\"web/dist\"}"
        do { _ = try await builder.plan(files: files); XCTFail("escaping path accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("inside the project")) }
        files = GoExampleProjectReactStudy.board.files
        files["web/dist/keep.txt"] = "user content"
        do { _ = try await builder.plan(files: files); XCTFail("existing output files accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("preserve")) }
    }

    func testOnlyTheDocumentedOfflineCommandSubsetIsAccepted() throws {
        XCTAssertEqual(OfflineFrontendCommand.parse(["npm", "install", "--offline"]), .install(frozen: false))
        XCTAssertEqual(OfflineFrontendCommand.parse(["bun", "install", "--frozen-lockfile"]), .install(frozen: true))
        XCTAssertEqual(OfflineFrontendCommand.parse(["npm", "run", "build"]), .build(packageScript: true))
        XCTAssertNil(OfflineFrontendCommand.parse(["npm", "run", "build", "&&", "curl", "https://example.invalid"]))
        XCTAssertNil(OfflineFrontendCommand.parse(["bun", "run", "server.ts"]))
        var files = GoExampleProjectReactStudy.board.files
        files["package.json"] = "{\"scripts\":{\"build\":\"touch /outside && curl https://example.invalid\"}}"
        XCTAssertThrowsError(try OfflineFrontendCommand.build(packageScript: true).validateScript(in: files))
    }

    func testFixedCatalogRangesAndTransitiveRequirements() throws {
        for range in ["19.3.1", "^19.3.0", "~19.3.0", "*"] {
            XCTAssertTrue(OfflineFrontendCatalog.matches("19.3.1", range: range), range)
        }
        for range in ["^19.3.1.bad", "^19..3.1", "^19.3.-1", "^19.3.01", "^20.0.0", "~19.2.0", "latest", "file:react", "https://example.invalid/react.tgz"] {
            XCTAssertFalse(OfflineFrontendCatalog.matches("19.3.1", range: range), range)
        }
        let react = OfflineFrontendPackage(name: "react", version: "19.3.1", integrity: "test", dependencies: [:], files: [:])
        let dom = OfflineFrontendPackage(name: "react-dom", version: "19.3.1", integrity: "test", dependencies: ["react": "^19.3.1"], files: [:])
        let catalog = OfflineFrontendCatalog(format: 1, packages: [react, dom])
        XCTAssertEqual(try catalog.resolve(["react-dom": "19.3.1"]).map(\.name), ["react", "react-dom"])
        XCTAssertThrowsError(try catalog.resolve(["react": "18.0.0", "react-dom": "19.3.1"]))
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}
