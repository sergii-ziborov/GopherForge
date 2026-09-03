import XCTest
@testable import GopherForge

/// Temporary: times the catalogue lookups a screen makes on every body pass.
final class CatalogCostTests: XCTestCase {
    private func time(_ label: String, _ work: () -> Void) {
        let start = Date()
        work()
        print("COST \(label): \(Date().timeIntervalSince(start))s")
    }

    func testReportCatalogueCost() {
        time("GoCourseCatalog.lessons x100") {
            for _ in 0..<100 { _ = GoCourseCatalog.lessons.count }
        }
        time("PracticeCatalog.items x100") {
            for _ in 0..<100 { _ = PracticeCatalog.items.count }
        }
        let completed: Set<String> = []
        time("PracticeCatalog.unlockedItems x100") {
            for _ in 0..<100 { _ = PracticeCatalog.unlockedItems(completed: completed).count }
        }
        time("AchievementCatalog.totalLevelCount x100") {
            for _ in 0..<100 { _ = AchievementCatalog.totalLevelCount }
        }
        time("SpotTheBugCatalog.all x100") {
            for _ in 0..<100 { _ = SpotTheBugCatalog.all.count }
        }
        time("InterviewCatalog.all x100") {
            for _ in 0..<100 { _ = InterviewCatalog.all.count }
        }
        time("WasmGoCompiler() + probe() x1") {
            _ = WasmGoCompiler().probe()
        }
        time("WasmGoCompiler() + probe() x10") {
            for _ in 0..<10 { _ = WasmGoCompiler().probe() }
        }
    }
}
