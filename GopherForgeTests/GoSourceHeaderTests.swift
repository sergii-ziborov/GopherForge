import XCTest
@testable import GopherForge

/// The scanner that decides which packages exist and what they import.
///
/// A wrong answer here does not produce a wrong diagnostic — it produces a
/// build that never starts, or one that omits a package, so the shapes real Go
/// files actually take are worth pinning down.
final class GoSourceHeaderTests: XCTestCase {
    func testReadsASingleImport() {
        let header = GoSourceHeader.parse("""
        package main

        import "fmt"

        func main() {}
        """)

        XCTAssertEqual(header.packageName, "main")
        XCTAssertEqual(header.imports, ["fmt"])
    }

    func testReadsAGroupWithAliasesAndBlanks() {
        let header = GoSourceHeader.parse("""
        package worker

        import (
        \t"fmt"
        \t_ "embed"
        \tstr "strings"
        \t. "math"
        )

        func Run() {}
        """)

        XCTAssertEqual(header.imports, ["fmt", "embed", "strings", "math"])
    }

    func testIgnoresImportsInsideComments() {
        let header = GoSourceHeader.parse("""
        package main

        // import "os"
        /* import "net/http" */
        import "fmt"

        func main() {}
        """)

        XCTAssertEqual(header.imports, ["fmt"])
    }

    func testIgnoresAMultiLineBlockComment() {
        let header = GoSourceHeader.parse("""
        package main

        /*
        import (
        \t"os"
        )
        */
        import "fmt"

        func main() {}
        """)

        XCTAssertEqual(header.imports, ["fmt"])
    }

    /// Go requires imports to precede declarations, which is what makes a
    /// header-only scan correct. This pins the consequence: a string that looks
    /// like an import inside a function body is not one.
    func testStopsAtTheFirstDeclaration() {
        let header = GoSourceHeader.parse("""
        package main

        import "fmt"

        func main() {
        \tfmt.Println("import \\"os\\"")
        }
        """)

        XCTAssertEqual(header.imports, ["fmt"])
    }

    func testRecognisesAnExternalTestPackage() {
        let header = GoSourceHeader.parse("""
        package mathx_test

        import "testing"
        """)

        XCTAssertTrue(header.isExternalTestPackage)
        XCTAssertEqual(header.packageName, "mathx_test")
    }

    func testReadsAnEmptySourceWithoutCrashing() {
        let header = GoSourceHeader.parse("")

        XCTAssertEqual(header.packageName, "")
        XCTAssertTrue(header.imports.isEmpty)
    }
}
