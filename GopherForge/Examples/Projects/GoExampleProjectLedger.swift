import Foundation

/// Types, methods and errors as values.
///
/// It keeps money in whole cents, which is the first thing to know about money
/// in any language, and uses both receiver kinds on purpose: a pointer where
/// the account changes, a value where printing must not change it.
enum GoExampleProjectLedger {
    static let ledger = GoExample(
        id: "project.ledger",
        title: "Ledger",
        summary: "Types, methods and errors as values, in a program that adds up.",
        takeaway: "A method on a value type cannot change it; a pointer receiver can.",
        conceptTags: [GoConcept.methodSet, GoConcept.explicitErrorCheck, GoConcept.errorSentinel],
        source: """
        package main

        import (
        \t"errors"
        \t"fmt"

        \t"example.com/ledger/internal/money"
        )

        func main() {
        \taccount := money.Account{Owner: "ada"}

        \tfor _, amount := range []int64{5_00, 12_50, -3_25} {
        \t\tif err := account.Apply(amount); err != nil {
        \t\t\tfmt.Println("rejected:", err)
        \t\t}
        \t}
        \tfmt.Println(account)

        \tif err := account.Apply(-100_00); err != nil {
        \t\tfmt.Println("rejected:", err)
        \t\tfmt.Println("insufficient:", errors.Is(err, money.ErrInsufficient))
        \t}
        \tfmt.Println(account)
        }
        """,
        expectedOutput: """
        ada: 14.25
        rejected: apply -100.00: insufficient funds
        insufficient: true
        ada: 14.25

        """,
        extraFiles: [
            "internal/money/money.go": """
            // Package money keeps amounts in whole cents, because floating point
            // and currency do not belong in the same program.
            package money

            import (
            \t"errors"
            \t"fmt"
            )

            // ErrInsufficient is returned when a withdrawal is larger than the
            // balance. A sentinel, so callers can test for it with errors.Is.
            var ErrInsufficient = errors.New("insufficient funds")

            // Account is a balance with a name on it.
            type Account struct {
            \tOwner   string
            \tBalance int64
            }

            // Apply adds an amount, which may be negative. The receiver is a
            // pointer because this changes the account.
            func (a *Account) Apply(amount int64) error {
            \tif a.Balance+amount < 0 {
            \t\treturn fmt.Errorf("apply %s: %w", Format(amount), ErrInsufficient)
            \t}
            \ta.Balance += amount
            \treturn nil
            }

            // String makes Account satisfy fmt.Stringer. A value receiver,
            // because printing must never change what it prints.
            func (a Account) String() string {
            \treturn fmt.Sprintf("%s: %s", a.Owner, Format(a.Balance))
            }

            // Format renders cents as an amount.
            func Format(cents int64) string {
            \tsign := ""
            \tif cents < 0 {
            \t\tsign = "-"
            \t\tcents = -cents
            \t}
            \treturn fmt.Sprintf("%s%d.%02d", sign, cents/100, cents%100)
            }
            """,
            "internal/money/money_test.go": """
            package money

            import (
            \t"errors"
            \t"testing"
            )

            func TestApplyRefusesToOverdraw(t *testing.T) {
            \taccount := Account{Owner: "ada", Balance: 100}

            \tif err := account.Apply(-500); !errors.Is(err, ErrInsufficient) {
            \t\tt.Fatalf("err = %v, want ErrInsufficient", err)
            \t}
            \tif account.Balance != 100 {
            \t\tt.Errorf("balance changed to %d after a rejected apply", account.Balance)
            \t}
            }

            func TestFormat(t *testing.T) {
            \tfor _, c := range []struct {
            \t\tin   int64
            \t\twant string
            \t}{{0, "0.00"}, {5, "0.05"}, {1425, "14.25"}, {-99, "-0.99"}} {
            \t\tif got := Format(c.in); got != c.want {
            \t\t\tt.Errorf("Format(%d) = %s, want %s", c.in, got, c.want)
            \t\t}
            \t}
            }
            """,
        ],
        modulePath: "example.com/ledger"
    )
}
