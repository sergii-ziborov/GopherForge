import Foundation

/// Reads the official Go checksum database.
///
/// Every module published through the proxy has its `h1:` hash recorded here,
/// and that record is what `go.sum` would contain. The app downloads a module,
/// computes the same hash itself, and refuses to write anything into a project
/// unless the two agree.
///
/// What this does **not** do is verify the signed transparency-log proof. The
/// note is signed by `sum.golang.org` and the full check involves a Merkle tree
/// and a public key; skipping it means the trust here is TLS to a Google
/// endpoint rather than the log's own signature. That is a real limitation, it
/// is stated in Settings, and it is still far stronger than downloading a zip
/// and running whatever comes out.
struct GoChecksumDatabase: Sendable {
    enum ChecksumError: Error, Equatable {
        case notFound(String)
        case badStatus(Int)
        case noHashInResponse(String)
        /// The download and the database disagree. Nothing is written.
        case mismatch(expected: String, actual: String)
    }

    /// What the database says about one module version.
    struct Record: Equatable, Sendable {
        /// The `h1:` hash of the module zip.
        let moduleHash: String
        /// The `h1:` hash of the `go.mod`, which `go.sum` also records.
        let goModHash: String
    }

    let baseURL: URL
    private let transport: any GoHTTPTransport

    init(
        baseURL: URL = URL(string: "https://sum.golang.org")!,
        transport: any GoHTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func record(for reference: GoModuleReference) async throws -> Record {
        let url = baseURL.appendingPathComponent("lookup/\(reference.path)@\(reference.version)")
        let (data, status) = try await transport.get(url)
        switch status {
        case 200: break
        case 404, 410: throw ChecksumError.notFound(reference.id)
        default: throw ChecksumError.badStatus(status)
        }
        return try Self.parse(String(decoding: data, as: UTF8.self), for: reference)
    }

    /// The response opens with a record number, then the `go.sum` lines for
    /// this module, then the signed tree. Only the two lines are read here.
    static func parse(_ response: String, for reference: GoModuleReference) throws -> Record {
        var moduleHash: String?
        var goModHash: String?

        for line in response.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ").map(String.init)
            guard fields.count == 3, fields[0] == reference.path, fields[2].hasPrefix("h1:") else {
                continue
            }
            if fields[1] == reference.version {
                moduleHash = fields[2]
            } else if fields[1] == "\(reference.version)/go.mod" {
                goModHash = fields[2]
            }
        }

        guard let moduleHash, let goModHash else {
            throw ChecksumError.noHashInResponse(reference.id)
        }
        return Record(moduleHash: moduleHash, goModHash: goModHash)
    }

    /// The `go.sum` lines this module contributes, written verbatim into the
    /// project so the record travels with the code.
    static func goSumLines(for reference: GoModuleReference, record: Record) -> String {
        """
        \(reference.path) \(reference.version) \(record.moduleHash)
        \(reference.path) \(reference.version)/go.mod \(record.goModHash)

        """
    }
}
