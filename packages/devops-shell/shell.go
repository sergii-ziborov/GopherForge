package main

// An intentionally bounded shell language over a private virtual filesystem.
// No command opens a host path, launches a process or has network access.
import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"path"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"

	"mvdan.cc/sh/v3/expand"
	"mvdan.cc/sh/v3/syntax"
)

const maxSource = 16384
const maxFile = 65536
const maxTotal = 2 * 1024 * 1024
const maxOutput = 65536
const maxSteps = 256

type State struct {
	Files map[string]string `json:"files"`
	Dirs  map[string]bool   `json:"dirs"`
	Vars  map[string]string `json:"vars"`
	Cwd   string            `json:"cwd"`
}
type Result struct {
	State  State  `json:"state"`
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
	Status int    `json:"status"`
}
type Shell struct {
	state                 State
	steps, depth, emitted int
	stopped               func() bool
}
type outcome struct {
	out, err string
	status   int
}

func initialState() State {
	return State{map[string]string{}, map[string]bool{"/lab": true}, map[string]string{}, "/lab"}
}
func validateState(s State) error {
	if s.Files == nil || s.Dirs == nil || s.Vars == nil || len(s.Files)+len(s.Dirs) > 128 || len(s.Vars) > 64 || len(s.Files) > 96 {
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
	if total > maxTotal || !s.Dirs[s.Cwd] || !s.Dirs["/lab"] {
		return errors.New("lab storage limit reached")
	}
	return nil
}
func safePath(p string) bool {
	return len(p) <= 256 && path.Clean(p) == p && (p == "/lab" || strings.HasPrefix(p, "/lab/")) && !strings.ContainsRune(p, 0)
}
func (s *Shell) resolve(p string) (string, error) {
	if !path.IsAbs(p) {
		p = path.Join(s.state.Cwd, p)
	} else {
		p = path.Clean(p)
	}
	if !safePath(p) {
		return "", errors.New("path is outside /lab")
	}
	return p, nil
}
func (s *Shell) step() error {
	s.steps++
	if s.steps > maxSteps {
		return errors.New("stopped at the 256-step lab budget")
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
	s := &Shell{state: state, stopped: stopped}
	r := Result{State: state}
	if err := validateState(state); err != nil {
		r.Stderr = err.Error()
		r.Status = 2
		return r
	}
	o, err := s.script(source, "")
	r.State = s.state
	r.Stdout = o.out
	r.Stderr = o.err
	r.Status = o.status
	if err != nil {
		r.Stderr += err.Error() + "\n"
		r.Status = 2
	}
	return r
}
func (s *Shell) script(source, input string) (outcome, error) {
	if len(source) > maxSource {
		return outcome{}, errors.New("script exceeds 16 KiB")
	}
	f, err := syntax.NewParser(syntax.Variant(syntax.LangPOSIX)).Parse(strings.NewReader(source), "lab.sh")
	if err != nil {
		return outcome{}, err
	}
	// Reject unsupported constructs before any command mutates the lab.
	nodes := 0
	syntax.Walk(f, func(n syntax.Node) bool {
		if n == nil {
			return true
		}
		nodes++
		if nodes > 2048 {
			err = errors.New("script is too complex")
			return false
		}
		switch x := n.(type) {
		case *syntax.Stmt:
			if x.Background || x.Coprocess || x.Disown {
				err = errors.New("background jobs are unavailable")
			}
		case *syntax.ParamExp:
			if x.Param == nil || x.Exp != nil || x.Repl != nil || x.Slice != nil || x.Index != nil || x.Length || x.Excl || x.Names != 0 {
				err = errors.New("only simple $name and ${name} expansion is supported")
			}
		case *syntax.CmdSubst, *syntax.ProcSubst, *syntax.ArithmExp, *syntax.FuncDecl, *syntax.Subshell, *syntax.CaseClause:
			err = errors.New("command substitution, arithmetic, functions, subshells and case are unavailable; use a bounded script with named variables")
		}
		return err == nil
	})
	if err != nil {
		return outcome{}, err
	}
	return s.statements(f.Stmts, input)
}
func (s *Shell) config() *expand.Config {
	env := []string{"HOME=/lab", "PWD=" + s.state.Cwd, "?=" + s.state.Vars["?"]}
	for k, v := range s.state.Vars {
		if k != "HOME" && k != "PWD" && k != "IFS" && k != "?" {
			env = append(env, k+"="+v)
		}
	}
	return &expand.Config{Env: expand.ListEnviron(env...)} // no host environment, globber or command-substitution callback
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
	if n > 8192 || len(fields) > 128 {
		return nil, errors.New("expanded arguments exceed lab limits")
	}
	return fields, nil
}
func (s *Shell) statements(stmts []*syntax.Stmt, input string) (outcome, error) {
	s.depth++
	defer func() { s.depth-- }()
	if s.depth > 16 {
		return outcome{}, errors.New("script nesting limit reached")
	}
	var total outcome
	for _, stmt := range stmts {
		o, err := s.statement(stmt, input)
		total.out += o.out
		total.err += o.err
		total.status = o.status
		if len(total.out)+len(total.err) > maxOutput {
			return outcome{}, errors.New("output exceeded 64 KiB")
		}
		if err != nil {
			return total, err
		}
	}
	return total, nil
}
func (s *Shell) statement(stmt *syntax.Stmt, input string) (outcome, error) {
	if err := s.step(); err != nil {
		return outcome{}, err
	}
	target := ""
	appendMode := false
	for _, r := range stmt.Redirs {
		if r.N != nil || r.Hdoc != nil {
			return outcome{}, errors.New("only stdin <, stdout > and >> redirects are supported")
		}
		names, err := s.words([]*syntax.Word{r.Word})
		if err != nil {
			return outcome{}, err
		}
		if len(names) != 1 {
			return outcome{}, errors.New("redirect needs one file")
		}
		p, err := s.resolve(names[0])
		if err != nil {
			return outcome{}, err
		}
		switch r.Op {
		case syntax.RdrIn:
			v, ok := s.state.Files[p]
			if !ok {
				return outcome{}, fmt.Errorf("no such file: %s", p)
			}
			input = v
		case syntax.RdrOut, syntax.AppOut:
			target = p
			appendMode = r.Op == syntax.AppOut
		default:
			return outcome{}, errors.New("unsupported redirect")
		}
	}
	o, err := s.command(stmt.Cmd, input)
	if stmt.Negated {
		if o.status == 0 {
			o.status = 1
		} else {
			o.status = 0
		}
	}
	s.state.Vars["?"] = strconv.Itoa(o.status)
	if target != "" && err == nil {
		v := o.out
		if appendMode {
			v = s.state.Files[target] + v
		}
		if e := s.store(target, v); e != nil {
			return outcome{}, e
		}
		o.out = ""
	}
	s.emitted += len(o.out) + len(o.err)
	if s.emitted > maxOutput*4 {
		return outcome{}, errors.New("run output budget reached")
	}
	return o, err
}
func (s *Shell) command(cmd syntax.Command, input string) (outcome, error) {
	switch x := cmd.(type) {
	case nil:
		return outcome{}, nil
	case *syntax.CallExpr:
		// A command's arguments expand in the caller environment, before its
		// temporary prefix assignments are installed.
		var args []string
		if len(x.Args) > 0 {
			var err error
			args, err = s.words(x.Args)
			if err != nil {
				return outcome{}, err
			}
		}
		previous := map[string]string{}
		for k, v := range s.state.Vars {
			previous[k] = v
		}
		for _, a := range x.Assigns {
			if a.Name == nil || a.Array != nil || a.Index != nil || a.Append {
				return outcome{}, errors.New("unsupported assignment")
			}
			if a.Name.Value == "HOME" || a.Name.Value == "PWD" || a.Name.Value == "IFS" {
				s.state.Vars = previous
				return outcome{}, errors.New("HOME, PWD and IFS are reserved in this lab")
			}
			v := ""
			var e error
			if a.Value != nil {
				v, e = expand.Literal(s.config(), a.Value)
			}
			if e != nil {
				s.state.Vars = previous
				return outcome{}, e
			}
			if len(v) > 4096 {
				return outcome{}, errors.New("variable exceeds 4 KiB")
			}
			s.state.Vars[a.Name.Value] = v
		}
		if e := validateState(s.state); e != nil {
			s.state.Vars = previous
			return outcome{}, e
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
		return s.utility(args, input)
	case *syntax.BinaryCmd:
		left, e := s.statement(x.X, input)
		if e != nil {
			return left, e
		}
		switch x.Op {
		case syntax.Pipe:
			right, e := s.statement(x.Y, left.out)
			right.err = left.err + right.err
			return right, e
		case syntax.AndStmt:
			if left.status != 0 {
				return left, nil
			}
		case syntax.OrStmt:
			if left.status == 0 {
				return left, nil
			}
		default:
			return outcome{}, errors.New("unsupported operator")
		}
		right, e := s.statement(x.Y, input)
		right.out = left.out + right.out
		right.err = left.err + right.err
		return right, e
	case *syntax.Block:
		return s.statements(x.Stmts, input)
	case *syntax.IfClause:
		if len(x.Cond) == 0 {
			return s.statements(x.Then, input)
		}
		cond, e := s.statements(x.Cond, input)
		if e != nil {
			return cond, e
		}
		var body outcome
		if cond.status == 0 {
			body, e = s.statements(x.Then, input)
		} else if x.Else != nil {
			body, e = s.command(x.Else, input)
		}
		body.out = cond.out + body.out
		body.err = cond.err + body.err
		return body, e
	case *syntax.ForClause:
		loop, ok := x.Loop.(*syntax.WordIter)
		if !ok || !loop.InPos.IsValid() {
			return outcome{}, errors.New("for needs an explicit finite word list")
		}
		items, e := s.words(loop.Items)
		if e != nil {
			return outcome{}, e
		}
		var o outcome
		for _, v := range items {
			if e = s.step(); e != nil {
				return o, e
			}
			s.state.Vars[loop.Name.Value] = v
			r, e := s.statements(x.Do, input)
			o.out += r.out
			o.err += r.err
			o.status = r.status
			if e != nil {
				return o, e
			}
			if len(o.out)+len(o.err) > maxOutput {
				return outcome{}, errors.New("output limit reached")
			}
		}
		return o, nil
	case *syntax.WhileClause:
		var o outcome
		for {
			if e := s.step(); e != nil {
				return o, e
			}
			cond, e := s.statements(x.Cond, input)
			if e != nil {
				return o, e
			}
			o.out += cond.out
			o.err += cond.err
			if (cond.status == 0) == x.Until {
				return o, nil
			}
			r, e := s.statements(x.Do, input)
			o.out += r.out
			o.err += r.err
			o.status = r.status
			if e != nil {
				return o, e
			}
			if len(o.out)+len(o.err) > maxOutput {
				return outcome{}, errors.New("output limit reached")
			}
		}
	default:
		return outcome{}, errors.New("unsupported shell construct")
	}
}
func failure(message string) (outcome, error) { return outcome{err: message + "\n", status: 1}, nil }
func (s *Shell) contents(args []string, input string) (string, error) {
	if len(args) == 0 {
		return input, nil
	}
	var out strings.Builder
	for _, name := range args {
		p, e := s.resolve(name)
		if e != nil {
			return "", e
		}
		v, ok := s.state.Files[p]
		if !ok {
			return "", fmt.Errorf("no such file: %s", name)
		}
		if out.Len()+len(v) > maxOutput {
			return "", errors.New("input exceeds 64 KiB")
		}
		out.WriteString(v)
	}
	return out.String(), nil
}
func (s *Shell) utility(a []string, input string) (outcome, error) {
	cmd, args := a[0], a[1:]
	switch cmd {
	case "help":
		return outcome{out: help}, nil
	case "true", ":":
		return outcome{}, nil
	case "false":
		return outcome{status: 1}, nil
	case "pwd":
		if len(args) != 0 {
			return failure("pwd takes no arguments")
		}
		return outcome{out: s.state.Cwd + "\n"}, nil
	case "echo":
		return outcome{out: strings.Join(args, " ") + "\n"}, nil
	case "printf":
		if len(args) == 0 {
			return outcome{}, nil
		}
		format := strings.ReplaceAll(strings.ReplaceAll(args[0], `\n`, "\n"), `\t`, "\t")
		var b strings.Builder
		index := 1
		for i := 0; i < len(format); i++ {
			if format[i] != '%' {
				b.WriteByte(format[i])
				continue
			}
			i++
			if i >= len(format) {
				return failure("incomplete printf format")
			}
			if format[i] == '%' {
				b.WriteByte('%')
				continue
			}
			if format[i] != 's' && format[i] != 'd' {
				return failure("printf supports %s, %d and %% only")
			}
			v := ""
			if index < len(args) {
				v = args[index]
				index++
			}
			if format[i] == 'd' {
				if _, e := strconv.Atoi(v); e != nil {
					return failure("printf expected integer")
				}
			}
			b.WriteString(v)
		}
		return outcome{out: b.String()}, nil
	case "cd":
		if len(args) != 1 {
			return failure("cd needs one directory")
		}
		p, e := s.resolve(args[0])
		if e != nil {
			return outcome{}, e
		}
		if !s.state.Dirs[p] {
			return failure("no such directory")
		}
		s.state.Cwd = p
		return outcome{}, nil
	case "ls":
		if len(args) > 1 {
			return failure("ls supports one literal directory; flags/globs are unavailable")
		}
		name := "."
		if len(args) == 1 {
			name = args[0]
		}
		p, e := s.resolve(name)
		if e != nil {
			return outcome{}, e
		}
		if !s.state.Dirs[p] {
			return failure("no such directory")
		}
		items := []string{}
		for f := range s.state.Files {
			if path.Dir(f) == p {
				items = append(items, path.Base(f))
			}
		}
		for d := range s.state.Dirs {
			if d != p && path.Dir(d) == p {
				items = append(items, path.Base(d)+"/")
			}
		}
		sort.Strings(items)
		if len(items) == 0 {
			return outcome{}, nil
		}
		return outcome{out: strings.Join(items, "\n") + "\n"}, nil
	case "mkdir":
		if len(args) != 1 {
			return failure("mkdir needs one directory")
		}
		p, e := s.resolve(args[0])
		if e != nil {
			return outcome{}, e
		}
		if s.state.Dirs[p] || !s.state.Dirs[path.Dir(p)] {
			return failure("directory exists or parent is missing")
		}
		if _, ok := s.state.Files[p]; ok {
			return failure("a file exists there")
		}
		if len(s.state.Files)+len(s.state.Dirs) >= 128 {
			return failure("file/directory quota reached")
		}
		s.state.Dirs[p] = true
		return outcome{}, nil
	case "touch":
		if len(args) != 1 {
			return failure("touch needs one file")
		}
		p, e := s.resolve(args[0])
		if e != nil {
			return outcome{}, e
		}
		if _, ok := s.state.Files[p]; !ok {
			e = s.store(p, "")
		}
		return outcome{}, e
	case "cp", "mv":
		if len(args) != 2 {
			return failure(cmd + " needs two files")
		}
		from, e := s.resolve(args[0])
		if e != nil {
			return outcome{}, e
		}
		to, e := s.resolve(args[1])
		if e != nil {
			return outcome{}, e
		}
		v, ok := s.state.Files[from]
		if !ok {
			return failure("source file is missing")
		}
		if e = s.store(to, v); e != nil {
			return outcome{}, e
		}
		if cmd == "mv" && from != to {
			delete(s.state.Files, from)
		}
		return outcome{}, nil
	case "rm":
		if len(args) != 1 || strings.HasPrefix(args[0], "-") {
			return failure("rm supports one literal file, without flags")
		}
		p, e := s.resolve(args[0])
		if e != nil {
			return outcome{}, e
		}
		if _, ok := s.state.Files[p]; !ok {
			return failure("file is missing")
		}
		delete(s.state.Files, p)
		return outcome{}, nil
	case "test", "[":
		if cmd == "[" {
			if len(args) == 0 || args[len(args)-1] != "]" {
				return failure("missing ]")
			}
			args = args[:len(args)-1]
		}
		ok := false
		if len(args) == 1 {
			ok = args[0] != ""
		} else if len(args) == 2 {
			switch args[0] {
			case "-n":
				ok = args[1] != ""
			case "-z":
				ok = args[1] == ""
			case "-f", "-d":
				p, e := s.resolve(args[1])
				if e != nil {
					return outcome{}, e
				}
				if args[0] == "-f" {
					_, ok = s.state.Files[p]
				} else {
					ok = s.state.Dirs[p]
				}
			default:
				return failure("unsupported test")
			}
		} else if len(args) == 3 {
			switch args[1] {
			case "=":
				ok = args[0] == args[2]
			case "!=":
				ok = args[0] != args[2]
			default:
				return failure("test supports =, !=, -n, -z, -f and -d")
			}
		} else {
			return failure("unsupported test")
		}
		if ok {
			return outcome{}, nil
		}
		return outcome{status: 1}, nil
	case "sh":
		if len(args) != 1 {
			return failure("sh needs one lab script")
		}
		source, e := s.contents(args, "")
		if e != nil {
			return outcome{}, e
		}
		previous := s.state.Vars
		copied := map[string]string{}
		for k, v := range previous {
			copied[k] = v
		}
		cwd := s.state.Cwd
		s.state.Vars = copied
		defer func() { s.state.Vars = previous; s.state.Cwd = cwd }()
		return s.script(source, input)
	case "cat", "grep", "sort", "uniq", "wc", "head", "sha256sum":
		pattern := ""
		if cmd == "grep" {
			if len(args) == 0 {
				return failure("grep needs a literal substring")
			}
			pattern = args[0]
			args = args[1:]
			if strings.HasPrefix(pattern, "-") {
				return failure("grep accepts a literal substring, without flags")
			}
		}
		if cmd == "wc" {
			if len(args) == 0 || args[0] != "-l" {
				return failure("wc supports -l only")
			}
			args = args[1:]
		}
		data, e := s.contents(args, input)
		if e != nil {
			return outcome{}, e
		}
		switch cmd {
		case "cat":
			return outcome{out: data}, nil
		case "sha256sum":
			sum := sha256.Sum256([]byte(data))
			return outcome{out: hex.EncodeToString(sum[:]) + "\n"}, nil
		case "wc":
			return outcome{out: strconv.Itoa(strings.Count(data, "\n")) + "\n"}, nil
		}
		lines := strings.Split(strings.TrimSuffix(data, "\n"), "\n")
		if data == "" {
			lines = nil
		}
		switch cmd {
		case "grep":
			kept := []string{}
			for _, line := range lines {
				if strings.Contains(line, pattern) {
					kept = append(kept, line)
				}
			}
			lines = kept
			if len(lines) == 0 {
				return outcome{status: 1}, nil
			}
		case "sort":
			sort.Strings(lines)
		case "uniq":
			kept := []string{}
			for i, line := range lines {
				if i == 0 || line != lines[i-1] {
					kept = append(kept, line)
				}
			}
			lines = kept
		case "head":
			if len(lines) > 10 {
				lines = lines[:10]
			}
		}
		if len(lines) == 0 {
			return outcome{}, nil
		}
		return outcome{out: strings.Join(lines, "\n") + "\n"}, nil
	default:
		return outcome{err: cmd + ": unavailable in this local lab. No host process or network request was started. Type help.\n", status: 127}, nil
	}
}

const help = `GopherForge local DevOps shell
Real commands over your private /lab files. No host processes or network.
pwd, ls [dir], cd dir, mkdir dir, touch file, cp/mv source target, rm file
echo, printf (%s/%d/%%, \n/\t), cat [files], grep literal [files]
sort, uniq, wc -l, head (10 lines), sha256sum (input digest), test / [ ]
Variables, quotes, < > >>, finite pipelines, && ||, if, for-in, while, sh file.
No globbing, substitutions, functions, background jobs or arbitrary binaries.
Pipelines buffer up to 64 KiB; commands are not concurrent OS processes.
Limits: 16 KiB script, 256 steps, 16 nesting levels, 64 KiB/file/output,
128 files/directories, 2 MiB total. Each run starts fresh variables/cwd from
the saved lab state. No Docker, kubectl, SSH, sudo or package installation.
`
