package main

import (
	"errors"
	"fmt"
	"golang.org/x/text/cases"
	"golang.org/x/text/unicode/norm"
	"strings"
	"unicode/utf8"
)

var ErrInvalidUTF8 = errors.New("invalid UTF-8")

// CanonicalLabel is an explicit display-data policy, not an account-identity,
// password, filesystem-path or general security canonicalization function.
func CanonicalLabel(s string) (string, error) {
	if !utf8.ValidString(s) {
		return "", ErrInvalidUTF8
	}
	return norm.NFC.String(s), nil
}
func main() {
	a, _ := CanonicalLabel("é")
	b, _ := CanonicalLabel("e\u0301")
	fmt.Println("normalizer Unicode tables:", norm.Version)
	fmt.Printf("raw equal=%v NFC equal=%v\n", "é" == "e\u0301", a == b)
	fmt.Printf("circled digit: NFC=%q NFKC=%q\n", norm.NFC.String("①"), norm.NFKC.String("①"))
	fmt.Printf("sharp-s: simple fold=%v full fold=%v\n", strings.EqualFold("Straße", "STRASSE"), cases.Fold().String("Straße") == cases.Fold().String("STRASSE"))
	fmt.Printf("long combining sequence adds stream-safe CGJ: %v\n", strings.Contains(norm.NFC.String("a"+strings.Repeat("\u0301", 31)), "\u034f"))
}
