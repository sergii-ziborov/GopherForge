package genericlab

type Box[T any] struct{ Value T }

// Map requires Go 1.27's generic methods. It does not implement a generic
// interface method; interface methods cannot declare their own type parameters.
func (b Box[T]) Map[U any](fn func(T) U) Box[U] { return Box[U]{Value: fn(b.Value)} }

// MapSlice preserves nil and allocates a new outer result. Referenced objects
// returned by fn may still be shared; this is not a deep-copy contract.
func MapSlice[S ~[]E, E, R any](src S, fn func(E) R) []R {
	if src == nil {
		return nil
	}
	out := make([]R, len(src))
	for i, value := range src {
		out[i] = fn(value)
	}
	return out
}
