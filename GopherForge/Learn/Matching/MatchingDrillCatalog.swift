import Foundation

/// Every matching drill in the product.
///
/// The content is authored against the same concept tags as the course, so a
/// pair someone keeps getting wrong strengthens the same review signal a failed
/// lesson would. Text lengths are budgeted rather than free-form — see
/// `MatchingDrill.maximumPromptCharacters` — because the board's promise is
/// that every tile is the same height and nothing shifts as you play.
enum MatchingDrillCatalog {
    static let drills: [MatchingDrill] = [
        core, slices, interfaces, errors, concurrency, standardLibrary,
    ]

    static func drill(id: String) -> MatchingDrill? {
        drills.first { $0.id == id }
    }

    static func drills(forUnit unitID: String) -> [MatchingDrill] {
        drills.filter { $0.unitID == unitID }
    }

    // MARK: - Content

    static let core = MatchingDrill(
        id: "drill.core",
        title: "Declarations",
        subtitle: "What Go does with a name",
        unitID: "core",
        pairs: [
            MatchingPair(
                id: "core.short",
                prompt: "x := 3",
                answer: "Declares and infers, inside a function only",
                conceptTag: GoConcept.shortDeclaration
            ),
            MatchingPair(
                id: "core.unused",
                prompt: "declared and not used",
                answer: "A local you named but never read",
                conceptTag: GoConcept.varsUnused
            ),
            MatchingPair(
                id: "core.zero",
                prompt: "var s string",
                answer: "Exists already, holding the zero value \"\"",
                conceptTag: GoConcept.shortDeclaration
            ),
            MatchingPair(
                id: "core.return",
                prompt: "missing return",
                answer: "A path out of the function returns nothing",
                conceptTag: GoConcept.missingReturn
            ),
            MatchingPair(
                id: "core.import",
                prompt: "imported and not used",
                answer: "An import no line in the file refers to",
                conceptTag: GoConcept.unusedImport
            ),
        ]
    )

    static let slices = MatchingDrill(
        id: "drill.slices",
        title: "Slices and maps",
        subtitle: "What the header actually holds",
        unitID: "collections",
        pairs: [
            MatchingPair(
                id: "slices.append",
                prompt: "append past cap",
                answer: "Allocates a new array; the old one is untouched",
                conceptTag: GoConcept.sliceCapacity
            ),
            MatchingPair(
                id: "slices.alias",
                prompt: "b := a[1:3]",
                answer: "Shares memory with a until one of them grows",
                conceptTag: GoConcept.sliceAliasing
            ),
            MatchingPair(
                id: "slices.bounds",
                prompt: "index out of range",
                answer: "Read past len, which is not the same as cap",
                conceptTag: GoConcept.sliceCapacity
            ),
            MatchingPair(
                id: "maps.missing",
                prompt: "m[\"nope\"]",
                answer: "The zero value, not an error and not a panic",
                conceptTag: GoConcept.mapZeroValue
            ),
            MatchingPair(
                id: "strings.range",
                prompt: "for i, r := range s",
                answer: "r is a rune; i counts bytes, not characters",
                conceptTag: GoConcept.stringRunes
            ),
        ]
    )

    static let interfaces = MatchingDrill(
        id: "drill.interfaces",
        title: "Interfaces",
        subtitle: "Who satisfies what",
        unitID: "interfaces",
        pairs: [
            MatchingPair(
                id: "iface.pointer",
                prompt: "func (c *Counter) Add()",
                answer: "Only *Counter satisfies it, never Counter",
                conceptTag: GoConcept.methodSet
            ),
            MatchingPair(
                id: "iface.nil",
                prompt: "err != nil, but err is nil",
                answer: "A nil pointer inside a non-nil interface value",
                conceptTag: GoConcept.nilInterface
            ),
            MatchingPair(
                id: "iface.small",
                prompt: "interface { Read(...) }",
                answer: "One method is easier to satisfy than five",
                conceptTag: GoConcept.smallInterface
            ),
            MatchingPair(
                id: "iface.accept",
                prompt: "Accept interfaces",
                answer: "Take what you need; return what you built",
                conceptTag: GoConcept.smallInterface
            ),
        ]
    )

    static let errors = MatchingDrill(
        id: "drill.errors",
        title: "Errors",
        subtitle: "Values, not exceptions",
        unitID: "errors",
        pairs: [
            MatchingPair(
                id: "errors.check",
                prompt: "if err != nil",
                answer: "The check Go asks for at every call that can fail",
                conceptTag: GoConcept.explicitErrorCheck
            ),
            MatchingPair(
                id: "errors.wrap",
                prompt: "fmt.Errorf(\"...: %w\", err)",
                answer: "Adds context and keeps the original reachable",
                conceptTag: GoConcept.errorWrapping
            ),
            MatchingPair(
                id: "errors.sentinel",
                prompt: "errors.Is(err, io.EOF)",
                answer: "Compares against a known error, through wrapping",
                conceptTag: GoConcept.errorSentinel
            ),
            MatchingPair(
                id: "errors.defer",
                prompt: "defer f.Close()",
                answer: "Runs when the function returns, however it returns",
                conceptTag: GoConcept.deferCleanup
            ),
        ]
    )

    static let concurrency = MatchingDrill(
        id: "drill.concurrency",
        title: "Concurrency",
        subtitle: "What blocks, and until when",
        unitID: "concurrency",
        pairs: [
            MatchingPair(
                id: "conc.unbuffered",
                prompt: "make(chan int)",
                answer: "A rendezvous: send waits for a receiver",
                conceptTag: GoConcept.deadlock
            ),
            MatchingPair(
                id: "conc.close",
                prompt: "close(ch)",
                answer: "The sender's job, and only ever once",
                conceptTag: GoConcept.channelClose
            ),
            MatchingPair(
                id: "conc.select",
                prompt: "select with default",
                answer: "Takes the ready branch, or gives up at once",
                conceptTag: GoConcept.selectBranch
            ),
            MatchingPair(
                id: "conc.ctx",
                prompt: "ctx context.Context",
                answer: "First parameter, never stored in a struct",
                conceptTag: GoConcept.contextFirstParameter
            ),
            MatchingPair(
                id: "conc.wg",
                prompt: "wg.Add before go",
                answer: "Add outside the goroutine, Done inside it",
                conceptTag: GoConcept.waitGroup
            ),
            MatchingPair(
                id: "conc.leak",
                prompt: "A goroutine nobody reads",
                answer: "Blocks on send forever and is never collected",
                conceptTag: GoConcept.goroutineLeak
            ),
        ]
    )

    static let standardLibrary = MatchingDrill(
        id: "drill.stdlib",
        title: "Standard library",
        subtitle: "Reach for these first",
        unitID: "stdlib",
        pairs: [
            MatchingPair(
                id: "std.io",
                prompt: "io.Reader",
                answer: "One method, and half the library accepts it",
                conceptTag: GoConcept.stdlibIO
            ),
            MatchingPair(
                id: "std.json",
                prompt: "json.Unmarshal",
                answer: "Fills a value you pass by pointer",
                conceptTag: GoConcept.stdlibJSON
            ),
            MatchingPair(
                id: "std.testing",
                prompt: "t.Run(name, func)",
                answer: "A subtest that can fail on its own",
                conceptTag: GoConcept.stdlibTesting
            ),
            MatchingPair(
                id: "std.bufio",
                prompt: "bufio.Scanner",
                answer: "Reads a stream a line at a time",
                conceptTag: GoConcept.stdlibIO
            ),
        ]
    )
}
