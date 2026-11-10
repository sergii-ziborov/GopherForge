package main

// The commands. Each one works on the lab's State and the statement's stdin;
// none of them can name a host path, start a process or open a connection.
import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"path"
	"sort"
	"strconv"
	"strings"
	"time"
)

type utilityFunc func(s *Shell, cmd string, args []string, in *stream) (outcome, error)

var utilities map[string]utilityFunc

func init() {
	utilities = map[string]utilityFunc{
		"help": (*Shell).help, "man": (*Shell).help,
		"true":  func(*Shell, string, []string, *stream) (outcome, error) { return outcome{}, nil },
		":":     func(*Shell, string, []string, *stream) (outcome, error) { return outcome{}, nil },
		"false": func(*Shell, string, []string, *stream) (outcome, error) { return outcome{status: 1}, nil },
		"pwd":   (*Shell).pwd, "cd": (*Shell).cd, "ls": (*Shell).ls, "tree": (*Shell).tree, "find": (*Shell).find,
		"mkdir": (*Shell).mkdir, "rmdir": (*Shell).rmdir, "touch": (*Shell).touch, "cp": (*Shell).copyMove, "mv": (*Shell).copyMove,
		"rm": (*Shell).rm, "chmod": (*Shell).chmod, "du": (*Shell).du, "df": (*Shell).df,
		"echo": (*Shell).echo, "printf": (*Shell).printf, "cat": (*Shell).cat, "head": (*Shell).headTail, "tail": (*Shell).headTail,
		"wc": (*Shell).wc, "grep": (*Shell).grep, "egrep": (*Shell).grep, "fgrep": (*Shell).grep, "sed": (*Shell).sed, "awk": (*Shell).awk,
		"cut": (*Shell).cut, "tr": (*Shell).tr, "sort": (*Shell).sort, "uniq": (*Shell).uniq, "nl": (*Shell).nl, "rev": (*Shell).rev,
		"tee": (*Shell).tee, "xargs": (*Shell).xargs, "diff": (*Shell).diff, "basename": (*Shell).basename, "dirname": (*Shell).dirname,
		"realpath": (*Shell).realpath, "seq": (*Shell).seq, "date": (*Shell).date, "sleep": (*Shell).sleep,
		"env": (*Shell).env, "printenv": (*Shell).env, "set": (*Shell).set, "unset": (*Shell).unset, "shift": (*Shell).shift,
		"export": (*Shell).export, "readonly": (*Shell).export, "read": (*Shell).read,
		"test": (*Shell).test, "[": (*Shell).test, "sh": (*Shell).sh, "bash": (*Shell).sh, "source": (*Shell).source, ".": (*Shell).source,
		"eval": (*Shell).eval, "exit": (*Shell).control, "return": (*Shell).control, "break": (*Shell).control, "continue": (*Shell).control,
		"command": (*Shell).commandBuiltin, "type": (*Shell).typeBuiltin, "which": (*Shell).typeBuiltin,
		"whoami": (*Shell).identity, "id": (*Shell).identity, "hostname": (*Shell).identity, "uname": (*Shell).identity,
		"sha256sum": (*Shell).sha256sum, "base64": (*Shell).base64,
		"clear": func(*Shell, string, []string, *stream) (outcome, error) { return outcome{out: "\x1b[2J"}, nil },
	}
}

// Commands people reach for that a local lab cannot honestly provide, with
// the reason, so "command not found" never reads as a broken install.
var unavailable = map[string]string{
	"docker": "no container runtime runs here", "podman": "no container runtime runs here",
	"kubectl": "there is no cluster to talk to", "helm": "there is no cluster to talk to",
	"terraform": "no cloud provider is reachable", "ssh": "the lab has no network", "scp": "the lab has no network",
	"curl": "the lab has no network", "wget": "the lab has no network", "ping": "the lab has no network",
	"nc": "the lab has no network", "dig": "the lab has no network", "nslookup": "the lab has no network",
	"sudo": "you already own everything in /lab", "su": "you already own everything in /lab",
	"apt": "packages cannot be installed", "apt-get": "packages cannot be installed", "brew": "packages cannot be installed",
	"yum": "packages cannot be installed", "pip": "packages cannot be installed", "npm": "packages cannot be installed",
	"systemctl": "there are no services or processes", "service": "there are no services or processes",
	"ps": "commands here are not OS processes", "kill": "commands here are not OS processes", "top": "commands here are not OS processes",
	"jobs": "commands here are not OS processes", "bg": "commands here are not OS processes", "fg": "commands here are not OS processes",
	"exec": "commands here are not OS processes", "ln": "links are not modelled in /lab", "chown": "ownership is not modelled in /lab",
	"git": "use the Projects tab for Go repositories", "go": "use the Build tab to compile Go", "python": "only the shell runs here",
	"python3": "only the shell runs here", "node": "only the shell runs here",
	"history": "history is available at the interactive prompt", "nano": "type nano FILE at the prompt to open the editor",
	"vi": "type vi FILE at the prompt to open the editor", "vim": "type vim FILE at the prompt to open the editor",
}

func (s *Shell) utility(a []string, in *stream) (outcome, error) {
	cmd, args := a[0], a[1:]
	fn, ok := utilities[cmd]
	if !ok {
		reason := unavailable[cmd]
		if reason == "" {
			return outcome{err: cmd + ": command not found. Type help to see what this lab shell runs.\n", status: 127}, nil
		}
		return outcome{err: cmd + ": unavailable here: " + reason + ". Nothing was started.\n", status: 127}, nil
	}
	if len(args) == 1 && args[0] == "--help" && cmd != "echo" {
		return s.help("help", []string{cmd}, in)
	}
	return fn(s, cmd, args, in)
}

func failure(message string) (outcome, error) { return outcome{err: message + "\n", status: 1}, nil }
func fail(cmd, name string, err error) outcome {
	return outcome{err: cmd + ": " + name + ": " + err.Error() + "\n", status: 1}
}

var errHelp = errors.New("help")

// options splits leading short flags from operands. A letter followed by ':'
// in spec takes a value, attached (-n5) or separate (-n 5).
func options(cmd string, args []string, spec string) (map[byte]string, []string, error) {
	flags := map[byte]string{}
	i := 0
	for ; i < len(args); i++ {
		a := args[i]
		if a == "--" {
			i++
			break
		}
		if len(a) < 2 || a[0] != '-' {
			break
		}
		if a[1] == '-' {
			return nil, nil, fmt.Errorf("%s: unrecognized option '%s'. Type help %s", cmd, a, cmd)
		}
		for j := 1; j < len(a); j++ {
			c := a[j]
			k := strings.IndexByte(spec, c)
			if k < 0 {
				return nil, nil, fmt.Errorf("%s: invalid option -- '%c'. Type help %s", cmd, c, cmd)
			}
			if k+1 < len(spec) && spec[k+1] == ':' {
				v := a[j+1:]
				if v == "" {
					if i+1 >= len(args) {
						return nil, nil, fmt.Errorf("%s: option requires an argument -- '%c'", cmd, c)
					}
					i++
					v = args[i]
				}
				flags[c] = v
				break
			}
			flags[c] = "1"
		}
	}
	return flags, args[i:], nil
}
func optionFailure(err error) (outcome, error) {
	return outcome{err: err.Error() + "\n", status: 2}, nil
}

// read gathers the named files, or stdin when there are none.
func (s *Shell) read(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "rp:sn:t:")
	if err != nil {
		return optionFailure(err)
	}
	line, ok := in.line()
	if len(names) == 0 {
		names = []string{"REPLY"}
	}
	if f['r'] == "" {
		line = strings.ReplaceAll(line, "\\", "")
	}
	fields := strings.Fields(line)
	for i, name := range names {
		v := ""
		if i < len(fields) && i == len(names)-1 {
			v = strings.Join(fields[i:], " ")
		} else if i < len(fields) {
			v = fields[i]
		}
		if !validName(name) {
			return failure("read: '" + name + "': not a valid identifier")
		}
		if e := s.setVar(name, v); e != nil {
			return outcome{}, e
		}
	}
	return outcome{status: boolStatus(ok)}, nil
}

type source struct {
	name, data string
	err        error
}

// inputs gathers the named files, or stdin when there are none. A missing
// file is reported and skipped, as coreutils does.
func (s *Shell) inputs(names []string, in *stream) []source {
	if len(names) == 0 {
		return []source{{name: "-", data: in.rest()}}
	}
	var out []source
	for _, name := range names {
		if name == "-" {
			out = append(out, source{name: "-", data: in.rest()})
			continue
		}
		p, err := s.resolve(name)
		if err != nil {
			out = append(out, source{name: name, err: err})
			continue
		}
		if s.state.Dirs[p] {
			out = append(out, source{name: name, err: errors.New("Is a directory")})
			continue
		}
		v, ok := s.state.Files[p]
		if !ok {
			out = append(out, source{name: name, err: errors.New("No such file or directory")})
			continue
		}
		out = append(out, source{name: name, data: v})
	}
	return out
}
func splitLines(data string) []string {
	if data == "" {
		return nil
	}
	return strings.Split(strings.TrimSuffix(data, "\n"), "\n")
}
func joinLines(lines []string) string {
	if len(lines) == 0 {
		return ""
	}
	return strings.Join(lines, "\n") + "\n"
}

func (s *Shell) pwd(cmd string, args []string, in *stream) (outcome, error) {
	return outcome{out: s.state.Cwd + "\n"}, nil
}
func (s *Shell) cd(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) > 1 {
		return failure("cd: too many arguments")
	}
	target, show := "/lab", false
	if len(args) == 1 {
		target = args[0]
	}
	if target == "-" {
		target, show = s.state.Vars["OLDPWD"], true
		if target == "" {
			return failure("cd: OLDPWD not set")
		}
	}
	p, err := s.resolve(target)
	if err != nil {
		return fail(cmd, target, err), nil
	}
	if _, isFile := s.state.Files[p]; isFile {
		return fail(cmd, target, errors.New("Not a directory")), nil
	}
	if !s.state.Dirs[p] {
		return fail(cmd, target, errors.New("No such file or directory")), nil
	}
	old := s.state.Cwd
	s.state.Cwd = p
	if err := s.setVar("OLDPWD", old); err != nil {
		return outcome{}, err
	}
	if show {
		return outcome{out: p + "\n"}, nil
	}
	return outcome{}, nil
}

func perm(name string, dir bool) string {
	switch {
	case dir:
		return "drwxr-xr-x"
	case strings.HasSuffix(name, ".sh"):
		return "-rwxr-xr-x"
	}
	return "-rw-r--r--"
}
func human(n int) string {
	if n < 1024 {
		return strconv.Itoa(n)
	}
	v, units := float64(n), "KMG"
	for i := 0; i < len(units); i++ {
		v /= 1024
		if v < 1024 || i == len(units)-1 {
			if v < 10 {
				return fmt.Sprintf("%.1f%c", v, units[i])
			}
			return fmt.Sprintf("%.0f%c", v, units[i])
		}
	}
	return strconv.Itoa(n)
}

func (s *Shell) ls(cmd string, args []string, in *stream) (outcome, error) {
	f, operands, err := options(cmd, args, "laA1hRFpdrtSs")
	if err != nil {
		return optionFailure(err)
	}
	if len(operands) == 0 {
		operands = []string{"."}
	}
	long := f['l'] != ""
	entry := func(name, p string, dir bool) string {
		shown := name
		if dir && name != "." && name != ".." {
			shown += "/"
		}
		if !long {
			return shown
		}
		size := len(s.state.Files[p])
		if dir {
			size = 4096
		}
		sz := strconv.Itoa(size)
		if f['h'] != "" {
			sz = human(size)
		}
		return fmt.Sprintf("%s 1 lab lab %5s %s", perm(name, dir), sz, shown)
	}
	var out, errs strings.Builder
	status := 0
	var dirs []string
	var files []string
	for _, name := range operands {
		p, e := s.resolve(name)
		if e != nil {
			errs.WriteString("ls: cannot access '" + name + "': " + e.Error() + "\n")
			status = 2
			continue
		}
		if _, ok := s.state.Files[p]; ok || (f['d'] != "" && s.state.Dirs[p]) {
			files = append(files, entry(name, p, s.state.Dirs[p]))
		} else if s.state.Dirs[p] {
			dirs = append(dirs, name)
		} else {
			errs.WriteString("ls: cannot access '" + name + "': No such file or directory\n")
			status = 2
		}
	}
	if len(files) > 0 {
		out.WriteString(joinLines(files))
	}
	var listDir func(name string, header bool)
	listDir = func(name string, header bool) {
		p, _ := s.resolve(name)
		if header {
			if out.Len() > 0 {
				out.WriteString("\n")
			}
			out.WriteString(name + ":\n")
		}
		var lines []string
		if f['a'] != "" {
			lines = append(lines, entry(".", p, true), entry("..", path.Dir(p), true))
		}
		kids := s.children(p)
		if f['S'] != "" {
			sort.SliceStable(kids, func(i, j int) bool {
				return len(s.state.Files[path.Join(p, kids[i].name)]) > len(s.state.Files[path.Join(p, kids[j].name)])
			})
		}
		if f['r'] != "" {
			for i, j := 0, len(kids)-1; i < j; i, j = i+1, j-1 {
				kids[i], kids[j] = kids[j], kids[i]
			}
		}
		var sub []string
		for _, k := range kids {
			if strings.HasPrefix(k.name, ".") && f['a'] == "" && f['A'] == "" {
				continue
			}
			lines = append(lines, entry(k.name, path.Join(p, k.name), k.dir))
			if k.dir {
				sub = append(sub, strings.TrimSuffix(name, "/")+"/"+k.name)
			}
		}
		if long {
			out.WriteString("total " + strconv.Itoa(len(lines)) + "\n")
		}
		out.WriteString(joinLines(lines))
		if f['R'] != "" {
			for _, d := range sub {
				listDir(d, true)
			}
		}
	}
	for _, d := range dirs {
		listDir(d, len(dirs)+len(files) > 1 || f['R'] != "")
	}
	return outcome{out: out.String(), err: errs.String(), status: status}, nil
}

func (s *Shell) tree(cmd string, args []string, in *stream) (outcome, error) {
	f, operands, err := options(cmd, args, "adL:")
	if err != nil {
		return optionFailure(err)
	}
	if len(operands) == 0 {
		operands = []string{"."}
	}
	limit := 64
	if f['L'] != "" {
		if limit, err = strconv.Atoi(f['L']); err != nil || limit < 1 {
			return failure("tree: invalid level, must be greater than 0")
		}
	}
	var out strings.Builder
	dirs, files := 0, 0
	for _, name := range operands {
		p, e := s.resolve(name)
		if e != nil || !s.state.Dirs[p] {
			out.WriteString(name + " [error opening dir]\n")
			continue
		}
		out.WriteString(name + "\n")
		var walk func(p, prefix string, level int)
		walk = func(p, prefix string, level int) {
			var kids []child
			for _, k := range s.children(p) {
				if (f['a'] != "" || !strings.HasPrefix(k.name, ".")) && (f['d'] == "" || k.dir) {
					kids = append(kids, k)
				}
			}
			for i, k := range kids {
				branch, next := "├── ", "│   "
				if i == len(kids)-1 {
					branch, next = "└── ", "    "
				}
				shown := k.name
				if k.dir {
					shown += "/"
					dirs++
				} else {
					files++
				}
				out.WriteString(prefix + branch + shown + "\n")
				if k.dir && level < limit {
					walk(path.Join(p, k.name), prefix+next, level+1)
				}
			}
		}
		walk(p, "", 1)
	}
	plural := func(n int, word string) string {
		if n == 1 {
			return "1 " + word
		}
		if word == "directory" {
			return strconv.Itoa(n) + " directories"
		}
		return strconv.Itoa(n) + " " + word + "s"
	}
	out.WriteString("\n" + plural(dirs, "directory"))
	if f['d'] == "" {
		out.WriteString(", " + plural(files, "file"))
	}
	out.WriteString("\n")
	return outcome{out: out.String()}, nil
}

func (s *Shell) find(cmd string, args []string, in *stream) (outcome, error) {
	var starts []string
	i := 0
	for ; i < len(args) && !strings.HasPrefix(args[i], "-") && args[i] != "!" && args[i] != "("; i++ {
		starts = append(starts, args[i])
	}
	if len(starts) == 0 {
		starts = []string{"."}
	}
	type test func(name, p string, dir bool, depth int) bool
	var tests []test
	maxDepth, minDepth := 64, 0
	for ; i < len(args); i++ {
		a := args[i]
		value := func() (string, error) {
			if i+1 >= len(args) {
				return "", fmt.Errorf("find: missing argument to '%s'", a)
			}
			i++
			return args[i], nil
		}
		switch a {
		case "-name", "-iname":
			v, e := value()
			if e != nil {
				return failure(e.Error())
			}
			fold := a == "-iname"
			tests = append(tests, func(name, p string, dir bool, depth int) bool {
				if fold {
					ok, _ := path.Match(strings.ToLower(v), strings.ToLower(name))
					return ok
				}
				ok, _ := path.Match(v, name)
				return ok
			})
		case "-path":
			v, e := value()
			if e != nil {
				return failure(e.Error())
			}
			tests = append(tests, func(name, p string, dir bool, depth int) bool { return globMatch(v, p) })
		case "-type":
			v, e := value()
			if e != nil {
				return failure(e.Error())
			}
			if v != "f" && v != "d" {
				return failure("find: -type supports f and d here")
			}
			tests = append(tests, func(name, p string, dir bool, depth int) bool { return dir == (v == "d") })
		case "-maxdepth", "-mindepth":
			v, e := value()
			if e != nil {
				return failure(e.Error())
			}
			n, e := strconv.Atoi(v)
			if e != nil || n < 0 {
				return failure("find: " + a + ": expected a non-negative number")
			}
			if a == "-maxdepth" {
				maxDepth = n
			} else {
				minDepth = n
			}
		case "-empty":
			tests = append(tests, func(name, p string, dir bool, depth int) bool {
				if dir {
					return len(s.children(p)) == 0
				}
				return s.state.Files[p] == ""
			})
		case "-print":
		case "-exec", "-execdir", "-delete", "-ok":
			return failure("find: " + a + " is unavailable here; pipe the paths to xargs instead")
		default:
			return failure("find: unknown predicate '" + a + "'. Type help find")
		}
	}
	var out, errs strings.Builder
	status := 0
	for _, start := range starts {
		p, e := s.resolve(start)
		if e != nil || (!s.state.Dirs[p] && s.state.Files[p] == "" && !s.hasFile(p)) {
			errs.WriteString("find: '" + start + "': No such file or directory\n")
			status = 1
			continue
		}
		var walk func(shown, p string, dir bool, depth int)
		walk = func(shown, p string, dir bool, depth int) {
			ok := depth >= minDepth
			for _, t := range tests {
				ok = ok && t(path.Base(p), shown, dir, depth)
			}
			if ok {
				out.WriteString(shown + "\n")
			}
			if dir && depth < maxDepth {
				for _, k := range s.children(p) {
					walk(strings.TrimSuffix(shown, "/")+"/"+k.name, path.Join(p, k.name), k.dir, depth+1)
				}
			}
		}
		walk(start, p, s.state.Dirs[p], 0)
	}
	return outcome{out: out.String(), err: errs.String(), status: status}, nil
}
func (s *Shell) hasFile(p string) bool { _, ok := s.state.Files[p]; return ok }

func (s *Shell) mkdir(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "pv")
	if err != nil {
		return optionFailure(err)
	}
	if len(names) == 0 {
		return failure("mkdir: missing operand")
	}
	var o outcome
	for _, name := range names {
		p, e := s.resolve(name)
		if e != nil {
			o.err += "mkdir: cannot create directory '" + name + "': " + e.Error() + "\n"
			o.status = 1
			continue
		}
		var create []string
		for q := p; !s.state.Dirs[q]; q = path.Dir(q) {
			if s.hasFile(q) {
				create = nil
				o.err += "mkdir: cannot create directory '" + name + "': Not a directory\n"
				o.status = 1
				break
			}
			create = append([]string{q}, create...)
			if f['p'] == "" && len(create) > 1 {
				create = nil
				o.err += "mkdir: cannot create directory '" + name + "': No such file or directory\n"
				o.status = 1
				break
			}
		}
		if len(create) == 0 && s.state.Dirs[p] && f['p'] == "" {
			o.err += "mkdir: cannot create directory '" + name + "': File exists\n"
			o.status = 1
		}
		for _, q := range create {
			if len(s.state.Files)+len(s.state.Dirs) >= 128 {
				return outcome{}, errors.New("file/directory quota reached (128)")
			}
			s.state.Dirs[q] = true
			if f['v'] != "" {
				o.out += "mkdir: created directory '" + q + "'\n"
			}
		}
	}
	return o, nil
}
func (s *Shell) rmdir(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 {
		return failure("rmdir: missing operand")
	}
	var o outcome
	for _, name := range args {
		p, e := s.resolve(name)
		switch {
		case e != nil:
			o.err += "rmdir: failed to remove '" + name + "': " + e.Error() + "\n"
		case p == "/lab":
			o.err += "rmdir: failed to remove '" + name + "': it is the lab root\n"
		case !s.state.Dirs[p]:
			o.err += "rmdir: failed to remove '" + name + "': No such file or directory\n"
		case len(s.children(p)) > 0:
			o.err += "rmdir: failed to remove '" + name + "': Directory not empty\n"
		default:
			delete(s.state.Dirs, p)
			s.leave(p)
			continue
		}
		o.status = 1
	}
	return o, nil
}

// leave moves the working directory out of a directory that no longer exists.
func (s *Shell) leave(p string) {
	for !s.state.Dirs[s.state.Cwd] {
		s.state.Cwd = path.Dir(s.state.Cwd)
	}
}

func (s *Shell) touch(cmd string, args []string, in *stream) (outcome, error) {
	_, names, err := options(cmd, args, "acm")
	if err != nil {
		return optionFailure(err)
	}
	if len(names) == 0 {
		return failure("touch: missing file operand")
	}
	var o outcome
	for _, name := range names {
		p, e := s.resolve(name)
		if e != nil {
			o.err += "touch: cannot touch '" + name + "': " + e.Error() + "\n"
			o.status = 1
			continue
		}
		if s.hasFile(p) || s.state.Dirs[p] {
			continue
		}
		if !s.state.Dirs[path.Dir(p)] {
			o.err += "touch: cannot touch '" + name + "': No such file or directory\n"
			o.status = 1
			continue
		}
		if e := s.store(p, ""); e != nil {
			return outcome{}, e
		}
	}
	return o, nil
}

func (s *Shell) copyMove(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "rRfivn")
	if err != nil {
		return optionFailure(err)
	}
	if len(names) < 2 {
		return failure(cmd + ": missing destination file operand")
	}
	recursive := cmd == "mv" || f['r'] != "" || f['R'] != ""
	dest, err := s.resolve(names[len(names)-1])
	if err != nil {
		return fail(cmd, names[len(names)-1], err), nil
	}
	sources := names[:len(names)-1]
	intoDir := s.state.Dirs[dest]
	if len(sources) > 1 && !intoDir {
		return failure(cmd + ": target '" + names[len(names)-1] + "' is not a directory")
	}
	var o outcome
	for _, name := range sources {
		from, e := s.resolve(name)
		if e != nil {
			o = joinFailure(o, fail(cmd, name, e))
			continue
		}
		to := dest
		if intoDir {
			to = path.Join(dest, path.Base(from))
		}
		if from == to {
			o = joinFailure(o, outcome{err: cmd + ": '" + name + "' and '" + names[len(names)-1] + "' are the same file\n", status: 1})
			continue
		}
		if s.state.Dirs[from] {
			if !recursive {
				o = joinFailure(o, outcome{err: cmd + ": -r not specified; omitting directory '" + name + "'\n", status: 1})
				continue
			}
			if strings.HasPrefix(to+"/", from+"/") {
				o = joinFailure(o, outcome{err: cmd + ": cannot " + map[string]string{"cp": "copy", "mv": "move"}[cmd] + " a directory into itself\n", status: 1})
				continue
			}
			if from == "/lab" {
				o = joinFailure(o, outcome{err: cmd + ": cannot move the lab root\n", status: 1})
				continue
			}
			if e := s.copyTree(from, to, cmd == "mv"); e != nil {
				return outcome{}, e
			}
			continue
		}
		v, ok := s.state.Files[from]
		if !ok {
			o = joinFailure(o, fail(cmd, name, errors.New("No such file or directory")))
			continue
		}
		if !s.state.Dirs[path.Dir(to)] {
			o = joinFailure(o, fail(cmd, names[len(names)-1], errors.New("No such file or directory")))
			continue
		}
		if f['n'] != "" && s.hasFile(to) {
			continue
		}
		if e := s.store(to, v); e != nil {
			return outcome{}, e
		}
		if cmd == "mv" {
			delete(s.state.Files, from)
		}
		if f['v'] != "" {
			o.out += "'" + name + "' -> '" + to + "'\n"
		}
	}
	return o, nil
}
func joinFailure(o, more outcome) outcome {
	o.err += more.err
	if more.status != 0 {
		o.status = more.status
	}
	return o
}
func (s *Shell) copyTree(from, to string, move bool) error {
	if !s.state.Dirs[path.Dir(to)] {
		return errors.New("destination parent directory is missing")
	}
	if s.hasFile(to) {
		return errors.New("cannot overwrite a file with a directory")
	}
	var dirs, files []string
	for d := range s.state.Dirs {
		if d == from || strings.HasPrefix(d, from+"/") {
			dirs = append(dirs, d)
		}
	}
	for p := range s.state.Files {
		if strings.HasPrefix(p, from+"/") {
			files = append(files, p)
		}
	}
	saved := State{Files: copyMap(s.state.Files), Dirs: copyMap(s.state.Dirs), Vars: s.state.Vars, Cwd: s.state.Cwd, Funcs: s.state.Funcs}
	for _, d := range dirs {
		s.state.Dirs[to+strings.TrimPrefix(d, from)] = true
	}
	for _, p := range files {
		s.state.Files[to+strings.TrimPrefix(p, from)] = s.state.Files[p]
	}
	if move {
		for _, d := range dirs {
			delete(s.state.Dirs, d)
		}
		for _, p := range files {
			delete(s.state.Files, p)
		}
		if s.state.Cwd == from || strings.HasPrefix(s.state.Cwd, from+"/") {
			s.state.Cwd = to + strings.TrimPrefix(s.state.Cwd, from)
		}
	}
	if err := validateState(s.state); err != nil {
		s.state = saved
		return err
	}
	return nil
}

func (s *Shell) rm(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "rRfiv")
	if err != nil {
		return optionFailure(err)
	}
	if len(names) == 0 {
		if f['f'] != "" {
			return outcome{}, nil
		}
		return failure("rm: missing operand")
	}
	var o outcome
	for _, name := range names {
		p, e := s.resolve(name)
		if e != nil {
			o = joinFailure(o, outcome{err: "rm: cannot remove '" + name + "': " + e.Error() + "\n", status: 1})
			continue
		}
		base := path.Base(name)
		if base == "." || base == ".." || p == "/lab" {
			o = joinFailure(o, outcome{err: "rm: refusing to remove '" + name + "': it is the lab root or its parent\n", status: 1})
			continue
		}
		if s.state.Dirs[p] {
			if f['r'] == "" && f['R'] == "" {
				o = joinFailure(o, outcome{err: "rm: cannot remove '" + name + "': Is a directory\n", status: 1})
				continue
			}
			for d := range s.state.Dirs {
				if d == p || strings.HasPrefix(d, p+"/") {
					delete(s.state.Dirs, d)
				}
			}
			for q := range s.state.Files {
				if strings.HasPrefix(q, p+"/") {
					delete(s.state.Files, q)
				}
			}
			s.leave(p)
		} else if s.hasFile(p) {
			delete(s.state.Files, p)
		} else if f['f'] == "" {
			o = joinFailure(o, outcome{err: "rm: cannot remove '" + name + "': No such file or directory\n", status: 1})
			continue
		}
		if f['v'] != "" {
			o.out += "removed '" + name + "'\n"
		}
	}
	return o, nil
}
func (s *Shell) chmod(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) < 2 {
		return failure("chmod: missing operand")
	}
	var o outcome
	for _, name := range args[1:] {
		if p, e := s.resolve(name); e != nil || (!s.hasFile(p) && !s.state.Dirs[p]) {
			o = joinFailure(o, outcome{err: "chmod: cannot access '" + name + "': No such file or directory\n", status: 1})
		}
	}
	return o, nil
}
func (s *Shell) treeSize(p string) int {
	if v, ok := s.state.Files[p]; ok {
		return len(v)
	}
	n := 0
	for q, v := range s.state.Files {
		if strings.HasPrefix(q, p+"/") {
			n += len(v)
		}
	}
	return n
}
func (s *Shell) du(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "shac")
	if err != nil {
		return optionFailure(err)
	}
	if len(names) == 0 {
		names = []string{"."}
	}
	size := func(n int) string {
		if f['h'] != "" {
			return human(n)
		}
		return strconv.Itoa((n + 1023) / 1024)
	}
	var out strings.Builder
	for _, name := range names {
		p, e := s.resolve(name)
		if e != nil || (!s.state.Dirs[p] && !s.hasFile(p)) {
			return failure("du: cannot access '" + name + "': No such file or directory")
		}
		if f['s'] == "" && s.state.Dirs[p] {
			var dirs []string
			for d := range s.state.Dirs {
				if strings.HasPrefix(d, p+"/") {
					dirs = append(dirs, d)
				}
			}
			sort.Sort(sort.Reverse(sort.StringSlice(dirs)))
			for _, d := range dirs {
				out.WriteString(size(s.treeSize(d)) + "\t" + strings.TrimSuffix(name, "/") + strings.TrimPrefix(d, p) + "\n")
			}
		}
		out.WriteString(size(s.treeSize(p)) + "\t" + name + "\n")
	}
	return outcome{out: out.String()}, nil
}
func (s *Shell) df(cmd string, args []string, in *stream) (outcome, error) {
	used := s.treeSize("/lab")
	pct := used * 100 / maxTotal
	return outcome{out: fmt.Sprintf("Filesystem  Size  Used Avail Use%% Mounted on\nlab         %4s %5s %5s %3d%% /lab\n", human(maxTotal), human(used), human(maxTotal-used), pct)}, nil
}

// escapes interprets the backslash sequences of echo -e and printf.
func escapes(v string) (string, bool) {
	var b strings.Builder
	for i := 0; i < len(v); i++ {
		if v[i] != '\\' || i+1 >= len(v) {
			b.WriteByte(v[i])
			continue
		}
		i++
		switch v[i] {
		case 'n':
			b.WriteByte('\n')
		case 't':
			b.WriteByte('\t')
		case 'r':
			b.WriteByte('\r')
		case 'a':
			b.WriteByte('\a')
		case 'v':
			b.WriteByte('\v')
		case 'f':
			b.WriteByte('\f')
		case 'e':
			b.WriteByte(0x1b)
		case '\\':
			b.WriteByte('\\')
		case 'c':
			return b.String(), true
		case '0':
			n, j := 0, i+1
			for ; j < len(v) && j < i+4 && v[j] >= '0' && v[j] <= '7'; j++ {
				n = n*8 + int(v[j]-'0')
			}
			b.WriteByte(byte(n))
			i = j - 1
		default:
			b.WriteByte('\\')
			b.WriteByte(v[i])
		}
	}
	return b.String(), false
}

func (s *Shell) echo(cmd string, args []string, in *stream) (outcome, error) {
	newline, interpret := true, false
	for len(args) > 0 && len(args[0]) > 1 && args[0][0] == '-' && strings.Trim(args[0][1:], "neE") == "" {
		for _, c := range args[0][1:] {
			switch c {
			case 'n':
				newline = false
			case 'e':
				interpret = true
			case 'E':
				interpret = false
			}
		}
		args = args[1:]
	}
	out := strings.Join(args, " ")
	if interpret {
		var stop bool
		if out, stop = escapes(out); stop {
			newline = false
		}
	}
	if newline {
		out += "\n"
	}
	return outcome{out: out}, nil
}

func (s *Shell) printf(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) > 1 && args[0] == "-v" {
		o, err := s.printf(cmd, args[2:], in)
		if err == nil && o.status == 0 {
			if e := s.setVar(args[1], o.out); e != nil {
				return outcome{}, e
			}
			o.out = ""
		}
		return o, err
	}
	if len(args) == 0 {
		return failure("printf: usage: printf FORMAT [ARGUMENTS...]")
	}
	format, values := args[0], args[1:]
	var b strings.Builder
	for {
		used := 0
		for i := 0; i < len(format); i++ {
			c := format[i]
			if c == '\\' {
				j := i + 1
				for j < len(format) && j < i+2 {
					j++
				}
				v, _ := escapes(format[i:j])
				b.WriteString(v)
				i = j - 1
				continue
			}
			if c != '%' {
				b.WriteByte(c)
				continue
			}
			j := i + 1
			for j < len(format) && strings.IndexByte("-+ #0123456789.", format[j]) >= 0 {
				j++
			}
			if j >= len(format) {
				return failure("printf: missing format character")
			}
			spec, verb := format[i+1:j], format[j]
			i = j
			if verb == '%' {
				b.WriteByte('%')
				continue
			}
			arg := ""
			if used < len(values) {
				arg = values[used]
			}
			used++
			switch verb {
			case 's':
				b.WriteString(fmt.Sprintf("%"+spec+"s", arg))
			case 'b':
				v, _ := escapes(arg)
				b.WriteString(fmt.Sprintf("%"+spec+"s", v))
			case 'q':
				b.WriteString(strconv.Quote(arg))
			case 'c':
				if arg != "" {
					b.WriteString(arg[:1])
				}
			case 'd', 'i', 'u', 'x', 'X', 'o':
				n, err := strconv.ParseInt(strings.TrimSpace(orZero(arg)), 0, 64)
				if err != nil {
					if f, ferr := strconv.ParseFloat(strings.TrimSpace(arg), 64); ferr == nil {
						n = int64(f)
					} else {
						return failure("printf: " + arg + ": invalid number")
					}
				}
				v := verb
				if v == 'i' || v == 'u' {
					v = 'd'
				}
				b.WriteString(fmt.Sprintf("%"+spec+string(v), n))
			case 'f', 'F', 'e', 'E', 'g', 'G':
				n, err := strconv.ParseFloat(strings.TrimSpace(orZero(arg)), 64)
				if err != nil {
					return failure("printf: " + arg + ": invalid number")
				}
				b.WriteString(fmt.Sprintf("%"+spec+string(verb), n))
			default:
				return failure("printf: %" + string(verb) + ": invalid format character")
			}
		}
		if used == 0 || used >= len(values) {
			break
		}
		values = values[used:]
		if b.Len() > maxOutput {
			break
		}
	}
	return outcome{out: b.String()}, nil
}
func orZero(v string) string {
	if strings.TrimSpace(v) == "" {
		return "0"
	}
	return v
}

func (s *Shell) cat(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "nbAEs")
	if err != nil {
		return optionFailure(err)
	}
	var o outcome
	n := 0
	for _, src := range s.inputs(names, in) {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		if f['n'] == "" && f['b'] == "" && f['E'] == "" && f['A'] == "" {
			o.out += src.data
			continue
		}
		for _, line := range splitLines(src.data) {
			if f['E'] != "" || f['A'] != "" {
				line += "$"
			}
			if f['n'] != "" || (f['b'] != "" && line != "") {
				n++
				line = fmt.Sprintf("%6d\t%s", n, line)
			}
			o.out += line + "\n"
		}
		if len(o.out) > maxOutput {
			return outcome{}, errors.New("input exceeds 64 KiB")
		}
	}
	return o, nil
}

func (s *Shell) headTail(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) > 0 && len(args[0]) > 1 && args[0][0] == '-' {
		if _, err := strconv.Atoi(args[0][1:]); err == nil {
			args = append([]string{"-n", args[0][1:]}, args[1:]...)
		}
	}
	f, names, err := options(cmd, args, "n:c:fqv")
	if err != nil {
		return optionFailure(err)
	}
	if f['f'] != "" {
		return failure("tail: -f needs a live process; files here change only when your commands run")
	}
	count, fromStart := 10, false
	if v := f['n']; v != "" {
		fromStart = strings.HasPrefix(v, "+") && cmd == "tail"
		if count, err = strconv.Atoi(strings.TrimPrefix(v, "+")); err != nil {
			return failure(cmd + ": invalid number of lines: '" + v + "'")
		}
	}
	bytes := -1
	if v := f['c']; v != "" {
		if bytes, err = strconv.Atoi(v); err != nil || bytes < 0 {
			return failure(cmd + ": invalid number of bytes: '" + v + "'")
		}
	}
	var o outcome
	sources := s.inputs(names, in)
	for i, src := range sources {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		if len(sources) > 1 && f['q'] == "" || f['v'] != "" {
			if i > 0 {
				o.out += "\n"
			}
			o.out += "==> " + src.name + " <==\n"
		}
		if bytes >= 0 {
			v := src.data
			if bytes < len(v) {
				if cmd == "head" {
					v = v[:bytes]
				} else {
					v = v[len(v)-bytes:]
				}
			}
			o.out += v
			continue
		}
		lines := splitLines(src.data)
		switch {
		case cmd == "head" && count < 0:
			lines = lines[:max(0, len(lines)+count)]
		case cmd == "head":
			lines = lines[:min(len(lines), count)]
		case fromStart:
			lines = lines[min(len(lines), max(0, count-1)):]
		default:
			lines = lines[max(0, len(lines)-count):]
		}
		o.out += joinLines(lines)
	}
	return o, nil
}

func (s *Shell) wc(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "lwcm")
	if err != nil {
		return optionFailure(err)
	}
	if len(f) == 0 {
		f = map[byte]string{'l': "1", 'w': "1", 'c': "1"}
	}
	var o outcome
	var rows [][]int
	var labels []string
	total := make([]int, 3)
	for _, src := range s.inputs(names, in) {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		counts := []int{strings.Count(src.data, "\n"), len(strings.Fields(src.data)), len(src.data)}
		if f['m'] != "" {
			counts[2] = len([]rune(src.data))
		}
		for i := range counts {
			total[i] += counts[i]
		}
		rows = append(rows, counts)
		labels = append(labels, src.name)
	}
	if len(rows) > 1 {
		rows = append(rows, total)
		labels = append(labels, "total")
	}
	for i, counts := range rows {
		var fields []string
		for k, flag := range []byte{'l', 'w', 'c'} {
			if f[flag] != "" || (flag == 'c' && f['m'] != "") {
				fields = append(fields, strconv.Itoa(counts[k]))
			}
		}
		width := 0
		if len(fields) > 1 || len(rows) > 1 {
			width = 7
		}
		line := ""
		for k, v := range fields {
			if k > 0 {
				line += " "
			}
			line += fmt.Sprintf("%*s", width, v)
		}
		if labels[i] != "-" {
			line += " " + labels[i]
		}
		o.out += line + "\n"
	}
	return o, nil
}

func (s *Shell) cut(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "d:f:c:b:s")
	if err != nil {
		return optionFailure(err)
	}
	list, byChar := f['f'], false
	if list == "" {
		list, byChar = f['c']+f['b'], true
	}
	if list == "" {
		return failure("cut: you must specify a list of bytes, characters, or fields")
	}
	selected, err := ranges(list)
	if err != nil {
		return failure("cut: " + err.Error())
	}
	delim := "\t"
	if v, ok := f['d']; ok {
		if len([]rune(v)) != 1 {
			return failure("cut: the delimiter must be a single character")
		}
		delim = v
	}
	var o outcome
	for _, src := range s.inputs(names, in) {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		for _, line := range splitLines(src.data) {
			var parts []string
			if byChar {
				parts = strings.Split(line, "")
			} else {
				if !strings.Contains(line, delim) {
					if f['s'] == "" {
						o.out += line + "\n"
					}
					continue
				}
				parts = strings.Split(line, delim)
			}
			var kept []string
			for i, p := range parts {
				if selected(i + 1) {
					kept = append(kept, p)
				}
			}
			sep := delim
			if byChar {
				sep = ""
			}
			o.out += strings.Join(kept, sep) + "\n"
		}
	}
	return o, nil
}

// ranges parses a cut list such as 1,3-5,7-.
func ranges(list string) (func(int) bool, error) {
	type span struct{ from, to int }
	var spans []span
	for _, part := range strings.Split(list, ",") {
		from, to, dash := strings.Cut(part, "-")
		a, b := 1, 1<<30
		var err error
		if from != "" {
			if a, err = strconv.Atoi(from); err != nil || a < 1 {
				return nil, fmt.Errorf("invalid field value '%s'", part)
			}
		}
		if !dash {
			b = a
		} else if to != "" {
			if b, err = strconv.Atoi(to); err != nil || b < a {
				return nil, fmt.Errorf("invalid range '%s'", part)
			}
		}
		spans = append(spans, span{a, b})
	}
	return func(i int) bool {
		for _, sp := range spans {
			if i >= sp.from && i <= sp.to {
				return true
			}
		}
		return false
	}, nil
}

func (s *Shell) tr(cmd string, args []string, in *stream) (outcome, error) {
	f, sets, err := options(cmd, args, "dsc")
	if err != nil {
		return optionFailure(err)
	}
	if len(sets) == 0 || len(sets) > 2 || (f['d'] == "" && f['s'] == "" && len(sets) != 2) {
		return failure("tr: usage: tr [-d] [-s] SET1 [SET2]")
	}
	from := expandSet(sets[0])
	var to []rune
	if len(sets) == 2 {
		to = expandSet(sets[1])
	}
	member := func(set []rune, r rune) int {
		for i, c := range set {
			if c == r {
				return i
			}
		}
		return -1
	}
	data := in.rest()
	var b strings.Builder
	var last rune = -1
	squeeze := to
	if len(to) == 0 {
		squeeze = from
	}
	for _, r := range data {
		i := member(from, r)
		if f['c'] != "" {
			if i >= 0 {
				i = -1
			} else {
				i = 0
			}
		}
		if i >= 0 && f['d'] != "" {
			continue
		}
		if i >= 0 && len(to) > 0 && f['d'] == "" {
			if f['c'] != "" {
				r = to[len(to)-1]
			} else {
				r = to[min(i, len(to)-1)]
			}
		}
		if f['s'] != "" && r == last && member(squeeze, r) >= 0 {
			continue
		}
		b.WriteRune(r)
		last = r
	}
	return outcome{out: b.String()}, nil
}
func expandSet(v string) []rune {
	classes := map[string]string{
		"[:lower:]": "abcdefghijklmnopqrstuvwxyz", "[:upper:]": "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "[:digit:]": "0123456789",
		"[:space:]": " \t\n\r\v\f", "[:blank:]": " \t", "[:punct:]": "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
	}
	classes["[:alpha:]"] = classes["[:lower:]"] + classes["[:upper:]"]
	classes["[:alnum:]"] = classes["[:alpha:]"] + classes["[:digit:]"]
	for k, c := range classes {
		v = strings.ReplaceAll(v, k, c)
	}
	v, _ = escapes(v)
	r := []rune(v)
	var out []rune
	for i := 0; i < len(r); i++ {
		if i+2 < len(r) && r[i+1] == '-' && r[i] <= r[i+2] {
			for c := r[i]; c <= r[i+2]; c++ {
				out = append(out, c)
			}
			i += 2
			continue
		}
		out = append(out, r[i])
	}
	return out
}

func (s *Shell) sort(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "rnufk:t:hV")
	if err != nil {
		return optionFailure(err)
	}
	var o outcome
	var lines []string
	for _, src := range s.inputs(names, in) {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		lines = append(lines, splitLines(src.data)...)
	}
	key := func(line string) string { return line }
	if k := f['k']; k != "" {
		field, err := strconv.Atoi(strings.SplitN(strings.SplitN(k, ",", 2)[0], ".", 2)[0])
		if err != nil || field < 1 {
			return failure("sort: invalid key '" + k + "'")
		}
		key = func(line string) string {
			var parts []string
			if t := f['t']; t != "" {
				parts = strings.Split(line, t)
			} else {
				parts = strings.Fields(line)
			}
			if field <= len(parts) {
				return parts[field-1]
			}
			return ""
		}
	}
	number := func(v string) float64 {
		v = strings.TrimSpace(v)
		end := 0
		for end < len(v) && strings.IndexByte("+-.0123456789", v[end]) >= 0 {
			end++
		}
		n, _ := strconv.ParseFloat(v[:end], 64)
		return n
	}
	less := func(a, b string) bool {
		ka, kb := key(a), key(b)
		if f['f'] != "" {
			ka, kb = strings.ToLower(ka), strings.ToLower(kb)
		}
		if f['n'] != "" || f['h'] != "" {
			if na, nb := number(ka), number(kb); na != nb {
				return na < nb
			}
		} else if ka != kb {
			return ka < kb
		}
		return a < b
	}
	sort.SliceStable(lines, func(i, j int) bool {
		if f['r'] != "" {
			return less(lines[j], lines[i])
		}
		return less(lines[i], lines[j])
	})
	if f['u'] != "" {
		var kept []string
		for i, line := range lines {
			if i == 0 || key(line) != key(lines[i-1]) {
				kept = append(kept, line)
			}
		}
		lines = kept
	}
	o.out = joinLines(lines)
	return o, nil
}

func (s *Shell) uniq(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "cdui")
	if err != nil {
		return optionFailure(err)
	}
	var o outcome
	srcs := s.inputs(names[:min(len(names), 1)], in)
	if srcs[0].err != nil {
		return fail(cmd, srcs[0].name, srcs[0].err), nil
	}
	lines := splitLines(srcs[0].data)
	same := func(a, b string) bool {
		if f['i'] != "" {
			return strings.EqualFold(a, b)
		}
		return a == b
	}
	var kept []string
	for i := 0; i < len(lines); {
		j := i + 1
		for j < len(lines) && same(lines[j], lines[i]) {
			j++
		}
		n := j - i
		if (f['d'] == "" || n > 1) && (f['u'] == "" || n == 1) {
			if f['c'] != "" {
				kept = append(kept, fmt.Sprintf("%7d %s", n, lines[i]))
			} else {
				kept = append(kept, lines[i])
			}
		}
		i = j
	}
	o.out = joinLines(kept)
	return o, nil
}

func (s *Shell) nl(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "b:")
	if err != nil {
		return optionFailure(err)
	}
	var o outcome
	n := 0
	for _, src := range s.inputs(names, in) {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		for _, line := range splitLines(src.data) {
			if line == "" && f['b'] != "a" {
				o.out += "\n"
				continue
			}
			n++
			o.out += fmt.Sprintf("%6d\t%s\n", n, line)
		}
	}
	return o, nil
}
func (s *Shell) rev(cmd string, args []string, in *stream) (outcome, error) {
	var o outcome
	for _, src := range s.inputs(args, in) {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		for _, line := range splitLines(src.data) {
			r := []rune(line)
			for i, j := 0, len(r)-1; i < j; i, j = i+1, j-1 {
				r[i], r[j] = r[j], r[i]
			}
			o.out += string(r) + "\n"
		}
	}
	return o, nil
}

func (s *Shell) tee(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "a")
	if err != nil {
		return optionFailure(err)
	}
	data := in.rest()
	var o outcome
	for _, name := range names {
		p, e := s.resolve(name)
		if e != nil || s.state.Dirs[p] || !s.state.Dirs[path.Dir(p)] {
			o = joinFailure(o, outcome{err: "tee: " + name + ": No such file or directory\n", status: 1})
			continue
		}
		v := data
		if f['a'] != "" {
			v = s.state.Files[p] + data
		}
		if e := s.store(p, v); e != nil {
			return outcome{}, e
		}
	}
	o.out = data
	return o, nil
}

func (s *Shell) xargs(cmd string, args []string, in *stream) (outcome, error) {
	f, command, err := options(cmd, args, "n:I:0rt")
	if err != nil {
		return optionFailure(err)
	}
	if len(command) == 0 {
		command = []string{"echo"}
	}
	data := in.rest()
	var o outcome
	runOne := func(argv []string) error {
		if err := s.step(); err != nil {
			return err
		}
		if f['t'] != "" {
			o.err += strings.Join(argv, " ") + "\n"
		}
		r, err := s.invoke(argv, &stream{}, true)
		o.out += r.out
		o.err += r.err
		if r.status != 0 {
			o.status = 123
		}
		return err
	}
	if marker := f['I']; marker != "" {
		for _, line := range splitLines(data) {
			if strings.TrimSpace(line) == "" {
				continue
			}
			argv := make([]string, len(command))
			for i, a := range command {
				argv[i] = strings.ReplaceAll(a, marker, line)
			}
			if err := runOne(argv); err != nil {
				return o, err
			}
		}
		return o, nil
	}
	var items []string
	if f['0'] != "" {
		items = strings.Split(strings.TrimSuffix(data, "\x00"), "\x00")
	} else {
		items = strings.Fields(data)
	}
	if len(items) == 0 && f['r'] != "" {
		return o, nil
	}
	batch := len(items)
	if v := f['n']; v != "" {
		if batch, err = strconv.Atoi(v); err != nil || batch < 1 {
			return failure("xargs: invalid number for -n")
		}
	}
	if batch == 0 {
		batch = 1
	}
	for i := 0; i < len(items) || (i == 0 && len(items) == 0); i += batch {
		end := min(len(items), i+batch)
		if err := runOne(append(append([]string{}, command...), items[i:end]...)); err != nil {
			return o, err
		}
		if len(items) == 0 {
			break
		}
	}
	return o, nil
}

func (s *Shell) basename(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 || len(args) > 2 {
		return failure("basename: usage: basename NAME [SUFFIX]")
	}
	v := path.Base(args[0])
	if len(args) == 2 && v != args[1] {
		v = strings.TrimSuffix(v, args[1])
	}
	return outcome{out: v + "\n"}, nil
}
func (s *Shell) dirname(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 {
		return failure("dirname: missing operand")
	}
	var o outcome
	for _, a := range args {
		o.out += path.Dir(a) + "\n"
	}
	return o, nil
}
func (s *Shell) realpath(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 {
		return failure("realpath: missing operand")
	}
	var o outcome
	for _, a := range args {
		p, e := s.resolve(a)
		if e != nil {
			o = joinFailure(o, fail(cmd, a, e))
			continue
		}
		o.out += p + "\n"
	}
	return o, nil
}

func (s *Shell) seq(cmd string, args []string, in *stream) (outcome, error) {
	f, nums, err := options(cmd, args, "s:w")
	if err != nil && !(len(args) > 0 && strings.HasPrefix(args[0], "-") && isNumber(args[0])) {
		return optionFailure(err)
	}
	if err != nil {
		f, nums = map[byte]string{}, args
	}
	if len(nums) == 0 || len(nums) > 3 {
		return failure("seq: usage: seq [FIRST [INCREMENT]] LAST")
	}
	values := []float64{1, 1, 0}
	decimals := 0
	for i, v := range nums {
		n, e := strconv.ParseFloat(v, 64)
		if e != nil {
			return failure("seq: invalid floating point argument: '" + v + "'")
		}
		if dot := strings.IndexByte(v, '.'); dot >= 0 {
			decimals = max(decimals, len(v)-dot-1)
		}
		switch {
		case len(nums) == 1:
			values[2] = n
		case len(nums) == 2 && i == 0:
			values[0] = n
		case len(nums) == 2:
			values[2] = n
		default:
			values[i] = n
		}
	}
	first, step, last := values[0], values[1], values[2]
	if step == 0 {
		return failure("seq: invalid Zero increment value: '0'")
	}
	sep := "\n"
	if v, ok := f['s']; ok {
		sep, _ = escapes(v)
	}
	var out []string
	width := 0
	if f['w'] != "" {
		width = len(strconv.FormatFloat(last, 'f', decimals, 64))
	}
	for v := first; (step > 0 && v <= last+1e-9) || (step < 0 && v >= last-1e-9); v += step {
		if len(out) >= 10000 {
			return outcome{}, errors.New("seq stopped at 10000 numbers")
		}
		out = append(out, fmt.Sprintf("%0*s", width, strconv.FormatFloat(v, 'f', decimals, 64)))
	}
	if len(out) == 0 {
		return outcome{}, nil
	}
	return outcome{out: strings.Join(out, sep) + "\n"}, nil
}
func isNumber(v string) bool { _, err := strconv.ParseFloat(v, 64); return err == nil }

func (s *Shell) date(cmd string, args []string, in *stream) (outcome, error) {
	now := time.Now().UTC()
	format := "+%a %b %e %H:%M:%S %Z %Y"
	for _, a := range args {
		switch {
		case strings.HasPrefix(a, "+"):
			format = a
		case a == "-u" || a == "--utc":
		case a == "-I" || a == "--iso-8601":
			format = "+%F"
		case a == "-R":
			format = "+%a, %d %b %Y %H:%M:%S +0000"
		default:
			return failure("date: setting or parsing dates is unavailable; use +FORMAT")
		}
	}
	return outcome{out: strftime(format[1:], now) + "\n"}, nil
}
func strftime(format string, t time.Time) string {
	var b strings.Builder
	for i := 0; i < len(format); i++ {
		if format[i] != '%' || i+1 >= len(format) {
			b.WriteByte(format[i])
			continue
		}
		i++
		switch format[i] {
		case 'Y':
			b.WriteString(strconv.Itoa(t.Year()))
		case 'y':
			b.WriteString(fmt.Sprintf("%02d", t.Year()%100))
		case 'm':
			b.WriteString(fmt.Sprintf("%02d", int(t.Month())))
		case 'd':
			b.WriteString(fmt.Sprintf("%02d", t.Day()))
		case 'e':
			b.WriteString(fmt.Sprintf("%2d", t.Day()))
		case 'H':
			b.WriteString(fmt.Sprintf("%02d", t.Hour()))
		case 'M':
			b.WriteString(fmt.Sprintf("%02d", t.Minute()))
		case 'S':
			b.WriteString(fmt.Sprintf("%02d", t.Second()))
		case 's':
			b.WriteString(strconv.FormatInt(t.Unix(), 10))
		case 'F':
			b.WriteString(t.Format("2006-01-02"))
		case 'T':
			b.WriteString(t.Format("15:04:05"))
		case 'Z':
			b.WriteString("UTC")
		case 'z':
			b.WriteString("+0000")
		case 'a':
			b.WriteString(t.Format("Mon"))
		case 'A':
			b.WriteString(t.Format("Monday"))
		case 'b', 'h':
			b.WriteString(t.Format("Jan"))
		case 'B':
			b.WriteString(t.Format("January"))
		case 'j':
			b.WriteString(fmt.Sprintf("%03d", t.YearDay()))
		case 'u':
			b.WriteString(strconv.Itoa((int(t.Weekday())+6)%7 + 1))
		case 'n':
			b.WriteByte('\n')
		case 't':
			b.WriteByte('\t')
		case '%':
			b.WriteByte('%')
		default:
			b.WriteByte('%')
			b.WriteByte(format[i])
		}
	}
	return b.String()
}

func (s *Shell) sleep(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) != 1 {
		return failure("sleep: usage: sleep SECONDS")
	}
	v := args[0]
	scale := 1.0
	switch {
	case strings.HasSuffix(v, "m"):
		scale, v = 60, strings.TrimSuffix(v, "m")
	case strings.HasSuffix(v, "s"):
		v = strings.TrimSuffix(v, "s")
	}
	n, err := strconv.ParseFloat(v, 64)
	if err != nil || n < 0 {
		return failure("sleep: invalid time interval '" + args[0] + "'")
	}
	if n*scale > 10 {
		return failure("sleep: up to 10 seconds in this lab")
	}
	deadline := time.Now().Add(time.Duration(n * scale * float64(time.Second)))
	for time.Now().Before(deadline) {
		if s.stopped != nil && s.stopped() {
			return outcome{}, errors.New("stopped by user")
		}
		time.Sleep(min(50*time.Millisecond, time.Until(deadline)))
	}
	return outcome{}, nil
}

func (s *Shell) env(cmd string, args []string, in *stream) (outcome, error) {
	e := labEnv{s}
	if len(args) > 0 {
		if cmd == "printenv" {
			var o outcome
			for _, name := range args {
				if v := e.Get(name); v.IsSet() {
					o.out += v.Str + "\n"
				} else {
					o.status = 1
				}
			}
			return o, nil
		}
		return failure("env: running commands with a modified environment is unavailable; use NAME=value command")
	}
	var out strings.Builder
	for _, name := range e.names() {
		out.WriteString(name + "=" + e.Get(name).Str + "\n")
	}
	return outcome{out: out.String()}, nil
}
func (s *Shell) export(cmd string, args []string, in *stream) (outcome, error) {
	for _, a := range args {
		if strings.HasPrefix(a, "-") {
			continue
		}
		name, value, ok := strings.Cut(a, "=")
		if !validName(name) {
			return failure(cmd + ": '" + a + "': not a valid identifier")
		}
		if ok {
			if e := s.setVar(name, value); e != nil {
				return outcome{}, e
			}
		}
	}
	return outcome{}, nil
}
func (s *Shell) set(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 {
		var out strings.Builder
		for _, name := range (labEnv{s}).names() {
			out.WriteString(name + "=" + strconv.Quote(labEnv{s}.Get(name).Str) + "\n")
		}
		return outcome{out: out.String()}, nil
	}
	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--" {
			s.args = append([]string{}, args[i+1:]...)
			return outcome{}, nil
		}
		if len(a) < 2 || (a[0] != '-' && a[0] != '+') {
			s.args = append([]string{}, args[i:]...)
			return outcome{}, nil
		}
		on := a[0] == '-'
		for _, c := range a[1:] {
			switch c {
			case 'e':
				s.errexit = on
			case 'u':
				s.nounset = on
			case 'x':
				s.xtrace = on
			case 'o':
				if i+1 >= len(args) {
					return failure("set: -o needs an option name")
				}
				i++
				switch args[i] {
				case "pipefail":
					s.pipefail = on
				case "errexit":
					s.errexit = on
				case "nounset":
					s.nounset = on
				case "xtrace":
					s.xtrace = on
				default:
					return failure("set: " + args[i] + ": invalid option name")
				}
			case 'f', 'h', 'v', 'C', 'a', 'b', 'm', 'n':
			default:
				return failure("set: -" + string(c) + ": invalid option")
			}
		}
	}
	return outcome{}, nil
}
func (s *Shell) unset(cmd string, args []string, in *stream) (outcome, error) {
	functions := false
	for _, a := range args {
		switch a {
		case "-f":
			functions = true
		case "-v":
			functions = false
		default:
			if a == "HOME" || a == "PWD" || a == "IFS" {
				return failure("unset: " + a + ": cannot unset: reserved in this lab")
			}
			if functions {
				delete(s.state.Funcs, a)
			} else if _, ok := s.state.Vars[a]; ok {
				delete(s.state.Vars, a)
			} else {
				delete(s.state.Funcs, a)
			}
		}
	}
	return outcome{}, nil
}
func (s *Shell) shift(cmd string, args []string, in *stream) (outcome, error) {
	n := 1
	if len(args) == 1 {
		var err error
		if n, err = strconv.Atoi(args[0]); err != nil || n < 0 {
			return failure("shift: " + args[0] + ": numeric argument required")
		}
	}
	if n > len(s.args) {
		return outcome{status: 1}, nil
	}
	s.args = s.args[n:]
	return outcome{}, nil
}
func (s *Shell) control(cmd string, args []string, in *stream) (outcome, error) {
	n := 0
	if cmd == "break" || cmd == "continue" {
		n = 1
	}
	if cmd == "exit" || cmd == "return" {
		n, _ = strconv.Atoi(s.state.Vars["?"])
	}
	if len(args) > 0 {
		v, err := strconv.Atoi(args[0])
		if err != nil {
			return outcome{err: cmd + ": " + args[0] + ": numeric argument required\n", status: 2}, nil
		}
		n = v
	}
	if cmd == "exit" || cmd == "return" {
		return outcome{status: n & 255}, &flow{kind: cmd, status: n & 255}
	}
	if n < 1 {
		return failure(cmd + ": " + strconv.Itoa(n) + ": loop count out of range")
	}
	return outcome{}, &flow{kind: cmd, n: n}
}

// test implements the classic [ ] grammar over its arguments.
func (s *Shell) test(cmd string, args []string, in *stream) (outcome, error) {
	if cmd == "[" {
		if len(args) == 0 || args[len(args)-1] != "]" {
			return outcome{err: "[: missing ']'\n", status: 2}, nil
		}
		args = args[:len(args)-1]
	}
	p := &testParser{s: s, args: args}
	ok, err := p.or()
	if err == nil && p.i < len(args) {
		err = fmt.Errorf("%s: unexpected argument", args[p.i])
	}
	if err != nil {
		return outcome{err: cmd + ": " + err.Error() + "\n", status: 2}, nil
	}
	return outcome{status: boolStatus(ok)}, nil
}

type testParser struct {
	s    *Shell
	args []string
	i    int
}

func (p *testParser) peek() string {
	if p.i < len(p.args) {
		return p.args[p.i]
	}
	return ""
}
func (p *testParser) or() (bool, error) {
	left, err := p.and()
	for err == nil && p.peek() == "-o" {
		p.i++
		var right bool
		right, err = p.and()
		left = left || right
	}
	return left, err
}
func (p *testParser) and() (bool, error) {
	left, err := p.not()
	for err == nil && p.peek() == "-a" {
		p.i++
		var right bool
		right, err = p.not()
		left = left && right
	}
	return left, err
}
func (p *testParser) not() (bool, error) {
	if p.peek() == "!" && p.i+1 < len(p.args) {
		p.i++
		ok, err := p.not()
		return !ok, err
	}
	return p.primary()
}
func (p *testParser) primary() (bool, error) {
	if p.i >= len(p.args) {
		return false, nil
	}
	if p.peek() == "(" {
		p.i++
		ok, err := p.or()
		if p.peek() != ")" {
			return false, errors.New("missing ')'")
		}
		p.i++
		return ok, err
	}
	rest := len(p.args) - p.i
	if rest >= 3 && isBinaryTest(p.args[p.i+1]) {
		left, op, right := p.args[p.i], p.args[p.i+1], p.args[p.i+2]
		p.i += 3
		return binaryTest(op, left, right)
	}
	if rest >= 2 && len(p.peek()) == 2 && p.peek()[0] == '-' {
		op, v := p.args[p.i], p.args[p.i+1]
		p.i += 2
		return p.s.unaryTest(op, v)
	}
	v := p.args[p.i]
	p.i++
	return v != "", nil
}
func isBinaryTest(op string) bool {
	switch op {
	case "=", "==", "!=", "<", ">", "-eq", "-ne", "-lt", "-le", "-gt", "-ge":
		return true
	}
	return false
}

func (s *Shell) sh(cmd string, args []string, in *stream) (outcome, error) {
	restore := s.scope()
	defer restore()
	for len(args) > 0 && strings.HasPrefix(args[0], "-") && args[0] != "-c" {
		for _, c := range args[0][1:] {
			switch c {
			case 'e':
				s.errexit = true
			case 'x':
				s.xtrace = true
			case 'u':
				s.nounset = true
			default:
				return failure(cmd + ": -" + string(c) + ": invalid option")
			}
		}
		args = args[1:]
	}
	if len(args) > 0 && args[0] == "-c" {
		if len(args) < 2 {
			return failure(cmd + ": -c: option requires an argument")
		}
		name := cmd
		if len(args) > 2 {
			name = args[2]
		}
		var rest []string
		if len(args) > 3 {
			rest = args[3:]
		}
		return s.runScript(name, args[1], rest, in, true)
	}
	if len(args) == 0 {
		return s.runScript(cmd, in.rest(), nil, &stream{}, true)
	}
	p, err := s.resolve(args[0])
	if err != nil {
		return outcome{err: cmd + ": " + args[0] + ": " + err.Error() + "\n", status: 127}, nil
	}
	v, ok := s.state.Files[p]
	if !ok {
		return outcome{err: cmd + ": " + args[0] + ": No such file or directory\n", status: 127}, nil
	}
	return s.runScript(args[0], v, args[1:], in, true)
}
func (s *Shell) source(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 {
		return failure(cmd + ": filename argument required")
	}
	p, err := s.resolve(args[0])
	if err != nil {
		return fail(cmd, args[0], err), nil
	}
	v, ok := s.state.Files[p]
	if !ok {
		return fail(cmd, args[0], errors.New("No such file or directory")), nil
	}
	params := s.args
	if len(args) > 1 {
		params = args[1:]
	}
	return s.runScript(s.name, v, params, in, false)
}
func (s *Shell) eval(cmd string, args []string, in *stream) (outcome, error) {
	f, err := parse(strings.Join(args, " "))
	if err != nil {
		return outcome{err: "eval: " + err.Error() + "\n", status: 2}, nil
	}
	return s.statements(f.Stmts, in)
}

func (s *Shell) commandBuiltin(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) > 0 && (args[0] == "-v" || args[0] == "-V") {
		var o outcome
		for _, name := range args[1:] {
			if s.known(name) == "" {
				o.status = 1
				continue
			}
			if args[0] == "-v" {
				o.out += name + "\n"
			} else {
				o.out += name + " is " + s.known(name) + "\n"
			}
		}
		return o, nil
	}
	if len(args) == 0 {
		return outcome{}, nil
	}
	return s.invoke(args, in, false)
}
func (s *Shell) known(name string) string {
	if _, ok := s.state.Funcs[name]; ok {
		return "a function"
	}
	switch name {
	case "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "function", "in", "time", "[[", "]]", "!", "{", "}":
		return "a shell keyword"
	case "local", "declare", "typeset":
		return "a shell builtin"
	}
	if _, ok := utilities[name]; ok {
		return "a shell builtin"
	}
	return ""
}
func (s *Shell) typeBuiltin(cmd string, args []string, in *stream) (outcome, error) {
	var o outcome
	for _, name := range args {
		if strings.HasPrefix(name, "-") {
			continue
		}
		kind := s.known(name)
		switch {
		case kind == "":
			o = joinFailure(o, outcome{err: cmd + ": " + name + ": not found\n", status: 1})
		case cmd == "which" && kind == "a shell builtin":
			o.out += name + ": built into the lab shell\n"
		case cmd == "which":
			o.out += name + ": " + kind + "\n"
		default:
			o.out += name + " is " + kind + "\n"
		}
	}
	return o, nil
}

func (s *Shell) identity(cmd string, args []string, in *stream) (outcome, error) {
	switch cmd {
	case "whoami":
		return outcome{out: "lab\n"}, nil
	case "id":
		return outcome{out: "uid=1000(lab) gid=1000(lab) groups=1000(lab)\n"}, nil
	case "hostname":
		return outcome{out: "gopherforge\n"}, nil
	}
	f, _, err := options(cmd, args, "asnrmo")
	if err != nil {
		return optionFailure(err)
	}
	parts := []struct {
		flag  byte
		value string
	}{{'s', "GopherForge"}, {'n', "gopherforge"}, {'r', "1.0"}, {'m', "wasm32"}, {'o', "lab-shell"}}
	var out []string
	for _, p := range parts {
		if f[p.flag] != "" || f['a'] != "" || (len(f) == 0 && p.flag == 's') {
			out = append(out, p.value)
		}
	}
	return outcome{out: strings.Join(out, " ") + "\n"}, nil
}

// sha256sum prints the digest alone for a single input, which is what the
// guided labs record and check; several files get the usual digest and name.
func (s *Shell) sha256sum(cmd string, args []string, in *stream) (outcome, error) {
	var o outcome
	sources := s.inputs(args, in)
	for _, src := range sources {
		if src.err != nil {
			o = joinFailure(o, fail(cmd, src.name, src.err))
			continue
		}
		sum := sha256.Sum256([]byte(src.data))
		o.out += hex.EncodeToString(sum[:])
		if len(sources) > 1 {
			o.out += "  " + src.name
		}
		o.out += "\n"
	}
	return o, nil
}
func (s *Shell) base64(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "dw:i")
	if err != nil {
		return optionFailure(err)
	}
	srcs := s.inputs(names[:min(len(names), 1)], in)
	if srcs[0].err != nil {
		return fail(cmd, srcs[0].name, srcs[0].err), nil
	}
	if f['d'] != "" {
		v, err := base64.StdEncoding.DecodeString(strings.Join(strings.Fields(srcs[0].data), ""))
		if err != nil {
			return failure("base64: invalid input")
		}
		return outcome{out: string(v)}, nil
	}
	v := base64.StdEncoding.EncodeToString([]byte(srcs[0].data))
	wrap := 76
	if w := f['w']; w != "" {
		if wrap, err = strconv.Atoi(w); err != nil || wrap < 0 {
			return failure("base64: invalid wrap size")
		}
	}
	var lines []string
	for wrap > 0 && len(v) > wrap {
		lines, v = append(lines, v[:wrap]), v[wrap:]
	}
	lines = append(lines, v)
	return outcome{out: strings.Join(lines, "\n") + "\n"}, nil
}
