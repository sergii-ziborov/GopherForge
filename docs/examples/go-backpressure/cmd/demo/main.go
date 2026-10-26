package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	bp "example.com/backpressure"
)

func main() {
	lookup := func(ctx context.Context, id string) (bp.Quote, error) {
		timer := time.NewTimer(80 * time.Millisecond)
		defer timer.Stop()
		select {
		case <-ctx.Done():
			return bp.Quote{}, ctx.Err()
		case <-timer.C:
			return bp.Quote{ID: id, Cents: 1250}, nil
		}
	}
	mux := http.NewServeMux()
	mux.Handle("/quote", bp.WithBudget(300*time.Millisecond,
		bp.Limit(16, bp.QuoteHandler(lookup))))
	srv := &http.Server{
		Addr: "127.0.0.1:8080", Handler: mux,
		ReadHeaderTimeout: 2 * time.Second,
		WriteTimeout:      time.Second,
		IdleTimeout:       30 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	serveErr := make(chan error, 1)
	go func() { serveErr <- srv.ListenAndServe() }()
	select {
	case err := <-serveErr:
		if !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("shutdown deadline: %v", err)
			_ = srv.Close()
		}
		if err := <-serveErr; !errors.Is(err, http.ErrServerClosed) {
			log.Printf("server: %v", err)
		}
	}
}
