import XCTest
@testable import GopherForge

/// The licence notices, checked against what the app actually ships.
///
/// A notice file drifts silently: a dependency is added, the file is not, and
/// nothing anywhere complains until somebody notices the app is redistributing
/// software without its licence. These tests are the thing that complains.
final class ThirdPartyNoticesTests: XCTestCase {
    private var notices: String {
        ThirdPartyNotices.text(bundle: Bundle(for: Self.self))
    }

    /// Read from the test bundle, which carries its own copy, so this checks
    /// the file's contents rather than the app bundle's packaging — that is
    /// what `testTheNoticesShipInTheAppBundle` is for.
    private var source: String {
        let url = Bundle(for: Self.self).url(forResource: "ThirdPartyNotices", withExtension: "md")
        return url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? notices
    }

    func testEveryBundledDependencyIsNamed() {
        for component in [
            "Go", "WasmKit", "swift-system", "ZIPFoundation", "go-cmp",
            "swift-nio", "swift-collections", "swift-atomics", "swift-log",
            "swift-argument-parser",
        ] {
            XCTAssertTrue(
                source.contains(component),
                "\(component) ships in the app but is not in the notices"
            )
        }
    }

    /// Getting a licence wrong is worse than omitting it: it is a claim about
    /// somebody else's terms. WasmKit is MIT and was written down as Apache-2.0
    /// once already.
    func testEachLicenceIsNamedCorrectly() {
        for (component, licence) in [
            ("WasmKit", "MIT License"),
            ("ZIPFoundation", "MIT License"),
            ("swift-system", "Apache License 2.0"),
            ("swift-nio", "Apache License 2.0"),
            ("swift-collections", "Apache License 2.0"),
            ("swift-atomics", "Apache License 2.0"),
            ("swift-log", "Apache License 2.0"),
            ("swift-argument-parser", "Apache License 2.0"),
            ("go-cmp", "BSD 3-Clause License"),
        ] {
            let section = Self.section(named: component, in: source)
            XCTAssertTrue(
                section.contains(licence),
                "\(component) should be recorded as \(licence), got: \(section)"
            )
        }
    }

    func testTheGoToolchainIsRecordedAsARedistribution() {
        let section = Self.section(named: "The Go toolchain", in: source)

        XCTAssertTrue(section.contains("BSD 3-Clause License"))
        XCTAssertTrue(
            section.contains("LICENSE"),
            "the notices should say where Go's own licence text ships"
        )
    }

    /// The gopher is Renée French's work and this app does not use it.
    func testTheNoticesDisclaimTheGoGopher() {
        XCTAssertTrue(source.contains("Renée French"))
        XCTAssertTrue(source.lowercased().contains("original artwork"))
    }

    /// A notice that does not ship is not a notice.
    func testTheNoticesShipInTheAppBundle() {
        let text = ThirdPartyNotices.text(bundle: Bundle(for: Self.self))

        XCTAssertFalse(
            text.contains("missing from this build"),
            "ThirdPartyNotices.md should be a bundled resource"
        )
        XCTAssertTrue(text.contains("Third-party notices"))
    }

    /// Our Swift, course snippets and example programs stay at a size a
    /// reviewer can read. Third-party `VendoredModules` are excluded: they
    /// ship with their own licence and are named in the notices.
    func testAppAndTeachingSourcesStayWithinTheLineBudget() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appRoot = testsDirectory.deletingLastPathComponent().appending(path: "GopherForge")
        var offenders: [String] = []

        let enumerator = FileManager.default.enumerator(
            at: appRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            if url.path.contains("VendoredModules") || url.path.contains("Toolchain") { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if SourceFileLimit.exceedsLimit(text) {
                offenders.append("\(SourceFileLimit.lineCount(of: text)) \(url.path)")
            }
        }

        for lesson in GoCourseCatalog.lessons {
            for (label, text) in Self.sources(in: lesson) where SourceFileLimit.exceedsLimit(text) {
                offenders.append("\(SourceFileLimit.lineCount(of: text)) lesson \(lesson.id) \(label)")
            }
        }

        for example in GoExampleLibrary.all {
            if SourceFileLimit.exceedsLimit(example.source) {
                offenders.append("\(SourceFileLimit.lineCount(of: example.source)) example \(example.id)")
            }
            for (path, text) in example.extraFiles where SourceFileLimit.exceedsLimit(text) {
                offenders.append("\(SourceFileLimit.lineCount(of: text)) example \(example.id) \(path)")
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "files longer than \(SourceFileLimit.maximumLines) lines:\n"
                + offenders.joined(separator: "\n")
        )
    }

    private static func sources(in lesson: Lesson) -> [(String, String)] {
        var items: [(String, String)] = []
        switch lesson.task {
        case let .guidedTyping(target):
            items.append(("target", target))
        case let .fillGaps(template, blanks):
            items.append(("template", template))
            items.append(contentsOf: blanks.enumerated().map { ("blank.\($0.offset)", $0.element) })
        case let .compile(starter, hiddenTest):
            items.append(("starter", starter))
            items.append(("hiddenTest", hiddenTest))
        case let .predict(source, _, answer):
            items.append(("source", source))
            items.append(("answer", answer))
        }
        if let solution = lesson.idiomaticSolution { items.append(("solution", solution)) }
        if let verified = lesson.verifiedSolution { items.append(("verified", verified)) }
        return items
    }

    private static func section(named name: String, in text: String) -> String {
        let parts = text.components(separatedBy: "\n## ")
        return parts.first { $0.hasPrefix(name) } ?? ""
    }
}
