import Foundation

/// A teaching program for the Concurrency Lab.
///
/// Each scenario is a real Go program that really compiles and really runs in
/// the sandbox. The instrumentation is ordinary code inside the program, not a
/// hook into the runtime, so what the lab draws is exactly what the program
/// reported doing.
struct ConcurrencyLabScenario: Identifiable, Sendable {
    let id: String
    let title: String
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
    """

    static let all: [ConcurrencyLabScenario] = [
        unbufferedRendezvous,
        senderClosesChannel,
        selectWithCancellation,
        leakedReceiver,
    ]

    static let unbufferedRendezvous = ConcurrencyLabScenario(
        id: "unbuffered-rendezvous",
        title: "An unbuffered channel is a meeting, not a mailbox",
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

        func itoa(value int) string {
        \tif value == 0 {
        \t\treturn "0"
        \t}
        \tdigits := ""
        \tfor value > 0 {
        \t\tdigits = string(rune('0'+value%10)) + digits
        \t\tvalue /= 10
        \t}
        \treturn digits
        }
        """
    )

    static let selectWithCancellation = ConcurrencyLabScenario(
        id: "select-with-cancellation",
        title: "select takes the branch that is ready",
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
}
