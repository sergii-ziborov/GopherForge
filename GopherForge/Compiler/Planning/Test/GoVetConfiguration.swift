import Foundation

/// The JSON `cmd/vet` expects when it is driven directly.
///
/// `vet` refuses to be invoked with source files — it says so in as many words
/// — because its analyses need type information and the facts other packages
/// exported. `go vet` therefore hands it a unit-check configuration instead,
/// and so does this app: same tool, same protocol, no patch.
struct GoVetConfiguration: Encodable, Equatable {
    let id: String
    let compiler: String
    let dir: String
    let importPath: String
    let goFiles: [String]
    let nonGoFiles: [String]
    let ignoredFiles: [String]
    /// Import path as written to the canonical path. Identity here: the app
    /// resolves every import itself and never rewrites one.
    let importMap: [String: String]
    /// Canonical path to its compiled archive.
    let packageFile: [String: String]
    let standard: [String: Bool]
    let packageVetx: [String: String]
    let vetxOnly: Bool
    let vetxOutput: String
    let succeedOnTypecheckFailure: Bool

    /// The wire names are `cmd/vet`'s, and they are capitalised because Go
    /// exports them that way.
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case compiler = "Compiler"
        case dir = "Dir"
        case importPath = "ImportPath"
        case goFiles = "GoFiles"
        case nonGoFiles = "NonGoFiles"
        case ignoredFiles = "IgnoredFiles"
        case importMap = "ImportMap"
        case packageFile = "PackageFile"
        case standard = "Standard"
        case packageVetx = "PackageVetx"
        case vetxOnly = "VetxOnly"
        case vetxOutput = "VetxOutput"
        case succeedOnTypecheckFailure = "SucceedOnTypecheckFailure"
    }

    init(
        importPath: String,
        directory: String,
        goFiles: [String],
        archives: [String: String],
        standardLibrary: Set<String>,
        factsOutput: String
    ) {
        var packageFile = archives
        for path in standardLibrary where packageFile[path] == nil {
            packageFile[path] = GoGuestPath.standardLibraryArchive(for: path)
        }

        id = importPath
        compiler = "gc"
        dir = directory
        self.importPath = importPath
        self.goFiles = goFiles
        nonGoFiles = []
        ignoredFiles = []
        importMap = Dictionary(uniqueKeysWithValues: packageFile.keys.map { ($0, $0) })
        self.packageFile = packageFile
        standard = Dictionary(uniqueKeysWithValues: standardLibrary.map { ($0, true) })
        packageVetx = [:]
        vetxOnly = false
        vetxOutput = factsOutput
        succeedOnTypecheckFailure = false
    }

    func encoded() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
