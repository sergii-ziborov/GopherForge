import Foundation

/// The Go language version the app writes into the modules it creates.
///
/// One constant, because a `go` line is a promise: it tells the toolchain which
/// language rules to apply, and a module that asks for a version the bundled
/// compiler does not have is refused. Templates, lessons and the concurrency
/// lab all generate `go.mod` files, and four independent guesses is four ways
/// to promise something the app cannot keep.
///
/// `BundledCompilerGateTests` asserts this never exceeds what the staged
/// toolchain actually supports, so a Go downgrade cannot silently strand every
/// generated project.
enum GoLanguage {
    /// Kept at or below the bundled release. Raise it in the same change that
    /// raises the toolchain, never before.
    static let declaredModuleVersion = "1.24"

    /// The smallest `go.mod` that builds.
    static func module(_ path: String) -> String {
        "module \(path)\n\ngo \(declaredModuleVersion)\n"
    }
}
