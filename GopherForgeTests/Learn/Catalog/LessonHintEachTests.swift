import XCTest
@testable import GopherForge

/// One check per lesson so a missing hint fails on that lesson, not in a pile.
final class LessonHintEachTests: XCTestCase {
    func testCoreZeroValues() { check("core.zero-values") }
    func testCoreShortDeclaration() { check("core.short-declaration") }
    func testCoreMultipleReturns() { check("core.multiple-returns") }
    func testCoreUnused() { check("core.unused-is-an-error") }
    func testCoreConstants() { check("core.constants") }
    func testCoreSwitch() { check("core.switch") }
    func testCoreConversions() { check("core.conversions") }
    func testCoreNamedResults() { check("core.named-results") }
    func testCoreDeferStack() { check("core.defer-stack") }

    func testCollectionsLenCap() { check("collections.length-capacity") }
    func testCollectionsAlias() { check("collections.append-aliasing") }
    func testCollectionsMapZero() { check("collections.map-zero-value") }
    func testCollectionsRunes() { check("collections.runes-not-bytes") }
    func testCollectionsIterators() { check("collections.iterators") }
    func testCollectionsBounds() { check("collections.bounds") }
    func testCollectionsMapOrder() { check("collections.map-order") }
    func testCollectionsBuilder() { check("collections.strings-builder") }
    func testCollectionsMake() { check("collections.make-and-new") }
    func testCollectionsArrays() { check("collections.arrays") }
    func testCollectionsMapOK() { check("collections.map-ok") }
    func testCollectionsNilSlice() { check("collections.nil-slice") }
    func testCollectionsFunctionValues() { check("collections.function-values") }

    func testStructsLiterals() { check("structs.literals") }
    func testStructsMethods() { check("structs.methods") }
    func testStructsPointers() { check("structs.pointers") }
    func testStructsClosures() { check("structs.closures") }
    func testStructsEscape() { check("structs.escape") }

    func testInterfacesImplicit() { check("interfaces.implicit") }
    func testInterfacesMethodSets() { check("interfaces.method-sets") }
    func testInterfacesNil() { check("interfaces.nil") }
    func testInterfacesTypeSwitch() { check("interfaces.type-switch") }
    func testInterfacesEmbedding() { check("interfaces.embedding") }
    func testInterfacesStringer() { check("interfaces.stringer") }
    func testInterfacesEmpty() { check("interfaces.empty") }

    func testGenericsParameters() { check("generics.type-parameters") }
    func testGenericsConstraints() { check("generics.constraints") }
    func testGenericsContainers() { check("generics.containers") }
    func testGenericsWhenNot() { check("generics.when-not-to") }
    func testGenericsMethods() { check("generics.methods") }

    func testErrorsWrapping() { check("errors.wrapping") }
    func testErrorsIsAs() { check("errors.is-and-as") }
    func testErrorsDefer() { check("errors.defer") }
    func testErrorsCustom() { check("errors.custom-type") }
    func testErrorsPanic() { check("errors.panic") }
    func testErrorsRecover() { check("errors.recover") }

    func testModulesPath() { check("modules.import-path") }
    func testModulesExport() { check("modules.exported-by-case") }
    func testModulesTests() { check("modules.tests") }
    func testModulesNaming() { check("modules.naming") }
    func testModulesInit() { check("modules.init") }

    func testConcUnbuffered() { check("concurrency.unbuffered-rendezvous") }
    func testConcNoHandle() { check("concurrency.no-handle") }
    func testConcClose() { check("concurrency.channel-close") }
    func testConcSelect() { check("concurrency.select-context") }
    func testConcMutex() { check("concurrency.mutex") }
    func testConcPool() { check("concurrency.worker-pool") }
    func testConcBuffered() { check("concurrency.buffered") }
    func testConcRange() { check("concurrency.range-and-close") }
    func testConcDefault() { check("concurrency.select-default") }
    func testConcDirection() { check("concurrency.direction") }
    func testConcOnce() { check("concurrency.once") }

    func testStdIO() { check("stdlib.io") }
    func testStdJSON() { check("stdlib.json") }
    func testStdTime() { check("stdlib.time") }
    func testStdSort() { check("stdlib.sort") }
    func testStdContext() { check("stdlib.context") }
    func testStdHTTP() { check("stdlib.http") }
    func testStdStrconv() { check("stdlib.strconv") }
    func testStdImage() { check("stdlib.image") }

    private func check(_ id: String) {
        guard let lesson = GoCourseCatalog.lesson(id: id) else {
            return XCTFail("no lesson \(id)")
        }
        XCTAssertTrue(LessonHintCatalog.authoredIDs.contains(id), id)
        let hint = LessonHintCatalog.hint(for: lesson)
        XCTAssertEqual(hint.lessonID, id)
        XCTAssertFalse(hint.hint.isEmpty)
        XCTAssertFalse(hint.nuance.isEmpty)
        if lesson.requiresCompiler {
            let source = LessonHintCatalog.realizeSource(for: lesson)
            XCTAssertNotNil(source, id)
            XCTAssertTrue(source?.contains("package main") == true, id)
        }
    }
}
