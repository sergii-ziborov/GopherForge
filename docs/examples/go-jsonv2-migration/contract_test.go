package migration

import (
	"bytes"
	jsonv1 "encoding/json"
	jsonv2 "encoding/json/v2"
	"strings"
	"testing"
)

func TestCollectionContracts(t *testing.T) {
	for _, tc := range []struct {
		name   string
		encode func(Listing) ([]byte, error)
		want   string
	}{
		{"v1", func(v Listing) ([]byte, error) { return jsonv1.Marshal(v) }, `{"items":null,"labels":null}`},
		{"v2", func(v Listing) ([]byte, error) { return jsonv2.Marshal(v) }, `{"items":[],"labels":{}}`},
		{"compatible", MarshalCompatible, `{"items":null,"labels":null}`},
		{"one opted-in change", MarshalEmptyItems, `{"items":[],"labels":null}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, err := tc.encode(Listing{})
			if err != nil || string(got) != tc.want {
				t.Fatalf("got %s, %v; want %s", got, err, tc.want)
			}
		})
	}
}

func TestOmissionContracts(t *testing.T) {
	type OldTags struct {
		Count   int  `json:"count,omitempty"`
		Enabled bool `json:"enabled,omitempty"`
	}
	type ZeroTags struct {
		Count   int  `json:"count,omitzero"`
		Enabled bool `json:"enabled,omitzero"`
	}
	old, err := jsonv1.Marshal(OldTags{})
	if err != nil || string(old) != `{}` {
		t.Fatalf("v1: %s %v", old, err)
	}
	next, err := jsonv2.Marshal(OldTags{})
	if err != nil || string(next) != `{"count":0,"enabled":false}` {
		t.Fatalf("v2: %s %v", next, err)
	}
	for _, encode := range []func(any) ([]byte, error){jsonv1.Marshal, func(v any) ([]byte, error) { return jsonv2.Marshal(v) }} {
		got, err := encode(ZeroTags{})
		if err != nil || string(got) != `{}` {
			t.Fatalf("omitzero: %s %v", got, err)
		}
	}
}

func TestInputPolicies(t *testing.T) {
	for _, tc := range []struct {
		name    string
		data    []byte
		wantErr bool
	}{
		{"false is valid", []byte(`{"name":"demo","enabled":false}`), false},
		{"duplicate", []byte(`{"name":"demo","name":"other"}`), true},
		{"case mismatch", []byte(`{"NAME":"demo"}`), true},
		{"unknown", []byte(`{"name":"demo","extra":1}`), true},
		{"trailing value", []byte(`{"name":"demo"} {}`), true},
		{"empty body", nil, true},
		{"null", []byte(`null`), true},
		{"blank", []byte(`{"name":" "}`), true},
		{"invalid utf8", append(append([]byte(`{"name":"`), 0xff), []byte(`"}`)...), true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, err := DecodeUpdate(tc.data)
			if (err != nil) != tc.wantErr {
				t.Fatalf("got %+v %v", got, err)
			}
			if err != nil && got != (Update{}) {
				t.Fatalf("published partially decoded value: %+v", got)
			}
			if err == nil && got != (Update{Name: "demo", Enabled: false}) {
				t.Fatalf("valid false changed: %+v", got)
			}
		})
	}
}

func TestCaseAndUTF8Differences(t *testing.T) {
	type Payload struct {
		Name string `json:"name"`
	}
	var old, next, explicit Payload
	input := []byte(`{"NAME":"demo"}`)
	if err := jsonv1.Unmarshal(input, &old); err != nil {
		t.Fatal(err)
	}
	if err := jsonv2.Unmarshal(input, &next); err != nil {
		t.Fatal(err)
	}
	if err := jsonv2.Unmarshal(input, &explicit, jsonv2.MatchCaseInsensitiveNames(true)); err != nil {
		t.Fatal(err)
	}
	if old.Name != "demo" || next.Name != "" || explicit.Name != "demo" {
		t.Fatalf("old=%+v next=%+v explicit=%+v", old, next, explicit)
	}
	bad := []byte{'"', 0xff, '"'}
	var s string
	if err := jsonv1.Unmarshal(bad, &s); err != nil || s != "\ufffd" {
		t.Fatalf("v1 utf8: %q %v", s, err)
	}
	if err := jsonv2.Unmarshal(bad, &s); err == nil {
		t.Fatal("v2 accepted invalid UTF-8")
	}
}

func TestFreshTargetsAndDeterminism(t *testing.T) {
	v := Listing{Items: []string{"a", "b"}, Labels: map[string]string{"z": "last", "a": "first"}}
	old, err := jsonv1.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	next, err := jsonv2.Marshal(v, jsonv2.Deterministic(true))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(old, next) {
		t.Fatalf("old=%s next=%s", old, next)
	}
	// A comparison must decode into separate destinations, not reuse merged state.
	var first, second Update
	if err := jsonv1.Unmarshal([]byte(`{"name":"demo","enabled":true}`), &first); err != nil {
		t.Fatal(err)
	}
	if err := jsonv2.Unmarshal([]byte(`{"name":"demo"}`), &second); err != nil {
		t.Fatal(err)
	}
	if !first.Enabled || second.Enabled {
		t.Fatal("comparison destinations shared state")
	}
}

func FuzzDecodeUpdate(f *testing.F) {
	for _, seed := range [][]byte{[]byte(`{"name":"demo","enabled":false}`), []byte(`{"NAME":"demo"}`), []byte(`{"name":"a","name":"b"}`), []byte(`null`), nil} {
		f.Add(seed)
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		if len(data) > 4096 {
			t.Skip()
		}
		got, err := DecodeUpdate(data)
		if err != nil {
			if got != (Update{}) {
				t.Fatal("partial value escaped on error")
			}
			return
		}
		if strings.TrimSpace(got.Name) == "" {
			t.Fatal("accepted blank name")
		}
		encoded, err := jsonv2.Marshal(got)
		if err != nil {
			t.Fatal(err)
		}
		roundtrip, err := DecodeUpdate(encoded)
		if err != nil || roundtrip != got {
			t.Fatalf("roundtrip: %+v %v", roundtrip, err)
		}
	})
}

var benchmarkResult []byte

func BenchmarkMarshal(b *testing.B) {
	v := Listing{Items: []string{"alpha", "beta", "gamma"}, Labels: map[string]string{"tier": "free", "region": "eu", "state": "ready"}}
	for _, tc := range []struct {
		name   string
		encode func(Listing) ([]byte, error)
	}{
		{"v1", func(v Listing) ([]byte, error) { return jsonv1.Marshal(v) }},
		{"v2-compatible", MarshalCompatible},
		{"v2-deterministic", func(v Listing) ([]byte, error) { return jsonv2.Marshal(v, jsonv2.Deterministic(true)) }},
	} {
		b.Run(tc.name, func(b *testing.B) {
			b.ReportAllocs()
			var out []byte
			for b.Loop() {
				var err error
				out, err = tc.encode(v)
				if err != nil {
					b.Fatal(err)
				}
			}
			benchmarkResult = out
		})
	}
}
