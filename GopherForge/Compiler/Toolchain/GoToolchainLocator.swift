import Foundation

/// Resolves the bundled toolchain layout and reports what is actually present.
///
/// The whole toolchain lives under `Resources/Toolchain/<tag>/`, staged at build
/// time by `scripts/fetch_toolchain.sh`. The running app never downloads
/// compiler components, so this type only ever reads.
struct GoToolchainLocator: Sendable {
    struct Layout: Sendable {
        let root: URL
        /// The WASI-hosted Go toolchain driver: build, vet, test and format all
        /// go through this one module.
        let driver: URL
        /// Bundled GOROOT: standard library sources and export data.
        let goroot: URL
        let tag: String
    }

    private let bundle: Bundle
    private let fileManager: FileManager

    init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    /// Locates the newest staged toolchain. The tag is discovered rather than
    /// hard-coded so a toolchain bump is a build-input change, not a code
    /// change that could drift from what was actually bundled.
    func resolve() -> Layout? {
        guard let toolchainRoot = bundle.resourceURL?
            .appendingPathComponent("Toolchain", isDirectory: true)
        else {
            return nil
        }

        let candidates = (try? fileManager.contentsOfDirectory(
            at: toolchainRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for directory in candidates.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
            let driver = directory.appendingPathComponent("gotool.wasm")
            let goroot = directory.appendingPathComponent("goroot", isDirectory: true)
            let marker = directory.appendingPathComponent(".complete")
            guard fileManager.fileExists(atPath: marker.path),
                  fileManager.fileExists(atPath: driver.path),
                  isDirectory(goroot)
            else {
                continue
            }
            return Layout(
                root: directory,
                driver: driver,
                goroot: goroot,
                tag: directory.lastPathComponent
            )
        }
        return nil
    }

    func probe() -> ToolchainStatus {
        guard let layout = resolve() else { return .missing }

        let size = (try? layout.driver.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .map(Int64.init) ?? 0
        let version = goVersion(in: layout) ?? layout.tag

        return ToolchainStatus(
            isReady: true,
            driverSize: size,
            goVersion: version,
            label: "Bundled gotool.wasm",
            detail: "WasmKit interpreter · fully local · \(version) · GOOS=wasip1"
        )
    }

    /// The staged GOROOT carries the release it was cut from in `VERSION`,
    /// exactly as a normal Go installation does.
    private func goVersion(in layout: Layout) -> String? {
        let versionFile = layout.goroot.appendingPathComponent("VERSION")
        guard let data = try? Data(contentsOf: versionFile) else { return nil }
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
