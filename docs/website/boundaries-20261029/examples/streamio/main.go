package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"strings"
)

var ErrTooLarge = errors.New("input exceeds byte limit")
var ErrTrailingValue = errors.New("expected one JSON document")

type finalChunk struct{ text string }

func (r *finalChunk) Read(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	if r.text == "" {
		return 0, io.EOF
	}
	n := copy(p, r.text)
	r.text = r.text[n:]
	if r.text == "" {
		return n, io.EOF
	}
	return n, nil
}

// ReadBounded consumes up to max+1 bytes to distinguish exact-size from overflow.
// It returns no accepted payload on a size or underlying-reader error.
func ReadBounded(r io.Reader, max int64) ([]byte, error) {
	if max < 0 || max == math.MaxInt64 {
		return nil, errors.New("invalid byte limit")
	}
	b, err := io.ReadAll(io.LimitReader(r, max+1))
	if int64(len(b)) > max {
		return nil, ErrTooLarge
	}
	if err != nil {
		return nil, err
	}
	return b, nil
}

type Event struct {
	ID string `json:"id"`
}

func DecodeOne(r io.Reader, max int64) (Event, error) {
	var event Event
	b, err := ReadBounded(r, max)
	if err != nil {
		return event, err
	}
	dec := json.NewDecoder(strings.NewReader(string(b)))
	dec.DisallowUnknownFields()
	if err = dec.Decode(&event); err != nil {
		return Event{}, err
	}
	var extra json.RawMessage
	if err = dec.Decode(&extra); err == nil {
		return Event{}, ErrTrailingValue
	}
	if err != io.EOF {
		return Event{}, err
	}
	if event.ID == "" {
		return Event{}, errors.New("id is required")
	}
	return event, nil
}
func LineCount(r io.Reader, maxToken int) (int, error) {
	if maxToken <= 0 {
		return 0, errors.New("invalid token limit")
	}
	scan := bufio.NewScanner(r)
	scan.Buffer(make([]byte, 0, min(1024, maxToken)), maxToken)
	count := 0
	for scan.Scan() {
		count++
	}
	return count, scan.Err()
}
func main() {
	p := make([]byte, 16)
	n, err := (&finalChunk{text: "tail"}).Read(p)
	fmt.Printf("final read: n=%d data=%q EOF=%v\n", n, p[:n], err == io.EOF)
	b, err := io.ReadAll(&finalChunk{text: "tail"})
	fmt.Printf("ReadAll: %q error=%v\n", b, err)
	for _, input := range []string{"1234", "12345"} {
		b, err := ReadBounded(strings.NewReader(input), 4)
		fmt.Printf("limit 4, input %q: accepted=%q error=%v\n", input, b, err)
	}
	for _, input := range []string{`{"id":"one"}`, `{"id":"one"} {"id":"two"}`, `{"id":"one","extra":1}`, `null`, `{"id":"one","id":"two"}`} {
		event, err := DecodeOne(strings.NewReader(input), 128)
		fmt.Printf("JSON %s: id=%q error=%v\n", input, event.ID, err)
	}
	line := strings.Repeat("x", 70*1024) + "\n"
	scan := bufio.NewScanner(strings.NewReader(line))
	ok := scan.Scan()
	fmt.Printf("default scanner: token=%v error=%v\n", ok, scan.Err() != nil)
	count, err := LineCount(strings.NewReader(line), 128*1024)
	fmt.Printf("configured scanner: lines=%d error=%v\n", count, err)
}
