import Foundation

/// A short Go program with exactly one thing wrong in it, and the line it is on.
///
/// The game is tapping that line. It trains the thing code review is: reading
/// something plausible and noticing the one part that is not. Multiple choice
/// cannot practise it, because the options tell you what kind of mistake to
/// look for — here the program tells you nothing.
///
/// Every fault is unambiguous under the bundled Go. Nothing here depends on a
/// version's behaviour changing: no loop-variable capture, which Go fixed in
/// 1.22, and no "this might be slow" opinions.
struct SpotTheBugRound: Identifiable, Equatable, Sendable {
    let id: String
    let unitID: String
    /// What the program is supposed to do, so the reader knows what "wrong"
    /// would even mean.
    let brief: String
    /// One entry per line, without trailing newlines.
    let lines: [String]
    /// Index into `lines`. Zero-based; the view numbers from one.
    let faultyLine: Int
    /// Why that line is the bug, shown once an answer is committed.
    let explanation: String
    let conceptTag: String

    var lineCount: Int { lines.count }

    func isCorrect(_ index: Int) -> Bool { index == faultyLine }
}

enum SpotTheBugCatalog {
    static func rounds(forUnit unitID: String) -> [SpotTheBugRound] {
        all.filter { $0.unitID == unitID }
    }

    static let all: [SpotTheBugRound] = [
        SpotTheBugRound(
            id: "bug.core.unused",
            unitID: "core",
            brief: "This should print the doubled value. It does not compile.",
            lines: [
                "func main() {",
                "\tvalue := 21",
                "\tdoubled := value * 2",
                "\tfmt.Println(value)",
                "}",
            ],
            faultyLine: 2,
            explanation: "`doubled` is declared and never used, which is a compile error in Go rather than a warning. The language treats an unused local as a mistake you meant to catch — either print it or do not declare it.",
            conceptTag: GoConcept.varsUnused
        ),
        SpotTheBugRound(
            id: "bug.collections.nil-map",
            unitID: "collections",
            brief: "This should count words. It panics at run time.",
            lines: [
                "func count(words []string) map[string]int {",
                "\tvar totals map[string]int",
                "\tfor _, word := range words {",
                "\t\ttotals[word]++",
                "\t}",
                "\treturn totals",
                "}",
            ],
            faultyLine: 1,
            explanation: "A `var` map is nil. Reading from a nil map is fine and gives the zero value, which is why the loop looks safe — but writing to one panics. It needed `make(map[string]int)`.",
            conceptTag: GoConcept.mapZeroValue
        ),
        SpotTheBugRound(
            id: "bug.collections.append-copy",
            unitID: "collections",
            brief: "This should add an item to the caller's slice. The caller never sees it.",
            lines: [
                "func add(items []string, item string) {",
                "\titems = append(items, item)",
                "}",
                "",
                "func main() {",
                "\tnames := []string{\"a\"}",
                "\tadd(names, \"b\")",
                "\tfmt.Println(len(names))",
                "}",
            ],
            faultyLine: 1,
            explanation: "append returns a new slice header, and the parameter is a copy of the caller's. Assigning to it changes nothing outside the function. The signature has to return the slice, or take a pointer to it.",
            conceptTag: GoConcept.sliceCapacity
        ),
        SpotTheBugRound(
            id: "bug.errors.ignored",
            unitID: "errors",
            brief: "This should fail loudly when the file is missing. It carries on instead.",
            lines: [
                "func load(path string) []byte {",
                "\tdata, _ := os.ReadFile(path)",
                "\treturn data",
                "}",
            ],
            faultyLine: 1,
            explanation: "The error is discarded with `_`, so a missing file returns an empty slice that looks exactly like an empty file. In Go an error is a value you have to decide about; throwing it away is the decision to pretend nothing went wrong.",
            conceptTag: GoConcept.explicitErrorCheck
        ),
        SpotTheBugRound(
            id: "bug.errors.comparison",
            unitID: "errors",
            brief: "This should recognise a missing file. It stops recognising it the moment anybody wraps the error.",
            lines: [
                "func handle(err error) {",
                "\tif err == os.ErrNotExist {",
                "\t\tcreate()",
                "\t\treturn",
                "\t}",
                "\tlog.Fatal(err)",
                "}",
            ],
            faultyLine: 1,
            explanation: "`==` compares the error you were handed, not the chain inside it. One `%w` between you and the sentinel and the branch stops firing. `errors.Is(err, os.ErrNotExist)` walks the chain, which is what it is for.",
            conceptTag: GoConcept.errorSentinel
        ),
        SpotTheBugRound(
            id: "bug.errors.capital",
            unitID: "errors",
            brief: "This compiles and runs. `go vet` and every reviewer will still stop on it.",
            lines: [
                "func parse(input string) error {",
                "\tif input == \"\" {",
                "\t\treturn errors.New(\"Input was empty\")",
                "\t}",
                "\treturn nil",
                "}",
            ],
            faultyLine: 2,
            explanation: "Error strings are lower case and unpunctuated, because they get wrapped: yours ends up in the middle of a longer sentence, and a capital letter there reads as a new one starting.",
            conceptTag: GoConcept.customError
        ),
        SpotTheBugRound(
            id: "bug.errors.defer-loop",
            unitID: "errors",
            brief: "This should close each file as it finishes with it. It holds every one of them open instead.",
            lines: [
                "func readAll(paths []string) {",
                "\tfor _, path := range paths {",
                "\t\tfile, err := os.Open(path)",
                "\t\tif err != nil {",
                "\t\t\tcontinue",
                "\t\t}",
                "\t\tdefer file.Close()",
                "\t\tprocess(file)",
                "\t}",
                "}",
            ],
            faultyLine: 6,
            explanation: "A defer runs when the *function* returns, not when the loop body ends. Over a long list that is every file open at once. The body has to become its own function, or the close has to be called explicitly.",
            conceptTag: GoConcept.deferCleanup
        ),
        SpotTheBugRound(
            id: "bug.concurrency.receiver-closes",
            unitID: "concurrency",
            brief: "This should hand three jobs to a worker. It panics somewhere in the middle.",
            lines: [
                "func main() {",
                "\tjobs := make(chan int)",
                "\tgo func() {",
                "\t\tfor job := range jobs {",
                "\t\t\tprocess(job)",
                "\t\t\tclose(jobs)",
                "\t\t}",
                "\t}()",
                "\tfor i := 1; i <= 3; i++ {",
                "\t\tjobs <- i",
                "\t}",
                "}",
            ],
            faultyLine: 5,
            explanation: "The receiver closes the channel. Closing means \"no more values are coming\", which only the sender knows — and the next send lands on a closed channel and panics. The sender closes, after its last send.",
            conceptTag: GoConcept.channelClose
        ),
        SpotTheBugRound(
            id: "bug.concurrency.waitgroup-inside",
            unitID: "concurrency",
            brief: "This should wait for three workers. It sometimes returns before any of them have run.",
            lines: [
                "func main() {",
                "\tvar workers sync.WaitGroup",
                "\tfor i := 0; i < 3; i++ {",
                "\t\tgo func() {",
                "\t\t\tworkers.Add(1)",
                "\t\t\tdefer workers.Done()",
                "\t\t\twork()",
                "\t\t}()",
                "\t}",
                "\tworkers.Wait()",
                "}",
            ],
            faultyLine: 4,
            explanation: "Add runs inside the goroutine, so Wait can be reached while the counter is still zero and return immediately. Add belongs before `go`, on the line that decides there will be another worker.",
            conceptTag: GoConcept.waitGroup
        ),
        SpotTheBugRound(
            id: "bug.concurrency.context-position",
            unitID: "concurrency",
            brief: "This compiles and works. It still gets sent back in review.",
            lines: [
                "func Fetch(url string, ctx context.Context) ([]byte, error) {",
                "\treq, err := http.NewRequestWithContext(ctx, \"GET\", url, nil)",
                "\tif err != nil {",
                "\t\treturn nil, err",
                "\t}",
                "\treturn send(req)",
                "}",
            ],
            faultyLine: 0,
            explanation: "A context.Context is the first parameter, always, and it is named ctx. It is a convention rather than a rule, which is exactly why breaking it is noticed: every other function in the codebase reads the other way round.",
            conceptTag: GoConcept.contextFirstParameter
        ),
        SpotTheBugRound(
            id: "bug.stdlib.map-order",
            unitID: "stdlib",
            brief: "This should print the keys in a stable order. The order changes between runs.",
            lines: [
                "func printKeys(scores map[string]int) {",
                "\tfor name := range scores {",
                "\t\tfmt.Println(name)",
                "\t}",
                "}",
            ],
            faultyLine: 1,
            explanation: "Range over a map visits keys in a deliberately randomised order — the runtime randomises it so nobody can depend on one by accident. Collect the keys, sort them, then range over the sorted slice.",
            conceptTag: GoConcept.mapOrder
        ),
        SpotTheBugRound(
            id: "bug.interfaces.typed-nil",
            unitID: "interfaces",
            brief: "This should return no error when the input is fine. The caller's `err != nil` fires anyway.",
            lines: [
                "func validate(input string) error {",
                "\tvar problem *ValidationError",
                "\tif input == \"\" {",
                "\t\tproblem = &ValidationError{}",
                "\t}",
                "\treturn problem",
                "}",
            ],
            faultyLine: 5,
            explanation: "Returning a typed nil pointer as an error fills the type half of the interface value, and an interface is nil only when both halves are. Return a literal nil on the happy path instead of a typed variable.",
            conceptTag: GoConcept.nilInterface
        ),
    ]
}
