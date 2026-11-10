// The browser drives stock Go compile/link directly: WASI cannot spawn cmd/go.
// Parsing, build constraints, test discovery and formatting use Go's own APIs.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/build"
	"go/doc"
	"go/format"
	"go/parser"
	"go/token"
	"io"
	"os"
	"path"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"
)

type Input struct {
	Files        map[string]string
	Dependencies map[string]string
	ModText      string
	Module       string
	Version      string
	Remote       map[string]string
	Latest       string
	Mode         string
	Standard     []string
}
type Step struct {
	Tool  string   `json:"tool"`
	Args  []string `json:"args"`
	Label string   `json:"label"`
}
type Plan struct {
	Modules   *moduleSpec       `json:"modules,omitempty"`
	Verified  []string          `json:"verified,omitempty"`
	Need      []string          `json:"need,omitempty"`
	Latest    string            `json:"latest,omitempty"`
	Files     map[string]string `json:"files"`
	Steps     []Step            `json:"steps"`
	Binaries  []string          `json:"binaries"`
	Formatted map[string]string `json:"formatted,omitempty"`
	Error     string            `json:"error,omitempty"`
	Points    []debugPoint      `json:"points,omitempty"`
}
type Package struct {
	Name, Import, Dir      string
	Files, Tests, External []string
	AST                    map[string]*ast.File
}

var input Input
var plan = Plan{Files: map[string]string{}, Steps: []Step{}, Binaries: []string{}}
var packages = map[string]*Package{}
var archives = map[string]string{}
var visiting = map[string]bool{}
var language = "go1.27"

func fail(f string, a ...any) { panic(fmt.Sprintf(f, a...)) }
func sortedKeys[V any](m map[string]V) []string {
	a := make([]string, 0, len(m))
	for k := range m {
		a = append(a, k)
	}
	sort.Strings(a)
	return a
}
func config(entries map[string]string) string {
	var b strings.Builder
	for _, k := range sortedKeys(entries) {
		fmt.Fprintf(&b, "packagefile %s=%s\n", k, entries[k])
	}
	return b.String()
}
func copyEntries() map[string]string {
	m := map[string]string{}
	for k, v := range archives {
		m[k] = v
	}
	return m
}
func compile(p *Package, files []string, importPath, output string, entries map[string]string) {
	cfg := output + ".importcfg"
	plan.Files[cfg] = config(entries)
	args := []string{"compile", "-o", output, "-p", importPath, "-lang", language, "-importcfg", cfg, "-complete", "-pack"}
	patterns := map[string][]string{}
	embedFiles := map[string]string{}
	for _, file := range files {
		for _, group := range p.AST[file].Comments {
			for _, c := range group.List {
				if strings.HasPrefix(c.Text, "//go:embed ") {
					for _, pattern := range strings.Fields(strings.TrimPrefix(c.Text, "//go:embed ")) {
						pattern = strings.Trim(pattern, "\"`")
						clean := strings.TrimPrefix(pattern, "all:")
						if clean == "" || strings.HasPrefix(clean, "/") || strings.Contains(clean, "..") {
							fail("%s: unsupported embed pattern %q", file, pattern)
						}
						matches := []string{}
						for _, source := range sortedKeys(input.Files) {
							rel := strings.TrimPrefix(source, p.Dir)
							rel = strings.TrimPrefix(rel, "/")
							if p.Dir != "" && !strings.HasPrefix(source, p.Dir+"/") {
								continue
							}
							matched, _ := path.Match(clean, rel)
							if matched || strings.HasPrefix(rel, clean+"/") {
								if !strings.HasPrefix(pattern, "all:") {
									hidden := false
									for _, part := range strings.Split(rel, "/") {
										if strings.HasPrefix(part, ".") || strings.HasPrefix(part, "_") {
											hidden = true
										}
									}
									if hidden {
										continue
									}
								}
								matches = append(matches, rel)
								embedFiles[rel] = "/work/" + source
							}
						}
						if len(matches) == 0 {
							fail("%s: embed pattern %q matches no files", file, pattern)
						}
						patterns[pattern] = matches
					}
				}
			}
		}
	}
	if len(patterns) > 0 {
		data, _ := json.Marshal(map[string]any{"Patterns": patterns, "Files": embedFiles})
		file := output + ".embedcfg"
		plan.Files[file] = string(data)
		args = append(args, "-embedcfg", file)
	}
	for _, f := range files {
		args = append(args, "/work/"+f)
	}
	plan.Steps = append(plan.Steps, Step{"compile", args, "Compile " + p.Import})
}
func buildPackage(key string) {
	if _, ok := archives[key]; ok {
		return
	}
	if visiting[key] {
		fail("Import cycle involving %s", key)
	}
	p := packages[key]
	if p == nil {
		fail("Dependency %q is not present. Import its WASI-compatible Go source under vendor/ or use the native project workspace to prepare dependencies.", key)
	}
	visiting[key] = true
	for _, f := range p.Files {
		for _, i := range p.AST[f].Imports {
			name, _ := strconv.Unquote(i.Path.Value)
			if name != "unsafe" {
				buildPackage(name)
			}
		}
	}
	if len(p.Files) == 0 {
		fail("No compatible Go source in %s", key)
	}
	output := fmt.Sprintf("/tmp/package-%d.a", len(plan.Steps))
	pkgPath := key
	if p.Name == "main" && input.Mode != "test" {
		pkgPath = "main"
	}
	compile(p, p.Files, pkgPath, output, archives)
	archives[key] = output
	visiting[key] = false
}
func link(archive, output string, entries map[string]string) {
	cfg := output + ".importcfg"
	plan.Files[cfg] = config(entries)
	plan.Steps = append(plan.Steps, Step{"link", []string{"link", "-o", output, "-importcfg", cfg, "-buildmode", "exe", "-w", "-s", archive}, "Link " + output})
	plan.Binaries = append(plan.Binaries, output)
}
func testName(s, prefix string) bool {
	if !strings.HasPrefix(s, prefix) {
		return false
	}
	tail := strings.TrimPrefix(s, prefix)
	if tail == "" {
		return true
	}
	r, _ := utf8.DecodeRuneInString(tail)
	return !unicode.IsLower(r)
}
func testPackage(p *Package) {
	buildPackage(p.Import)
	entries := copyEntries()
	both := append(append([]string{}, p.Files...), p.Tests...)
	for _, f := range append(append([]string{}, p.Tests...), p.External...) {
		for _, i := range p.AST[f].Imports {
			name, _ := strconv.Unquote(i.Path.Value)
			if name != "unsafe" && name != p.Import {
				buildPackage(name)
			}
		}
	}
	entries = copyEntries()
	output := fmt.Sprintf("/tmp/test-%d.a", len(plan.Steps))
	compile(p, both, p.Import, output, entries)
	entries[p.Import] = output
	if len(p.External) > 0 {
		ext := fmt.Sprintf("/tmp/external-%d.a", len(plan.Steps))
		compile(p, p.External, p.Import+"_test", ext, entries)
		entries[p.Import+"_test"] = ext
	}
	var imports, tests, benchmarks, fuzz, examples strings.Builder
	custom := ""
	seenMain := false
	for group, files := range [][]string{p.Tests, p.External} {
		if len(files) == 0 {
			continue
		}
		alias := "_test"
		pkg := p.Import
		if group == 1 {
			alias = "_xtest"
			pkg += "_test"
		}
		// A blank import retains init functions even if no tests are declared.
		used := false
		for _, file := range files {
			for _, d := range p.AST[file].Decls {
				fn, ok := d.(*ast.FuncDecl)
				if !ok || fn.Recv != nil {
					continue
				}
				name := fn.Name.Name
				if name == "TestMain" {
					if seenMain {
						fail("Multiple TestMain declarations")
					}
					seenMain = true
					custom = alias + ".TestMain(m)\nos.Exit(int(reflect.ValueOf(m).Elem().FieldByName(\"exitCode\").Int()))"
					used = true
				} else if testName(name, "Test") {
					fmt.Fprintf(&tests, "{%q,%s.%s},\n", name, alias, name)
					used = true
				} else if testName(name, "Benchmark") {
					fmt.Fprintf(&benchmarks, "{%q,%s.%s},\n", name, alias, name)
					used = true
				} else if testName(name, "Fuzz") {
					fmt.Fprintf(&fuzz, "{%q,%s.%s},\n", name, alias, name)
					used = true
				}
			}
		}
		asts := []*ast.File{}
		for _, f := range files {
			asts = append(asts, p.AST[f])
		}
		for _, e := range doc.Examples(asts...) {
			if e.Output != "" || e.EmptyOutput {
				fmt.Fprintf(&examples, "{Name:%q,F:%s.Example%s,Output:%q,Unordered:%t},\n", "Example"+e.Name, alias, e.Name, e.Output, e.Unordered)
				used = true
			}
		}
		if !used {
			alias = "_"
		}
		fmt.Fprintf(&imports, "%s %q\n", alias, pkg)
	}
	if seenMain {
		imports.WriteString("\"reflect\"\n")
	}
	main := fmt.Sprintf("package main\nimport(\"os\";\"testing\";\"testing/internal/testdeps\";\n%s)\nvar tests=[]testing.InternalTest{%s}\nvar benchmarks=[]testing.InternalBenchmark{%s}\nvar fuzz=[]testing.InternalFuzzTarget{%s}\nvar examples=[]testing.InternalExample{%s}\nfunc main(){testdeps.ImportPath=%q;m:=testing.MainStart(testdeps.TestDeps{},tests,benchmarks,fuzz,examples);", imports.String(), tests.String(), benchmarks.String(), fuzz.String(), examples.String(), p.Import)
	if custom != "" {
		main += custom
	} else {
		main += "os.Exit(m.Run())"
	}
	main += "}\n"
	id := len(plan.Steps)
	source := fmt.Sprintf("_gopherforge_testmain_%d.go", id)
	plan.Files["/work/"+source] = main
	a, err := parser.ParseFile(token.NewFileSet(), source, main, parser.ParseComments)
	if err != nil {
		fail("Test driver: %s", err)
	}
	driver := &Package{Import: p.Import + " test driver", AST: map[string]*ast.File{source: a}}
	archive := fmt.Sprintf("/tmp/testmain-%d.a", id)
	compile(driver, []string{source}, "main", archive, entries)
	entries["main"] = archive
	link(archive, fmt.Sprintf("/tmp/test-%d.wasm", id), entries)
}
func run() {
	if err := json.NewDecoder(io.LimitReader(os.Stdin, 24*1024*1024)).Decode(&input); err != nil {
		fail("Invalid project: %s", err)
	}
	if input.Mode == "modules" {
		plan.Modules = parseModule(input.ModText)
		return
	}
	if input.Mode == "sumdb" {
		verifyChecksum()
		return
	}
	if len(input.Files) == 0 || len(input.Files) > 32 {
		fail("Use 1–32 source files")
	}
	total := 0
	for name, source := range input.Files {
		total += len(source)
		if path.Clean(name) != name || strings.HasPrefix(name, "/") || strings.HasPrefix(name, "../") || len(source) > 65536 || strings.ContainsRune(source, 0) {
			fail("Invalid source file: %s", name)
		}
	}
	if total > 262144 {
		fail("Source exceeds 256 KiB")
	}
	if input.Mode == "format" {
		plan.Formatted = map[string]string{}
		for _, name := range sortedKeys(input.Files) {
			if strings.HasSuffix(name, ".go") {
				b, e := format.Source([]byte(input.Files[name]))
				if e != nil {
					fail("%s: %s", name, e)
				}
				plan.Formatted[name] = string(b)
			}
		}
		return
	}
	if input.Mode != "format" {
		if len(input.Dependencies) > 512 {
			fail("Prepared dependencies exceed 512 files")
		}
		size := 0
		for name, source := range input.Dependencies {
			size += len(source)
			if !strings.HasPrefix(name, "vendor/") || path.Clean(name) != name || strings.Contains(name, "..") || len(source) > 1024*1024 || strings.ContainsRune(source, 0) {
				fail("Invalid prepared dependency path %s", name)
			}
			if _, exists := input.Files[name]; exists {
				fail("Prepared dependency collides with project source: %s", name)
			}
			input.Files[name] = source
		}
		if size > 8*1024*1024 {
			fail("Prepared dependencies exceed 8 MiB")
		}
	}
	module := "playground"
	mod := input.Files["go.mod"]
	if m := regexp.MustCompile(`(?m)^module\s+(\S+)`).FindStringSubmatch(mod); len(m) > 1 {
		module = strings.Trim(m[1], "\"")
	}
	if m := regexp.MustCompile(`(?m)^go\s+(\d+)\.(\d+)`).FindStringSubmatch(mod); len(m) > 2 {
		major, _ := strconv.Atoi(m[1])
		minor, _ := strconv.Atoi(m[2])
		if major != 1 || minor > 27 {
			fail("This Playground bundles Go 1.27.1; go.mod requests %s.%s", m[1], m[2])
		}
		language = "go" + m[1] + "." + m[2]
	}
	for _, name := range input.Standard {
		archives[name] = "/goroot/pkg/wasip1_wasm/" + name + ".a"
	}
	ctx := build.Default
	ctx.GOOS = "wasip1"
	ctx.GOARCH = "wasm"
	ctx.CgoEnabled = false
	ctx.Compiler = "gc"
	ctx.ReleaseTags = nil
	for n := 1; n <= 27; n++ {
		ctx.ReleaseTags = append(ctx.ReleaseTags, fmt.Sprintf("go1.%d", n))
	}
	ctx.OpenFile = func(name string) (io.ReadCloser, error) {
		s, ok := input.Files[strings.TrimPrefix(name, "/work/")]
		if !ok {
			return nil, os.ErrNotExist
		}
		return io.NopCloser(bytes.NewBufferString(s)), nil
	}
	if input.Mode == "debug" {
		selected := map[string]string{}
		for name, source := range input.Files {
			if !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") || strings.HasPrefix(name, "vendor/") {
				continue
			}
			ok, err := ctx.MatchFile("/work/"+path.Dir(name), path.Base(name))
			if err != nil {
				fail("%s: %s", name, err)
			}
			if ok {
				selected[name] = source
			}
		}
		debug := instrumentGo(selected)
		plan.Points = debug.Points
		for name, source := range debug.Files {
			input.Files[name] = source
			plan.Files["/work/"+name] = source
		}
	}
	for _, name := range sortedKeys(input.Files) {
		if !strings.HasSuffix(name, ".go") {
			continue
		}
		dir := path.Dir(name)
		if dir == "." {
			dir = ""
		}
		ok, err := ctx.MatchFile("/work/"+dir, path.Base(name))
		if err != nil {
			fail("%s: %s", name, err)
		}
		if !ok {
			continue
		}
		a, err := parser.ParseFile(token.NewFileSet(), name, input.Files[name], parser.ParseComments|parser.AllErrors)
		if err != nil {
			fail("%s", err)
		}
		key := module
		if dir != "" {
			key += "/" + dir
		}
		if strings.HasPrefix(dir, "vendor/") {
			key = strings.TrimPrefix(dir, "vendor/")
		}
		p := packages[key]
		if p == nil {
			p = &Package{Import: key, Dir: dir, AST: map[string]*ast.File{}}
			packages[key] = p
		}
		p.AST[name] = a
		if strings.HasSuffix(name, "_test.go") {
			if strings.HasSuffix(a.Name.Name, "_test") {
				p.External = append(p.External, name)
			} else {
				p.Tests = append(p.Tests, name)
				if p.Name == "" {
					p.Name = a.Name.Name
				}
			}
		} else {
			if p.Name != "" && p.Name != a.Name.Name {
				fail("Mixed packages in %s", dir)
			}
			p.Name = a.Name.Name
			p.Files = append(p.Files, name)
		}
	}
	if input.Mode == "test" {
		count := 0
		for _, key := range sortedKeys(packages) {
			p := packages[key]
			if strings.HasPrefix(p.Dir, "vendor/") || len(p.Tests)+len(p.External) == 0 {
				continue
			}
			testPackage(p)
			count++
		}
		if count == 0 {
			fail("No _test.go files found. Add a Test function with a *testing.T parameter.")
		}
		return
	}
	p := packages[module]
	if p == nil {
		fail("Keep a compatible main.go in the project root")
	}
	if p.Name != "main" && input.Mode != "check" {
		fail("Run/Build needs package main at the project root")
	}
	buildPackage(module)
	if input.Mode != "check" {
		entries := copyEntries()
		entries["main"] = archives[module]
		link(archives[module], "/tmp/program.wasm", entries)
	}
}
func main() {
	defer func() {
		if e := recover(); e != nil {
			plan = Plan{Error: fmt.Sprint(e)}
		}
		json.NewEncoder(os.Stdout).Encode(plan)
	}()
	run()
}
