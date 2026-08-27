import Foundation

/// Resolves the bundled toolchain layout and reports what is actually present.
///
/// The whole toolchain lives under `Resources/Toolchain/<tag>/`, staged at build
/// time by `scripts/fetch_toolchain.sh`. The running app never downloads
/// compiler components, so this type only ever reads.
///
/// There is no `go` driver in the bundle, and that is the design rather than an
/// omission: `cmd/go` builds by spawning `compile` and `link` as child
/// processes, which WASI cannot do. The app orders the build itself and runs
/// the two tools directly, which is why the bundled Go needs no patches at all.
struct GoToolchainLocator {
    struct Layout: Sendable {
        let root: URL
        /// `cmd/compile`, built for `wasip1/wasm`.
        let compiler: URL
        /// `cmd/link`, built for `wasip1/wasm`.
        let linker: URL
        /// `cmd/vet`, present only when the artifact carries it.
        let vet: URL?
        /// `cmd/gofmt`, present only when the artifact carries it.
        let formatter: URL?
        /// Bundled GOROOT: `VERSION` and the staged standard-library archives.
        let goroot: URL
        let tag: String

        var standardLibraryPackages: URL {
            goroot
                .appendingPathComponent("pkg", isDirectory: true)
                .appendingPathComponent("wasip1_wasm", isDirectory: true)
        }

        /// The module a step needs, or nil when the artifact does not carry
        /// that tool. `compile` and `link` are always present; `vet` and
        /// `gofmt` are optional, and a plan that needs a missing one is
        /// refused rather than silently reported as a pass.
        func module(for tool: GoToolStep.Tool) -> URL? {
            switch tool {
            case .compile: compiler
            case .link: linker
            case .vet: vet
            case .format: formatter
            }
        }
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
            if let layout = layout(at: directory) { return layout }
        }
        return nil
    }

    private func layout(at directory: URL) -> Layout? {
        let compiler = directory.appendingPathComponent("compile.wasm")
        let linker = directory.appendingPathComponent("link.wasm")
        let goroot = directory.appendingPathComponent("goroot", isDirectory: true)
        let marker = directory.appendingPathComponent(".complete")

        guard fileManager.fileExists(atPath: marker.path),
              fileManager.fileExists(atPath: compiler.path),
              fileManager.fileExists(atPath: linker.path),
              isDirectory(goroot)
        else {
            return nil
        }

        return Layout(
            root: directory,
            compiler: compiler,
            linker: linker,
            vet: optional(directory.appendingPathComponent("vet.wasm")),
            formatter: optional(directory.appendingPathComponent("gofmt.wasm")),
            goroot: goroot,
            tag: directory.lastPathComponent
        )
    }

    func probe() -> ToolchainStatus {
        guard let layout = resolve() else { return .missing }

        let size = [layout.compiler, layout.linker]
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0) { $0 + Int64($1) }
        let version = goVersion(in: layout) ?? layout.tag

        return ToolchainStatus(
            isReady: true,
            toolSize: size,
            goVersion: version,
            label: "Bundled Go \(shortVersion(version))",
            detail: "compile + link · WasmKit interpreter · fully local · GOOS=wasip1"
        )
    }

    /// The `-lang` value the compiler is given: the release without its patch
    /// number, which is what Go's language-version flag accepts.
    static func languageVersion(fromGoVersion version: String) -> String {
        let digits = version.drop(while: { !$0.isNumber })
        let parts = digits.split(separator: ".")
        guard parts.count >= 2 else { return "go1.21" }
        return "go\(parts[0]).\(parts[1])"
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

    private func shortVersion(_ version: String) -> String {
        version.hasPrefix("go") ? String(version.dropFirst(2)) : version
    }

    private func optional(_ url: URL) -> URL? {
        fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
