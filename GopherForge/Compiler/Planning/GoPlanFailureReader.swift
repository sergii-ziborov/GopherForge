import Foundation

/// Says, in a sentence a learner can act on, why a project could not be
/// planned.
///
/// These failures happen before any tool runs, so there is no compiler message
/// to show. Left unexplained they would surface as "build failed" with nothing
/// to read, which is the worst thing a teaching tool can do.
enum GoPlanFailureReader {
    static func describe(_ error: GoPackageGraph.GraphError) -> String {
        switch error {
        case .noGoFiles:
            "This project has no .go files to build yet."
        case let .conflictingPackageNames(directory, names):
            "\(place(directory)) declares more than one package: \(names.joined(separator: ", ")). "
                + "Every file in a directory has to share one package clause."
        case let .importCycle(path):
            "These packages import each other in a circle: \(path.joined(separator: " → ")). "
                + "Go does not allow that; move the shared code into a package both can import."
        case let .unresolvedImport(importPath, importedBy):
            "\(importedBy) imports \(importPath), which is neither a package in this module nor part "
                + "of the bundled standard library. The app compiles offline, so it can only build "
                + "what it ships with and what you wrote."
        }
    }

    private static func place(_ directory: String) -> String {
        directory.isEmpty ? "The module root" : directory
    }
}
