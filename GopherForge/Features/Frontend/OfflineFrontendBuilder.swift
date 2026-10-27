import CryptoKit
import Foundation
import WasmKit

/// Trusted parsing/bundling code in WASI. No network imports, shell or Node APIs.
actor OfflineFrontendBuilder {
    struct Result: Sendable {
        let generated: [String: String]
        let outputDirectory: String
        let stdout: String
    }

    private let resourceRoot: URL?
    private var cachedCatalog: OfflineFrontendCatalog?

    init(resourceRoot: URL? = Bundle.main.url(forResource: "Frontend", withExtension: nil)) {
        self.resourceRoot = resourceRoot
    }

    func plan(files: [String: String]) throws -> OfflineFrontendPlan {
        try OfflineFrontendPlan(files: files, catalog: catalog())
    }

    func packageSummary() throws -> String {
        try catalog().packages.map { "\($0.name)@\($0.version)" }.joined(separator: "\n")
    }

    func instrumentGo(files: [String: String]) throws -> GoDebugInstrumented {
        _ = try catalog()
        guard files.count <= 2000, files.values.reduce(0, { $0 + $1.utf8.count }) <= 32 * 1024 * 1024 else {
            throw OfflineFrontendError.message("Debug source exceeds the 2,000-file / 32 MiB budget.")
        }
        let stager = GoWorkspaceStager()
        let job = try stager.createLayout(named: "debug-" + UUID().uuidString)
        defer { stager.remove(job) }
        let own = files.filter { $0.key.hasSuffix(".go") && !$0.key.hasPrefix("vendor/") && !$0.key.hasSuffix("_test.go") }
        try stager.stage(files: own, into: job.work)
        let recipe = try JSONSerialization.data(withJSONObject: ["files": own.keys.sorted(), "output": ".gopherforge-debug-output.json"])
        try recipe.write(to: job.work.appending(path: ".gopherforge-debug-job.json"))
        guard let resourceRoot else { throw OfflineFrontendError.message("The source debugger tool is missing.") }
        let module = try parseWasm(bytes: [UInt8](Data(contentsOf: resourceRoot.appending(path: "bundler.wasm"))))
        let invocation = WasiProcessRunner.Invocation(arguments: ["gopherforge-frontend", "instrument", "/work/.gopherforge-debug-job.json"], environment: ["PWD": "/work", "GOMAXPROCS": "1"], preopens: ["/": job.jobRoot.path], memoryLimitBytes: 384 * 1024 * 1024, tableElementLimit: 65_536, outputLimitBytes: 1024 * 1024)
        let (exit, output) = try WasiProcessRunner().run(module: module, invocation: invocation)
        guard exit == 0 else { throw OfflineFrontendError.message(output.stderr) }
        let url = job.work.appending(path: ".gopherforge-debug-output.json")
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 32 * 1024 * 1024 else { throw OfflineFrontendError.message("Debug source output exceeds 32 MiB.") }
        return try JSONDecoder().decode(GoDebugInstrumented.self, from: Data(contentsOf: url))
    }

    func build(files: [String: String]) throws -> Result {
        let plan = try plan(files: files)
        guard files[OfflineFrontendRecipe.lockPath] == plan.lock else {
            throw OfflineFrontendError.message("Run frontend install (or npm install --offline) before building. The offline lock must match package.json.")
        }
        guard files.count <= 2_000, files.values.reduce(0, { $0 + $1.utf8.count }) <= 32 * 1024 * 1024,
              files.keys.allSatisfy(OfflineFrontendPlan.validPath) else {
            throw OfflineFrontendError.message("Frontend source exceeds the 2,000-file / 32 MiB limit or contains an invalid path.")
        }
        let stager = GoWorkspaceStager()
        let job = try stager.createLayout(named: "frontend-" + UUID().uuidString)
        defer { stager.remove(job) }
        var staged = files.filter { !$0.key.hasPrefix(plan.recipe.output + "/") && !$0.key.hasPrefix("node_modules/") }
        for package in plan.packages {
            for (path, contents) in package.files { staged["node_modules/\(package.name)/\(path)"] = contents }
        }
        staged[".gopherforge-frontend-job.json"] = String(decoding: try JSONSerialization.data(withJSONObject: ["entry": plan.recipe.entry, "output": plan.recipe.output, "minify": plan.recipe.minify]), as: UTF8.self)
        try stager.stage(files: staged, into: job.work)
        guard let resourceRoot else { throw OfflineFrontendError.message("The offline frontend compiler is not bundled in this build.") }
        let module = try parseWasm(bytes: [UInt8](Data(contentsOf: resourceRoot.appending(path: "bundler.wasm"))))
        let invocation = WasiProcessRunner.Invocation(
            arguments: ["gopherforge-frontend", "/work/.gopherforge-frontend-job.json"],
            environment: ["PWD": "/work", "HOME": "/work", "TMPDIR": "/tmp", "GOMAXPROCS": "1"],
            // esbuild walks parent directories during resolution. Its virtual
            // root contains only this fresh job, never the host filesystem.
            preopens: ["/": job.jobRoot.path],
            memoryLimitBytes: 384 * 1024 * 1024,
            tableElementLimit: 65_536,
            outputLimitBytes: 1024 * 1024
        )
        let (exit, output) = try WasiProcessRunner().run(module: module, invocation: invocation)
        guard exit == 0 else { throw OfflineFrontendError.message(output.stderr.isEmpty ? "Offline bundling failed (\(exit))." : output.stderr) }
        let outputRoot = job.work.appending(path: plan.recipe.output)
        guard let enumerator = FileManager.default.enumerator(at: outputRoot, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            throw OfflineFrontendError.message("The bundler produced no output.")
        }
        var generated: [String: String] = [:]
        var bytes = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw OfflineFrontendError.message("Symbolic links are not accepted as build output.") }
            guard values.isRegularFile == true else { continue }
            let data = try Data(contentsOf: url)
            bytes += data.count
            guard bytes <= 8 * 1024 * 1024, generated.count < 100, let contents = String(data: data, encoding: .utf8) else {
                throw OfflineFrontendError.message("Frontend output exceeds the 100-file / 8 MiB UTF-8 budget.")
            }
            generated[plan.recipe.output + "/" + String(url.path.dropFirst(outputRoot.path.count + 1))] = contents
        }
        guard generated[plan.recipe.output + "/assets/app.js"] != nil else { throw OfflineFrontendError.message("The browser bundle is missing.") }
        let css = generated[plan.recipe.output + "/assets/app.css"] == nil ? "" : "<link rel=\"stylesheet\" href=\"/assets/app.css\">"
        generated[plan.recipe.output + "/index.html"] = files[plan.recipe.html]!.replacingOccurrences(of: "<!-- gopherforge:assets -->", with: css + "<script type=\"module\" src=\"/assets/app.js\"></script>")
        generated[plan.recipe.output + "/.gopherforge-build.json"] = OfflineFrontendPlan.digest(files: files, output: plan.recipe.output)
        return Result(generated: generated, outputDirectory: plan.recipe.output, stdout: output.stdout + output.stderr)
    }

    private func catalog() throws -> OfflineFrontendCatalog {
        if let cachedCatalog { return cachedCatalog }
        guard let resourceRoot else { throw OfflineFrontendError.message("Offline frontend resources are missing. This build cannot install or bundle frontend packages.") }
        let manifest = try JSONDecoder().decode(ResourceManifest.self, from: Data(contentsOf: resourceRoot.appending(path: "manifest.json")))
        guard manifest.format == 1 else { throw OfflineFrontendError.message("Unsupported frontend resource format.") }
        for name in ["bundler.wasm", "packages.json"] {
            let data = try Data(contentsOf: resourceRoot.appending(path: name))
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard manifest.sha256[name] == actual else { throw OfflineFrontendError.message("Offline frontend resource integrity check failed: \(name).") }
        }
        let catalog = try JSONDecoder().decode(OfflineFrontendCatalog.self, from: Data(contentsOf: resourceRoot.appending(path: "packages.json")))
        guard catalog.format == 1 else { throw OfflineFrontendError.message("Unsupported offline package catalog.") }
        cachedCatalog = catalog
        return catalog
    }

    private struct ResourceManifest: Decodable {
        let format: Int
        let sha256: [String: String]
    }
}
