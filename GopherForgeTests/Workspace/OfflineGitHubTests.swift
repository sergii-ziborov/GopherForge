import CryptoKit
import XCTest
import WebKit
@testable import GopherForge

final class OfflineGitHubTests: XCTestCase {
    @MainActor
    func testPinnedGitHubReactAndGoCRUDWorkInsideTheOfflinePreview() async throws {
        // Developer-only fixture. Never a resource or an example in the app.
        let fixtureURL = try TestRepoRoot.url().appending(path: "build/test-fixtures/OfflineGitHubDogs.json")
        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Run python3 scripts/prepare_github_frontend_check.py to prepare the external test checkout.")
        }
        let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        let upstreamFiles = try XCTUnwrap(fixture["files"] as? [String: String])
        var projectFiles = GoExampleGinVendor.files(modulePath: "example.com/github-dogs-offline")
        projectFiles.merge(upstreamFiles) { _, external in external }
        let expected = try XCTUnwrap(fixture["upstreamSHA256"] as? [String: String])
        for (source, path) in [("client/src/App.js", "web/src/App.js"), ("server/main.go", "main.go"), ("LICENSE", "LICENSE.upstream")] {
            let contents = try XCTUnwrap(projectFiles[path])
            XCTAssertEqual(SHA256.hash(data: Data(contents.utf8)).map { String(format: "%02x", $0) }.joined(), expected[source])
        }
        let builder = OfflineFrontendBuilder()
        var files = projectFiles
        files[OfflineFrontendRecipe.lockPath] = try await builder.plan(files: files).lock
        let result = try await builder.build(files: files)
        files.merge(result.generated) { _, generated in generated }
        let url = URL(string: "gopherforge-preview://github-dogs-test/")!
        let backend = OfflineGoBackend(files: files, paths: ["/dogs"])
        let coordinator = OfflineFrontendWebView.Coordinator(url: url, generation: 0, files: files, backend: backend)
        let view = try await OfflineFrontendWebView.makeWebView(coordinator: coordinator)
        // A visible host avoids WebKit freezing a zero-sized, detached test view.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        window.rootViewController?.view.addSubview(view)
        window.makeKeyAndVisible()
        view.load(URLRequest(url: url))
        defer { view.stopLoading(); window.isHidden = true }
        try await wait(view, for: "document.querySelectorAll('tbody tr').length===3", reason: "initial GET must execute the Go handler")
        let initial = try await view.evaluateJavaScript("document.body.textContent") as? String ?? ""
        XCTAssertTrue(initial.contains("Fido") && initial.contains("Labrador"), initial)

        _ = try await view.evaluateJavaScript("""
            const fields=document.querySelectorAll('form input');
            const setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;
            setter.call(fields[0],'Offline puppy'); fields[0].dispatchEvent(new Event('input',{bubbles:true}));
            setter.call(fields[1],'Go gopher'); fields[1].dispatchEvent(new Event('input',{bubbles:true}));
            """)
        _ = try await view.evaluateJavaScript("document.querySelector('form').requestSubmit()")
        try await wait(view, for: "document.querySelectorAll('tbody tr').length===4 && document.body.innerText.includes('Offline puppy')", reason: "POST must reach the real Go handler")
        let created = try await view.callAsyncJavaScript("return await (await fetch('/dogs')).json();", in: nil, contentWorld: .page) as? [[String: Any]]
        XCTAssertEqual(created?.last?["id"] as? Int, 4)
        XCTAssertEqual(created?.last?["name"] as? String, "Offline puppy")

        _ = try await view.evaluateJavaScript("document.querySelector('tbody tr button').click()")
        _ = try await view.evaluateJavaScript("""
            const edit=document.querySelector('tbody input');
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(edit,'Edited offline');
            edit.dispatchEvent(new Event('input',{bubbles:true}));
            """)
        _ = try await view.evaluateJavaScript("document.querySelector('tbody tr button').click()")
        try await wait(view, for: "document.body.innerText.includes('Edited offline') && !document.querySelector('tbody input')", reason: "PUT must update the Go model and React state")
        let updated = try await view.callAsyncJavaScript("return await (await fetch('/dogs')).json();", in: nil, contentWorld: .page) as? [[String: Any]]
        XCTAssertEqual(updated?.first?["name"] as? String, "Edited offline")

        _ = try await view.evaluateJavaScript("document.querySelectorAll('tbody tr')[3].querySelectorAll('button')[1].click()")
        try await wait(view, for: "document.querySelectorAll('tbody tr').length===3 && !document.body.innerText.includes('Offline puppy')", reason: "DELETE must change both Go and React state")
        let remaining = try await view.callAsyncJavaScript("return await (await fetch('/dogs')).json();", in: nil, contentWorld: .page) as? [[String: Any]]
        XCTAssertEqual(remaining?.count, 3)
        XCTAssertFalse(remaining?.contains(where: { $0["name"] as? String == "Offline puppy" }) ?? true)

        let fullCoordinator = OfflineFrontendWebView.Coordinator(url: url, generation: 0, files: files, backend: backend)
        let fullView = try await OfflineFrontendWebView.makeWebView(coordinator: fullCoordinator)
        fullView.frame = view.frame
        window.rootViewController?.view.addSubview(fullView)
        fullView.load(URLRequest(url: url))
        defer { fullView.stopLoading() }
        try await wait(fullView, for: "document.querySelectorAll('tbody tr').length===3 && document.body.innerText.includes('Edited offline')", reason: "full-screen preview must share the current Go API state")

        let denied = try await view.callAsyncJavaScript("""
            try { await window.webkit.messageHandlers.gopherforgeGo.postMessage({method:'GET',path:'https://example.invalid/private',body:'',headers:{}}); return false; } catch { return true; }
            """, in: nil, contentWorld: .page) as? Bool
        XCTAssertEqual(denied, true)
        let externalBlocked = try await view.callAsyncJavaScript("try { await fetch('https://example.invalid'); return false; } catch { return true; }", in: nil, contentWorld: .page) as? Bool
        XCTAssertEqual(externalBlocked, true)
        XCTAssertEqual(view.url?.scheme, OfflinePreviewResources.scheme)
    }

    @MainActor
    private func wait(_ view: WKWebView, for script: String, reason: String) async throws {
        for _ in 0..<300 {
            if (try? await view.evaluateJavaScript(script)) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        let body = (try? await view.evaluateJavaScript("document.body.innerText")) as? String ?? "no body"
        XCTFail("\(reason): \(body)")
        throw OfflineFrontendError.message(reason)
    }
}
