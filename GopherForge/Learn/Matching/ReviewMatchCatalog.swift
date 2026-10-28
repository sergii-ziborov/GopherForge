import Foundation

/// Matching practice from completed lessons, including short first sessions.
enum ReviewMatchCatalog {
    static let pairsPerRound = 5
    static let minimumPairsPerRound = 3
    static let minimumRounds = 3
    static let maximumRounds = 5

    static let rounds: [MatchingDrill] = [
        core, collections, types, errors, concurrency, tour, stdlib,
    ]

    static var allPairs: [MatchingPair] {
        rounds.flatMap(\.pairs) + additionalPairs + ReadingLessonCatalog.all.map {
            MatchingPair(id: "review.reading.\($0.id)", prompt: $0.reviewPrompt,
                         answer: $0.reviewAnswer, conceptTag: $0.conceptTag,
                         requiredLessonID: $0.id)
        }
    }

    /// Keep complete authored boards, but also deal the remaining learned
    /// concepts. A partial board must not disappear just because it has fewer
    /// than five pairs. Shuffling spreads a later session across the catalog.
    static func unlocked(
        completed: Set<String>,
        confirmedConcepts: Set<String> = [],
        shuffle: ([MatchingDrill]) -> [MatchingDrill] = { $0 }
    ) -> [MatchingDrill] {
        var used = Set<String>()
        var boards: [MatchingDrill] = []

        for round in rounds {
            let ready = round.pairs.filter { pair in
                guard let lessonID = pair.requiredLessonID else { return false }
                return completed.contains(lessonID) || confirmedConcepts.contains(pair.conceptTag)
            }
            if ready.count == round.pairs.count, ready.count == pairsPerRound {
                boards.append(round)
                used.formUnion(round.pairs.map(\.id))
            }
        }

        let leftovers = allPairs
            .filter { pair in
                guard let lessonID = pair.requiredLessonID else { return false }
                return (completed.contains(lessonID) || confirmedConcepts.contains(pair.conceptTag))
                    && !used.contains(pair.id)
            }

        var remaining = leftovers
        if !remaining.isEmpty, remaining.count < minimumPairsPerRound, !boards.isEmpty {
            for pair in boards.flatMap(\.pairs) where !remaining.contains(where: { $0.answer == pair.answer }) {
                remaining.append(pair)
                if remaining.count == minimumPairsPerRound { break }
            }
        }
        // Rebalance a 1- or 2-pair tail instead of dealing a trivial board.
        while remaining.count >= minimumPairsPerRound {
            let take = remaining.count > pairsPerRound && remaining.count < pairsPerRound + minimumPairsPerRound
                ? remaining.count - minimumPairsPerRound : min(pairsPerRound, remaining.count)
            let slice = Array(remaining.prefix(take))
            remaining.removeFirst(take)
            boards.append(
                MatchingDrill(
                    id: "review.mixed." + slice.map(\.id).joined(separator: "+"),
                    title: "What you have learned",
                    subtitle: "\(slice.count) pair\(slice.count == 1 ? "" : "s") from concepts you have learned",
                    unitID: slice.first.flatMap { pair in
                        GoCourseCatalog.lesson(id: pair.requiredLessonID ?? "")
                            .map { GoCourseCatalog.unit(containing: $0.id)?.id ?? "core" }
                    } ?? "core",
                    pairs: slice
                )
            )
        }
        // Reinforce a small learned pool without introducing unfinished concepts.
        guard !boards.isEmpty else { return [] }
        let learnedBoards = boards
        while boards.count < minimumRounds {
            let source = learnedBoards[boards.count % learnedBoards.count]
            boards.append(MatchingDrill(id: source.id + ".reinforce.\(boards.count)",
                title: source.title, subtitle: "Reinforce concepts you have learned",
                unitID: source.unitID, pairs: source.pairs))
        }
        return Array(shuffle(boards).prefix(maximumRounds))
    }

    // MARK: - Boards

    static let core = MatchingDrill(
        id: "review.core",
        title: "Go core",
        subtitle: "Names, zeros and what the compiler rejects",
        unitID: "core",
        pairs: [
            MatchingPair(
                id: "review.core.zero",
                prompt: "var n int",
                answer: "Already 0; nothing is uninitialised",
                conceptTag: GoConcept.varsUnused,
                requiredLessonID: "core.zero-values",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.core.short",
                prompt: "x := 3",
                answer: "Declares, and only inside a function",
                conceptTag: GoConcept.shortDeclaration,
                requiredLessonID: "core.short-declaration",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.core.returns",
                prompt: "v, err := Open()",
                answer: "Two results instead of one exception",
                conceptTag: GoConcept.missingReturn,
                requiredLessonID: "core.multiple-returns",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.core.unused",
                prompt: "declared and not used",
                answer: "A local you named but never read",
                conceptTag: GoConcept.varsUnused,
                requiredLessonID: "core.unused-is-an-error"
            ),
            MatchingPair(
                id: "review.core.const",
                prompt: "const n = 3",
                answer: "Untyped until a use gives it a type",
                conceptTag: GoConcept.constants,
                requiredLessonID: "core.constants",
                promptIsCode: true
            ),
        ]
    )

    static let collections = MatchingDrill(
        id: "review.collections",
        title: "Slices, maps, strings",
        subtitle: "What the header actually holds",
        unitID: "collections",
        pairs: [
            MatchingPair(
                id: "review.col.len",
                prompt: "len(s) vs cap(s)",
                answer: "len is readable; cap is room to grow",
                conceptTag: GoConcept.sliceCapacity,
                requiredLessonID: "collections.length-capacity",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.col.alias",
                prompt: "b := a[1:3]",
                answer: "Shares a's array until one of them grows",
                conceptTag: GoConcept.sliceAliasing,
                requiredLessonID: "collections.append-aliasing",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.col.map",
                prompt: "m[\"missing\"]",
                answer: "The zero value, not an error or a panic",
                conceptTag: GoConcept.mapZeroValue,
                requiredLessonID: "collections.map-zero-value",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.col.runes",
                prompt: "for i, r := range s",
                answer: "r is a rune; i counts bytes",
                conceptTag: GoConcept.stringRunes,
                requiredLessonID: "collections.runes-not-bytes",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.col.iter",
                prompt: "range over a function",
                answer: "yield stops the loop when it returns false",
                conceptTag: GoConcept.rangeOverFunc,
                requiredLessonID: "collections.iterators"
            ),
        ]
    )

    static let types = MatchingDrill(
        id: "review.types",
        title: "Types and interfaces",
        subtitle: "Who owns the data, who names the methods",
        unitID: "structs",
        pairs: [
            MatchingPair(
                id: "review.types.struct",
                prompt: "Person{Name: \"Ada\"}",
                answer: "A keyed struct literal; other fields stay zero",
                conceptTag: GoConcept.structLiteral,
                requiredLessonID: "structs.literals",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.types.method",
                prompt: "func (c *Counter) Add()",
                answer: "Only *Counter has Add, never Counter",
                conceptTag: GoConcept.methodSet,
                requiredLessonID: "structs.methods",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.types.ptr",
                prompt: "p := &value",
                answer: "A pointer is for changing, not for speed",
                conceptTag: GoConcept.pointerReceiver,
                requiredLessonID: "structs.pointers",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.types.iface",
                prompt: "type Reader interface",
                answer: "The consumer names the methods it needs",
                conceptTag: GoConcept.smallInterface,
                requiredLessonID: "interfaces.implicit",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.types.nil",
                prompt: "err != nil, but err is nil",
                answer: "A nil pointer inside a non-nil interface",
                conceptTag: GoConcept.nilInterface,
                requiredLessonID: "interfaces.nil"
            ),
        ]
    )

    static let errors = MatchingDrill(
        id: "review.errors",
        title: "Errors and packages",
        subtitle: "Values, wrapping, and what a capital letter means",
        unitID: "errors",
        pairs: [
            MatchingPair(
                id: "review.err.wrap",
                prompt: "fmt.Errorf(\"...: %w\", err)",
                answer: "Adds context; the cause stays reachable",
                conceptTag: GoConcept.errorWrapping,
                requiredLessonID: "errors.wrapping",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.err.is",
                prompt: "errors.Is(err, io.EOF)",
                answer: "Compares a sentinel through wrapping",
                conceptTag: GoConcept.errorSentinel,
                requiredLessonID: "errors.is-and-as",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.err.defer",
                prompt: "defer f.Close()",
                answer: "Runs last-in first-out, every return",
                conceptTag: GoConcept.deferCleanup,
                requiredLessonID: "errors.defer",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.mod.path",
                prompt: "import \"mod/pkg\"",
                answer: "Module path plus the directory",
                conceptTag: GoConcept.importPath,
                requiredLessonID: "modules.import-path",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.mod.export",
                prompt: "func Parse()",
                answer: "A capital letter is the access modifier",
                conceptTag: GoConcept.smallInterface,
                requiredLessonID: "modules.exported-by-case",
                promptIsCode: true
            ),
        ]
    )

    static let concurrency = MatchingDrill(
        id: "review.concurrency",
        title: "Concurrency",
        subtitle: "What blocks, who closes, and what a lock is for",
        unitID: "concurrency",
        pairs: [
            MatchingPair(
                id: "review.conc.unbuf",
                prompt: "make(chan int)",
                answer: "A meeting: send waits for a receiver",
                conceptTag: GoConcept.deadlock,
                requiredLessonID: "concurrency.unbuffered-rendezvous",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.conc.go",
                prompt: "go work()",
                answer: "Starts a goroutine and returns nothing",
                conceptTag: GoConcept.goroutineLeak,
                requiredLessonID: "concurrency.no-handle",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.conc.close",
                prompt: "close(ch)",
                answer: "The sender's job, and only ever once",
                conceptTag: GoConcept.channelClose,
                requiredLessonID: "concurrency.channel-close",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.conc.select",
                prompt: "select { ... }",
                answer: "Waits on several cases; context says stop",
                conceptTag: GoConcept.selectBranch,
                requiredLessonID: "concurrency.select-context",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.conc.mutex",
                prompt: "mu.Lock(); defer Unlock",
                answer: "A mutex is for state you keep",
                conceptTag: GoConcept.mutex,
                requiredLessonID: "concurrency.mutex",
                promptIsCode: true
            ),
        ]
    )

    static let tour = MatchingDrill(
        id: "review.tour",
        title: "From A Tour of Go",
        subtitle: "Named results, make, arrays, Stringer, any",
        unitID: "core",
        pairs: [
            MatchingPair(
                id: "review.tour.named",
                prompt: "return  // naked",
                answer: "Sends the named results as they stand",
                conceptTag: GoConcept.namedResults,
                requiredLessonID: "core.named-results",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.tour.make",
                prompt: "make vs new",
                answer: "make initializes; new returns a pointer",
                conceptTag: GoConcept.makeVsNew,
                requiredLessonID: "collections.make-and-new"
            ),
            MatchingPair(
                id: "review.tour.array",
                prompt: "[4]int vs [3]int",
                answer: "The length is part of the type",
                conceptTag: GoConcept.arrays,
                requiredLessonID: "collections.arrays",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.tour.stringer",
                prompt: "fmt.Stringer",
                answer: "String(); fmt looks for it",
                conceptTag: GoConcept.stringer,
                requiredLessonID: "interfaces.stringer",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.tour.any",
                prompt: "any",
                answer: "interface{} with zero methods",
                conceptTag: GoConcept.emptyInterface,
                requiredLessonID: "interfaces.empty",
                promptIsCode: true
            ),
        ]
    )

    static let stdlib = MatchingDrill(
        id: "review.stdlib",
        title: "Stdlib and channels",
        subtitle: "Handler, Atoi, Image, buffers, direction",
        unitID: "stdlib",
        pairs: [
            MatchingPair(
                id: "review.std.http",
                prompt: "http.Handler",
                answer: "ServeHTTP, one method",
                conceptTag: GoConcept.stdlibHTTP,
                requiredLessonID: "stdlib.http",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.std.atoi",
                prompt: "strconv.Atoi",
                answer: "Text to int, plus an error",
                conceptTag: GoConcept.stdlibStrconv,
                requiredLessonID: "stdlib.strconv",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.std.image",
                prompt: "image.Image",
                answer: "ColorModel, Bounds and At",
                conceptTag: GoConcept.stdlibImage,
                requiredLessonID: "stdlib.image",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.std.buf",
                prompt: "make(chan T, n)",
                answer: "A mailbox; send waits when full",
                conceptTag: GoConcept.bufferedChannel,
                requiredLessonID: "concurrency.buffered",
                promptIsCode: true
            ),
            MatchingPair(
                id: "review.std.dir",
                prompt: "chan<- int",
                answer: "Send-only; close lives here",
                conceptTag: GoConcept.channelDirection,
                requiredLessonID: "concurrency.direction",
                promptIsCode: true
            ),
        ]
    )
}
