package main

import (
	"bufio"
	"bytes"
	"errors"
	"io"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestFinalChunk(t *testing.T) {
	for _, size := range []int{1, 2, 16} {
		r := &finalChunk{text: "tail"}
		var out []byte
		p := make([]byte, size)
		for {
			n, err := r.Read(p)
			out = append(out, p[:n]...)
			if err == io.EOF {
				break
			}
			if err != nil {
				t.Fatal(err)
			}
		}
		if string(out) != "tail" {
			t.Fatalf("lost tail with buffer %d: %q", size, out)
		}
	}
}
func TestLimitBoundary(t *testing.T) {
	for _, tc := range []struct {
		in    string
		max   int64
		large bool
	}{{"", 0, false}, {"x", 0, true}, {"123", 4, false}, {"1234", 4, false}, {"12345", 4, true}} {
		b, e := ReadBounded(strings.NewReader(tc.in), tc.max)
		if errors.Is(e, ErrTooLarge) != tc.large {
			t.Fatalf("input %q max %d: %q, %v", tc.in, tc.max, b, e)
		}
		if !tc.large && string(b) != tc.in {
			t.Fatal("silently truncated")
		}
		if tc.large && b != nil {
			t.Fatal("accepted partial oversize payload")
		}
	}
	for _, n := range []int64{-1, math.MaxInt64} {
		if _, e := ReadBounded(strings.NewReader(""), n); e == nil {
			t.Fatal("invalid limit accepted")
		}
	}
}

type brokenReader struct{}

func (brokenReader) Read(p []byte) (int, error) { return copy(p, "x"), io.ErrUnexpectedEOF }
func TestUnderlyingError(t *testing.T) {
	b, e := ReadBounded(brokenReader{}, 10)
	if b != nil || !errors.Is(e, io.ErrUnexpectedEOF) {
		t.Fatalf("partial transport failure accepted: %q %v", b, e)
	}
}
func TestSingleDocument(t *testing.T) {
	for _, s := range []string{`{"id":"one"}`, "{\"id\":\"one\"} \n\t"} {
		v, e := DecodeOne(strings.NewReader(s), 128)
		if e != nil || v.ID != "one" {
			t.Fatalf("valid document: %v", e)
		}
	}
	for _, s := range []string{`{"id":"one"} {"id":"two"}`, `{"id":"one"} false`, `{"id":"one"} trailing`, `{"id":"one","extra":1}`, `null`, `{}`, `{"id":`, ``} {
		if _, e := DecodeOne(strings.NewReader(s), 128); e == nil {
			t.Fatalf("accepted invalid envelope: %s", s)
		}
	}
}
func TestDuplicatePolicyIsNotStrict(t *testing.T) {
	v, e := DecodeOne(strings.NewReader(`{"id":"one","id":"two"}`), 128)
	if e != nil || v.ID != "two" {
		t.Fatalf("fixture no longer demonstrates documented duplicate behavior: %v %v", v, e)
	}
}
func TestScannerLimits(t *testing.T) {
	s := strings.Repeat("x", 70*1024) + "\n"
	scan := bufio.NewScanner(strings.NewReader(s))
	if scan.Scan() || scan.Err() == nil {
		t.Fatal("expected default token size error")
	}
	n, e := LineCount(strings.NewReader(s), 128*1024)
	if e != nil || n != 1 {
		t.Fatalf("configured token failed: %d %v", n, e)
	}
}
func TestHTTPSizeError(t *testing.T) {
	r := http.MaxBytesReader(httptest.NewRecorder(), io.NopCloser(strings.NewReader("12345")), 4)
	defer r.Close()
	_, err := io.ReadAll(r)
	var sizeErr *http.MaxBytesError
	if !errors.As(err, &sizeErr) || sizeErr.Limit != 4 {
		t.Fatalf("missing HTTP size error: %v", err)
	}
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, io.ErrClosedPipe }
func TestBufferedOutput(t *testing.T) {
	var dst bytes.Buffer
	w := bufio.NewWriter(&dst)
	if _, err := w.WriteString("payload"); err != nil {
		t.Fatal(err)
	}
	if dst.Len() != 0 {
		t.Fatal("fixture bypassed buffering")
	}
	if err := w.Flush(); err != nil || dst.String() != "payload" {
		t.Fatalf("flush: %q %v", dst.String(), err)
	}
	broken := bufio.NewWriter(failingWriter{})
	if _, err := broken.WriteString("payload"); err != nil {
		t.Fatal(err)
	}
	if !errors.Is(broken.Flush(), io.ErrClosedPipe) {
		t.Fatal("flush failure was lost")
	}
}
