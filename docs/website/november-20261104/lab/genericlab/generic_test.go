package genericlab

import (
	"math"
	"strconv"
	"testing"
)

func TestGenericMethod(t *testing.T) {
	got := Box[int]{Value: 42}.Map(strconv.Itoa)
	if got.Value != "42" {
		t.Fatal(got)
	}
}
func TestNamedSliceAndNil(t *testing.T) {
	type IDs []int
	src := IDs{1, 2}
	out := MapSlice(src, func(n int) int { return n * 2 })
	out[0] = 99
	if src[0] != 1 || out[1] != 4 {
		t.Fatal(src, out)
	}
	if MapSlice(IDs(nil), func(n int) int { return n }) != nil {
		t.Fatal("nil lost")
	}
}
func TestNestedReferencesRemainShared(t *testing.T) {
	v := 1
	out := MapSlice([]*int{&v}, func(p *int) *int { return p })
	*out[0] = 2
	if v != 2 {
		t.Fatal(v)
	}
}
func TestComparableDoesNotMeanReflexive(t *testing.T) {
	n := math.NaN()
	m := map[float64]int{n: 1}
	if len(m) != 1 {
		t.Fatal(m)
	}
	if _, ok := m[n]; ok {
		t.Fatal("NaN unexpectedly equal to itself")
	}
}
