import Foundation

/// The concept vocabulary shared by the compiler, the idiom coach, the course
/// and the review scheduler.
///
/// Everything that can produce evidence about a learner speaks these tags, so a
/// mistake found by the compiler and a mistake found by a lesson land in the
/// same review queue instead of two parallel taxonomies.
enum GoConcept {
    static let varsUnused = "vars.unused"
    static let shortDeclaration = "vars.short-declaration"
    static let unusedImport = "modules.unused-import"
    static let undefinedSymbol = "packages.undefined"
    static let importPath = "modules.import-path"
    static let missingReturn = "functions.missing-return"
    static let typeAssignment = "types.assignment"

    static let sliceCapacity = "slices.capacity"
    static let sliceBounds = "slices.bounds"
    static let sliceAliasing = "slices.aliasing"
    static let mapZeroValue = "maps.zero-value"
    static let stringRunes = "strings.runes"

    static let methodSet = "interfaces.method-set"
    static let nilInterface = "interfaces.nil"
    static let smallInterface = "interfaces.size"

    static let explicitErrorCheck = "errors.explicit-check"
    static let errorWrapping = "errors.wrapping"
    static let errorSentinel = "errors.sentinel"
    static let deferCleanup = "errors.defer"

    static let deadlock = "concurrency.deadlock"
    static let channelClose = "concurrency.channel-close"
    static let selectBranch = "concurrency.select"
    static let contextCancel = "context.cancel"
    static let contextFirstParameter = "context.first-parameter"
    static let goroutineLeak = "concurrency.goroutine-leak"
    static let waitGroup = "concurrency.waitgroup"

    static let constants = "types.constants"
    static let switchNoFallthrough = "control.switch"
    static let conversion = "types.conversion"
    static let mapOrder = "maps.order"
    static let stringsBuilder = "strings.builder"
    static let typeAssertion = "types.assertion"
    static let embedding = "types.embedding"
    static let customError = "errors.custom"
    static let panicIsNotAnError = "errors.panic"
    static let packageInit = "packages.init"
    static let mutex = "concurrency.mutex"
    static let stdlibTime = "stdlib.time"
    static let stdlibSort = "stdlib.sort"

    static let stdlibIO = "stdlib.io"
    static let stdlibHTTP = "stdlib.http"
    static let stdlibJSON = "stdlib.json"
    static let stdlibTesting = "stdlib.testing"
    static let stdlibImage = "stdlib.image"

    /// Every tag the product knows, used to validate course content and to
    /// keep the review scheduler from inventing categories at runtime.
    static let all: Set<String> = [
        varsUnused, shortDeclaration, unusedImport, undefinedSymbol, importPath,
        missingReturn, typeAssignment, sliceCapacity, sliceBounds, sliceAliasing,
        mapZeroValue, stringRunes, methodSet, nilInterface, smallInterface,
        explicitErrorCheck, errorWrapping, errorSentinel, deferCleanup,
        deadlock, channelClose, selectBranch, contextCancel, contextFirstParameter,
        goroutineLeak, waitGroup, stdlibIO, stdlibHTTP, stdlibJSON, stdlibTesting,
        constants, switchNoFallthrough, conversion, mapOrder, stringsBuilder,
        typeAssertion, embedding, customError, panicIsNotAnError, packageInit,
        mutex, stdlibTime, stdlibSort, stdlibImage,
    ]
}
