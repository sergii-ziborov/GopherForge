import Foundation

/// A teaching program for the Concurrency Lab.
///
/// Each scenario is a real Go program that really compiles and really runs in
/// the sandbox. The instrumentation is ordinary code inside the program, not a
/// hook into the runtime, so what the lab draws is exactly what the program
/// reported doing.
struct ConcurrencyLabScenario: Identifiable, Sendable {
    /// What a scenario is about, so the lab can be a shelf of related things
    /// rather than one dropdown holding everything.
    enum Family: String, CaseIterable, Identifiable, Sendable {
        case channels
        case coordination
        case mistakes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .channels: "Channels"
            case .coordination: "Coordination"
            case .mistakes: "Ways it goes wrong"
            }
        }

        var summary: String {
            switch self {
            case .channels: "What a send and a receive actually do to each other."
            case .coordination: "Making several goroutines finish, and knowing when."
            case .mistakes: "The failures worth recognising on sight."
            }
        }

        var systemImage: String {
            switch self {
            case .channels: "arrow.left.arrow.right"
            case .coordination: "person.3"
            case .mistakes: "exclamationmark.triangle"
            }
        }
    }

    let id: String
    let title: String
    let family: Family
    /// The one sentence to leave with, shown after the run rather than before
    /// it — it is the answer, and the prediction has to come first.
    let takeaway: String
    let question: String
    let conceptTags: [String]
    /// What the learner should predict before running. The lab asks first and
    /// runs second, because a prediction that turns out wrong is the moment
    /// the lesson lands.
    let prediction: String
    let source: String

    var snapshot: GoSourceSnapshot {
        GoSourceSnapshot(
            files: [
                "go.mod": GoLanguage.module("lab"),
                "lab.go": ConcurrencyLabScenario.instrumentation,
                "main.go": source,
            ],
            packagePattern: ".",
            entryFile: "main.go"
        )
    }
}

extension ConcurrencyLabScenario {
    /// The instrumentation every scenario imports. It is deliberately tiny and
    /// visible to the learner: nothing about the lab is hidden machinery.
    static let instrumentation = """
    package main

    import (
    \t"fmt"
    \t"sync/atomic"
    )

    var labSequence atomic.Int64

    // trace prints one structured line the app reads to draw the lab. It is
    // ordinary code: remove it and the program still behaves the same way.
    func trace(kind, actor string, fields ...string) {
    \tline := fmt.Sprintf("#lab %d %s %s", labSequence.Add(1), kind, actor)
    \tfor _, field := range fields {
    \t\tline += " " + field
    \t}
    \tfmt.Println(line)
    }

    // itoa without importing strconv, so a scenario's own source stays about
    // concurrency and nothing else.
    func itoa(value int) string {
    \treturn fmt.Sprintf("%d", value)
    }
    """

    static let all: [ConcurrencyLabScenario] = [
        unbufferedRendezvous,
        bufferedChannel,
        senderClosesChannel,
        waitGroupFanOut,
        workerPool,
        mutexCounter,
        nilChannelInSelect,
        selectWithCancellation,
        leakedReceiver,
    ]

    static let unbufferedRendezvous = ConcurrencyLabScenario(
        id: "unbuffered-rendezvous",
        title: "An unbuffered channel is a meeting, not a mailbox",
        family: .channels,
        takeaway: """
        An unbuffered channel has no room in it, so a send and a receive have to happen at the same moment — whichever arrives first waits for the other.
        """,
        question: "Which line runs first: the send or the receive?",
        conceptTags: [GoConcept.selectBranch, GoConcept.deadlock],
        prediction: "Neither. Both goroutines wait until the other arrives.",
        source: """
        package main

        func main() {
        \tready := make(chan string)

        \tgo func() {
        \t\ttrace("go", "greeter")
        \t\ttrace("send", "greeter", "ready", "hello")
        \t\tready <- "hello"
        \t\ttrace("done", "greeter")
        \t}()

        \ttrace("blocked", "main", "ready", "waiting-for-value")
        \tmessage := <-ready
        \ttrace("receive", "main", "ready", message)
        \tprintln(message)
        }
        """
    )

    static let senderClosesChannel = ConcurrencyLabScenario(
        id: "sender-closes-channel",
        title: "Closing is the sender's job",
        family: .channels,
        takeaway: """
        The side that sends is the side that knows there is nothing more coming, which is why closing is its job and why range on the receiver ends by itself.
        """,
        question: "Who is allowed to close jobs, and how does the receiver know it ended?",
        conceptTags: [GoConcept.channelClose],
        prediction: "The producer closes, and range on the receiver ends by itself.",
        source: """
        package main

        func main() {
        \tjobs := make(chan int, 2)

        \tgo func() {
        \t\ttrace("go", "producer")
        \t\tfor i := 1; i <= 3; i++ {
        \t\t\ttrace("send", "producer", "jobs", itoa(i))
        \t\t\tjobs <- i
        \t\t}
        \t\ttrace("close", "producer", "jobs")
        \t\tclose(jobs)
        \t\ttrace("done", "producer")
        \t}()

        \tfor job := range jobs {
        \t\ttrace("receive", "main", "jobs", itoa(job))
        \t}
        \ttrace("done", "main")
        }

        """
    )

    static let selectWithCancellation = ConcurrencyLabScenario(
        id: "select-with-cancellation",
        title: "select takes the branch that is ready",
        family: .coordination,
        takeaway: """
        A select takes whichever branch is ready first, and a cancelled context is a branch that becomes ready — which is how you make a blocking wait give up.
        """,
        question: "When the context is cancelled before the work finishes, which branch wins?",
        conceptTags: [GoConcept.selectBranch, GoConcept.contextCancel],
        prediction: "The ctx.Done branch, and the worker's result is never read.",
        source: """
        package main

        import "context"

        func main() {
        \tctx, cancel := context.WithCancel(context.Background())
        \tresults := make(chan string)

        \tgo func() {
        \t\ttrace("go", "worker")
        \t\ttrace("blocked", "worker", "results", "no-receiver-yet")
        \t\tresults <- "finished"
        \t\ttrace("done", "worker")
        \t}()

        \ttrace("cancel", "main", "ctx")
        \tcancel()

        \tselect {
        \tcase value := <-results:
        \t\ttrace("select", "main", "results", value)
        \tcase <-ctx.Done():
        \t\ttrace("select", "main", "ctx.Done")
        \t}
        \ttrace("done", "main")
        }
        """
    )

    static let leakedReceiver = ConcurrencyLabScenario(
        id: "leaked-receiver",
        title: "A goroutine nobody will ever meet",
        family: .mistakes,
        takeaway: """
        A goroutine blocked on a channel nobody will ever send to is not an error anywhere; it simply stops, holding its stack, for as long as the program runs.
        """,
        question: "main returns immediately. What happens to the goroutine still waiting?",
        conceptTags: [GoConcept.goroutineLeak],
        prediction: "It stays blocked forever and its work is silently lost.",
        source: """
        package main

        func main() {
        \tvalues := make(chan int)

        \tgo func() {
        \t\ttrace("go", "listener")
        \t\ttrace("blocked", "listener", "values", "waiting-for-value")
        \t\t<-values
        \t\ttrace("done", "listener")
        \t}()

        \ttrace("done", "main")
        }
        """
    )

    static let bufferedChannel = ConcurrencyLabScenario(
        id: "buffered-channel",
        title: "A buffer moves where the waiting happens",
        family: .channels,
        takeaway: """
        A buffer does not remove the waiting, it relocates it: sends run ahead \
        until the buffer is full, and only then does the sender wait for a \
        receiver — which is why capacity is a decision about who blocks, not \
        an optimisation.
        """,
        question: "With room for two, how many sends finish before anybody receives?",
        conceptTags: [GoConcept.channelClose, GoConcept.deadlock],
        prediction: "Two. The third send waits until the reader takes something out.",
        source: """
        package main

        func main() {
        \tnotes := make(chan string, 2)
        \tfinished := make(chan bool)

        \tgo func() {
        \t\ttrace("go", "reader")
        \t\tfor note := range notes {
        \t\t\ttrace("receive", "reader", "notes", note)
        \t\t}
        \t\ttrace("done", "reader")
        \t\tfinished <- true
        \t}()

        \tfor _, note := range []string{"first", "second", "third"} {
        \t\ttrace("send", "main", "notes", note)
        \t\tnotes <- note
        \t}
        \ttrace("close", "main", "notes")
        \tclose(notes)

        \ttrace("blocked", "main", "finished", "waiting-for-reader")
        \t<-finished
        \ttrace("done", "main")
        }
        """
    )

    static let waitGroupFanOut = ConcurrencyLabScenario(
        id: "waitgroup-fan-out",
        title: "A WaitGroup counts, it does not carry",
        family: .coordination,
        takeaway: """
        A WaitGroup answers exactly one question — have they all finished — and \
        nothing about what they produced. Add before you start the goroutine, \
        never inside it, or Wait can return before the count was ever raised.
        """,
        question: "What does Wait actually wait for, and what does it tell you afterwards?",
        conceptTags: [GoConcept.waitGroup],
        prediction: "It waits for the count to reach zero, and tells you nothing else.",
        source: """
        package main

        import "sync"

        func main() {
        \tvar workers sync.WaitGroup

        \tfor id := 1; id <= 3; id++ {
        \t\tworkers.Add(1)
        \t\ttrace("wg-add", "main", "workers")
        \t\tgo func(id int) {
        \t\t\tdefer workers.Done()
        \t\t\tname := "worker-" + itoa(id)
        \t\t\ttrace("go", name)
        \t\t\ttrace("wg-done", name, "workers")
        \t\t}(id)
        \t}

        \ttrace("blocked", "main", "workers", "waiting-for-three")
        \tworkers.Wait()
        \ttrace("wg-wait", "main", "workers")
        \ttrace("done", "main")
        }
        """
    )

    static let workerPool = ConcurrencyLabScenario(
        id: "worker-pool",
        title: "Fan out to workers, fan back in to one reader",
        family: .coordination,
        takeaway: """
        Two channels and a WaitGroup are the whole pattern: the sender closes \
        jobs so the workers' range ends, and a separate goroutine waits for the \
        workers and closes results so the reader's range ends too. Nobody \
        counts anything by hand.
        """,
        question: "Who closes results, and why can it not be one of the workers?",
        conceptTags: [GoConcept.waitGroup, GoConcept.channelClose],
        prediction: "A goroutine that waits for all the workers. A worker closing it would cut off the others.",
        source: """
        package main

        import "sync"

        func main() {
        \tjobs := make(chan int)
        \tresults := make(chan int)
        \tvar workers sync.WaitGroup

        \tfor id := 1; id <= 2; id++ {
        \t\tworkers.Add(1)
        \t\tgo func(id int) {
        \t\t\tdefer workers.Done()
        \t\t\tname := "worker-" + itoa(id)
        \t\t\ttrace("go", name)
        \t\t\tfor job := range jobs {
        \t\t\t\ttrace("receive", name, "jobs", itoa(job))
        \t\t\t\tresults <- job * job
        \t\t\t\ttrace("send", name, "results", itoa(job*job))
        \t\t\t}
        \t\t\ttrace("done", name)
        \t\t}(id)
        \t}

        \tgo func() {
        \t\tfor job := 1; job <= 4; job++ {
        \t\t\ttrace("send", "feeder", "jobs", itoa(job))
        \t\t\tjobs <- job
        \t\t}
        \t\ttrace("close", "feeder", "jobs")
        \t\tclose(jobs)
        \t}()

        \tgo func() {
        \t\tworkers.Wait()
        \t\ttrace("wg-wait", "closer", "workers")
        \t\ttrace("close", "closer", "results")
        \t\tclose(results)
        \t}()

        \ttotal := 0
        \tfor result := range results {
        \t\ttrace("receive", "main", "results", itoa(result))
        \t\ttotal += result
        \t}
        \ttrace("done", "main")
        \tprintln("total", total)
        }
        """
    )

    static let mutexCounter = ConcurrencyLabScenario(
        id: "mutex-counter",
        title: "A mutex guards state; a channel hands it over",
        family: .coordination,
        takeaway: """
        Reach for a mutex when several goroutines need the same variable, and \
        for a channel when one goroutine is done with a value and another \
        should have it. A counter is the first case, and routing it through a \
        channel would be ceremony around an increment.
        """,
        question: "Four goroutines increment the same counter. What makes the total reliable?",
        conceptTags: [GoConcept.mutex, GoConcept.waitGroup],
        prediction: "The lock. Without it the increments can interleave and land on top of each other.",
        source: """
        package main

        import "sync"

        func main() {
        \tvar lock sync.Mutex
        \tvar workers sync.WaitGroup
        \tcount := 0

        \tfor id := 1; id <= 4; id++ {
        \t\tworkers.Add(1)
        \t\tgo func(id int) {
        \t\t\tdefer workers.Done()
        \t\t\tname := "worker-" + itoa(id)
        \t\t\ttrace("go", name)
        \t\t\tlock.Lock()
        \t\t\tcount++
        \t\t\ttrace("send", name, "count", itoa(count))
        \t\t\tlock.Unlock()
        \t\t\ttrace("done", name)
        \t\t}(id)
        \t}

        \ttrace("blocked", "main", "workers", "waiting-for-four")
        \tworkers.Wait()
        \ttrace("wg-wait", "main", "workers")
        \tprintln("count", count)
        }
        """
    )

    static let nilChannelInSelect = ConcurrencyLabScenario(
        id: "nil-channel-in-select",
        title: "A nil channel turns a select branch off",
        family: .mistakes,
        takeaway: """
        A receive from a nil channel blocks for ever, which inside a select \
        means that branch is simply never ready. That is a bug when the nil was \
        an accident, and a technique when it was not: setting a channel to nil \
        is how you retire one branch of a loop.
        """,
        question: "One of these channels is nil. Does the select fail, or pick the other one?",
        conceptTags: [GoConcept.selectBranch, GoConcept.deadlock],
        prediction: "It picks the other one. A nil channel is never ready, so that branch cannot win.",
        source: """
        package main

        func main() {
        \tvar disabled chan string
        \tready := make(chan string, 1)
        \tready <- "value"

        \ttrace("go", "main")
        \tselect {
        \tcase value := <-disabled:
        \t\ttrace("select", "main", "disabled", value)
        \tcase value := <-ready:
        \t\ttrace("select", "main", "ready", value)
        \t\ttrace("receive", "main", "ready", value)
        \t}
        \ttrace("done", "main")
        \tprintln("took the branch that was ready")
        }
        """
    )

}
