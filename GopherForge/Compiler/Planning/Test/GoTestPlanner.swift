import Foundation

/// Planning a test run.
///
/// Separate from the rest of the planner because a test build is a different
/// shape: the package under test is recompiled with its test files folded in,
/// an external test package may exist beside it, and the entry point is a file
/// this app writes rather than one the user did.
extension GoBuildPlanner {
    func testPlan(graph: GoPackageGraph, files: [String: String]) -> GoBuildPlan {
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

    func testSteps(
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

    func testFunctions(in package: GoPackage, files: [String: String]) -> [GoTestFunction] {
        let internalFunctions = package.internalTestFiles.flatMap {
            GoTestFunctionScanner.scan(source: files[$0] ?? "", isExternal: false)
        }
        let externalFunctions = package.externalTestFiles.flatMap {
            GoTestFunctionScanner.scan(source: files[$0] ?? "", isExternal: true)
        }
        return internalFunctions + externalFunctions
    }

}
