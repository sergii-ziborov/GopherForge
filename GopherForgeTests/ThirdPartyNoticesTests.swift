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
        for component in ["Go", "WasmKit", "swift-system", "ZIPFoundation", "go-cmp"] {
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

    private static func section(named name: String, in text: String) -> String {
        let parts = text.components(separatedBy: "\n## ")
        return parts.first { $0.hasPrefix(name) } ?? ""
    }
}
