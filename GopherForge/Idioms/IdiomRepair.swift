import Foundation

/// Applies an accepted idiom suggestion to a source file.
///
/// A repair is only ever applied to the exact line the finding pointed at, and
/// only when that line still looks the way it did when the finding was made.
/// If the user has edited it since, the repair is refused rather than applied
/// to a line it was never computed against.
enum IdiomRepair {
    enum RepairError: Error, Equatable {
        case notRepairable
        case lineOutOfRange
        case sourceChanged
    }

    static func apply(
        _ finding: IdiomFinding,
        to source: String,
        expectedLine: String
    ) throws -> String {
        guard let replacement = finding.suggestedReplacement else {
            throw RepairError.notRepairable
        }
        var lines = source.components(separatedBy: "\n")
        let index = finding.line - 1
        guard lines.indices.contains(index) else { throw RepairError.lineOutOfRange }
        guard lines[index] == expectedLine else { throw RepairError.sourceChanged }

        lines[index] = replacement
        return lines.joined(separator: "\n")
    }

    /// The line the finding was computed against, so a caller can pass it back
    /// to `apply` and get the staleness check for free.
    static func line(at finding: IdiomFinding, in source: String) -> String? {
        let lines = source.components(separatedBy: "\n")
        let index = finding.line - 1
        guard lines.indices.contains(index) else { return nil }
        return lines[index]
    }
}
