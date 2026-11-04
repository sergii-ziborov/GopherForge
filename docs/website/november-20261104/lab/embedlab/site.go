package embedlab

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"
	"time"
)

//go:embed ui
var bundle embed.FS

func Handler() http.Handler {
	root, err := fs.Sub(bundle, "ui")
	if err != nil {
		panic(err)
	}
	index, err := fs.ReadFile(root, "index.html")
	if err != nil {
		panic(err)
	}
	mux := http.NewServeMux()
	page := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		http.ServeContent(w, r, "index.html", time.Time{}, strings.NewReader(string(index)))
	}
	mux.HandleFunc("GET /{$}", page)
	mux.HandleFunc("GET /projects/{id}", page)
	files := http.FileServerFS(root)
	mux.HandleFunc("GET /assets/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/") {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Cache-Control", "no-cache")
		files.ServeHTTP(w, r)
	})
	mux.HandleFunc("GET /api/status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"ok":true}`))
	})
	return mux
}
