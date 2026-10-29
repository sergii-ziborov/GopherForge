package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"strings"
	"unicode"
	"unicode/utf16"
	"unicode/utf8"
)

var ErrInvalidUTF8 = errors.New("invalid UTF-8")
var ErrLimit = errors.New("negative prefix limit")

// PrefixRunes validates the entire input and returns an independently owned
// prefix of at most n code points. It does not count grapheme clusters.
func PrefixRunes(s string, n int) (string, error) {
	if n < 0 {
		return "", ErrLimit
	}
	if !utf8.ValidString(s) {
		return "", ErrInvalidUTF8
	}
	count := 0
	for offset := range s {
		if count == n {
			return strings.Clone(s[:offset]), nil
		}
		count++
	}
	return strings.Clone(s), nil
}

// PrefixBytes preserves UTF-8 boundaries inside a byte budget. It can still
// split a grapheme cluster and is not a visual-text truncation function.
func PrefixBytes(s string, n int) (string, error) {
	if n < 0 {
		return "", ErrLimit
	}
	if !utf8.ValidString(s) {
		return "", ErrInvalidUTF8
	}
	if n >= len(s) {
		return strings.Clone(s), nil
	}
	end := n
	for end > 0 && !utf8.RuneStart(s[end]) {
		end--
	}
	return strings.Clone(s[:end]), nil
}

type Counts struct{ Bytes, Runes int64 }

// CountUTF8 reports the valid prefix before an error. Its working buffer is
// bounded; its caller must bound total input and blocking time separately.
func CountUTF8(r io.Reader) (Counts, error) {
	b := bufio.NewReaderSize(r, 16)
	var c Counts
	for {
		value, width, err := b.ReadRune()
		if err == io.EOF {
			return c, nil
		}
		if err != nil {
			return c, err
		}
		if value == utf8.RuneError && width == 1 {
			return c, fmt.Errorf("byte %d: %w", c.Bytes, ErrInvalidUTF8)
		}
		c.Bytes += int64(width)
		c.Runes++
	}
}

// ASCIIKey is a deliberately narrow example wire-key policy, not a policy for
// people's names. It permits 1..32 bytes of lowercase ASCII, digits, '_' and '-'.
func ASCIIKey(s string) bool {
	if len(s) == 0 || len(s) > 32 {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}
func main() {
	fmt.Println("stdlib Unicode tables:", unicode.Version)
	for _, s := range []string{"Go", "é", "e\u0301", "世界", "👩🏽‍💻", "\ufffd"} {
		fmt.Printf("%q: bytes=%d runes=%d valid=%v\n", s, len(s), utf8.RuneCountInString(s), utf8.ValidString(s))
	}
	s := "A😀B"
	offsets := []int{}
	for i := range s {
		offsets = append(offsets, i)
	}
	fmt.Printf("A+emoji+B: byte offsets=%v UTF16 units=%d\n", offsets, len(utf16.Encode([]rune(s))))
	prefix, _ := PrefixBytes("e\u0301", 1)
	fmt.Printf("valid byte prefix, not a whole cluster: %q\n", prefix)
	fmt.Printf("simple folds: Go/go=%v sharp-s/ss=%v K/Kelvin=%v\n", strings.EqualFold("Go", "go"), strings.EqualFold("ß", "ss"), strings.EqualFold("K", "\u212a"))
	c, err := CountUTF8(strings.NewReader("A€👩🏽‍💻"))
	fmt.Printf("stream: %+v err=%v\n", c, err)
	fmt.Printf("ASCII keys: user-1=%v Cyrillic-lookalike=%v\n", ASCIIKey("user-1"), ASCIIKey("pаypal"))
}
