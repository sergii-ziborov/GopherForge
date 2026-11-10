package main

// A bounded shell over a private virtual filesystem. Bash syntax is parsed by
// mvdan.cc/sh, but every command is interpreted here: nothing opens a host
// path, launches a process or has network access. The only filesystem is the
// State map the app hands in and takes back.
import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"math/rand"
	"path"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"mvdan.cc/sh/v3/expand"
	"mvdan.cc/sh/v3/pattern"
	"mvdan.cc/sh/v3/syntax"
)

const maxSource = 16384
const maxFile = 65536
const maxTotal = 2 * 1024 * 1024
const maxOutput = 65536
const maxSteps = 5000
const maxFuncs = 32
const maxDepth = 24

type State struct {
	Files map[string]string `json:"files"`
	Dirs  map[string]bool   `json:"dirs"`
	Vars  map[string]string `json:"vars"`
	Cwd   string            `json:"cwd"`
	// Function bodies, printed back to source, so a function defined at one
	// prompt can be called from the next.
	Funcs map[string]string `json:"funcs,omitempty"`
}
type Result struct {
	State  State  `json:"state"`
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
	Status int    `json:"status"`
	// The source ended inside a quote, block or heredoc. Nothing ran; an
	// interactive prompt asks for the next line instead of reporting an error.
	Incomplete bool `json:"incomplete,omitempty"`
	// Stdout and stderr interleaved per top-level statement, the order a
	// terminal shows them in.
	Output []Chunk `json:"output,omitempty"`
}
type Chunk struct {
	Text  string `json:"text"`
	Error bool   `json:"error,omitempty"`
}
type Shell struct {
	state                 State
	steps, depth, emitted int
	stopped               func() bool
	args                  []string
	name                  string
	locals                []map[string]*string
	errexit, nounset      bool
	xtrace, pipefail      bool
	guard                 int
	substErr              strings.Builder
	output                []Chunk
}
type outcome struct {
	out, err string
	status   int
	// The status came from a condition or a non-final && / || operand, which
	// set -e does not treat as a failure.
	exempt bool
}

// Control flow travels as an error so that every enclosing construct unwinds
// without having to know which one will stop it.
type flow struct {
	kind   string
	n      int
	status int
}

func (f *flow) Error() string { return f.kind + " outside its construct" }

func initialState() State {
	return State{map[string]string{}, map[string]bool{"/lab": true}, map[string]string{}, "/lab", map[string]string{}}
}
func validateState(s State) error {
	if s.Files == nil || s.Dirs == nil || s.Vars == nil || len(s.Files)+len(s.Dirs) > 128 || len(s.Vars) > 64 || len(s.Files) > 96 || len(s.Funcs) > maxFuncs {
		return errors.New("lab state exceeds its limits")
	}
	total := 0
	for p, v := range s.Files {
		if !safePath(p) || len(v) > maxFile || !utf8.ValidString(v) {
			return errors.New("invalid lab file")
		}
		total += len(v)
	}
	for p, v := range s.Dirs {
		_, fileExists := s.Files[p]
		if !safePath(p) || !v || fileExists {
			return errors.New("invalid lab directory")
		}
	}
	for k, v := range s.Vars {
		if len(k) > 128 || len(v) > 4096 {
			return errors.New("variable limit reached")
		}
		total += len(k) + len(v)
	}
	for k, v := range s.Funcs {
		if !validName(k) || len(k) > 64 || len(v) > 8192 {
			return errors.New("function limit reached")
		}
		total += len(k) + len(v)
	}
	if total > maxTotal || !s.Dirs[s.Cwd] || !s.Dirs["/lab"] {
		return errors.New("lab storage limit reached")
	}
	return nil
}
func validName(name string) bool {
	for i, r := range name {
		letter := r == '_' || (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
		if !letter && (i == 0 || !((r >= '0' && r <= '9') || r == '-' || r == '.')) {
			return false
		}
	}
	return name != ""
}
func safePath(p string) bool {
	return len(p) <= 256 && path.Clean(p) == p && (p == "/lab" || strings.HasPrefix(p, "/lab/")) && !strings.ContainsRune(p, 0)
}

var errOutside = errors.New("Permission denied (only /lab is available)")

func (s *Shell) resolve(p string) (string, error) {
	if p == "" {
		return "", errors.New("No such file or directory")
	}
	if !path.IsAbs(p) {
		p = path.Join(s.state.Cwd, p)
	} else {
		p = path.Clean(p)
	}
	if !safePath(p) {
		return "", errOutside
	}
	return p, nil
}
func (s *Shell) step() error {
	s.steps++
	if s.steps > maxSteps {
		return fmt.Errorf("stopped at the %d-step lab budget", maxSteps)
	}
	if s.stopped != nil && s.stopped() {
		return errors.New("stopped by user")
	}
	return nil
}
func (s *Shell) store(p, v string) error {
	if len(v) > maxFile {
		return errors.New("file exceeds 64 KiB")
	}
	if !s.state.Dirs[path.Dir(p)] || s.state.Dirs[p] {
		return errors.New("parent directory missing or target is a directory")
	}
	old, exists := s.state.Files[p]
	s.state.Files[p] = v
	if err := validateState(s.state); err != nil {
		if exists {
			s.state.Files[p] = old
		} else {
			delete(s.state.Files, p)
		}
		return err
	}
	return nil
}

func run(source string, state State, stopped func() bool) Result {
	if state.Vars != nil {
		if _, ok := state.Vars["?"]; !ok {
			state.Vars["?"] = "0"
		}
	}
	if state.Funcs == nil {
		state.Funcs = map[string]string{}
	}
	s := &Shell{state: state, stopped: stopped, name: "sh"}
	r := Result{State: state}
	if err := validateState(state); err != nil {
		r.Stderr = err.Error()
		r.Status = 2
		return r
	}
	f, err := parse(source)
	if err != nil {
		r.Stderr = err.Error() + "\n"
		r.Status = 2
		r.Incomplete = syntax.IsIncomplete(err) || strings.Contains(err.Error(), "unclosed here-document")
		return r
	}
	o, err := s.statements(f.Stmts, &stream{})
	var stop *flow
	if errors.As(err, &stop) {
		if stop.kind == "return" {
			o.err += "return: can only be used in a function or a sourced script\n"
			s.emit("return: can only be used in a function or a sourced script\n", true)
		}
		o.status, err = stop.status, nil
	}
	r.State = s.state
	r.Stdout = o.out
	r.Stderr = o.err
	r.Status = o.status
	if err != nil {
		r.Stderr += err.Error() + "\n"
		s.emit(err.Error()+"\n", true)
		r.Status = 2
	}
	r.Output = s.output
	r.State.Vars["?"] = strconv.Itoa(r.Status)
	return r
}

// parse rejects unsupported constructs before any command can change the lab.
func parse(source string) (*syntax.File, error) {
	if len(source) > maxSource {
		return nil, errors.New("script exceeds 16 KiB")
	}
	f, err := syntax.NewParser(syntax.Variant(syntax.LangBash)).Parse(strings.NewReader(source), "lab.sh")
	if err != nil {
		return nil, err
	}
	nodes := 0
	syntax.Walk(f, func(n syntax.Node) bool {
		if n == nil || err != nil {
			return err == nil
		}
		nodes++
		if nodes > 4096 {
			err = errors.New("script is too complex")
			return false
		}
		switch x := n.(type) {
		case *syntax.Stmt:
			if x.Background || x.Coprocess || x.Disown {
				err = errors.New("background jobs are unavailable: commands here are not OS processes")
			}
		case *syntax.ParamExp:
			if x.Excl || x.Names != 0 || x.Index != nil {
				err = errors.New("arrays and indirect expansion are unavailable; use named variables")
			}
		case *syntax.Assign:
			if x.Array != nil || x.Index != nil {
				err = errors.New("arrays are unavailable; use named variables")
			}
		case *syntax.ArrayExpr:
			err = errors.New("arrays are unavailable; use named variables")
		case *syntax.ProcSubst:
			err = errors.New("process substitution is unavailable")
		case *syntax.CoprocClause:
			err = errors.New("coprocesses are unavailable")
		case *syntax.ExtGlob:
			err = errors.New("extended globs are unavailable")
		case *syntax.TestDecl:
			err = errors.New("test declarations are unavailable")
		case *syntax.Word:
			// Brace expansion happens before any argument limit can be
			// checked, so a range like {1..9999999} is refused here.
			if braceWords(x) > 10000 {
				err = errors.New("brace expansion is limited to 10000 words")
			}
		}
		return err == nil
	})
	if err != nil {
		return nil, err
	}
	return f, nil
}

// braceWords estimates how many words a word's brace expansion produces.
func braceWords(word *syntax.Word) int {
	w := &syntax.Word{Parts: append([]syntax.WordPart(nil), word.Parts...)}
	if !syntax.SplitBraces(w) {
		return 1
	}
	total := 1
	for _, part := range w.Parts {
		b, ok := part.(*syntax.BraceExp)
		if !ok {
			continue
		}
		n := 0
		if b.Sequence && len(b.Elems) >= 2 {
			from, e1 := strconv.Atoi(b.Elems[0].Lit())
			to, e2 := strconv.Atoi(b.Elems[1].Lit())
			n = 52
			if e1 == nil && e2 == nil {
				n = max(from-to, to-from) + 1
			}
		} else {
			for _, e := range b.Elems {
				n += braceWords(e)
			}
		}
		if total *= max(n, 1); total > 1<<20 {
			return total
		}
	}
	return total
}

// The environment the expander sees: the lab's own variables, the reserved
// ones it derives, and the positional parameters of the running script.
type labEnv struct{ s *Shell }

func str(v string) expand.Variable {
	return expand.Variable{Set: true, Exported: true, Kind: expand.String, Str: v}
}
func (e labEnv) Get(name string) expand.Variable {
	s := e.s
	switch name {
	case "HOME":
		return str("/lab")
	case "PWD":
		return str(s.state.Cwd)
	case "IFS":
		return expand.Variable{}
	case "#":
		return str(strconv.Itoa(len(s.args)))
	case "@", "*":
		return expand.Variable{Set: true, Kind: expand.Indexed, List: s.args}
	case "0":
		return str(s.name)
	case "$":
		return str("4242")
	case "RANDOM":
		return str(strconv.Itoa(rand.Intn(32768)))
	}
	if n, err := strconv.Atoi(name); err == nil && n > 0 {
		if n <= len(s.args) {
			return str(s.args[n-1])
		}
		return expand.Variable{}
	}
	if v, ok := s.state.Vars[name]; ok {
		return str(v)
	}
	if v, ok := defaultEnv[name]; ok {
		return str(v)
	}
	return expand.Variable{}
}

var defaultEnv = map[string]string{"USER": "lab", "LOGNAME": "lab", "SHELL": "/bin/sh", "HOSTNAME": "gopherforge", "TERM": "xterm-256color", "LANG": "C.UTF-8", "PATH": "/usr/local/bin:/usr/bin:/bin"}

func (e labEnv) Each(fn func(string, expand.Variable) bool) {
	for _, name := range e.names() {
		if !fn(name, e.Get(name)) {
			return
		}
	}
}
func (e labEnv) names() []string {
	names := []string{"HOME", "PWD"}
	for k := range defaultEnv {
		if _, shadowed := e.s.state.Vars[k]; !shadowed {
			names = append(names, k)
		}
	}
	for k := range e.s.state.Vars {
		if k != "?" {
			names = append(names, k)
		}
	}
	sort.Strings(names)
	return names
}
func (e labEnv) Set(name string, vr expand.Variable) error {
	if vr.Kind == expand.KeepValue {
		return nil
	}
	if !vr.IsSet() {
		delete(e.s.state.Vars, name)
		return nil
	}
	if vr.Kind != expand.String {
		return errors.New("arrays are unavailable; use named variables")
	}
	return e.s.setVar(name, vr.Str)
}
func (s *Shell) setVar(name, value string) error {
	switch name {
	case "HOME", "PWD", "IFS":
		return errors.New("HOME, PWD and IFS are reserved in this lab")
	}
	if len(value) > 4096 {
		return errors.New("variable exceeds 4 KiB")
	}
	old, existed := s.state.Vars[name]
	s.state.Vars[name] = value
	if err := validateState(s.state); err != nil {
		if existed {
			s.state.Vars[name] = old
		} else {
			delete(s.state.Vars, name)
		}
		return err
	}
	return nil
}

func (s *Shell) config() *expand.Config {
	return &expand.Config{Env: labEnv{s}, CmdSubst: s.substitute, ReadDir2: s.readDir, NoUnset: s.nounset}
}

// substitute runs $(...) like a subshell: its variables and directory do not
// leak back, its files do, and its errors reach the enclosing command.
func (s *Shell) substitute(w io.Writer, cs *syntax.CmdSubst) error {
	restore := s.scope()
	o, err := s.statements(cs.Stmts, &stream{})
	restore()
	var stop *flow
	if errors.As(err, &stop) {
		o.status, err = stop.status, nil
	}
	if err != nil {
		return err
	}
	s.substErr.WriteString(o.err)
	s.state.Vars["?"] = strconv.Itoa(o.status)
	_, err = io.WriteString(w, o.out)
	return err
}

// scope saves what a subshell may change and returns how to put it back.
func (s *Shell) scope() func() {
	vars := copyMap(s.state.Vars)
	funcs := copyMap(s.state.Funcs)
	cwd, args := s.state.Cwd, s.args
	errexit, nounset, xtrace, pipefail := s.errexit, s.nounset, s.xtrace, s.pipefail
	return func() {
		s.state.Vars, s.state.Funcs, s.state.Cwd, s.args = vars, funcs, cwd, args
		s.errexit, s.nounset, s.xtrace, s.pipefail = errexit, nounset, xtrace, pipefail
		if !s.state.Dirs[s.state.Cwd] {
			s.state.Cwd = "/lab"
		}
	}
}
func copyMap[V any](m map[string]V) map[string]V {
	out := make(map[string]V, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

type dirEntry struct {
	name string
	dir  bool
}

func (d dirEntry) Name() string { return d.name }
func (d dirEntry) IsDir() bool  { return d.dir }
func (d dirEntry) Type() fs.FileMode {
	if d.dir {
		return fs.ModeDir
	}
	return 0
}
func (d dirEntry) Info() (fs.FileInfo, error) { return nil, fs.ErrInvalid }

// readDir lets globs match the lab's own files, and nothing else.
func (s *Shell) readDir(dir string) ([]fs.DirEntry, error) {
	// A directory outside /lab, or one that does not exist, simply has no
	// entries, so the pattern stays literal as it does in a shell.
	dir = path.Clean(dir)
	if !safePath(dir) || !s.state.Dirs[dir] {
		return nil, nil
	}
	var out []fs.DirEntry
	for _, e := range s.children(dir) {
		out = append(out, dirEntry{e.name, e.dir})
	}
	return out, nil
}

type child struct {
	name string
	dir  bool
}

func (s *Shell) children(dir string) []child {
	var out []child
	for f := range s.state.Files {
		if path.Dir(f) == dir {
			out = append(out, child{path.Base(f), false})
		}
	}
	for d := range s.state.Dirs {
		if d != dir && path.Dir(d) == dir {
			out = append(out, child{path.Base(d), true})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].name < out[j].name })
	return out
}

func (s *Shell) words(words []*syntax.Word) ([]string, error) {
	fields, err := expand.Fields(s.config(), words...)
	if err != nil {
		return nil, err
	}
	n := 0
	for _, v := range fields {
		n += len(v)
	}
	if n > 16384 || len(fields) > 512 {
		return nil, errors.New("expanded arguments exceed lab limits")
	}
	return fields, nil
}
func (s *Shell) literal(word *syntax.Word) (string, error) {
	if word == nil {
		return "", nil
	}
	return expand.Literal(s.config(), word)
}

// stdin is shared by every command of a statement, so `while read line` sees
// successive lines instead of the first one forever.
type stream struct {
	data string
	off  int
}

func text(v string) *stream { return &stream{data: v} }
func (r *stream) rest() string {
	v := r.data[r.off:]
	r.off = len(r.data)
	return v
}
func (r *stream) line() (string, bool) {
	if r.off >= len(r.data) {
		return "", false
	}
	v := r.data[r.off:]
	if i := strings.IndexByte(v, '\n'); i >= 0 {
		r.off += i + 1
		return v[:i], true
	}
	r.off = len(r.data)
	return v, true
}

func (s *Shell) statements(stmts []*syntax.Stmt, in *stream) (outcome, error) {
	s.depth++
	defer func() { s.depth-- }()
	if s.depth > maxDepth {
		return outcome{}, errors.New("script nesting limit reached")
	}
	var total outcome
	for _, stmt := range stmts {
		o, err := s.statement(stmt, in)
		if s.depth == 1 {
			s.emit(o.out, false)
			s.emit(o.err, true)
		}
		total.out += o.out
		total.err += o.err
		total.status = o.status
		total.exempt = o.exempt
		if len(total.out)+len(total.err) > maxOutput {
			total.out = clip(total.out)
			return total, errors.New("output exceeded 64 KiB")
		}
		if err != nil {
			return total, err
		}
		if s.errexit && o.status != 0 && !o.exempt && s.guard == 0 {
			return total, &flow{kind: "exit", status: o.status}
		}
	}
	return total, nil
}
func (s *Shell) emit(text string, isError bool) {
	if text == "" {
		return
	}
	if n := len(s.output); n > 0 && s.output[n-1].Error == isError {
		s.output[n-1].Text += text
		return
	}
	s.output = append(s.output, Chunk{text, isError})
}
func clip(v string) string {
	if len(v) > maxOutput {
		return v[:maxOutput]
	}
	return v
}

// A redirect target: the terminal's stdout or stderr, nowhere, or a lab file.
type sink struct {
	fd   int
	null bool
	file string
}

func (s *Shell) statement(stmt *syntax.Stmt, in *stream) (outcome, error) {
	if err := s.step(); err != nil {
		return outcome{}, err
	}
	fds := [3]sink{{}, {fd: 1}, {fd: 2}}
	for _, r := range stmt.Redirs {
		next, err := s.redirect(r, &fds, in)
		if err != nil {
			var limit *limitError
			if errors.As(err, &limit) {
				return outcome{}, limit.err
			}
			return outcome{err: "sh: " + err.Error() + "\n", status: 1}, nil
		}
		in = next
	}
	if stmt.Negated {
		s.guard++
	}
	o, err := s.command(stmt.Cmd, in)
	if stmt.Negated {
		s.guard--
		if o.status == 0 {
			o.status = 1
		} else {
			o.status = 0
		}
		o.exempt = true
	}
	if s.substErr.Len() > 0 {
		o.err = s.substErr.String() + o.err
		s.substErr.Reset()
	}
	s.state.Vars["?"] = strconv.Itoa(o.status)
	var routed outcome
	routed.status, routed.exempt = o.status, o.exempt
	for _, part := range []struct {
		fd   int
		data string
	}{{1, o.out}, {2, o.err}} {
		if part.data == "" {
			continue
		}
		switch dest := fds[part.fd]; {
		case dest.null:
		case dest.file != "":
			if e := s.store(dest.file, s.state.Files[dest.file]+part.data); e != nil {
				return outcome{}, e
			}
		case dest.fd == 2:
			routed.err += part.data
		default:
			routed.out += part.data
		}
	}
	s.emitted += len(routed.out) + len(routed.err)
	if s.emitted > maxOutput*4 {
		return outcome{}, errors.New("run output budget reached")
	}
	return routed, err
}

// A failure that must stop the run rather than fail one command.
type limitError struct{ err error }

func (l *limitError) Error() string { return l.err.Error() }

func (s *Shell) redirect(r *syntax.Redirect, fds *[3]sink, in *stream) (*stream, error) {
	fd := 1
	switch r.Op {
	case syntax.RdrIn, syntax.DplIn, syntax.Hdoc, syntax.DashHdoc, syntax.WordHdoc, syntax.RdrInOut:
		fd = 0
	}
	if r.N != nil {
		n, err := strconv.Atoi(r.N.Value)
		if err != nil || n < 0 || n > 2 {
			return nil, errors.New("only file descriptors 0, 1 and 2 exist here")
		}
		fd = n
	}
	switch r.Op {
	case syntax.Hdoc, syntax.DashHdoc:
		if r.Hdoc == nil {
			return text(""), nil
		}
		v, err := expand.Document(s.config(), r.Hdoc)
		if err != nil {
			return nil, err
		}
		return text(v), nil
	case syntax.WordHdoc:
		v, err := s.literal(r.Word)
		if err != nil {
			return nil, err
		}
		return text(v + "\n"), nil
	}
	names, err := s.words([]*syntax.Word{r.Word})
	if err != nil {
		return nil, err
	}
	if len(names) != 1 {
		return nil, errors.New("ambiguous redirect")
	}
	name := names[0]
	switch r.Op {
	case syntax.DplOut:
		switch name {
		case "1", "2":
			n, _ := strconv.Atoi(name)
			fds[fd] = fds[n]
		case "-":
			fds[fd] = sink{null: true}
		default:
			return nil, errors.New(name + ": bad file descriptor")
		}
		return in, nil
	case syntax.DplIn:
		if name == "0" {
			return in, nil
		}
		return nil, errors.New(name + ": bad file descriptor")
	case syntax.RdrInOut:
		return nil, errors.New("<> is unavailable")
	}
	switch name {
	case "/dev/null":
		if fd == 0 {
			return text(""), nil
		}
		fds[fd] = sink{null: true}
		if r.Op == syntax.RdrAll || r.Op == syntax.AppAll {
			fds[1], fds[2] = fds[fd], fds[fd]
		}
		return in, nil
	case "/dev/stdout", "/dev/stderr":
		if fd != 0 {
			fds[fd] = fds[map[string]int{"/dev/stdout": 1, "/dev/stderr": 2}[name]]
		}
		return in, nil
	case "/dev/stdin":
		return in, nil
	}
	p, err := s.resolve(name)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", name, err)
	}
	if r.Op == syntax.RdrIn {
		if s.state.Dirs[p] {
			return nil, errors.New(name + ": Is a directory")
		}
		v, ok := s.state.Files[p]
		if !ok {
			return nil, errors.New(name + ": No such file or directory")
		}
		return text(v), nil
	}
	if s.state.Dirs[p] {
		return nil, errors.New(name + ": Is a directory")
	}
	if !s.state.Dirs[path.Dir(p)] {
		return nil, errors.New(name + ": No such file or directory")
	}
	_, exists := s.state.Files[p]
	if !exists || r.Op == syntax.RdrOut || r.Op == syntax.ClbOut || r.Op == syntax.RdrAll {
		if err := s.store(p, ""); err != nil {
			return nil, &limitError{err}
		}
	}
	fds[fd] = sink{file: p}
	if r.Op == syntax.RdrAll || r.Op == syntax.AppAll {
		fds[1], fds[2] = fds[fd], fds[fd]
	}
	return in, nil
}

func (s *Shell) command(cmd syntax.Command, in *stream) (outcome, error) {
	switch x := cmd.(type) {
	case nil:
		return outcome{}, nil
	case *syntax.CallExpr:
		return s.call(x, in)
	case *syntax.BinaryCmd:
		switch x.Op {
		case syntax.Pipe, syntax.PipeAll:
			left, e := s.statement(x.X, in)
			if e != nil {
				return left, e
			}
			input := left.out
			if x.Op == syntax.PipeAll {
				input += left.err
				left.err = ""
			}
			right, e := s.statement(x.Y, text(input))
			right.err = left.err + right.err
			if s.pipefail && right.status == 0 && left.status != 0 {
				right.status = left.status
			}
			return right, e
		case syntax.AndStmt, syntax.OrStmt:
			s.guard++
			left, e := s.statement(x.X, in)
			s.guard--
			if e != nil {
				return left, e
			}
			if (x.Op == syntax.AndStmt) != (left.status == 0) {
				left.exempt = true
				return left, nil
			}
			right, e := s.statement(x.Y, in)
			right.out = left.out + right.out
			right.err = left.err + right.err
			return right, e
		}
		return outcome{}, errors.New("unsupported operator")
	case *syntax.Block:
		return s.statements(x.Stmts, in)
	case *syntax.Subshell:
		restore := s.scope()
		o, err := s.statements(x.Stmts, in)
		restore()
		var stop *flow
		if errors.As(err, &stop) && stop.kind == "exit" {
			o.status, err = stop.status, nil
		}
		return o, err
	case *syntax.IfClause:
		if len(x.Cond) == 0 {
			return s.statements(x.Then, in)
		}
		s.guard++
		cond, e := s.statements(x.Cond, in)
		s.guard--
		if e != nil {
			return cond, e
		}
		var body outcome
		if cond.status == 0 {
			body, e = s.statements(x.Then, in)
		} else if x.Else != nil {
			body, e = s.command(x.Else, in)
		}
		body.out = cond.out + body.out
		body.err = cond.err + body.err
		return body, e
	case *syntax.ForClause:
		return s.forLoop(x, in)
	case *syntax.WhileClause:
		var o outcome
		for {
			if e := s.step(); e != nil {
				return o, e
			}
			s.guard++
			cond, e := s.statements(x.Cond, in)
			s.guard--
			o.out += cond.out
			o.err += cond.err
			if e != nil {
				return o, e
			}
			if (cond.status == 0) == x.Until {
				return o, nil
			}
			r, e := s.statements(x.Do, in)
			o.out += r.out
			o.err += r.err
			o.status = r.status
			if stop, done := loopControl(&e); done {
				return o, e
			} else if stop {
				return o, nil
			}
			if len(o.out)+len(o.err) > maxOutput {
				return outcome{}, errors.New("output limit reached")
			}
		}
	case *syntax.CaseClause:
		word, e := s.literal(x.Word)
		if e != nil {
			return outcome{}, e
		}
		for i := 0; i < len(x.Items); i++ {
			item := x.Items[i]
			matched := false
			for _, p := range item.Patterns {
				pat, e := expand.Pattern(s.config(), p)
				if e != nil {
					return outcome{}, e
				}
				if globMatch(pat, word) {
					matched = true
					break
				}
			}
			if !matched {
				continue
			}
			o, e := s.statements(item.Stmts, in)
			for item.Op == syntax.Fallthrough && i+1 < len(x.Items) && e == nil {
				i++
				item = x.Items[i]
				r, err := s.statements(item.Stmts, in)
				o.out, o.err, o.status, e = o.out+r.out, o.err+r.err, r.status, err
			}
			return o, e
		}
		return outcome{}, nil
	case *syntax.FuncDecl:
		if x.Name == nil || !validName(x.Name.Value) {
			return failure("function needs a name")
		}
		var b strings.Builder
		if err := syntax.NewPrinter().Print(&b, x.Body); err != nil {
			return outcome{}, err
		}
		if _, exists := s.state.Funcs[x.Name.Value]; !exists && len(s.state.Funcs) >= maxFuncs {
			return failure("function limit reached (32)")
		}
		old, existed := s.state.Funcs[x.Name.Value]
		s.state.Funcs[x.Name.Value] = b.String()
		if err := validateState(s.state); err != nil {
			if existed {
				s.state.Funcs[x.Name.Value] = old
			} else {
				delete(s.state.Funcs, x.Name.Value)
			}
			return outcome{}, err
		}
		return outcome{}, nil
	case *syntax.ArithmCmd:
		n, e := expand.Arithm(s.config(), x.X)
		if e != nil {
			return failure("((: " + e.Error())
		}
		return outcome{status: boolStatus(n != 0)}, nil
	case *syntax.LetClause:
		n := 0
		for _, expr := range x.Exprs {
			var e error
			if n, e = expand.Arithm(s.config(), expr); e != nil {
				return failure("let: " + e.Error())
			}
		}
		return outcome{status: boolStatus(n != 0)}, nil
	case *syntax.TestClause:
		ok, e := s.testExpr(x.X)
		if e != nil {
			return outcome{err: "[[: " + e.Error() + "\n", status: 2}, nil
		}
		return outcome{status: boolStatus(ok)}, nil
	case *syntax.DeclClause:
		return s.declare(x)
	case *syntax.TimeClause:
		start := time.Now()
		var o outcome
		var e error
		if x.Stmt != nil {
			o, e = s.statement(x.Stmt, in)
		}
		elapsed := time.Since(start)
		o.err += fmt.Sprintf("\nreal\t%dm%.3fs\nuser\t0m0.000s\nsys\t0m0.000s\n", int(elapsed.Minutes()), elapsed.Seconds()-float64(int(elapsed.Minutes())*60))
		return o, e
	default:
		return outcome{}, errors.New("unsupported shell construct")
	}
}
func boolStatus(ok bool) int {
	if ok {
		return 0
	}
	return 1
}

// loopControl consumes a break or continue aimed at this loop. It reports
// whether the loop stops, and whether the error must still propagate.
func loopControl(err *error) (stop, propagate bool) {
	var f *flow
	if *err == nil {
		return false, false
	}
	if !errors.As(*err, &f) || (f.kind != "break" && f.kind != "continue") {
		return true, true
	}
	if f.n > 1 {
		f.n--
		return true, true
	}
	*err = nil
	return f.kind == "break", false
}

func (s *Shell) forLoop(x *syntax.ForClause, in *stream) (outcome, error) {
	var o outcome
	body := func() (bool, error) {
		r, e := s.statements(x.Do, in)
		o.out += r.out
		o.err += r.err
		o.status = r.status
		stop, propagate := loopControl(&e)
		if propagate {
			return true, e
		}
		if len(o.out)+len(o.err) > maxOutput {
			return true, errors.New("output limit reached")
		}
		return stop, nil
	}
	switch loop := x.Loop.(type) {
	case *syntax.WordIter:
		var items []string
		if loop.InPos.IsValid() {
			var e error
			if items, e = s.words(loop.Items); e != nil {
				return outcome{}, e
			}
		} else {
			items = append(items, s.args...)
		}
		for _, v := range items {
			if e := s.step(); e != nil {
				return o, e
			}
			if e := s.setVar(loop.Name.Value, v); e != nil {
				return o, e
			}
			if stop, e := body(); stop || e != nil {
				return o, e
			}
		}
	case *syntax.CStyleLoop:
		cfg := s.config()
		if loop.Init != nil {
			if _, e := expand.Arithm(cfg, loop.Init); e != nil {
				return o, e
			}
		}
		for {
			if e := s.step(); e != nil {
				return o, e
			}
			if loop.Cond != nil {
				n, e := expand.Arithm(cfg, loop.Cond)
				if e != nil {
					return o, e
				}
				if n == 0 {
					return o, nil
				}
			}
			if stop, e := body(); stop || e != nil {
				return o, e
			}
			if loop.Post != nil {
				if _, e := expand.Arithm(cfg, loop.Post); e != nil {
					return o, e
				}
			}
		}
	}
	return o, nil
}

func globMatch(pat, value string) bool {
	expr, err := pattern.Regexp(pat, pattern.EntireString)
	if err != nil {
		return pat == value
	}
	re, err := compileRegexp(expr)
	return err == nil && re.MatchString(value)
}

func (s *Shell) call(x *syntax.CallExpr, in *stream) (outcome, error) {
	// A command's arguments expand in the caller environment, before its
	// temporary prefix assignments are installed.
	var args []string
	if len(x.Args) > 0 {
		var err error
		if args, err = s.words(x.Args); err != nil {
			return s.expansionFailure(err)
		}
	}
	previous := copyMap(s.state.Vars)
	for _, a := range x.Assigns {
		if a.Name == nil || a.Array != nil || a.Index != nil {
			return outcome{}, errors.New("unsupported assignment")
		}
		v, e := s.literal(a.Value)
		if e != nil {
			s.state.Vars = previous
			return s.expansionFailure(e)
		}
		if a.Append {
			v = s.state.Vars[a.Name.Value] + v
		}
		if e := s.setVar(a.Name.Value, v); e != nil {
			s.state.Vars = previous
			return outcome{}, e
		}
	}
	if len(x.Args) == 0 {
		return outcome{}, nil
	}
	// Prefix assignments are scoped to this invocation, as in a shell.
	if len(x.Assigns) > 0 {
		defer func() { s.state.Vars = previous }()
	}
	if len(args) == 0 {
		return outcome{}, nil
	}
	if s.xtrace {
		s.substErr.WriteString("+ " + strings.Join(args, " ") + "\n")
	}
	return s.invoke(args, in, true)
}

// An expansion error such as ${x:?missing} fails the command, not the run;
// lab limits still stop everything.
func (s *Shell) expansionFailure(err error) (outcome, error) {
	if strings.Contains(err.Error(), "limit") || strings.Contains(err.Error(), "budget") || strings.Contains(err.Error(), "stopped") {
		return outcome{}, err
	}
	return outcome{err: "sh: " + err.Error() + "\n", status: 1}, nil
}

func (s *Shell) invoke(args []string, in *stream, functions bool) (outcome, error) {
	if body, ok := s.state.Funcs[args[0]]; ok && functions {
		return s.callFunction(args[0], body, args[1:], in)
	}
	if strings.Contains(args[0], "/") {
		if p, err := s.resolve(args[0]); err == nil {
			if v, ok := s.state.Files[p]; ok {
				return s.runScript(args[0], v, args[1:], in, true)
			}
			if s.state.Dirs[p] {
				return outcome{err: "sh: " + args[0] + ": Is a directory\n", status: 126}, nil
			}
		}
		return outcome{err: "sh: " + args[0] + ": No such file or directory\n", status: 127}, nil
	}
	return s.utility(args, in)
}

func (s *Shell) callFunction(name, body string, args []string, in *stream) (outcome, error) {
	if err := s.step(); err != nil {
		return outcome{}, err
	}
	f, err := parse(body)
	if err != nil {
		return failure(name + ": " + err.Error())
	}
	savedArgs := s.args
	s.args = args
	s.locals = append(s.locals, map[string]*string{})
	defer func() {
		frame := s.locals[len(s.locals)-1]
		for k, v := range frame {
			if v == nil {
				delete(s.state.Vars, k)
			} else {
				s.state.Vars[k] = *v
			}
		}
		s.locals = s.locals[:len(s.locals)-1]
		s.args = savedArgs
	}()
	o, err := s.statements(f.Stmts, in)
	var stop *flow
	if errors.As(err, &stop) && stop.kind == "return" {
		o.status, err = stop.status, nil
	}
	return o, err
}

// runScript runs lab source with its own positional parameters. A scoped
// script, like `sh file`, cannot change the caller's variables or directory;
// `source file` can.
func (s *Shell) runScript(name, source string, args []string, in *stream, scoped bool) (outcome, error) {
	f, err := parse(source)
	if err != nil {
		return outcome{err: name + ": " + err.Error() + "\n", status: 2}, nil
	}
	savedArgs, savedName := s.args, s.name
	s.args, s.name = args, name
	restore := func() {}
	if scoped {
		restore = s.scope()
	}
	o, err := s.statements(f.Stmts, in)
	restore()
	s.args, s.name = savedArgs, savedName
	var stop *flow
	if errors.As(err, &stop) && ((stop.kind == "exit" && scoped) || (stop.kind == "return" && !scoped)) {
		o.status, err = stop.status, nil
	}
	return o, err
}

func (s *Shell) declare(x *syntax.DeclClause) (outcome, error) {
	variant := x.Variant.Value
	local := variant == "local" || ((variant == "declare" || variant == "typeset") && len(s.locals) > 0)
	if variant == "local" && len(s.locals) == 0 {
		return failure("local: can only be used in a function")
	}
	if variant == "nameref" {
		return failure("nameref is unavailable")
	}
	var listing []string
	for _, a := range x.Args {
		if a.Naked && a.Name == nil {
			flag, e := s.literal(a.Value)
			if e != nil {
				return s.expansionFailure(e)
			}
			switch {
			case strings.ContainsAny(flag, "aA"):
				return failure(variant + ": arrays are unavailable; use named variables")
			case flag == "-p" || flag == "-x" || flag == "-r" || flag == "-g" || flag == "-i" || flag == "-l" || flag == "-u" || flag == "-xr":
				if flag == "-p" {
					for _, name := range (labEnv{s}).names() {
						listing = append(listing, "declare -x "+name+"="+strconv.Quote(labEnv{s}.Get(name).Str))
					}
				}
			case flag == "-f" || flag == "-F":
				for _, name := range sortedKeys(s.state.Funcs) {
					if flag == "-F" {
						listing = append(listing, "declare -f "+name)
					} else {
						listing = append(listing, name+" () \n"+s.state.Funcs[name])
					}
				}
			default:
				return failure(variant + ": " + flag + ": invalid option")
			}
			continue
		}
		if a.Name == nil {
			continue
		}
		name := a.Name.Value
		if local {
			frame := s.locals[len(s.locals)-1]
			if _, saved := frame[name]; !saved {
				if v, ok := s.state.Vars[name]; ok {
					frame[name] = &v
				} else {
					frame[name] = nil
				}
			}
		}
		if a.Naked {
			if local {
				if e := s.setVar(name, ""); e != nil {
					return outcome{}, e
				}
			}
			continue
		}
		v, e := s.literal(a.Value)
		if e != nil {
			return s.expansionFailure(e)
		}
		if a.Append {
			v = s.state.Vars[name] + v
		}
		if e := s.setVar(name, v); e != nil {
			return outcome{}, e
		}
	}
	if len(listing) > 0 {
		return outcome{out: strings.Join(listing, "\n") + "\n"}, nil
	}
	return outcome{}, nil
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func (s *Shell) testExpr(expr syntax.TestExpr) (bool, error) {
	switch x := expr.(type) {
	case *syntax.Word:
		v, err := s.literal(x)
		return v != "", err
	case *syntax.ParenTest:
		return s.testExpr(x.X)
	case *syntax.UnaryTest:
		if x.Op == syntax.TsNot {
			ok, err := s.testExpr(x.X)
			return !ok, err
		}
		word, ok := x.X.(*syntax.Word)
		if !ok {
			return false, errors.New("unsupported test")
		}
		v, err := s.literal(word)
		if err != nil {
			return false, err
		}
		return s.unaryTest(x.Op.String(), v)
	case *syntax.BinaryTest:
		switch x.Op {
		case syntax.AndTest, syntax.OrTest:
			left, err := s.testExpr(x.X)
			if err != nil || (x.Op == syntax.AndTest) != left {
				return left, err
			}
			return s.testExpr(x.Y)
		}
		lw, lok := x.X.(*syntax.Word)
		rw, rok := x.Y.(*syntax.Word)
		if !lok || !rok {
			return false, errors.New("unsupported test")
		}
		left, err := s.literal(lw)
		if err != nil {
			return false, err
		}
		switch x.Op {
		case syntax.TsMatch, syntax.TsMatchShort, syntax.TsNoMatch:
			pat, err := expand.Pattern(s.config(), rw)
			if err != nil {
				return false, err
			}
			return globMatch(pat, left) == (x.Op != syntax.TsNoMatch), nil
		case syntax.TsReMatch:
			right, err := s.literal(rw)
			if err != nil {
				return false, err
			}
			re, err := compileRegexp(right)
			if err != nil {
				return false, err
			}
			return re.MatchString(left), nil
		}
		right, err := s.literal(rw)
		if err != nil {
			return false, err
		}
		return binaryTest(x.Op.String(), left, right)
	}
	return false, errors.New("unsupported test")
}

func (s *Shell) unaryTest(op, v string) (bool, error) {
	switch op {
	case "-n":
		return v != "", nil
	case "-z":
		return v == "", nil
	case "-v":
		_, ok := s.state.Vars[v]
		return ok, nil
	}
	p, err := s.resolve(v)
	if err != nil {
		return false, nil
	}
	data, isFile := s.state.Files[p]
	isDir := s.state.Dirs[p]
	switch op {
	case "-e", "-r", "-w", "-x":
		return isFile || isDir, nil
	case "-f":
		return isFile, nil
	case "-d":
		return isDir, nil
	case "-s":
		return isFile && data != "", nil
	case "-L", "-h", "-p", "-S", "-b", "-c":
		return false, nil
	}
	return false, errors.New(op + ": unsupported test")
}

func binaryTest(op, left, right string) (bool, error) {
	switch op {
	case "=", "==":
		return left == right, nil
	case "!=":
		return left != right, nil
	case "<":
		return left < right, nil
	case ">":
		return left > right, nil
	}
	a, err1 := strconv.Atoi(strings.TrimSpace(left))
	b, err2 := strconv.Atoi(strings.TrimSpace(right))
	if err1 != nil || err2 != nil {
		return false, fmt.Errorf("integer expression expected")
	}
	switch op {
	case "-eq":
		return a == b, nil
	case "-ne":
		return a != b, nil
	case "-lt":
		return a < b, nil
	case "-le":
		return a <= b, nil
	case "-gt":
		return a > b, nil
	case "-ge":
		return a >= b, nil
	}
	return false, errors.New(op + ": unsupported test")
}
