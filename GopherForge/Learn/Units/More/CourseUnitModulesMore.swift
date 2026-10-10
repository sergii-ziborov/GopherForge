import Foundation

/// Two more for modules: what a package is called, and what init is for.
extension CourseUnitModules {
    static let packageNaming = Lesson(
        id: "modules.naming",
        title: "The package name is half the API",
        objective: "Name a package and its exported function without repeating yourself.",
        explanation: """
        A package's name becomes the qualifier callers read: `http.Server` is clearer than `http.HTTPServer`. Prefer short, descriptive lowercase names. Singular names are common, but useful standard-library packages such as `strings`, `errors` and `slices` are plural.

        Avoid needless repetition between package and exported name. `chart.New` can be clear for a package centered on one chart type; a package with several constructors may need more specific names. Read the whole selector to judge it.
        """,
        conceptTags: [GoConcept.importPath],
        task: .predict(
            source: """
            package main

            import (
            \t"fmt"
            \t"strings"
            )

            func main() {
            \t// Every one of these reads as package.Identifier at the call site.
            \tfmt.Println(strings.ToUpper("go"))
            \tfmt.Println(strings.HasPrefix("gopher", "go"))
            \tr := strings.NewReplacer("a", "4", "e", "3")
            \tfmt.Println(r.Replace("beware"))
            }
            """,
            question: "What does this print?",
            answer: """
            GO
            true
            b3w4r3
            """
        ),
        idiomaticSolution: nil
    )

    static let initAndPackageState = Lesson(
        id: "modules.init",
        title: "init runs before main, and order is defined",
        objective: "Predict the order of package variables, init and main.",
        explanation: """
        A package initializes its variables using their dependency relationships, then runs its init functions in source order as presented to the compiler. Imported packages finish initialization before the importing package. `main` starts after the program's initialization completes.

        Do not depend on arbitrary file presentation order for important behavior. Explicit constructors make configuration and recoverable failure handling visible. An init function takes no arguments and returns no result, though it can register a driver or format as a deliberate import side effect.
        """,
        conceptTags: [GoConcept.packageInit],
        task: .predict(
            source: """
            package main

            import "fmt"

            var first = announce("first")
            var second = announce("second")

            func announce(name string) string {
            \tfmt.Println("var", name)
            \treturn name
            }

            func init() {
            \tfmt.Println("init")
            }

            func main() {
            \tfmt.Println("main", first, second)
            }
            """,
            question: "In what order do the lines appear?",
            answer: """
            var first
            var second
            init
            main first second
            """
        ),
        idiomaticSolution: nil
    )
}
