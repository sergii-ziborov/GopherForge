package fuzzlab

import (
	"errors"
	"strings"
	"testing"
)

func TestFirstDelimiterAndUTF8(t *testing.T) {
	for _, line := range []string{"mode=a=b", "name=世界", "empty="} {
		r, e := Parse(line)
		if e != nil {
			t.Fatal(e)
		}
		got, e := Encode(r)
		if e != nil || got != line {
			t.Fatal(got, e)
		}
	}
	r, _ := Parse("mode=a=b")
	if r.Key != "mode" || r.Value != "a=b" {
		t.Fatal(r)
	}
}
func TestRejectMalformedRecords(t *testing.T) {
	for _, line := range []string{"", "missing", "=value", "Upper=x", "key=\xff", "key=x\ny", strings.Repeat("a", 33) + "=x", "k=" + strings.Repeat("x", 1023)} {
		if _, e := Parse(line); !errors.Is(e, ErrRecord) {
			t.Fatal(line, e)
		}
	}
}
func FuzzParse(f *testing.F) {
	for _, line := range []string{"mode=a=b", "name=世界", "empty=", "bad", "k=\xff"} {
		f.Add(line)
	}
	f.Fuzz(func(t *testing.T, line string) {
		r, e := Parse(line)
		if e != nil {
			return
		}
		if len(line) > 1024 || r.Key == "" || strings.ContainsAny(r.Key, "=\r\n") {
			t.Fatal(r)
		}
		encoded, e := Encode(r)
		if e != nil || encoded != line {
			t.Fatal(r, encoded, e)
		}
	})
}
