package main

// grep, sed and diff. Patterns compile to Go's RE2, whose matching time is
// linear in the input, so no pattern can stall the lab.
import (
	"errors"
	"fmt"
	"path"
	"regexp"
	"strconv"
	"strings"
)

var regexpCache = map[string]*regexp.Regexp{}

func compileRegexp(expr string) (*regexp.Regexp, error) {
	if re, ok := regexpCache[expr]; ok {
		return re, nil
	}
	if len(expr) > 2048 {
		return nil, errors.New("pattern is too long")
	}
	re, err := regexp.Compile(expr)
	if err != nil {
		return nil, fmt.Errorf("invalid pattern: %v", strings.TrimPrefix(err.Error(), "error parsing regexp: "))
	}
	if len(regexpCache) < 128 {
		regexpCache[expr] = re
	}
	return re, nil
}

// breToRE2 rewrites a POSIX basic regular expression, where ( ) { } | + ?
// are literal unless escaped, into RE2's extended syntax.
func breToRE2(p string) string {
	var b strings.Builder
	for i := 0; i < len(p); i++ {
		c := p[i]
		switch {
		case c == '\\' && i+1 < len(p):
			i++
			if strings.IndexByte("(){}|+?", p[i]) >= 0 {
				b.WriteByte(p[i])
			} else {
				b.WriteByte('\\')
				b.WriteByte(p[i])
			}
		case strings.IndexByte("(){}|+?", c) >= 0:
			b.WriteByte('\\')
			b.WriteByte(c)
		case c == '*' && (b.Len() == 0 || strings.HasSuffix(b.String(), "^") || strings.HasSuffix(b.String(), "(")):
			b.WriteString(`\*`)
		case c == '[':
			j := i + 1
			if j < len(p) && p[j] == '^' {
				j++
			}
			if j < len(p) && p[j] == ']' {
				j++
			}
			for j < len(p) && p[j] != ']' {
				if p[j] == '[' && j+1 < len(p) && p[j+1] == ':' {
					if end := strings.Index(p[j+2:], ":]"); end >= 0 {
						j += end + 4
						continue
					}
				}
				j++
			}
			if j >= len(p) {
				b.WriteString(`\[`)
				continue
			}
			b.WriteString(p[i : j+1])
			i = j
		default:
			b.WriteByte(c)
		}
	}
	return b.String()
}

func (s *Shell) grep(cmd string, args []string, in *stream) (outcome, error) {
	f, operands, err := options(cmd, args, "ivnclLqEFwxorRhHse:m:")
	if err != nil {
		return optionFailure(err)
	}
	extended, fixed := f['E'] != "" || cmd == "egrep", f['F'] != "" || cmd == "fgrep"
	var patterns []string
	if e, ok := f['e']; ok {
		patterns = append(patterns, e)
	} else {
		if len(operands) == 0 {
			return outcome{err: "grep: usage: grep [OPTION]... PATTERN [FILE]...\n", status: 2}, nil
		}
		patterns = append(patterns, strings.Split(operands[0], "\n")...)
		operands = operands[1:]
	}
	for i, p := range patterns {
		switch {
		case fixed:
			p = regexp.QuoteMeta(p)
		case !extended:
			p = breToRE2(p)
		}
		if f['w'] != "" {
			p = `\b(?:` + p + `)\b`
		}
		if f['x'] != "" {
			p = `^(?:` + p + `)$`
		}
		patterns[i] = "(?:" + p + ")"
	}
	expr := strings.Join(patterns, "|")
	if f['i'] != "" {
		expr = "(?i)" + expr
	}
	re, err := compileRegexp(expr)
	if err != nil {
		return outcome{err: "grep: " + err.Error() + "\n", status: 2}, nil
	}
	limit := -1
	if v := f['m']; v != "" {
		if limit, err = strconv.Atoi(v); err != nil {
			return outcome{err: "grep: invalid max count\n", status: 2}, nil
		}
	}
	recursive := f['r'] != "" || f['R'] != ""
	if recursive && len(operands) == 0 {
		operands = []string{"."}
	}
	var sources []source
	for _, name := range operands {
		p, e := s.resolve(name)
		if recursive && e == nil && s.state.Dirs[p] {
			for _, file := range sortedKeys(s.state.Files) {
				if strings.HasPrefix(file, p+"/") {
					shown := path.Join(name, strings.TrimPrefix(file, p+"/"))
					if name == "." {
						shown = strings.TrimPrefix(file, p+"/")
					}
					sources = append(sources, source{name: shown, data: s.state.Files[file]})
				}
			}
			continue
		}
		sources = append(sources, s.inputs([]string{name}, in)...)
	}
	if len(operands) == 0 {
		sources = s.inputs(nil, in)
	}
	prefix := (len(sources) > 1 || recursive) && f['h'] == ""
	if f['H'] != "" {
		prefix = true
	}
	var o outcome
	matched, failed := false, false
	for _, src := range sources {
		if src.err != nil {
			if f['s'] == "" {
				o.err += "grep: " + src.name + ": " + src.err.Error() + "\n"
			}
			failed = true
			continue
		}
		count := 0
		for n, line := range splitLines(src.data) {
			if limit >= 0 && count >= limit {
				break
			}
			if re.MatchString(line) == (f['v'] != "") {
				continue
			}
			count++
			matched = true
			if f['q'] != "" || f['c'] != "" || f['l'] != "" || f['L'] != "" {
				continue
			}
			lead := ""
			if prefix {
				lead = src.name + ":"
			}
			if f['n'] != "" {
				lead += strconv.Itoa(n+1) + ":"
			}
			if f['o'] != "" && f['v'] == "" {
				for _, m := range re.FindAllString(line, -1) {
					if m != "" {
						o.out += lead + m + "\n"
					}
				}
				continue
			}
			o.out += lead + line + "\n"
			if len(o.out) > maxOutput {
				return outcome{}, errors.New("output exceeded 64 KiB")
			}
		}
		switch {
		case f['c'] != "" && prefix:
			o.out += src.name + ":" + strconv.Itoa(count) + "\n"
		case f['c'] != "":
			o.out += strconv.Itoa(count) + "\n"
		case f['l'] != "" && count > 0, f['L'] != "" && count == 0:
			o.out += src.name + "\n"
		}
	}
	if f['q'] != "" {
		o.out = ""
	}
	switch {
	case failed && !(matched && f['q'] != ""):
		o.status = 2
	case !matched:
		o.status = 1
	}
	return o, nil
}

type sedAddress struct {
	line int
	last bool
	re   *regexp.Regexp
}
type sedCommand struct {
	from, to *sedAddress
	negate   bool
	op       byte
	re       *regexp.Regexp
	repl     string
	global   bool
	nth      int
	print    bool
	text     string
	src, dst []rune
	active   bool
}

func (s *Shell) sed(cmd string, args []string, in *stream) (outcome, error) {
	f, operands, err := options(cmd, args, "nErie:s")
	if err != nil {
		return optionFailure(err)
	}
	script, hasScript := f['e']
	if !hasScript {
		if len(operands) == 0 {
			return failure("sed: usage: sed [-n] [-E] [-i] SCRIPT [FILE]...")
		}
		script, operands = operands[0], operands[1:]
	}
	commands, err := parseSed(script, f['E'] != "" || f['r'] != "")
	if err != nil {
		return failure("sed: " + err.Error())
	}
	var o outcome
	if f['i'] != "" {
		if len(operands) == 0 {
			return failure("sed: -i needs at least one file")
		}
		for _, name := range operands {
			src := s.inputs([]string{name}, in)[0]
			if src.err != nil {
				o = joinFailure(o, outcome{err: "sed: can't read " + name + ": " + src.err.Error() + "\n", status: 2})
				continue
			}
			out := runSed(commands, src.data, f['n'] != "")
			p, _ := s.resolve(name)
			if e := s.store(p, out); e != nil {
				return outcome{}, e
			}
		}
		return o, nil
	}
	var data strings.Builder
	for _, src := range s.inputs(operands, in) {
		if src.err != nil {
			o = joinFailure(o, outcome{err: "sed: can't read " + src.name + ": " + src.err.Error() + "\n", status: 2})
			continue
		}
		data.WriteString(src.data)
	}
	o.out = runSed(commands, data.String(), f['n'] != "")
	return o, nil
}

func parseSed(script string, extended bool) ([]*sedCommand, error) {
	compile := func(p string) (*regexp.Regexp, error) {
		if !extended {
			p = breToRE2(p)
		}
		return compileRegexp(p)
	}
	var commands []*sedCommand
	i := 0
	skip := func() {
		for i < len(script) && strings.IndexByte(" \t\n;", script[i]) >= 0 {
			i++
		}
	}
	delimited := func(delim byte) (string, error) {
		var b strings.Builder
		for i < len(script) && script[i] != delim {
			if script[i] == '\\' && i+1 < len(script) {
				if script[i+1] == delim {
					b.WriteByte(delim)
				} else if script[i+1] == 'n' {
					b.WriteString("\\n")
				} else {
					b.WriteByte('\\')
					b.WriteByte(script[i+1])
				}
				i += 2
				continue
			}
			b.WriteByte(script[i])
			i++
		}
		if i >= len(script) {
			return "", errors.New("unterminated command")
		}
		i++
		return b.String(), nil
	}
	address := func() (*sedAddress, error) {
		switch {
		case i < len(script) && script[i] == '$':
			i++
			return &sedAddress{last: true}, nil
		case i < len(script) && script[i] >= '0' && script[i] <= '9':
			j := i
			for j < len(script) && script[j] >= '0' && script[j] <= '9' {
				j++
			}
			n, _ := strconv.Atoi(script[i:j])
			i = j
			return &sedAddress{line: n}, nil
		case i < len(script) && script[i] == '/':
			i++
			p, err := delimited('/')
			if err != nil {
				return nil, err
			}
			re, err := compile(p)
			if err != nil {
				return nil, err
			}
			return &sedAddress{re: re}, nil
		}
		return nil, nil
	}
	for skip(); i < len(script); skip() {
		c := &sedCommand{}
		var err error
		if c.from, err = address(); err != nil {
			return nil, err
		}
		if c.from != nil && i < len(script) && script[i] == ',' {
			i++
			if c.to, err = address(); err != nil || c.to == nil {
				return nil, errors.New("unexpected ','")
			}
		}
		for i < len(script) && script[i] == ' ' {
			i++
		}
		if i < len(script) && script[i] == '!' {
			c.negate = true
			i++
		}
		if i >= len(script) {
			return nil, errors.New("missing command")
		}
		c.op = script[i]
		i++
		switch c.op {
		case 's':
			if i >= len(script) {
				return nil, errors.New("unterminated `s' command")
			}
			delim := script[i]
			i++
			pat, err := delimited(delim)
			if err != nil {
				return nil, errors.New("unterminated `s' command")
			}
			if c.repl, err = delimited(delim); err != nil {
				return nil, errors.New("unterminated `s' command")
			}
			fold := false
			for i < len(script) && strings.IndexByte("gpiI0123456789", script[i]) >= 0 {
				switch ch := script[i]; {
				case ch == 'g':
					c.global = true
				case ch == 'p':
					c.print = true
				case ch == 'i' || ch == 'I':
					fold = true
				default:
					c.nth = c.nth*10 + int(ch-'0')
				}
				i++
			}
			if fold {
				pat = "(?i)" + pat
			}
			if c.re, err = compile(pat); err != nil {
				return nil, err
			}
		case 'y':
			delim := script[i]
			i++
			a, err := delimited(delim)
			if err != nil {
				return nil, err
			}
			b, err := delimited(delim)
			if err != nil {
				return nil, err
			}
			if c.src, c.dst = []rune(a), []rune(b); len(c.src) != len(c.dst) {
				return nil, errors.New("strings for `y' command are different lengths")
			}
		case 'a', 'i', 'c':
			if i < len(script) && script[i] == '\\' {
				i++
			}
			for i < len(script) && (script[i] == ' ' || script[i] == '\n') {
				i++
			}
			end := strings.IndexByte(script[i:], '\n')
			if end < 0 {
				end = len(script) - i
			}
			c.text, i = script[i:i+end], i+end
		case 'd', 'p', 'q', '=', 'n':
		default:
			return nil, fmt.Errorf("unknown command: `%c'", c.op)
		}
		commands = append(commands, c)
	}
	return commands, nil
}

func runSed(commands []*sedCommand, data string, quiet bool) string {
	lines := splitLines(data)
	var out strings.Builder
	matches := func(a *sedAddress, n int, line string) bool {
		switch {
		case a.last:
			return n == len(lines)
		case a.re != nil:
			return a.re.MatchString(line)
		}
		return a.line == n
	}
	for n := 1; n <= len(lines); n++ {
		line := lines[n-1]
		deleted, quit := false, false
		var after []string
		for _, c := range commands {
			selected := true
			switch {
			case c.from == nil:
			case c.to == nil:
				selected = matches(c.from, n, line)
			case c.active:
				selected = true
				if matches(c.to, n, line) || (c.to.line > 0 && n >= c.to.line) {
					c.active = false
				}
			default:
				selected = matches(c.from, n, line)
				if selected && !(c.to.line > 0 && n >= c.to.line) {
					c.active = true
				}
			}
			if selected == c.negate {
				continue
			}
			switch c.op {
			case 's':
				var b strings.Builder
				last, count, did := 0, 0, false
				for _, m := range c.re.FindAllStringSubmatchIndex(line, -1) {
					count++
					first := c.nth == 0 && (c.global || count == 1)
					nth := c.nth > 0 && (count == c.nth || (c.global && count > c.nth))
					if !first && !nth {
						continue
					}
					b.WriteString(line[last:m[0]])
					b.WriteString(sedReplacement(c.repl, line, m))
					last = m[1]
					did = true
				}
				if did {
					b.WriteString(line[last:])
					line = b.String()
					if c.print {
						out.WriteString(line + "\n")
					}
				}
			case 'y':
				r := []rune(line)
				for k, ch := range r {
					for j, from := range c.src {
						if ch == from {
							r[k] = c.dst[j]
							break
						}
					}
				}
				line = string(r)
			case 'd':
				deleted = true
			case 'p':
				out.WriteString(line + "\n")
			case '=':
				out.WriteString(strconv.Itoa(n) + "\n")
			case 'a':
				after = append(after, c.text)
			case 'i':
				out.WriteString(c.text + "\n")
			case 'c':
				out.WriteString(c.text + "\n")
				deleted = true
			case 'q':
				quit = true
			case 'n':
				if !quiet {
					out.WriteString(line + "\n")
				}
				if n < len(lines) {
					n++
					line = lines[n-1]
				}
			}
			if deleted || quit {
				break
			}
		}
		if !deleted && !quiet {
			out.WriteString(line + "\n")
		}
		for _, a := range after {
			out.WriteString(a + "\n")
		}
		if quit || out.Len() > maxOutput {
			break
		}
	}
	return out.String()
}

func sedReplacement(repl, line string, m []int) string {
	var b strings.Builder
	for i := 0; i < len(repl); i++ {
		c := repl[i]
		switch {
		case c == '&':
			b.WriteString(line[m[0]:m[1]])
		case c == '\\' && i+1 < len(repl):
			i++
			switch d := repl[i]; {
			case d >= '1' && d <= '9':
				k := int(d - '0')
				if 2*k+1 < len(m) && m[2*k] >= 0 {
					b.WriteString(line[m[2*k]:m[2*k+1]])
				}
			case d == 'n':
				b.WriteByte('\n')
			case d == 't':
				b.WriteByte('\t')
			default:
				b.WriteByte(d)
			}
		default:
			b.WriteByte(c)
		}
	}
	return b.String()
}

func (s *Shell) diff(cmd string, args []string, in *stream) (outcome, error) {
	f, names, err := options(cmd, args, "uqU:")
	if err != nil {
		return optionFailure(err)
	}
	if len(names) != 2 {
		return outcome{err: "diff: usage: diff [-u] FILE1 FILE2\n", status: 2}, nil
	}
	srcs := s.inputs(names, in)
	for _, src := range srcs {
		if src.err != nil {
			return outcome{err: "diff: " + src.name + ": " + src.err.Error() + "\n", status: 2}, nil
		}
	}
	a, b := splitLines(srcs[0].data), splitLines(srcs[1].data)
	if srcs[0].data == srcs[1].data {
		return outcome{}, nil
	}
	if f['q'] != "" {
		return outcome{out: "Files " + names[0] + " and " + names[1] + " differ\n", status: 1}, nil
	}
	if len(a) > 1000 || len(b) > 1000 {
		return outcome{err: "diff: files longer than 1000 lines are unavailable here\n", status: 2}, nil
	}
	// lcs[i][j] is the longest common subsequence of a[i:] and b[j:].
	lcs := make([][]uint16, len(a)+1)
	for i := range lcs {
		lcs[i] = make([]uint16, len(b)+1)
	}
	for i := len(a) - 1; i >= 0; i-- {
		for j := len(b) - 1; j >= 0; j-- {
			if a[i] == b[j] {
				lcs[i][j] = lcs[i+1][j+1] + 1
			} else {
				lcs[i][j] = max(lcs[i+1][j], lcs[i][j+1])
			}
		}
	}
	type op struct {
		kind byte
		i, j int
	}
	var ops []op
	for i, j := 0, 0; i < len(a) || j < len(b); {
		switch {
		case i < len(a) && j < len(b) && a[i] == b[j]:
			ops = append(ops, op{'=', i, j})
			i, j = i+1, j+1
		case i < len(a) && (j == len(b) || lcs[i+1][j] >= lcs[i][j+1]):
			ops = append(ops, op{'-', i, j})
			i++
		default:
			ops = append(ops, op{'+', i, j})
			j++
		}
	}
	var out strings.Builder
	span := func(from, to int) string {
		if to-from <= 1 {
			return strconv.Itoa(max(from, to))
		}
		return strconv.Itoa(from+1) + "," + strconv.Itoa(to)
	}
	if f['u'] != "" || f['U'] != "" {
		context := 3
		if v := f['U']; v != "" {
			context, _ = strconv.Atoi(v)
		}
		out.WriteString("--- " + names[0] + "\n+++ " + names[1] + "\n")
		for k := 0; k < len(ops); {
			if ops[k].kind == '=' {
				k++
				continue
			}
			start, end := max(0, k-context), k
			for {
				for end < len(ops) && ops[end].kind != '=' {
					end++
				}
				run := end
				for run < len(ops) && ops[run].kind == '=' {
					run++
				}
				if run == len(ops) || run-end > 2*context {
					end = min(end+context, run)
					break
				}
				end = run
			}
			aStart, bStart, aCount, bCount := ops[start].i, ops[start].j, 0, 0
			var body strings.Builder
			for _, o := range ops[start:end] {
				switch o.kind {
				case '=':
					body.WriteString(" " + a[o.i] + "\n")
					aCount++
					bCount++
				case '-':
					body.WriteString("-" + a[o.i] + "\n")
					aCount++
				case '+':
					body.WriteString("+" + b[o.j] + "\n")
					bCount++
				}
			}
			out.WriteString(fmt.Sprintf("@@ -%d,%d +%d,%d @@\n", aStart+1, aCount, bStart+1, bCount))
			out.WriteString(body.String())
			k = end
		}
		return outcome{out: out.String(), status: 1}, nil
	}
	for k := 0; k < len(ops); {
		if ops[k].kind == '=' {
			k++
			continue
		}
		end := k
		for end < len(ops) && ops[end].kind != '=' {
			end++
		}
		var del, add []string
		for _, o := range ops[k:end] {
			if o.kind == '-' {
				del = append(del, a[o.i])
			} else {
				add = append(add, b[o.j])
			}
		}
		i, j := ops[k].i, ops[k].j
		switch {
		case len(add) == 0:
			out.WriteString(span(i, i+len(del)) + "d" + strconv.Itoa(j) + "\n")
		case len(del) == 0:
			out.WriteString(strconv.Itoa(i) + "a" + span(j, j+len(add)) + "\n")
		default:
			out.WriteString(span(i, i+len(del)) + "c" + span(j, j+len(add)) + "\n")
		}
		for _, l := range del {
			out.WriteString("< " + l + "\n")
		}
		if len(del) > 0 && len(add) > 0 {
			out.WriteString("---\n")
		}
		for _, l := range add {
			out.WriteString("> " + l + "\n")
		}
		k = end
	}
	return outcome{out: out.String(), status: 1}, nil
}
