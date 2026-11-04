package cursorlab

import (
	"context"
	"errors"
	"testing"
)

type fixture struct {
	left                            int
	decodeErr, errorAfter, closeErr error
	closed                          bool
	cleanupLive                     bool
}

func (f *fixture) Next(ctx context.Context) bool {
	if ctx.Err() != nil {
		return false
	}
	if f.left > 0 {
		f.left--
		return true
	}
	return false
}
func (f *fixture) Decode(v any) error {
	if f.decodeErr != nil {
		return f.decodeErr
	}
	v.(*Label).Name = "fixture"
	return nil
}
func (f *fixture) Err() error { return f.errorAfter }
func (f *fixture) Close(ctx context.Context) error {
	f.closed = true
	_, deadline := ctx.Deadline()
	f.cleanupLive = ctx.Err() == nil && deadline
	return f.closeErr
}
func TestLimitAndCleanup(t *testing.T) {
	f := &fixture{left: 2}
	rows, e := ReadLabels(context.Background(), f, 1)
	if len(rows) != 1 || !errors.Is(e, ErrLimit) || !f.closed || !f.cleanupLive {
		t.Fatal(rows, e, f)
	}
}
func TestCleanupAfterCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	f := &fixture{}
	_, e := ReadLabels(ctx, f, 3)
	if !errors.Is(e, context.Canceled) || !f.closed || !f.cleanupLive {
		t.Fatal(e, f)
	}
}
func TestDecodeAndCloseErrors(t *testing.T) {
	a, b := errors.New("decode"), errors.New("close")
	f := &fixture{left: 1, decodeErr: a, closeErr: b}
	_, e := ReadLabels(context.Background(), f, 2)
	if !errors.Is(e, a) || !errors.Is(e, b) || !f.closed {
		t.Fatal(e, f)
	}
}
func TestCursorErrorAndExactLimit(t *testing.T) {
	a := errors.New("cursor")
	f := &fixture{errorAfter: a}
	if _, e := ReadLabels(context.Background(), f, 2); !errors.Is(e, a) {
		t.Fatal(e)
	}
	g := &fixture{left: 2}
	if rows, e := ReadLabels(context.Background(), g, 2); e != nil || len(rows) != 2 || !g.closed {
		t.Fatal(rows, e)
	}
}
