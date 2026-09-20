import XCTest
import WebKit
@testable import GopherForge

final class LocalSiteServerTests: XCTestCase {
    func testASiteIsRecognisedByItsPages() {
        XCTAssertTrue(LocalSiteFiles.isSite(["web/index.html": "<p>hi</p>"]))
        XCTAssertFalse(LocalSiteFiles.isSite(["main.go": "package main\n"]))
    }

    func testPathsMapOntoProjectFilesAndRejectTraversal() throws {
        let files = [
            "web/index.html": "<h1>home</h1>",
            "web/about.html": "<h1>about</h1>",
            "web/styles.css": "body{}",
            "web/app.js": "console.log(1)",
            "web/api/health.json": #"{"ok":true}"#,
            "main.go": "package main",
            "vendor/github.com/gin-gonic/gin/gin.go": "package gin",
        ]
        XCTAssertEqual(
            String(data: try XCTUnwrap(LocalSiteFiles.resource(for: "/", in: files)).body, encoding: .utf8),
            "<h1>home</h1>"
        )
        XCTAssertEqual(
            String(data: try XCTUnwrap(LocalSiteFiles.resource(for: "/about", in: files)).body, encoding: .utf8),
            "<h1>about</h1>"
        )
        XCTAssertEqual(LocalSiteFiles.resource(for: "/styles.css", in: files)?.contentType, "text/css; charset=utf-8")
        XCTAssertEqual(LocalSiteFiles.resource(for: "/app.js", in: files)?.contentType, "text/javascript; charset=utf-8")
        XCTAssertEqual(
            String(data: try XCTUnwrap(LocalSiteFiles.resource(for: "/api/health", in: files)).body, encoding: .utf8),
            #"{"ok":true}"#
        )
        XCTAssertEqual(
            LocalSiteFiles.resource(for: "/styles.css?cache=1", in: files)?.contentType,
            "text/css; charset=utf-8"
        )
        XCTAssertNil(LocalSiteFiles.resource(for: "/../web/index.html", in: files))
        XCTAssertNil(LocalSiteFiles.resource(for: "/main.go", in: files))
        XCTAssertNil(LocalSiteFiles.resource(for: "/vendor/github.com/gin-gonic/gin/gin.go", in: files))
        XCTAssertNil(LocalSiteFiles.resource(for: "/missing", in: files))
    }

    func testLoopbackServesEveryPageOfAGinExample() async throws {
        for example in GoExampleLibrarySites.all {
            let server = LocalSiteServer()
            try server.publish(example.files)
            defer { server.stop() }
            let root = try XCTUnwrap(server.url)

            let home = try await fetch(root)
            XCTAssertEqual(home.status, 200, example.id)
            XCTAssertTrue(home.body.contains("<html"), example.id)

            let css = try await fetch(root.appending(path: "styles.css"))
            XCTAssertEqual(css.status, 200, example.id)
            XCTAssertTrue(css.body.contains("{"), example.id)

            let js = try await fetch(root.appending(path: "app.js"))
            XCTAssertEqual(js.status, 200, example.id)
            XCTAssertTrue(js.body.contains("function") || js.body.contains("const") || js.body.contains("fetch"), example.id)

            let missing = try await fetch(root.appending(path: "no-such-page"))
            XCTAssertEqual(missing.status, 404, example.id)
        }
    }

    func testCafeAboutAndHealthAreReachable() async throws {
        let example = GoExampleProjectGinCafe.cafe
        let server = LocalSiteServer()
        try server.publish(example.files)
        defer { server.stop() }
        let root = try XCTUnwrap(server.url)

        let about = try await fetch(root.appending(path: "about"))
        XCTAssertEqual(about.status, 200)
        XCTAssertTrue(about.body.contains("About"))

        let health = try await fetch(root.appending(path: "api/health"))
        XCTAssertEqual(health.status, 200)
        XCTAssertTrue(health.body.contains("Gopher Café") || health.body.contains("ok"))
    }

    func testEditedWebFileIsServedWithoutRestartingTheSite() async throws {
        let server = LocalSiteServer()
        try server.publish(["web/index.html": "<html>before</html>"])
        defer { server.stop() }
        let root = try XCTUnwrap(server.url)
        let before = try await fetch(root)
        XCTAssertTrue(before.body.contains("before"))

        try server.publish(["web/index.html": "<html>after</html>"])
        XCTAssertEqual(server.url, root)
        let after = try await fetch(root)
        XCTAssertTrue(after.body.contains("after"))
    }

    func testShopCartAndCatalogAreReachable() async throws {
        let server = LocalSiteServer()
        try server.publish(GoExampleProjectGinShop.shop.files)
        defer { server.stop() }
        let root = try XCTUnwrap(server.url)

        let cart = try await fetch(root.appending(path: "cart"))
        XCTAssertEqual(cart.status, 200)
        XCTAssertTrue(cart.body.contains("cart") || cart.body.contains("Cart"))

        let catalog = try await fetch(root.appending(path: "api/catalog"))
        XCTAssertEqual(catalog.status, 200)
        XCTAssertTrue(catalog.body.contains("Compiler mug"))
    }

    @MainActor
    func testEachSiteLoadsItsAssetsAndJavaScriptInWebKit() async throws {
        for example in GoExampleLibrarySites.all {
            let server = LocalSiteServer()
            try server.publish(example.files)
            defer { server.stop() }

            let webView = WKWebView()
            let loaded = expectation(description: "loaded \(example.id)")
            let delegate = SiteNavigationDelegate(loaded)
            webView.navigationDelegate = delegate
            webView.load(URLRequest(url: try XCTUnwrap(server.url)))
            await fulfillment(of: [loaded], timeout: 15)

            let title = try await webView.evaluateJavaScript("document.title") as? String
            XCTAssertFalse((title ?? "").isEmpty, example.id)
            let background = try await webView.evaluateJavaScript(
                "getComputedStyle(document.body).backgroundColor"
            ) as? String
            XCTAssertNotEqual(background, "rgba(0, 0, 0, 0)", example.id)

            let readyExpression: String
            switch example.id {
            case "site.cafe":
                readyExpression = "document.querySelector('#status').textContent.includes('Gopher Café')"
            case "site.notes":
                readyExpression = "document.querySelector('#hint').textContent.includes('Notes stay')"
            case "site.shop":
                readyExpression = "document.querySelectorAll('#shelf .card').length === 3"
            default:
                XCTFail("Unexpected site \(example.id)")
                continue
            }
            var ready = false
            for _ in 0..<40 {
                ready = try await webView.evaluateJavaScript(readyExpression) as? Bool ?? false
                if ready { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertTrue(ready, "Assets or fetch did not finish for \(example.id)")

            if example.id == "site.cafe" {
                let greeting = try await webView.evaluateJavaScript("""
                    document.querySelector('#next').click();
                    document.querySelector('#greeting').textContent;
                    """) as? String
                XCTAssertTrue((greeting ?? "").contains("Sit anywhere"))
            } else if example.id == "site.notes" {
                let pinned = try await webView.evaluateJavaScript("""
                    document.querySelector('#text').value = 'A real note';
                    document.querySelector('#composer').dispatchEvent(
                      new Event('submit', {bubbles: true, cancelable: true}));
                    document.querySelector('#board').textContent.includes('A real note');
                    """) as? Bool
                XCTAssertEqual(pinned, true)
            } else if example.id == "site.shop" {
                let count = try await webView.evaluateJavaScript("""
                    document.querySelector('#shelf button').click();
                    document.querySelector('#count').textContent;
                    """) as? String
                XCTAssertEqual(count, "1")
            }
        }
    }

    private func fetch(_ url: URL) async throws -> (status: Int, body: String) {
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        return (http.statusCode, String(decoding: data, as: UTF8.self))
    }
}

private final class SiteNavigationDelegate: NSObject, WKNavigationDelegate {
    private let loaded: XCTestExpectation

    init(_ loaded: XCTestExpectation) { self.loaded = loaded }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded.fulfill()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        XCTFail("Site navigation failed: \(error)")
        loaded.fulfill()
    }
}
