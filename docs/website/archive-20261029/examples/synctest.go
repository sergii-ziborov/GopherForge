package examples

import (
	"context"
	"time"
)

func delayed(ctx context.Context, after time.Duration) <-chan string {
	out := make(chan string)
	go func() {
		defer close(out)
		timer := time.NewTimer(after)
		defer timer.Stop()
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		select {
		case out <- "ready":
		case <-ctx.Done():
		}
	}()
	return out
}
