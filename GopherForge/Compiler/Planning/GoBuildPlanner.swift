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

    func plan(phase: CompilationResult.Phase, files: [String: String]) throws -> GoBuildPlan {
        let graph = try GoPackageGraph.build(
            files: files,
            modulePath: modulePath,
            standardLibrary: standardLibrary
        )

        return switch phase {
        case .test: testPlan(graph: graph, files: files)
        case .run: buildPlan(graph: graph, output: GoGuestPath.runProgram, keepProduct: true)
        case .build: buildPlan(graph: graph, output: GoGuestPath.program(for: "build", suffix: ""), keepProduct: false)
        case .vet: vetPlan(graph: graph)
        case .format: formatPlan()
        case .setup: GoBuildPlan(steps: [], products: [])
        }
    }

    // MARK: - Build and run

    private func buildPlan(graph: GoPackageGraph, output: String, keepProduct: Bool) -> GoBuildPlan {
        var steps: [GoToolStep] = []
        var archives: [String: String] = [:]
        let entryPoint = graph.mainPackage

        for package in graph.packages where !package.goFiles.isEmpty {
            // The package that will be linked is compiled as `main`, not under
            // the module's import path. This is not cosmetic: the linker looks
            // up `main.main` by that path, and gets "function main is
            // undeclared in the main package" when it is compiled as anything
            // else. Nothing can import a main package, so it is also the one
            // archive no import configuration needs to name.
            let isEntryPoint = package.importPath == entryPoint?.importPath
            steps.append(
                compileStep(
                    package: package,
                    archives: archives,
                    packagePath: isEntryPoint ? "main" : package.importPath
                )
            )
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

    // MARK: - Test

    private func testPlan(graph: GoPackageGraph, files: [String: String]) -> GoBuildPlan {
        var steps: [GoToolStep] = []
        var products: [GoBuildPlan.Product] = []
        var archives: [String: String] = [:]

        // Every package is built first so a tested package can import its
        // siblings, exactly as it would outside the test.
        for package in graph.packages where !package.goFiles.isEmpty {
            steps.append(compileStep(package: package, archives: archives))
            archives[package.importPath] = GoGuestPath.archive(for: package.importPath)
        }

        for package in graph.packages where package.hasTests {
            let built = testSteps(for: package, files: files, archives: archives)
            steps.append(contentsOf: built.steps)
            if let product = built.product { products.append(product) }
        }

        return GoBuildPlan(steps: steps, products: products)
    }

    private func testSteps(
        for package: GoPackage,
        files: [String: String],
        archives: [String: String]
    ) -> (steps: [GoToolStep], product: GoBuildPlan.Product?) {
        let functions = testFunctions(in: package, files: files)
        guard functions.contains(where: { !$0.isCustomMain }) else { return ([], nil) }

        var steps: [GoToolStep] = []
        var testArchives = archives

        // The package under test is recompiled with its internal test files
        // folded in, which is how a test reaches unexported identifiers.
        let underTest = GoPackage(
            importPath: package.importPath,
            directory: package.directory,
            name: package.name,
            isVendored: package.isVendored,
            goFiles: package.goFiles + package.internalTestFiles,
            internalTestFiles: [],
            externalTestFiles: [],
            imports: package.imports.union(package.testImports),
            testImports: []
        )
        steps.append(compileStep(package: underTest, archives: archives, suffix: ".test"))
        testArchives[package.importPath] = GoGuestPath.archive(for: package.importPath + ".test")

        if !package.externalTestFiles.isEmpty {
            let external = GoPackage(
                importPath: package.externalTestImportPath,
                directory: package.directory,
                name: package.name + "_test",
                isVendored: package.isVendored,
                goFiles: package.externalTestFiles,
                internalTestFiles: [],
                externalTestFiles: [],
                imports: package.testImports,
                testImports: []
            )
            steps.append(compileStep(package: external, archives: testArchives))
            testArchives[external.importPath] = GoGuestPath.archive(for: external.importPath)
        }

        let mainSource = GoTestMainGenerator.source(
            importPath: package.importPath,
            functions: functions,
            hasExternalPackage: !package.externalTestFiles.isEmpty
        )
        let mainPath = GoGuestPath.generatedTestMain(for: package.importPath)
        let mainArchive = GoGuestPath.archive(for: package.importPath + ".testmain")
        steps.append(
            testMainStep(
                package: package,
                source: mainSource,
                sourcePath: mainPath,
                archive: mainArchive,
                archives: testArchives
            )
        )

        let program = GoGuestPath.program(for: package.importPath, suffix: ".test")
        steps.append(linkStep(mainArchive: mainArchive, output: program, archives: testArchives))
        return (steps, GoBuildPlan.Product(guestPath: program, importPath: package.importPath))
    }

    private func testFunctions(in package: GoPackage, files: [String: String]) -> [GoTestFunction] {
        let internalFunctions = package.internalTestFiles.flatMap {
            GoTestFunctionScanner.scan(source: files[$0] ?? "", isExternal: false)
        }
        let externalFunctions = package.externalTestFiles.flatMap {
            GoTestFunctionScanner.scan(source: files[$0] ?? "", isExternal: true)
        }
        return internalFunctions + externalFunctions
    }

    // MARK: - Steps

    private func compileStep(
        package: GoPackage,
        archives: [String: String],
        suffix: String = "",
        packagePath: String? = nil
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
            label: "compile \(package.importPath)\(suffix.isEmpty ? "" : " [test]")"
        )
    }

    private func testMainStep(
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

    private func linkStep(mainArchive: String, output: String, archives: [String: String]) -> GoToolStep {
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
    private func importConfiguration(archives: [String: String]) -> String {
        var entries = archives
        for path in standardLibrary where entries[path] == nil {
            entries[path] = GoGuestPath.standardLibraryArchive(for: path)
        }
        return GoImportConfiguration.render(entries)
    }
}
