import Foundation

/// Materialises an in-memory project into the job's working directory.
///
/// Every relative path is validated before it is joined: a project file that
/// escaped the working directory would let a build read or write outside the
/// sandbox, so a rejected path fails the job rather than being sanitised into
/// something that merely looks safe.
struct GoWorkspaceStager {
    enum StagingError: Error, Equatable {
        case invalidPath(String)
    }

    struct Layout {
        let jobRoot: URL
        let work: URL
        let temp: URL
        let cache: URL
        let sandbox: URL
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func createLayout(named jobName: String) throws -> Layout {
        let jobRoot = fileManager.temporaryDirectory
            .appendingPathComponent("GopherForgeCompiler", isDirectory: true)
            .appendingPathComponent(jobName, isDirectory: true)
        let layout = Layout(
            jobRoot: jobRoot,
            work: jobRoot.appendingPathComponent("work", isDirectory: true),
            temp: jobRoot.appendingPathComponent("tmp", isDirectory: true),
            cache: jobRoot.appendingPathComponent("cache", isDirectory: true),
            sandbox: jobRoot.appendingPathComponent("sandbox", isDirectory: true)
        )
        for directory in [layout.work, layout.temp, layout.cache, layout.sandbox] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return layout
    }

    func stage(files: [String: String], into work: URL) throws {
        for (relativePath, contents) in files.sorted(by: { $0.key < $1.key }) {
            guard let fileURL = Self.resolve(relativePath: relativePath, under: work) else {
                throw StagingError.invalidPath(relativePath)
            }
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: fileURL, options: .atomic)
        }
    }

    func remove(_ layout: Layout) {
        try? fileManager.removeItem(at: layout.jobRoot)
    }

    static func resolve(relativePath: String, under root: URL) -> URL? {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
              !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            return nil
        }
        return components.reduce(root) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }
}
