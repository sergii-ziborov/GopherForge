package main

import (
	"errors"
	"golang.org/x/text/cases"
	"golang.org/x/text/unicode/norm"
	"io"
	"strings"
	"testing"
)

func TestCanonicalNotCompatibility(t *testing.T) {
	a, e := CanonicalLabel("é")
	if e != nil {
		t.Fatal(e)
	}
	b, e := CanonicalLabel("e\u0301")
	if e != nil || a != b {
		t.Fatal(a, b, e)
	}
	if n, _ := CanonicalLabel("①"); n != "①" {
		t.Fatal("NFC must not become NFKC", n)
	}
	if norm.NFKC.String("①") != "1" {
		t.Fatal("compatibility example changed")
	}
}
func TestInvalidAndConfusable(t *testing.T) {
	if _, e := CanonicalLabel("\xff"); !errors.Is(e, ErrInvalidUTF8) {
		t.Fatal(e)
	}
	a, _ := CanonicalLabel("paypal")
	b, _ := CanonicalLabel("pаypal")
	if a == b {
		t.Fatal("confusable became identical")
	}
}
func TestFullFoldIsSeparate(t *testing.T) {
	fold := cases.Fold()
	if strings.EqualFold("Straße", "STRASSE") || fold.String("Straße") != fold.String("STRASSE") {
		t.Fatal("fold example changed")
	}
}

type oneByte struct{ s string }

func (r *oneByte) Read(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	if len(r.s) == 0 {
		return 0, io.EOF
	}
	p[0] = r.s[0]
	r.s = r.s[1:]
	return 1, nil
}
func TestNormalizationAcrossChunks(t *testing.T) {
	joined := norm.NFC.String("e") + norm.NFC.String("\u0301")
	if joined == norm.NFC.String("e\u0301") {
		t.Fatal("counterexample lost")
	}
	got, e := io.ReadAll(norm.NFC.Reader(&oneByte{s: "e\u0301"}))
	if e != nil || string(got) != "é" {
		t.Fatal(string(got), e)
	}
}
func TestStreamSafeLongSequence(t *testing.T) {
	input := "a" + strings.Repeat("\u0301", 31)
	got, e := CanonicalLabel(input)
	if e != nil || !strings.Contains(got, "\u034f") || strings.Contains(input, "\u034f") {
		t.Fatal(e)
	}
}
