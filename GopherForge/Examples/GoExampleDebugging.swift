import Foundation

enum GoExampleDebugging {
    static let walkthrough = GoExample(
        id: "project.debugger-walkthrough",
        title: "Source debugger walkthrough",
        summary: "Stop before a call, inspect locals and step into and out of a function.",
        takeaway: "Tap line 12 in the gutter, then Run. With no breakpoints Run executes normally. With a breakpoint use Continue, Step Into, Step Over, Step Out and Stop. Debug probes stay outside your saved source.",
        conceptTags: [],
        source: """
        package main

        import "fmt"

        func double(n int) int {
            value := n * 2
            return value
        }

        func main() {
            start := 3
            result := double(start)
            fmt.Println(result)
        }
        """,
        expectedOutput: "6\n"
    )
}
