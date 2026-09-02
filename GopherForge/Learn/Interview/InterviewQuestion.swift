import Foundation

/// A question a Go interview actually asks, and what a good answer covers.
///
/// Deliberately not multiple choice. An interview is answered out loud, and the
/// skill being practised is saying the thing clearly — a list of four options
/// trains recognition, which is a different and easier skill. So the app shows
/// the question, waits, and then shows what a strong answer would have said,
/// leaving the comparison to the reader.
///
/// Every question also names the answer that sounds right and is not, because
/// that is usually the one that arrives first.
struct InterviewQuestion: Identifiable, Equatable, Sendable {
    let id: String
    let unitID: String
    /// The question, worded the way somebody would ask it across a table.
    let prompt: String
    /// Go the question is about. Empty when it needs none.
    let code: String
    /// What a strong answer covers, in the order the points matter.
    let answerPoints: [String]
    /// The plausible wrong answer, named so it can be recognised on the way out
    /// of your own mouth.
    let trap: String
    /// The same vocabulary the compiler and the review scheduler use.
    let conceptTag: String
}

enum InterviewCatalog {
    static func questions(forUnit unitID: String) -> [InterviewQuestion] {
        all.filter { $0.unitID == unitID }
    }

    static let all: [InterviewQuestion] = core + collections + interfaces + errors
        + modules + concurrency + standardLibrary

    // MARK: - Go core

    private static let core: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.core.zero-values",
            unitID: "core",
            prompt: "Go has no constructors and no uninitialised memory. What is a zero value, and what does the language get in exchange for insisting on one?",
            code: "",
            answerPoints: [
                "Every type has a zero value and every declaration produces it: 0, \"\", false, nil for pointers, slices, maps, channels and interfaces, and a struct whose fields are each their own zero.",
                "So a declared variable is always usable. There is no uninitialised state to reason about and no constructor that might not have run.",
                "The exchange is that the zero value has to be designed. sync.Mutex and bytes.Buffer are usable at zero; a type that needs setup has to say so, which is why NewThing exists as a convention rather than a language feature.",
            ],
            trap: "Saying it is \"like default initialisation in C++ or Java\". Those languages leave some things uninitialised or require a constructor to run; Go's point is that neither is ever true.",
            conceptTag: GoConcept.shortDeclaration
        ),
        InterviewQuestion(
            id: "interview.core.receivers",
            unitID: "core",
            prompt: "When do you give a method a pointer receiver rather than a value receiver?",
            code: "",
            answerPoints: [
                "When the method mutates the receiver, because a value receiver mutates a copy and the caller sees nothing.",
                "When the value is large enough that copying it per call matters — though that is a measurement, not a guess.",
                "When any method on the type needs a pointer, all of them should take one: a mixed method set is confusing and changes what satisfies an interface.",
            ],
            trap: "\"Pointers are faster.\" For a small struct a copy is often cheaper than the indirection, and the real reason is mutation, not speed.",
            conceptTag: GoConcept.methodSet
        ),
    ]

    // MARK: - Slices, maps and strings

    private static let collections: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.collections.append",
            unitID: "collections",
            prompt: "What is the difference between a slice's length and its capacity, and when does append allocate?",
            code: "",
            answerPoints: [
                "A slice is a pointer to an array, a length and a capacity. Length is how many elements you can index; capacity is how many the underlying array has from that pointer onwards.",
                "append writes in place while length is below capacity. When it is not, it allocates a bigger array, copies, and returns a slice pointing at the new one.",
                "That is why the return value of append must be used: after a growth the old slice header is stale.",
            ],
            trap: "Saying append \"always allocates\" or \"never does\". Which one happened is invisible from the call site, which is exactly why the result has to be assigned.",
            conceptTag: GoConcept.sliceCapacity
        ),
        InterviewQuestion(
            id: "interview.collections.aliasing",
            unitID: "collections",
            prompt: "Two slices are taken from the same array. What happens to the second when you append to the first?",
            code: """
            base := make([]int, 3, 8)
            left := base[0:2]
            right := base[0:3]
            left = append(left, 99)
            """,
            answerPoints: [
                "left has room in the shared array, so append writes index 2 in place rather than allocating.",
                "right[2] is that same element, so it now reads 99 — nothing was copied and nothing warned you.",
                "Cutting the capacity with a three-index slice, base[0:2:2], makes the append allocate instead and breaks the aliasing on purpose.",
            ],
            trap: "Assuming a slice expression copies. It never does: it makes another view of the same array.",
            conceptTag: GoConcept.sliceAliasing
        ),
    ]

    // MARK: - Interfaces

    private static let interfaces: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.interfaces.satisfaction",
            unitID: "interfaces",
            prompt: "How does a type come to satisfy an interface in Go, and when is that decided?",
            code: "",
            answerPoints: [
                "Structurally and implicitly: a type satisfies an interface by having the methods, with no declaration that it intends to.",
                "It is checked at compile time, at the point of assignment or call — not at run time, and not where the type is defined.",
                "So an interface can be declared by the consumer, next to the code that needs it, and existing types satisfy it without being touched. That is why Go interfaces are usually small and defined where they are used.",
            ],
            trap: "Reaching for \"duck typing\". The checking is static; nothing is discovered at run time.",
            conceptTag: GoConcept.smallInterface
        ),
        InterviewQuestion(
            id: "interview.interfaces.nil",
            unitID: "interfaces",
            prompt: "A function returns an error that is not nil, but the pointer inside it is. How does that happen?",
            code: """
            func find() error {
            \tvar err *NotFoundError
            \treturn err
            }
            """,
            answerPoints: [
                "An interface value is a pair: a type and a value. It is nil only when both halves are.",
                "Returning a nil *NotFoundError as an error fills the type half, so the interface is not nil even though the pointer is.",
                "The fix is to return a literal nil rather than a typed nil variable — and to not declare a typed error variable for the happy path in the first place.",
            ],
            trap: "\"err == nil should be true because err is nil.\" It is the most reliably surprising thing in the language, and the answer is that the comparison is about the pair.",
            conceptTag: GoConcept.nilInterface
        ),
    ]

    // MARK: - Errors

    private static let errors: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.errors.wrapping",
            unitID: "errors",
            prompt: "When do you wrap an error, and when do you return it as it is?",
            code: "",
            answerPoints: [
                "Wrap with %w when you are adding context the caller does not have — which file, which key, which request — and the original still matters for a decision further up.",
                "Return it unchanged when you have nothing to add. A wrap that says \"failed to read: failed to read: no such file\" is noise.",
                "Do not wrap when the original is an implementation detail you do not want callers matching on: that turns a private failure into part of your API.",
            ],
            trap: "Wrapping everything by reflex. Every %w is a promise that callers may use errors.Is against what is inside.",
            conceptTag: GoConcept.errorWrapping
        ),
        InterviewQuestion(
            id: "interview.errors.is-as",
            unitID: "errors",
            prompt: "What is the difference between errors.Is and errors.As?",
            code: "",
            answerPoints: [
                "errors.Is asks whether an error in the chain is a particular value — a sentinel such as io.EOF or os.ErrNotExist.",
                "errors.As asks whether an error in the chain is a particular type, and if so assigns it to your variable so you can read its fields.",
                "Both walk the wrap chain, which is why == fails on a wrapped error and errors.Is does not.",
            ],
            trap: "Comparing with == out of habit. It works right up until somebody adds a %w between you and the sentinel.",
            conceptTag: GoConcept.errorSentinel
        ),
    ]

    // MARK: - Modules

    private static let modules: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.modules.go-sum",
            unitID: "modules",
            prompt: "What does a require line in go.mod pin, and what does go.sum add on top of it?",
            code: "",
            answerPoints: [
                "go.mod records the module path and the minimum version your build needs. Go picks the highest minimum across the whole graph — minimal version selection — so a build is reproducible without a lock file.",
                "go.sum records a cryptographic hash of each module's content, so a version that changed underneath you fails verification instead of building.",
                "They answer different questions: go.mod is which version, go.sum is whether the bytes are the ones everybody else got.",
            ],
            trap: "Calling go.sum a lock file. It does not choose versions; it verifies whatever was chosen.",
            conceptTag: GoConcept.importPath
        ),
    ]

    // MARK: - Concurrency

    private static let concurrency: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.concurrency.close",
            unitID: "concurrency",
            prompt: "Who closes a channel, and what goes wrong when the other side does it?",
            code: "",
            answerPoints: [
                "The sender closes, because closing means \"no more values are coming\" and only the sending side knows that.",
                "A receiver that closes can race with a send in flight, and a send on a closed channel panics — it is not an error you can handle at the send.",
                "With several senders, nobody closes directly: a WaitGroup waits for them and one goroutine closes afterwards.",
            ],
            trap: "\"Whoever finishes first closes it.\" Closing is not cleanup; it is a message, and it can only be sent by the side that has the news.",
            conceptTag: GoConcept.channelClose
        ),
        InterviewQuestion(
            id: "interview.concurrency.mutex-or-channel",
            unitID: "concurrency",
            prompt: "Mutex or channel — how do you choose?",
            code: "",
            answerPoints: [
                "A mutex protects state several goroutines share: a counter, a cache, a map. The value stays where it is and access is serialised.",
                "A channel hands a value over: one goroutine is finished with it and another should have it. Ownership moves.",
                "If routing something through a channel would just be ceremony around an increment, it is a mutex. If two goroutines are passing work along, it is a channel.",
            ],
            trap: "\"Share memory by communicating, so always use a channel.\" The proverb is advice about design, not a ban on sync — the standard library is full of mutexes.",
            conceptTag: GoConcept.mutex
        ),
        InterviewQuestion(
            id: "interview.concurrency.leak",
            unitID: "concurrency",
            prompt: "What is a goroutine leak, and how would you notice one in production?",
            code: "",
            answerPoints: [
                "A goroutine blocked on a channel nobody will ever send to, or on a receive from a context that is never cancelled. It is not an error anywhere: it simply stops, holding its stack.",
                "It shows as memory that climbs and never comes back, and as a goroutine count that only goes up — runtime.NumGoroutine, or the goroutine profile from net/http/pprof.",
                "The fixes are structural: give every goroutine a way to be told to stop, usually a context, and make sure every channel it might block on either gets closed or gets a select with a cancellation branch.",
            ],
            trap: "Expecting the runtime to complain. It only reports a deadlock when *every* goroutine is asleep — one stuck goroutine beside a busy program is silent.",
            conceptTag: GoConcept.goroutineLeak
        ),
        InterviewQuestion(
            id: "interview.concurrency.context",
            unitID: "concurrency",
            prompt: "What actually happens when you cancel a context?",
            code: "",
            answerPoints: [
                "Its Done channel is closed. That is the whole mechanism — cancellation is a closed channel, which is why a select can wait on it and why it can be observed by any number of goroutines at once.",
                "Cancellation propagates down to contexts derived from it, never up.",
                "Nothing is stopped for you. A goroutine that never checks Done keeps running; the context only makes it possible to notice.",
            ],
            trap: "Believing cancel() kills anything. Go has no way to stop another goroutine — cancellation is a request that has to be read.",
            conceptTag: GoConcept.contextCancel
        ),
    ]

    // MARK: - Standard library

    private static let standardLibrary: [InterviewQuestion] = [
        InterviewQuestion(
            id: "interview.stdlib.reader",
            unitID: "stdlib",
            prompt: "io.Reader returns (n int, err error). Why both, and what must a caller do with them?",
            code: "",
            answerPoints: [
                "A Read may return data and an error in the same call — n bytes were genuinely read even if err is io.EOF.",
                "So the caller processes the first n bytes before looking at err, in that order. Checking the error first and returning loses data.",
                "io.EOF is not a failure: it is how a reader says it has finished. Any other error is.",
            ],
            trap: "Treating a non-nil error as \"nothing was read\". That is true of most APIs and not of this one, which is why the interface is worth asking about.",
            conceptTag: GoConcept.stdlibIO
        ),
    ]
}
