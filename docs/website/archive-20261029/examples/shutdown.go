package examples

import (
	"context"
	"errors"
	"net"
	"net/http"
	"sync/atomic"
	"time"
)

func serve(ctx context.Context, ln net.Listener,
	handler http.Handler, ready *atomic.Bool) error {
	srv := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	stopped := make(chan error, 1)
	ready.Store(true)
	go func() { stopped <- srv.Serve(ln) }()

	select {
	case err := <-stopped:
		ready.Store(false)
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
	}

	ready.Store(false)
	drain, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	shutdownErr := srv.Shutdown(drain)
	if shutdownErr != nil {
		_ = srv.Close()
	}
	serveErr := <-stopped
	if errors.Is(serveErr, http.ErrServerClosed) {
		serveErr = nil
	}
	return errors.Join(shutdownErr, serveErr)
}
