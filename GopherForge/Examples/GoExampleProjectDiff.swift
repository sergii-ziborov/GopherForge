import Foundation

/// A project with a real dependency already installed.
///
/// Everything else in the library uses the standard library only, which teaches
/// Go but not what a Go project looks like. This one ships `go-cmp` vendored:
/// the `require` line, the `go.sum` entry, `vendor/modules.txt` and the source
/// itself are all there, and it builds with no network — which is the whole
/// point of vendoring.
enum GoExampleProjectDiff {
    static let diff = GoExample(
        id: "project.diff",
        title: "Comparing with go-cmp",
        summary: "A project with a dependency already vendored, and tests that read.",
        takeaway: "reflect.DeepEqual says whether; cmp.Diff says what, which is what a test needs.",
        conceptTags: [GoConcept.stdlibTesting, GoConcept.importPath],
        source: """
        package main

        import (
        \t"fmt"

        \t"github.com/google/go-cmp/cmp"

        \t"example.com/diff/internal/inventory"
        )

        func main() {
        \twant := inventory.Item{Name: "anvil", Count: 2, Tags: []string{"heavy"}}
        \tgot := inventory.Item{Name: "anvil", Count: 3, Tags: []string{"heavy", "iron"}}

        \t// A bool would tell you they differ. This tells you how.
        \t// Diff already ends in a newline, so Print rather than Println.
        \tfmt.Print(cmp.Diff(want, got))
        }
        """,
        expectedOutput: """
          inventory.Item{
          \tName:  "anvil",
        - \tCount: 2,
        + \tCount: 3,
          \tTags: []string{
          \t\t"heavy",
        + \t\t"iron",
          \t},
          }

        """,
        extraFiles: [
            "internal/inventory/inventory.go": """
            // Package inventory is the thing being compared.
            package inventory

            // Item is deliberately a plain struct: cmp works on exported fields
            // without any help.
            type Item struct {
            \tName  string
            \tCount int
            \tTags  []string
            }
            """,
            "internal/inventory/inventory_test.go": """
            package inventory

            import (
            \t"testing"

            \t"github.com/google/go-cmp/cmp"
            )

            func TestItemsCompareByValue(t *testing.T) {
            \ta := Item{Name: "anvil", Count: 2, Tags: []string{"heavy"}}
            \tb := Item{Name: "anvil", Count: 2, Tags: []string{"heavy"}}

            \tif diff := cmp.Diff(a, b); diff != "" {
            \t\tt.Errorf("identical items differ (-want +got):\\n%s", diff)
            \t}
            }

            func TestDiffNamesTheField(t *testing.T) {
            \ta := Item{Name: "anvil", Count: 2}
            \tb := Item{Name: "anvil", Count: 9}

            \tif diff := cmp.Diff(a, b); diff == "" {
            \t\tt.Fatal("expected a diff for different counts")
            \t}
            }
            """,
        ],
        modulePath: "example.com/diff",
        vendoredModule: VendoredModuleLoader.goCmp
    )
}
