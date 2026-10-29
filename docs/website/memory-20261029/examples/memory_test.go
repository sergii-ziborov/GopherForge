package memorylab

import (
	"bytes"
	"math"
	"testing"
)

func TestGraphShapes(t *testing.T) {
	for _, tc := range []struct {
		shape string
		depth int
	}{{"chain", 10000}, {"tree", 14}} {
		root := BuildGraph(10000, tc.shape)
		count, depth := GraphStats(root)
		if count != 10000 || depth != tc.depth {
			t.Fatalf("%s: count=%d depth=%d", tc.shape, count, depth)
		}
	}
}
func TestTokenContentsAndCapacity(t *testing.T) {
	v, c, k := RetainToken("view"), RetainToken("clip"), RetainToken("copy")
	if !bytes.Equal(v, c) || !bytes.Equal(c, k) || len(k) != 32 {
		t.Fatal("different token contents")
	}
	if cap(v) != 16<<20 || cap(c) != 32 {
		t.Fatal("wrong view/capacity contract")
	}
	k[0] = 99
	if v[0] == 99 {
		t.Fatal("copy shares backing storage")
	}
}
func TestFormatEquivalence(t *testing.T) {
	for _, id := range []uint64{0, 1, 42, 999999, math.MaxUint64} {
		for _, active := range []bool{false, true} {
			if got, want := AppendEvent(id, active), FormatEvent(id, active); got != want {
				t.Fatalf("%d %v: %q != %q", id, active, got, want)
			}
		}
	}
}

var result string

func BenchmarkFormat(b *testing.B) {
	b.ReportAllocs()
	for b.Loop() {
		result = FormatEvent(123456789, true)
	}
}
func BenchmarkAppend(b *testing.B) {
	b.ReportAllocs()
	for b.Loop() {
		result = AppendEvent(123456789, true)
	}
}

func TestIndependentPrefix(t *testing.T) {
	backing := []byte{1, 2, 3, 4}
	copied := CopyPrefix(backing, 2)
	copied[0] = 99
	if backing[0] != 1 {
		t.Fatal("copy retained alias")
	}
	backing[1] = 88
	if copied[1] != 2 {
		t.Fatal("source mutation changed copy")
	}
}
