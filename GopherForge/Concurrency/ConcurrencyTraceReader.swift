import Foundation

/// Reads the instrumented trace lines a lab program writes.
///
/// The wire format is deliberately boring so it can be read by a human in the
/// output pane too:
///
///     #lab 7 send producer jobs 3 buffered
///     #lab 8 blocked consumer results waiting-for-value
///
/// Any line that is not prefixed with `#lab` is ordinary program output and is
/// left alone.
enum ConcurrencyTraceReader {
    static let linePrefix = "#lab"

    static func events(in stdout: String) -> [ConcurrencyEvent] {
        stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { event(from: String($0)) }
    }

    /// Program output with the instrumentation removed, so the lab can show the
    /// program's real stdout next to the visualisation.
    static func programOutput(in stdout: String) -> String {
        stdout
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix(linePrefix) }
            .joined(separator: "\n")
    }

    private static func event(from line: String) -> ConcurrencyEvent? {
        guard line.hasPrefix(linePrefix) else { return nil }
        let fields = line
            .dropFirst(linePrefix.count)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard fields.count >= 3,
              let sequence = Int(fields[0]),
              let kind = ConcurrencyEvent.Kind(rawValue: fields[1])
        else {
            return nil
        }

        return ConcurrencyEvent(
            sequence: sequence,
            kind: kind,
            actor: fields[2],
            subject: fields.count > 3 ? fields[3] : nil,
            value: fields.count > 4 ? fields[4] : nil,
            note: fields.count > 5 ? fields[5...].joined(separator: " ") : nil
        )
    }
}
