// The iOS host supplies a validated browser recipe in a preopened work tree.
// Project scripts and plugins are never executed; esbuild only parses source.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/evanw/esbuild/pkg/api"
)

type recipe struct {
	Entry  string `json:"entry"`
	Output string `json:"output"`
	Minify bool   `json:"minify"`
}

func main() {
	if len(os.Args) == 3 && os.Args[1] == "instrument" {
		instrumentDebug(os.Args[2])
		return
	}
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "expected one build recipe")
		os.Exit(2)
	}
	raw, err := os.ReadFile(os.Args[1])
	if err != nil {
		fail(err)
	}
	var r recipe
	if err = json.Unmarshal(raw, &r); err != nil {
		fail(err)
	}
	if !relative(r.Entry) || !relative(r.Output) {
		fail(fmt.Errorf("build paths must stay inside the project"))
	}
	result := api.Build(api.BuildOptions{
		AbsWorkingDir: "/work", EntryPoints: []string{filepath.Join("/work", r.Entry)},
		Outfile: filepath.Join("/work", r.Output, "assets/app.js"),
		Bundle:  true, Write: true, Platform: api.PlatformBrowser, Format: api.FormatESModule,
		Target: api.ES2020, JSX: api.JSXAutomatic,
		MinifyWhitespace: r.Minify, MinifyIdentifiers: r.Minify, MinifySyntax: r.Minify,
		Define:   map[string]string{"process.env.NODE_ENV": "\"production\""},
		Loader:   map[string]api.Loader{".js": api.LoaderJSX, ".svg": api.LoaderDataURL, ".txt": api.LoaderText},
		LogLevel: api.LogLevelWarning, Color: api.ColorNever,
	})
	if len(result.Errors) > 0 {
		os.Exit(1)
	}
	fmt.Println("Offline browser build completed (esbuild 0.28.2).")
}
func relative(p string) bool {
	if p == "" || filepath.IsAbs(p) || strings.Contains(p, "\\") {
		return false
	}
	for _, part := range strings.Split(p, "/") {
		if part == ".." || part == "" || part == "." {
			return false
		}
	}
	return true
}
func fail(err error) { fmt.Fprintln(os.Stderr, err); os.Exit(2) }
