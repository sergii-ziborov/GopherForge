import Foundation
import WebKit

@MainActor
enum OfflinePreviewPolicy {
    static func apply(to configuration: WKWebViewConfiguration) async throws {
        let rules = #"[{"trigger":{"url-filter":"^https?://.*"},"action":{"type":"block"}},{"trigger":{"url-filter":"^wss?://.*"},"action":{"type":"block"}},{"trigger":{"url-filter":"^file:.*"},"action":{"type":"block"}}]"#
        let list = try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "gopherforge-offline-v1", encodedContentRuleList: rules)
        if let list { configuration.userContentController.add(list) }
        else { throw OfflineFrontendError.message("The offline network policy could not be installed.") }
        configuration.userContentController.addUserScript(WKUserScript(source: """
            for (const name of ['WebSocket','WebTransport','RTCPeerConnection','webkitRTCPeerConnection','Worker','SharedWorker']) {
              Object.defineProperty(globalThis,name,{value:undefined,writable:false,configurable:false});
            }
            Object.defineProperty(globalThis,'open',{value:()=>null,writable:false,configurable:false});
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    }
}

@MainActor
final class OfflinePreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    var resources: OfflinePreviewResources

    init(resources: OfflinePreviewResources) { self.resources = resources }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              urlSchemeTask.request.httpMethod == nil || urlSchemeTask.request.httpMethod == "GET",
              let resource = resources.resource(for: url) else {
            urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": resource.contentType,
            "Content-Length": String(resource.body.count),
            "Content-Security-Policy": OfflinePreviewResources.contentSecurityPolicy,
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff"
        ])!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(resource.body)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
