import Foundation
import Observation

/// No background fetch, launch download, partial install or automatic update.
@MainActor @Observable
final class CourseDownloadsModel {
    static let shared = CourseDownloadsModel()
    let library: CourseLibrary
    private(set) var revision = 0
    private(set) var downloadingID: String?
    /// Shown on the failed course's own card, wherever that card is, rather
    /// than in an alert only the downloads screen presents.
    private(set) var failedDownload: (id: String, message: String)?
    var error: String?
    private var downloadTask: Task<Void, Never>?

    init(library: CourseLibrary = .shared) { self.library = library }

    func download(_ descriptor: CourseDownload) {
        guard downloadingID == nil else { return }
        downloadingID = descriptor.id; failedDownload = nil
        downloadTask = Task {
            defer { downloadingID = nil; downloadTask = nil }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 180
            let session = URLSession(configuration: configuration, delegate: CourseRedirectPolicy(), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            do {
                let url = URL(string: "https://gopherforge.app/downloads/courses/")!.appending(path: descriptor.fileName)
                let (data, response) = try await BoundedDownload.load(url, limit: CourseLibrary.maximumPackageBytes, session: session)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      http.url?.scheme == "https", http.url?.host == "gopherforge.app" else {
                    throw CourseContentError.invalid("The course server could not provide a complete download. Try again when connected.")
                }
                try library.install(data, descriptor: descriptor)
                revision += 1
            } catch is CancellationError {
                // A cancelled transfer leaves the installed revision intact.
            } catch {
                if !Task.isCancelled { failedDownload = (descriptor.id, error.localizedDescription) }
            }
        }
    }

    func cancel() { downloadTask?.cancel() }
    func remove(_ descriptor: CourseDownload) {
        guard downloadingID == nil else { return }
        do { try library.remove(descriptor); revision += 1 }
        catch { self.error = error.localizedDescription }
    }
    func importCourse(_ url: URL) {
        guard downloadingID == nil else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try CourseLibrary.readBounded(url)
            // Validate before decoding any untrusted document into the catalog.
            guard let descriptor = library.catalog.first(where: { (try? CourseLibrary.validate(data, against: $0)) != nil }) else {
                throw CourseContentError.invalid("Choose a complete official course for this app version. Its size and checksum must match the catalog.")
            }
            try library.install(data, descriptor: descriptor); revision += 1
        } catch { self.error = error.localizedDescription }
    }
}

private final class CourseRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" && request.url?.host == "gopherforge.app" ? request : nil)
    }
}
