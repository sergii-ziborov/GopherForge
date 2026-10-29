import Foundation

struct OfflineGoRequest: Codable, Sendable {
    let method: String
    let path: String
    let body: String
    let headers: [String: String]
}

struct OfflineGoResponse: Codable, Sendable {
    let status: Int
    let body: String
    let headers: [String: String]
}

/// Runs real Go handlers with httptest. A bounded mutation log reconstructs
/// deterministic, in-memory teaching services between fresh WASI invocations.
actor OfflineGoBackend {
    private let files: [String: String]
    private let paths: [String]
    private let compiler = WasmGoCompiler()
    private var history: [OfflineGoRequest] = []
    private var tail: Task<OfflineGoResponse, Error>?

    init(files: [String: String], paths: [String]) {
        self.files = files
        self.paths = paths
    }

    func response(to request: OfflineGoRequest) async throws -> OfflineGoResponse {
        let previous = tail
        let next = Task { [self] in
            _ = await previous?.result
            return try await perform(request)
        }
        tail = next
        return try await next.value
    }

    private func perform(_ request: OfflineGoRequest) async throws -> OfflineGoResponse {
        guard ["GET", "POST", "PUT", "PATCH", "DELETE"].contains(request.method),
              request.path.hasPrefix("/"), !request.path.hasPrefix("//"),
              !request.path.contains("\\"), !request.path.contains("\0"),
              let components = URLComponents(string: request.path),
              components.scheme == nil, components.host == nil, components.fragment == nil,
              !LocalSiteFiles.isUnsafe(components.percentEncodedPath),
              paths.contains(where: { components.path == $0 || components.path.hasPrefix($0 + "/") }),
              request.body.utf8.count <= 32 * 1024,
              request.headers.count <= 32,
              request.headers.allSatisfy({ $0.key.utf8.count <= 128 && $0.value.utf8.count <= 2048 && !$0.key.contains("\n") && !$0.value.contains("\n") && !$0.key.contains("\r") && !$0.value.contains("\r") }),
              request.path.utf8.count <= 4096 else {
            throw OfflineFrontendError.message("The request is outside this preview's local API paths or limits.")
        }
        guard history.count < 64 || request.method == "GET" else {
            throw OfflineFrontendError.message("This teaching API reached 64 mutations. Rebuild or reopen the project to reset its temporary state.")
        }
        let data = try JSONEncoder().encode(history + [request])
        guard data.count <= 2 * 1024 * 1024 else { throw OfflineFrontendError.message("Offline API history exceeds 2 MiB.") }
        let snapshot = GoSourceSnapshot(files: files, packagePattern: ".", runtimeRequest: String(decoding: data, as: UTF8.self))
        let result = await compiler.run(project: snapshot)
        guard result.succeeded, let text = result.sandboxResponse,
              let response = try? JSONDecoder().decode(OfflineGoResponse.self, from: Data(text.utf8)),
              (200...599).contains(response.status), response.body.utf8.count <= 256 * 1024 else {
            throw OfflineFrontendError.message("The local Go API did not return a bounded response. Use the Gin replay adapter. \(result.detail)\n\(result.stderr)")
        }
        if request.method != "GET" { history.append(request) }
        return response
    }
}
