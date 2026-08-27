import Foundation

/// Turns a project into the exact sequence of `compile` and `link` calls that
/// builds it.
///
/// This is the part `cmd/go` would normally do. It cannot be used here: it
/// builds by spawning `compile` and `link` as child processes, and WASI has no
/// way to spawn anything. Doing the ordering here instead is what keeps the
/// bundled toolchain a stock, unpatched Go — see docs/TOOLCHAIN.md.
struct GoBuildPlanner {
    let modulePath: String
    /// The `-lang` the compiler is given, for example `go1.24`.
    let languageVersion: String
    /// Import paths with staged export data in the bundled GOROOT.
    let standardLibrary: Set<String>
    /// Identifies the toolchain, so a Go upgrade invalidates every cached
    /// artifact rather than mixing objects from two compilers.
    var toolchainTag: String = ""
    /// Decides which files are in the build. Nil means every `.go` file is,
    /// which is only right for content this app authored itself.
    var constraint: GoBuildConstraint?

    func plan(phase: CompilationResult.Phase, files: [String: String]) throws -> GoBuildPlan {
        let graph = try GoPackageGraph.build(
            files: files,
            modulePath: modulePath,
            standardLibrary: standardLibrary,
            constraint: constraint
        )

        return switch phase {
        case .test: testPlan(graph: graph, files: files)
        case .run:
            buildPlan(graph: graph, files: files, output: GoGuestPath.runProgram, keepProduct: true)
        case .build:
            buildPlan(
                graph: graph,
                files: files,
                output: GoGuestPath.program(for: "build", suffix: ""),
                keepProduct: false
            )
        case .vet: vetPlan(graph: graph)
        case .format: formatPlan()
        case .setup: GoBuildPlan(steps: [], products: [])
        }
    }

    // MARK: - Build and run

    private func buildPlan(
        graph: GoPackageGraph,
        files: [String: String],
        output: String,
        keepProduct: Bool
    ) -> GoBuildPlan {
        var steps: [GoToolStep] = []
        var archives: [String: String] = [:]
        var dependencyKeys: [String: String] = [:]
        let entryPoint = graph.mainPackage

        for package in graph.packages where !package.goFiles.isEmpty {
            // The package that will be linked is compiled as `main`, not under
            // the module's import path. This is not cosmetic: the linker looks
            // up `main.main` by that path, and gets "function main is
            // undeclared in the main package" when it is compiled as anything
            // else. Nothing can import a main package, so it is also the one
            // archive no import configuration needs to name.
            let isEntryPoint = package.importPath == entryPoint?.importPath
            let step = compileStep(
                package: package,
                archives: archives,
                packagePath: isEntryPoint ? "main" : package.importPath,
                files: files,
                dependencyKeys: dependencyKeys
            )
            steps.append(step)
            dependencyKeys[package.importPath] = step.cacheKey
            if !isEntryPoint {
                archives[package.importPath] = GoGuestPath.archive(for: package.importPath)
            }
        }

        guard let main = graph.mainPackage, !main.goFiles.isEmpty else {
            // A module with no main is a library. Type-checking every package
            // is the whole job, and reporting a missing entry point would be
            // wrong rather than strict.
            return GoBuildPlan(steps: steps, products: [])
        }

        steps.append(
            linkStep(
                mainArchive: GoGuestPath.archive(for: main.importPath),
                output: output,
                archives: archives
            )
        )
        let products = keepProduct
            ? [GoBuildPlan.Product(guestPath: output, importPath: main.importPath)]
            : []
        return GoBuildPlan(steps: steps, products: products)
    }

    // MARK: - Vet and format

    private func vetPlan(graph: GoPackageGraph) -> GoBuildPlan {
        var steps: [GoToolStep] = []
        var archives: [String: String] = [:]

        // vet type-checks the package it is given, so every dependency has to
        // have been compiled before its turn comes.
        for package in graph.packages where !package.goFiles.isEmpty {
            steps.append(compileStep(package: package, archives: archives))
            archives[package.importPath] = GoGuestPath.archive(for: package.importPath)
        }

        for package in graph.packages where !package.goFiles.isEmpty {
            let configuration = GoVetConfiguration(
                importPath: package.importPath,
                directory: package.directory.isEmpty
                    ? GoGuestPath.work
                    : GoGuestPath.source(package.directory),
                goFiles: (package.goFiles + package.internalTestFiles).map(GoGuestPath.source),
                archives: archives,
                standardLibrary: standardLibrary,
                factsOutput: GoGuestPath.vetFacts(for: package.importPath)
            )
            let path = GoGuestPath.vetConfiguration(for: package.importPath)
            steps.append(
                GoToolStep(
                    tool: .vet,
                    arguments: ["vet", path],
                    generatedFiles: [path: configuration.encoded()],
                    label: "vet \(package.importPath)"
                )
            )
        }

        return GoBuildPlan(steps: steps, products: [])
    }

    /// One pass over the whole staged module. `gofmt` rewrites in place, and
    /// the session reads the changed files back so the editor shows what the
    /// formatter produced rather than what the user typed.
    private func formatPlan() -> GoBuildPlan {
        GoBuildPlan(
            steps: [
                GoToolStep(
                    tool: .format,
                    arguments: ["gofmt", "-l", "-w", GoGuestPath.work],
                    generatedFiles: [:],
                    label: "gofmt"
                )
            ],
            products: []
        )
    }

    // MARK: - Steps

    func compileStep(
        package: GoPackage,
        archives: [String: String],
        suffix: String = "",
        packagePath: String? = nil,
        files: [String: String] = [:],
        dependencyKeys: [String: String] = [:]
    ) -> GoToolStep {
        let configuration = GoGuestPath.importConfiguration(for: package.importPath, suffix: suffix)
        let output = GoGuestPath.archive(for: package.importPath + suffix)
        return GoToolStep(
            tool: .compile,
            arguments: [
                "compile", "-o", output, "-p", packagePath ?? package.importPath,
                "-lang", languageVersion, "-importcfg", configuration, "-complete", "-pack",
            ] + package.goFiles.map(GoGuestPath.source),
            generatedFiles: [configuration: importConfiguration(archives: archives)],
            label: "compile \(package.importPath)\(suffix.isEmpty ? "" : " [test]")",
            outputPath: output,
            cacheKey: files.isEmpty ? nil : GoStepFingerprint.key(
                toolchainTag: toolchainTag,
                languageVersion: languageVersion,
                packagePath: (packagePath ?? package.importPath) + suffix,
                sources: package.goFiles.reduce(into: [:]) { $0[$1] = files[$1] },
                dependencyKeys: package.imports.sorted().compactMap { dependencyKeys[$0] }
            )
        )
    }

    func testMainStep(
        package: GoPackage,
        source: String,
        sourcePath: String,
        archive: String,
        archives: [String: String]
    ) -> GoToolStep {
        let configuration = GoGuestPath.importConfiguration(for: package.importPath, suffix: ".testmain")
        return GoToolStep(
            tool: .compile,
            arguments: [
                "compile", "-o", archive, "-p", "main",
                "-lang", languageVersion, "-importcfg", configuration, "-complete", "-pack", sourcePath,
            ],
            generatedFiles: [
                configuration: importConfiguration(archives: archives),
                sourcePath: source,
            ],
            label: "compile test main for \(package.importPath)"
        )
    }

    func linkStep(mainArchive: String, output: String, archives: [String: String]) -> GoToolStep {
        let configuration = output + ".importcfg"
        var entries = archives
        entries["main"] = mainArchive
        return GoToolStep(
            tool: .link,
            arguments: [
                "link", "-o", output, "-importcfg", configuration,
                "-buildmode", "exe",
                // No debugger can attach inside the sandbox, so DWARF and the
                // symbol table are weight with no reader. Go's tracebacks come
                // from its own tables and survive both.
                "-w", "-s",
                mainArchive,
            ],
            generatedFiles: [configuration: importConfiguration(archives: entries)],
            label: "link \(output)"
        )
    }

    /// The bundled standard library plus everything built so far.
    ///
    /// Handing the compiler the whole list rather than a computed minimum is
    /// deliberate: it reads only what it needs, and a missing indirect entry
    /// fails a build in a way no user of a teaching app could diagnose.
    ///
    /// `unsafe` is deliberately absent: the compiler provides it, there is no
    /// archive for it, and naming a file that does not exist would fail the
    /// build rather than help it.
    func importConfiguration(archives: [String: String]) -> String {
        var entries = archives
        for path in standardLibrary
        where entries[path] == nil && !GoStandardLibraryIndex.compilerProvided.contains(path) {
            entries[path] = GoGuestPath.standardLibraryArchive(for: path)
        }
        return GoImportConfiguration.render(entries)
    }
}
