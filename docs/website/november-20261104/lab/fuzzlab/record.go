package fuzzlab

import (
	"errors"
	"strings"
	"unicode/utf8"
)

var ErrRecord = errors.New("invalid record")

type Record struct{ Key, Value string }

func validKey(s string) bool {
	if len(s) == 0 || len(s) > 32 {
		return false
	}
	for i := range s {
		c := s[i]
		if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_') {
			return false
		}
	}
	return true
}
func Parse(line string) (Record, error) {
	if len(line) > 1024 || !utf8.ValidString(line) || strings.ContainsAny(line, "\r\n") {
		return Record{}, ErrRecord
	}
	split := strings.IndexByte(line, '=')
	if split < 0 || !validKey(line[:split]) {
		return Record{}, ErrRecord
	}
	return Record{Key: line[:split], Value: line[split+1:]}, nil
}
func Encode(r Record) (string, error) {
	line := r.Key + "=" + r.Value
	if _, e := Parse(line); e != nil {
		return "", e
	}
	return line, nil
}
