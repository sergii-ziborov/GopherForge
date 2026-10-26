package backpressure

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
)

type Quote struct {
	ID    string `json:"id"`
	Cents int64  `json:"cents"`
}

type Lookup func(context.Context, string) (Quote, error)

// QuoteHandler is deliberately small: a production service should also log
// classified dependency errors and response-write errors without leaking them.
func QuoteHandler(lookup Lookup) http.Handler {
	if lookup == nil {
		panic("QuoteHandler needs a lookup function")
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.Header().Set("Allow", http.MethodGet)
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		id := r.URL.Query().Get("id")
		if len(id) == 0 || len(id) > 64 {
			http.Error(w, "id must contain 1 to 64 bytes", http.StatusBadRequest)
			return
		}
		quote, err := lookup(r.Context(), id)
		ctxErr := r.Context().Err()
		switch {
		case errors.Is(ctxErr, context.Canceled):
			return // The caller went away; do not create replacement work.
		case errors.Is(ctxErr, context.DeadlineExceeded):
			http.Error(w, "work budget exhausted", http.StatusGatewayTimeout)
			return
		case err != nil:
			http.Error(w, "lookup failed", http.StatusBadGateway)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(quote)
	})
}
