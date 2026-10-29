package main

import (
	"errors"
	"io"
	"strings"
	"testing"
	"unicode/utf16"
	"unicode/utf8"
)

func TestUnitsAndOffsets(t *testing.T) {
	cases := []struct {
		s    string
		b, r int
	}{{"", 0, 0}, {"é", 2, 1}, {"e\u0301", 3, 2}, {"世界", 6, 2}, {"👩🏽‍💻", 15, 4}, {"A😀B", 6, 3}}
	for _, x := range cases {
		if len(x.s) != x.b || utf8.RuneCountInString(x.s) != x.r {
			t.Fatal(x)
		}
	}
	var offsets []int
	for i := range "A😀B" {
		offsets = append(offsets, i)
	}
	if len(offsets) != 3 || offsets[0] != 0 || offsets[1] != 1 || offsets[2] != 5 {
		t.Fatal(offsets)
	}
	if len(utf16.Encode([]rune("A😀B"))) != 4 {
		t.Fatal("UTF-16 units changed")
	}
}
func TestPrefixRunes(t *testing.T) {
	cases := []struct {
		s    string
		n    int
		want string
	}{{"A😀B", 0, ""}, {"A😀B", 1, "A"}, {"A😀B", 2, "A😀"}, {"A😀B", 3, "A😀B"}, {"A😀B", 99, "A😀B"}, {"e\u0301", 1, "e"}, {"", 0, ""}}
	for _, x := range cases {
		got, e := PrefixRunes(x.s, x.n)
		if e != nil || got != x.want {
			t.Fatal(x, got, e)
		}
	}
	if _, e := PrefixRunes("ok", -1); !errors.Is(e, ErrLimit) {
		t.Fatal(e)
	}
	if _, e := PrefixRunes("ok\xff", 1); !errors.Is(e, ErrInvalidUTF8) {
		t.Fatal("whole input must be validated", e)
	}
}
func TestBytePrefixAtEveryBoundary(t *testing.T) {
	s := "Aé世界👩🏽‍💻Z"
	for n := 0; n <= len(s)+2; n++ {
		got, e := PrefixBytes(s, n)
		if e != nil || !utf8.ValidString(got) || len(got) > n || !strings.HasPrefix(s, got) {
			t.Fatal(n, got, e)
		}
		if n < len(s) {
			_, width := utf8.DecodeRuneInString(s[len(got):])
			if len(got)+width <= n {
				t.Fatal("prefix not maximal", n, got)
			}
		}
	}
	if p, e := PrefixBytes("e\u0301", 1); e != nil || p != "e" {
		t.Fatal(p, e)
	}
	if _, e := PrefixBytes("x", -1); !errors.Is(e, ErrLimit) {
		t.Fatal(e)
	}
	if _, e := PrefixBytes("ok\xff", 1); !errors.Is(e, ErrInvalidUTF8) {
		t.Fatal(e)
	}
}

type tinyReader struct {
	s     string
	step  int
	final error
}

func (r *tinyReader) Read(p []byte) (int, error) {
	if len(r.s) == 0 {
		if r.final != nil {
			return 0, r.final
		}
		return 0, io.EOF
	}
	n := r.step
	if n > len(p) {
		n = len(p)
	}
	if n > len(r.s) {
		n = len(r.s)
	}
	copy(p, r.s[:n])
	r.s = r.s[n:]
	if len(r.s) == 0 {
		if r.final != nil {
			return n, r.final
		}
		return n, io.EOF
	}
	return n, nil
}
func TestStreamingEverySplitAndFinalData(t *testing.T) {
	input := "Aé世界👩🏽‍💻\ufffd"
	for step := 1; step <= len(input); step++ {
		got, e := CountUTF8(&tinyReader{s: input, step: step})
		if e != nil || got.Bytes != int64(len(input)) || got.Runes != int64(utf8.RuneCountInString(input)) {
			t.Fatal(step, got, e)
		}
	}
}
func TestInvalidVersusReplacement(t *testing.T) {
	got, e := CountUTF8(strings.NewReader("\ufffd"))
	if e != nil || got.Bytes != 3 || got.Runes != 1 {
		t.Fatal(got, e)
	}
	for _, s := range []string{"A\xffB", "A\xe2\x82", "A\xc0\xaf", "A\xed\xa0\x80"} {
		got, e = CountUTF8(&tinyReader{s: s, step: 1})
		if !errors.Is(e, ErrInvalidUTF8) || got.Bytes != 1 || got.Runes != 1 {
			t.Fatal(got, e)
		}
	}
}
func TestReaderFailureAfterValidPrefix(t *testing.T) {
	boom := errors.New("synthetic read failure")
	c, e := CountUTF8(&tinyReader{s: "abc", step: 1, final: boom})
	if !errors.Is(e, boom) || c.Bytes != 3 || c.Runes != 3 {
		t.Fatal(c, e)
	}
}
func TestWireKeyAndSimpleFolding(t *testing.T) {
	for _, s := range []string{"user-1", "a_b9", strings.Repeat("a", 32)} {
		if !ASCIIKey(s) {
			t.Fatal(s)
		}
	}
	for _, s := range []string{"", strings.Repeat("a", 33), "User", "pаypal", "a b", "\xff", "\u212a"} {
		if ASCIIKey(s) {
			t.Fatal(s)
		}
	}
	if !strings.EqualFold("K", "\u212a") || !strings.EqualFold("Go", "go") || strings.EqualFold("ß", "ss") || strings.EqualFold("é", "e\u0301") {
		t.Fatal("simple folding boundary changed")
	}
}
func FuzzBytePrefix(f *testing.F) {
	for _, s := range []string{"A😀B", "e\u0301", "👩🏽‍💻", "\xff", ""} {
		f.Add(s, uint8(3))
	}
	f.Fuzz(func(t *testing.T, s string, n uint8) {
		p, e := PrefixBytes(s, int(n))
		if !utf8.ValidString(s) {
			if !errors.Is(e, ErrInvalidUTF8) {
				t.Fatal(e)
			}
			return
		}
		if e != nil || len(p) > int(n) || !strings.HasPrefix(s, p) || !utf8.ValidString(p) {
			t.Fatal(s, n, p, e)
		}
	})
}
