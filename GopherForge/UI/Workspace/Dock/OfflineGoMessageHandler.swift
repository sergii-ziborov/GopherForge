import Foundation
import WebKit

/// The only additional browser capability is a bounded, same-project Go request.
@MainActor
final class OfflineGoMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    private let origin: URL
    private let backend: OfflineGoBackend

    init(origin: URL, backend: OfflineGoBackend) {
        self.origin = origin
        self.backend = backend
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.scheme == origin.scheme,
              message.frameInfo.request.url?.host == origin.host,
              JSONSerialization.isValidJSONObject(message.body),
              let data = try? JSONSerialization.data(withJSONObject: message.body), data.count <= 128 * 1024,
              let request = try? JSONDecoder().decode(OfflineGoRequest.self, from: data) else {
            replyHandler(nil, "Invalid local Go request")
            return
        }
        Task { @MainActor in
            do {
                let response = try await backend.response(to: request)
                replyHandler(["status": response.status, "body": response.body, "headers": response.headers], nil)
            } catch { replyHandler(nil, error.localizedDescription) }
        }
    }

    static func install(in configuration: WKWebViewConfiguration, origin: URL, files: [String: String], backend: OfflineGoBackend?) throws {
        guard let data = files[OfflineFrontendRecipe.path]?.data(using: .utf8) else { return }
        let recipe = try JSONDecoder().decode(OfflineFrontendRecipe.self, from: data)
        try recipe.validateBackend()
        guard recipe.backend == "gin-replay" else { return }
        let handler = OfflineGoMessageHandler(origin: origin, backend: backend ?? OfflineGoBackend(files: files, paths: recipe.backendPaths))
        configuration.userContentController.addScriptMessageHandler(handler, contentWorld: .page, name: "gopherforgeGo")
        configuration.userContentController.addUserScript(WKUserScript(source: try script(paths: recipe.backendPaths), injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    static func script(paths: [String]) throws -> String {
        let pathsJSON = String(decoding: try JSONEncoder().encode(paths), as: UTF8.self)
        return """
        (()=>{
          const originalFetch = globalThis.fetch.bind(globalThis);
          const paths = \(pathsJSON);
          const send = window.webkit.messageHandlers.gopherforgeGo.postMessage.bind(window.webkit.messageHandlers.gopherforgeGo);
          Object.defineProperty(globalThis,'fetch',{writable:false,configurable:false,value:async(input,init)=>{
            const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url,location.href);
            const local = url.protocol===location.protocol && url.host===location.host && paths.some(p=>url.pathname===p || url.pathname.startsWith(p+'/'));
            if(!local) return originalFetch(input,init);
            const request = input instanceof Request ? new Request(input,init) : new Request(url.href,init);
            if(request.signal.aborted) throw new DOMException('Aborted','AbortError');
            const headers = Object.fromEntries(request.headers.entries());
            const body = request.method==='GET' || request.method==='HEAD' ? '' : await request.text();
            if(new TextEncoder().encode(body).length>32768) throw new Error('Local Go request exceeds 32 KiB');
            const result = await send({method:request.method,path:url.pathname+url.search,body,headers});
            return new Response([204,205,304].includes(result.status)?null:result.body,{status:result.status,headers:result.headers});
          }});
        })();
        """
    }
}
