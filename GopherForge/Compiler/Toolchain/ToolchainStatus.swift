import Foundation

/// What the app can honestly say about the compiler it shipped with.
///
/// `isReady` is false whenever any required artifact is missing. Nothing in the
/// product downgrades that to a "skipped" state: a missing toolchain fails
/// every compiler gate rather than quietly falling back to a stub.
struct ToolchainStatus: Sendable, Equatable {
    let isReady: Bool
    /// The bundled tools' size on disk, which is what Settings reports.
    let toolSize: Int64
    /// The Go release the bundled toolchain was built from, for example
    /// `go1.27`. Reported verbatim from the staged toolchain marker so the UI
    /// can never claim a version the artifact does not carry.
    let goVersion: String
    let label: String
    let detail: String

    static let missing = ToolchainStatus(
        isReady: false,
        toolSize: 0,
        goVersion: "",
        label: "Toolchain missing",
        detail: "Run scripts/build_toolchain.sh, then rebuild the app."
    )
}
