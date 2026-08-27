import Foundation

/// Two more for modules: what a package is called, and what init is for.
extension CourseUnitModules {
    static let packageNaming = Lesson(
        id: "modules.naming",
        title: "The package name is half the API",
        objective: "Name a package and its exported function without repeating yourself.",
        explanation: """
        A caller always writes the package name, so the name is part of every \
        identifier in it. `http.Server` reads well; `http.HTTPServer` does not. \
        This is why Go package names are short, lower case, one word and never \
        plural — and why a function called `util.DoUtilThing` is a smell twice \
        over.

        The rule that follows: never repeat the package name inside it. Inside \
        package `chart`, the function is `New`, not `NewChart`, because callers \
        will write `chart.New`.
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
        Package-level variables are initialised first, in dependency order \
        rather than in the order they are written. Then every `init` function \
        in the package runs, in file order. Only then does `main` start. \
        Imported packages finish all of this before the package that imports \
        them begins.

        `init` is genuinely useful for registering something — a database \
        driver, an image format — and genuinely dangerous everywhere else: it \
        runs whether or not anyone wanted it to, it cannot fail except by \
        panicking, and it makes a package's behaviour depend on being imported.
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
