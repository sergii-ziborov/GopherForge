package main

// A small awk: patterns, fields, variables, arithmetic, print and printf,
// if/while/for and the common string functions. Arrays, getline and output
// redirection are not part of it, and every loop counts against a budget.
import (
	"errors"
	"fmt"
	"math"
	"regexp"
	"strconv"
	"strings"
)

type awkTok struct {
	kind byte // n number, s string, r regex, i name, p punctuation, ; terminator, e end
	text string
	num  float64
}

func awkLex(src string) ([]awkTok, error) {
	var toks []awkTok
	operand := false
	ops := []string{"+=", "-=", "*=", "/=", "%=", "^=", "==", "!=", "<=", ">=", "&&", "||", "++", "--", "!~", ">>"}
	for i := 0; i < len(src); {
		c := src[i]
		switch {
		case c == ' ' || c == '\t' || c == '\r':
			i++
			continue
		case c == '\\' && i+1 < len(src) && src[i+1] == '\n':
			i += 2
			continue
		case c == '#':
			for i < len(src) && src[i] != '\n' {
				i++
			}
			continue
		case c == '\n' || c == ';':
			toks = append(toks, awkTok{kind: ';', text: string(c)})
			i++
			operand = false
			continue
		case c == '"':
			var b strings.Builder
			i++
			for i < len(src) && src[i] != '"' {
				if src[i] == '\\' && i+1 < len(src) {
					i++
					switch src[i] {
					case 'n':
						b.WriteByte('\n')
					case 't':
						b.WriteByte('\t')
					default:
						b.WriteByte(src[i])
					}
				} else {
					b.WriteByte(src[i])
				}
				i++
			}
			if i >= len(src) {
				return nil, errors.New("unterminated string")
			}
			i++
			toks = append(toks, awkTok{kind: 's', text: b.String()})
			operand = true
			continue
		case c == '/' && !operand:
			var b strings.Builder
			i++
			for i < len(src) && src[i] != '/' {
				if src[i] == '\\' && i+1 < len(src) && src[i+1] == '/' {
					i++
				}
				b.WriteByte(src[i])
				i++
			}
			if i >= len(src) {
				return nil, errors.New("unterminated regular expression")
			}
			i++
			toks = append(toks, awkTok{kind: 'r', text: b.String()})
			operand = true
			continue
		case c >= '0' && c <= '9' || (c == '.' && i+1 < len(src) && src[i+1] >= '0' && src[i+1] <= '9'):
			j := i
			for j < len(src) && (src[j] >= '0' && src[j] <= '9' || src[j] == '.' || ((src[j] == 'e' || src[j] == 'E') && j > i)) {
				j++
			}
			n, err := strconv.ParseFloat(src[i:j], 64)
			if err != nil {
				return nil, fmt.Errorf("invalid number %q", src[i:j])
			}
			toks = append(toks, awkTok{kind: 'n', text: src[i:j], num: n})
			i = j
			operand = true
			continue
		case c == '_' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z':
			j := i
			for j < len(src) && (src[j] == '_' || src[j] >= 'a' && src[j] <= 'z' || src[j] >= 'A' && src[j] <= 'Z' || src[j] >= '0' && src[j] <= '9') {
				j++
			}
			toks = append(toks, awkTok{kind: 'i', text: src[i:j]})
			i = j
			operand = true
			continue
		}
		op := string(c)
		for _, o := range ops {
			if strings.HasPrefix(src[i:], o) {
				op = o
				break
			}
		}
		if !strings.Contains("{}()[],+-*/%^!<>=~?:$|", string(c)) && len(op) == 1 {
			return nil, fmt.Errorf("unexpected character %q", c)
		}
		toks = append(toks, awkTok{kind: 'p', text: op})
		i += len(op)
		operand = op == ")" || op == "]" || op == "++" || op == "--"
	}
	return append(toks, awkTok{kind: 'e'}), nil
}

type awkNode struct {
	kind string // num str regex field var binary unary assign incr call cond match concat group
	op   string
	num  float64
	str  string
	re   *regexp.Regexp
	kids []*awkNode
	pre  bool
}
type awkStmt struct {
	kind  string // print printf expr if while for block next exit
	exprs []*awkNode
	body  []*awkStmt
	els   []*awkStmt
	init  *awkStmt
	post  *awkStmt
}
type awkRule struct {
	begin, end bool
	pattern    *awkNode
	action     []*awkStmt
	hasAction  bool
}

type awkParser struct {
	toks []awkTok
	i    int
}

func (p *awkParser) peek() awkTok { return p.toks[p.i] }
func (p *awkParser) is(text string) bool {
	t := p.peek()
	return (t.kind == 'p' || t.kind == 'i') && t.text == text
}
func (p *awkParser) expect(text string) error {
	if !p.is(text) {
		return fmt.Errorf("syntax error near %q: expected %q", p.peek().text, text)
	}
	p.i++
	return nil
}
func (p *awkParser) newlines() {
	for p.peek().kind == ';' && p.peek().text == "\n" {
		p.i++
	}
}
func (p *awkParser) terminators() {
	for p.peek().kind == ';' {
		p.i++
	}
}

func parseAwk(src string) ([]*awkRule, error) {
	toks, err := awkLex(src)
	if err != nil {
		return nil, err
	}
	p := &awkParser{toks: toks}
	var rules []*awkRule
	for p.terminators(); p.peek().kind != 'e'; p.terminators() {
		r := &awkRule{}
		switch {
		case p.is("BEGIN"):
			p.i++
			r.begin = true
		case p.is("END"):
			p.i++
			r.end = true
		case !p.is("{"):
			if r.pattern, err = p.expr(false); err != nil {
				return nil, err
			}
		}
		if p.is("{") {
			if r.action, err = p.block(); err != nil {
				return nil, err
			}
			r.hasAction = true
		} else if r.begin || r.end {
			return nil, errors.New("BEGIN and END need an action in braces")
		}
		rules = append(rules, r)
	}
	return rules, nil
}

func (p *awkParser) block() ([]*awkStmt, error) {
	if err := p.expect("{"); err != nil {
		return nil, err
	}
	var out []*awkStmt
	for p.terminators(); !p.is("}"); p.terminators() {
		if p.peek().kind == 'e' {
			return nil, errors.New("missing '}'")
		}
		st, err := p.statement()
		if err != nil {
			return nil, err
		}
		out = append(out, st)
	}
	p.i++
	return out, nil
}

func (p *awkParser) body() ([]*awkStmt, error) {
	p.newlines()
	if p.is("{") {
		return p.block()
	}
	st, err := p.statement()
	if err != nil {
		return nil, err
	}
	return []*awkStmt{st}, nil
}

func (p *awkParser) simple() (*awkStmt, error) {
	if p.peek().kind == ';' || p.is(")") {
		return nil, nil
	}
	x, err := p.expr(false)
	return &awkStmt{kind: "expr", exprs: []*awkNode{x}}, err
}

func (p *awkParser) statement() (*awkStmt, error) {
	switch {
	case p.is("{"):
		b, err := p.block()
		return &awkStmt{kind: "block", body: b}, err
	case p.is("if"):
		p.i++
		if err := p.expect("("); err != nil {
			return nil, err
		}
		cond, err := p.expr(false)
		if err != nil {
			return nil, err
		}
		if err := p.expect(")"); err != nil {
			return nil, err
		}
		st := &awkStmt{kind: "if", exprs: []*awkNode{cond}}
		if st.body, err = p.body(); err != nil {
			return nil, err
		}
		save := p.i
		p.terminators()
		if p.is("else") {
			p.i++
			if st.els, err = p.body(); err != nil {
				return nil, err
			}
		} else {
			p.i = save
		}
		return st, nil
	case p.is("while"):
		p.i++
		if err := p.expect("("); err != nil {
			return nil, err
		}
		cond, err := p.expr(false)
		if err != nil {
			return nil, err
		}
		if err := p.expect(")"); err != nil {
			return nil, err
		}
		st := &awkStmt{kind: "while", exprs: []*awkNode{cond}}
		st.body, err = p.body()
		return st, err
	case p.is("for"):
		p.i++
		if err := p.expect("("); err != nil {
			return nil, err
		}
		st := &awkStmt{kind: "for"}
		var err error
		if st.init, err = p.simple(); err != nil {
			return nil, err
		}
		if p.peek().kind != ';' {
			return nil, errors.New("for (k in array) is unavailable: awk arrays are not part of this lab")
		}
		p.i++
		if p.peek().kind != ';' {
			cond, err := p.expr(false)
			if err != nil {
				return nil, err
			}
			st.exprs = []*awkNode{cond}
		}
		if p.peek().kind != ';' {
			return nil, errors.New("expected ';' in for")
		}
		p.i++
		if st.post, err = p.simple(); err != nil {
			return nil, err
		}
		if err := p.expect(")"); err != nil {
			return nil, err
		}
		st.body, err = p.body()
		return st, err
	case p.is("print"), p.is("printf"):
		kind := p.peek().text
		p.i++
		st := &awkStmt{kind: kind}
		paren := false
		if p.is("(") {
			save := p.i
			p.i++
			if list, err := p.list(false); err == nil && p.is(")") && (p.toks[p.i+1].kind == ';' || p.toks[p.i+1].text == "}" || p.toks[p.i+1].kind == 'e') {
				p.i++
				st.exprs, paren = list, true
			} else {
				p.i = save
			}
		}
		if !paren && p.peek().kind != ';' && !p.is("}") && p.peek().kind != 'e' {
			list, err := p.list(true)
			if err != nil {
				return nil, err
			}
			st.exprs = list
		}
		if p.is(">") || p.is(">>") || p.is("|") {
			return nil, errors.New("output redirection inside awk is unavailable; redirect the whole command instead")
		}
		if kind == "printf" && len(st.exprs) == 0 {
			return nil, errors.New("printf needs a format")
		}
		return st, nil
	case p.is("next"):
		p.i++
		return &awkStmt{kind: "next"}, nil
	case p.is("exit"):
		p.i++
		st := &awkStmt{kind: "exit"}
		if p.peek().kind != ';' && !p.is("}") && p.peek().kind != 'e' {
			x, err := p.expr(false)
			if err != nil {
				return nil, err
			}
			st.exprs = []*awkNode{x}
		}
		return st, nil
	case p.is("getline"), p.is("delete"), p.is("function"):
		return nil, errors.New(p.peek().text + " is unavailable in this awk")
	}
	return p.simple()
}

func (p *awkParser) list(noGT bool) ([]*awkNode, error) {
	var out []*awkNode
	for {
		x, err := p.expr(noGT)
		if err != nil {
			return nil, err
		}
		out = append(out, x)
		if !p.is(",") {
			return out, nil
		}
		p.i++
		p.newlines()
	}
}

func (p *awkParser) expr(noGT bool) (*awkNode, error) {
	left, err := p.ternary(noGT)
	if err != nil {
		return nil, err
	}
	if t := p.peek(); t.kind == 'p' && (t.text == "=" || strings.HasSuffix(t.text, "=") && len(t.text) == 2 && strings.Contains("+-*/%^", t.text[:1])) {
		if left.kind != "var" && left.kind != "field" {
			return nil, errors.New("assignment needs a variable or field")
		}
		p.i++
		value, err := p.expr(noGT)
		if err != nil {
			return nil, err
		}
		return &awkNode{kind: "assign", op: t.text, kids: []*awkNode{left, value}}, nil
	}
	return left, nil
}
func (p *awkParser) ternary(noGT bool) (*awkNode, error) {
	cond, err := p.binary(0, noGT)
	if err != nil || !p.is("?") {
		return cond, err
	}
	p.i++
	a, err := p.ternary(noGT)
	if err != nil {
		return nil, err
	}
	if err := p.expect(":"); err != nil {
		return nil, err
	}
	b, err := p.ternary(noGT)
	return &awkNode{kind: "cond", kids: []*awkNode{cond, a, b}}, err
}

var awkLevels = [][]string{{"||"}, {"&&"}, {"~", "!~"}, {"<", "<=", "==", "!=", ">", ">="}}

func (p *awkParser) binary(level int, noGT bool) (*awkNode, error) {
	if level == len(awkLevels) {
		return p.concat(noGT)
	}
	left, err := p.binary(level+1, noGT)
	for err == nil {
		t := p.peek()
		match := false
		for _, op := range awkLevels[level] {
			if t.kind == 'p' && t.text == op && !(noGT && op == ">") {
				match = true
			}
		}
		if !match {
			break
		}
		p.i++
		if level < 2 {
			p.newlines()
		}
		var right *awkNode
		if right, err = p.binary(level+1, noGT); err != nil {
			return nil, err
		}
		kind := "binary"
		if level == 2 {
			kind = "match"
		}
		left = &awkNode{kind: kind, op: t.text, kids: []*awkNode{left, right}}
		if level == 3 {
			break
		}
	}
	return left, err
}
func (p *awkParser) concat(noGT bool) (*awkNode, error) {
	left, err := p.additive()
	for err == nil {
		t := p.peek()
		if !(t.kind == 'n' || t.kind == 's' || t.kind == 'i' && !isAwkKeyword(t.text) || t.kind == 'p' && (t.text == "$" || t.text == "(")) {
			break
		}
		var right *awkNode
		if right, err = p.additive(); err != nil {
			return nil, err
		}
		left = &awkNode{kind: "concat", kids: []*awkNode{left, right}}
	}
	return left, err
}
func isAwkKeyword(v string) bool {
	switch v {
	case "if", "else", "while", "for", "print", "printf", "next", "exit", "in", "BEGIN", "END", "getline", "delete", "function":
		return true
	}
	return false
}
func (p *awkParser) additive() (*awkNode, error) {
	left, err := p.multiplicative()
	for err == nil && (p.is("+") || p.is("-")) {
		op := p.peek().text
		p.i++
		var right *awkNode
		if right, err = p.multiplicative(); err != nil {
			return nil, err
		}
		left = &awkNode{kind: "binary", op: op, kids: []*awkNode{left, right}}
	}
	return left, err
}
func (p *awkParser) multiplicative() (*awkNode, error) {
	left, err := p.unary()
	for err == nil && (p.is("*") || p.is("/") || p.is("%")) {
		op := p.peek().text
		p.i++
		var right *awkNode
		if right, err = p.unary(); err != nil {
			return nil, err
		}
		left = &awkNode{kind: "binary", op: op, kids: []*awkNode{left, right}}
	}
	return left, err
}
func (p *awkParser) unary() (*awkNode, error) {
	if p.is("!") || p.is("-") || p.is("+") {
		op := p.peek().text
		p.i++
		x, err := p.unary()
		return &awkNode{kind: "unary", op: op, kids: []*awkNode{x}}, err
	}
	return p.power()
}
func (p *awkParser) power() (*awkNode, error) {
	base, err := p.postfix()
	if err != nil || !p.is("^") {
		return base, err
	}
	p.i++
	exp, err := p.unary()
	return &awkNode{kind: "binary", op: "^", kids: []*awkNode{base, exp}}, err
}
func (p *awkParser) postfix() (*awkNode, error) {
	x, err := p.primary()
	if err == nil && (x.kind == "var" || x.kind == "field") && (p.is("++") || p.is("--")) {
		op := p.peek().text
		p.i++
		return &awkNode{kind: "incr", op: op, kids: []*awkNode{x}}, nil
	}
	return x, err
}
func (p *awkParser) primary() (*awkNode, error) {
	t := p.peek()
	switch t.kind {
	case 'n':
		p.i++
		return &awkNode{kind: "num", num: t.num}, nil
	case 's':
		p.i++
		return &awkNode{kind: "str", str: t.text}, nil
	case 'r':
		p.i++
		re, err := compileRegexp(t.text)
		return &awkNode{kind: "regex", re: re}, err
	case 'i':
		if isAwkKeyword(t.text) {
			return nil, fmt.Errorf("syntax error near %q", t.text)
		}
		p.i++
		if p.is("[") {
			return nil, errors.New("awk arrays are unavailable in this lab")
		}
		if p.is("(") {
			p.i++
			var args []*awkNode
			if !p.is(")") {
				var err error
				if args, err = p.list(false); err != nil {
					return nil, err
				}
			}
			if err := p.expect(")"); err != nil {
				return nil, err
			}
			return &awkNode{kind: "call", str: t.text, kids: args}, nil
		}
		if t.text == "length" {
			return &awkNode{kind: "call", str: "length"}, nil
		}
		return &awkNode{kind: "var", str: t.text}, nil
	case 'p':
		switch t.text {
		case "$":
			p.i++
			x, err := p.primary()
			if err != nil {
				return nil, err
			}
			return &awkNode{kind: "field", kids: []*awkNode{x}}, nil
		case "(":
			p.i++
			x, err := p.expr(false)
			if err != nil {
				return nil, err
			}
			if p.is(",") {
				return nil, errors.New("(a, b) in array is unavailable: awk arrays are not part of this lab")
			}
			return &awkNode{kind: "group", kids: []*awkNode{x}}, p.expect(")")
		case "++", "--":
			p.i++
			x, err := p.primary()
			if err != nil {
				return nil, err
			}
			if x.kind != "var" && x.kind != "field" {
				return nil, errors.New(t.text + " needs a variable")
			}
			return &awkNode{kind: "incr", op: t.text, pre: true, kids: []*awkNode{x}}, nil
		}
	case 'e':
		return nil, errors.New("unexpected end of program")
	}
	return nil, fmt.Errorf("syntax error near %q", t.text)
}

// Values carry a string, a number, or both, as awk's do: input fields compare
// as numbers when they look like numbers.
type awkValue struct {
	s      string
	n      float64
	number bool
	strnum bool
}

func awkNum(n float64) awkValue  { return awkValue{n: n, number: true} }
func awkStr(s string) awkValue   { return awkValue{s: s} }
func awkInput(s string) awkValue { return awkValue{s: s, strnum: true} }
func (v awkValue) str() string {
	if !v.number {
		return v.s
	}
	if v.n == math.Trunc(v.n) && math.Abs(v.n) < 1e16 {
		return strconv.FormatInt(int64(v.n), 10)
	}
	return strconv.FormatFloat(v.n, 'g', 6, 64)
}
func (v awkValue) num() float64 {
	if v.number {
		return v.n
	}
	s := strings.TrimSpace(v.s)
	end := 0
	for end < len(s) && strings.IndexByte("+-.0123456789eE", s[end]) >= 0 {
		end++
	}
	for end > 0 {
		if n, err := strconv.ParseFloat(s[:end], 64); err == nil {
			return n
		}
		end--
	}
	return 0
}
func (v awkValue) looksNumeric() bool {
	if v.number {
		return true
	}
	if !v.strnum {
		return false
	}
	_, err := strconv.ParseFloat(strings.TrimSpace(v.s), 64)
	return err == nil
}
func (v awkValue) truthy() bool {
	if v.number || v.looksNumeric() {
		return v.num() != 0
	}
	return v.s != ""
}

type awkVM struct {
	s          *Shell
	vars       map[string]awkValue
	fields     []string
	nr         int
	out        strings.Builder
	next, exit bool
	status     int
	budget     int
	filename   string
}

func (vm *awkVM) tick() error {
	vm.budget++
	if vm.budget > 200000 {
		return errors.New("awk stopped at its 200000-step lab budget")
	}
	if vm.budget%1000 == 0 && vm.s.stopped != nil && vm.s.stopped() {
		return errors.New("stopped by user")
	}
	return nil
}
func (vm *awkVM) setRecord(line string) {
	vm.fields = append([]string{line}, vm.split(line)...)
}
func (vm *awkVM) split(line string) []string {
	fs := vm.vars["FS"].str()
	switch {
	case fs == " ":
		return strings.Fields(line)
	case line == "":
		return nil
	case len([]rune(fs)) == 1 && fs != "\\":
		return strings.Split(line, fs)
	}
	re, err := compileRegexp(fs)
	if err != nil {
		return strings.Split(line, fs)
	}
	return re.Split(line, -1)
}
func (vm *awkVM) getField(i int) string {
	if i < 0 {
		return ""
	}
	if i < len(vm.fields) {
		return vm.fields[i]
	}
	return ""
}
func (vm *awkVM) setField(i int, v string) error {
	if i < 0 || i > 1024 {
		return errors.New("field index out of range")
	}
	if i == 0 {
		vm.setRecord(v)
		return nil
	}
	for len(vm.fields) <= i {
		vm.fields = append(vm.fields, "")
	}
	vm.fields[i] = v
	vm.fields[0] = strings.Join(vm.fields[1:], vm.vars["OFS"].str())
	return nil
}

func (vm *awkVM) get(name string) awkValue {
	switch name {
	case "NR", "FNR":
		return awkNum(float64(vm.nr))
	case "NF":
		return awkNum(float64(len(vm.fields) - 1))
	case "FILENAME":
		return awkStr(vm.filename)
	}
	return vm.vars[name]
}

func (vm *awkVM) eval(n *awkNode) (awkValue, error) {
	switch n.kind {
	case "num":
		return awkNum(n.num), nil
	case "str":
		return awkStr(n.str), nil
	case "regex":
		return awkNum(boolNum(n.re.MatchString(vm.getField(0)))), nil
	case "group":
		return vm.eval(n.kids[0])
	case "var":
		return vm.get(n.str), nil
	case "field":
		i, err := vm.eval(n.kids[0])
		if err != nil {
			return awkValue{}, err
		}
		return awkInput(vm.getField(int(i.num()))), nil
	case "cond":
		c, err := vm.eval(n.kids[0])
		if err != nil {
			return awkValue{}, err
		}
		if c.truthy() {
			return vm.eval(n.kids[1])
		}
		return vm.eval(n.kids[2])
	case "concat":
		a, err := vm.eval(n.kids[0])
		if err != nil {
			return awkValue{}, err
		}
		b, err := vm.eval(n.kids[1])
		if len(a.str())+len(b.str()) > maxFile {
			return awkValue{}, errors.New("awk string exceeds 64 KiB")
		}
		return awkStr(a.str() + b.str()), err
	case "unary":
		x, err := vm.eval(n.kids[0])
		switch n.op {
		case "!":
			return awkNum(boolNum(!x.truthy())), err
		case "-":
			return awkNum(-x.num()), err
		}
		return awkNum(x.num()), err
	case "match":
		left, err := vm.eval(n.kids[0])
		if err != nil {
			return awkValue{}, err
		}
		re := n.kids[1].re
		if n.kids[1].kind != "regex" {
			pat, err := vm.eval(n.kids[1])
			if err != nil {
				return awkValue{}, err
			}
			if re, err = compileRegexp(pat.str()); err != nil {
				return awkValue{}, err
			}
		}
		return awkNum(boolNum(re.MatchString(left.str()) == (n.op == "~"))), nil
	case "binary":
		if n.op == "&&" || n.op == "||" {
			a, err := vm.eval(n.kids[0])
			if err != nil || (n.op == "&&") != a.truthy() {
				return awkNum(boolNum(a.truthy())), err
			}
			b, err := vm.eval(n.kids[1])
			return awkNum(boolNum(b.truthy())), err
		}
		a, err := vm.eval(n.kids[0])
		if err != nil {
			return awkValue{}, err
		}
		b, err := vm.eval(n.kids[1])
		if err != nil {
			return awkValue{}, err
		}
		switch n.op {
		case "<", "<=", "==", "!=", ">", ">=":
			var c int
			if a.looksNumeric() && b.looksNumeric() {
				switch x, y := a.num(), b.num(); {
				case x < y:
					c = -1
				case x > y:
					c = 1
				}
			} else {
				c = strings.Compare(a.str(), b.str())
			}
			ok := map[string]bool{"<": c < 0, "<=": c <= 0, "==": c == 0, "!=": c != 0, ">": c > 0, ">=": c >= 0}[n.op]
			return awkNum(boolNum(ok)), nil
		}
		return arith(n.op, a.num(), b.num())
	case "assign":
		value, err := vm.eval(n.kids[1])
		if err != nil {
			return awkValue{}, err
		}
		if n.op != "=" {
			current, err := vm.eval(n.kids[0])
			if err != nil {
				return awkValue{}, err
			}
			if value, err = arith(n.op[:1], current.num(), value.num()); err != nil {
				return awkValue{}, err
			}
		}
		return value, vm.store(n.kids[0], value)
	case "incr":
		current, err := vm.eval(n.kids[0])
		if err != nil {
			return awkValue{}, err
		}
		delta := 1.0
		if n.op == "--" {
			delta = -1
		}
		next := awkNum(current.num() + delta)
		if err := vm.store(n.kids[0], next); err != nil {
			return awkValue{}, err
		}
		if n.pre {
			return next, nil
		}
		return awkNum(current.num()), nil
	case "call":
		return vm.call(n)
	}
	return awkValue{}, errors.New("unsupported awk expression")
}
func boolNum(ok bool) float64 {
	if ok {
		return 1
	}
	return 0
}
func arith(op string, a, b float64) (awkValue, error) {
	switch op {
	case "+":
		return awkNum(a + b), nil
	case "-":
		return awkNum(a - b), nil
	case "*":
		return awkNum(a * b), nil
	case "/":
		if b == 0 {
			return awkValue{}, errors.New("division by zero")
		}
		return awkNum(a / b), nil
	case "%":
		if b == 0 {
			return awkValue{}, errors.New("division by zero in %")
		}
		return awkNum(math.Mod(a, b)), nil
	case "^":
		return awkNum(math.Pow(a, b)), nil
	}
	return awkValue{}, errors.New("unknown operator " + op)
}
func (vm *awkVM) store(target *awkNode, v awkValue) error {
	if target.kind == "field" {
		i, err := vm.eval(target.kids[0])
		if err != nil {
			return err
		}
		return vm.setField(int(i.num()), v.str())
	}
	switch target.str {
	case "NR", "NF", "FNR", "FILENAME":
		return errors.New("assigning " + target.str + " is unavailable here")
	}
	if len(vm.vars) > 256 {
		return errors.New("awk variable limit reached")
	}
	vm.vars[target.str] = v
	return nil
}

func (vm *awkVM) call(n *awkNode) (awkValue, error) {
	args := make([]awkValue, len(n.kids))
	for i, k := range n.kids {
		if (n.str == "sub" || n.str == "gsub") && i == 0 && k.kind == "regex" {
			continue
		}
		v, err := vm.eval(k)
		if err != nil {
			return awkValue{}, err
		}
		args[i] = v
	}
	arg := func(i int) awkValue {
		if i < len(args) {
			return args[i]
		}
		return awkValue{}
	}
	switch n.str {
	case "length":
		if len(args) == 0 {
			return awkNum(float64(len([]rune(vm.getField(0))))), nil
		}
		return awkNum(float64(len([]rune(arg(0).str())))), nil
	case "substr":
		r := []rune(arg(0).str())
		start := int(math.Round(arg(1).num()))
		end := len(r) + 1
		if len(args) > 2 {
			end = start + int(math.Round(arg(2).num()))
		}
		start, end = max(start, 1), min(end, len(r)+1)
		if start >= end {
			return awkStr(""), nil
		}
		return awkStr(string(r[start-1 : end-1])), nil
	case "index":
		return awkNum(float64(strings.Index(arg(0).str(), arg(1).str()) + 1)), nil
	case "toupper":
		return awkStr(strings.ToUpper(arg(0).str())), nil
	case "tolower":
		return awkStr(strings.ToLower(arg(0).str())), nil
	case "int":
		return awkNum(math.Trunc(arg(0).num())), nil
	case "sqrt":
		return awkNum(math.Sqrt(arg(0).num())), nil
	case "sprintf":
		if len(args) == 0 {
			return awkValue{}, errors.New("sprintf needs a format")
		}
		v, err := awkFormat(arg(0).str(), args[1:])
		return awkStr(v), err
	case "sub", "gsub":
		if len(n.kids) < 2 {
			return awkValue{}, errors.New(n.str + " needs a pattern and a replacement")
		}
		re := n.kids[0].re
		if n.kids[0].kind != "regex" {
			var err error
			if re, err = compileRegexp(arg(0).str()); err != nil {
				return awkValue{}, err
			}
		}
		target := &awkNode{kind: "field", kids: []*awkNode{{kind: "num"}}}
		if len(n.kids) > 2 {
			target = n.kids[2]
			if target.kind != "var" && target.kind != "field" {
				return awkValue{}, errors.New(n.str + ": the target must be a variable or field")
			}
		}
		current, err := vm.eval(target)
		if err != nil {
			return awkValue{}, err
		}
		count := 0
		replaced := re.ReplaceAllStringFunc(current.str(), func(m string) string {
			count++
			if n.str == "sub" && count > 1 {
				return m
			}
			return strings.ReplaceAll(strings.ReplaceAll(strings.ReplaceAll(arg(1).str(), `\&`, "\x00"), "&", m), "\x00", "&")
		})
		if n.str == "sub" {
			count = min(count, 1)
		}
		if count > 0 {
			if err := vm.store(target, awkStr(replaced)); err != nil {
				return awkValue{}, err
			}
		}
		return awkNum(float64(count)), nil
	case "split", "match", "system", "close", "srand", "rand":
		return awkValue{}, errors.New(n.str + "() is unavailable in this awk")
	}
	return awkValue{}, errors.New("function " + n.str + " never defined")
}

func awkFormat(format string, args []awkValue) (string, error) {
	var b strings.Builder
	used := 0
	for i := 0; i < len(format); i++ {
		if format[i] != '%' {
			b.WriteByte(format[i])
			continue
		}
		j := i + 1
		for j < len(format) && strings.IndexByte("-+ #0123456789.", format[j]) >= 0 {
			j++
		}
		if j >= len(format) {
			return "", errors.New("printf: missing format character")
		}
		spec, verb := format[i+1:j], format[j]
		i = j
		if verb == '%' {
			b.WriteByte('%')
			continue
		}
		var v awkValue
		if used < len(args) {
			v = args[used]
		}
		used++
		switch verb {
		case 'd', 'i':
			b.WriteString(fmt.Sprintf("%"+spec+"d", int64(v.num())))
		case 'o', 'x', 'X':
			b.WriteString(fmt.Sprintf("%"+spec+string(verb), int64(v.num())))
		case 'f', 'e', 'E', 'g', 'G':
			b.WriteString(fmt.Sprintf("%"+spec+string(verb), v.num()))
		case 'c':
			if v.number {
				b.WriteRune(rune(int(v.n)))
			} else if s := v.str(); s != "" {
				b.WriteString(string([]rune(s)[:1]))
			}
		case 's':
			b.WriteString(fmt.Sprintf("%"+spec+"s", v.str()))
		default:
			return "", fmt.Errorf("printf: %%%c is unavailable", verb)
		}
	}
	return b.String(), nil
}

func (vm *awkVM) exec(stmts []*awkStmt) error {
	for _, st := range stmts {
		if vm.next || vm.exit {
			return nil
		}
		if err := vm.tick(); err != nil {
			return err
		}
		switch st.kind {
		case "expr":
			if _, err := vm.eval(st.exprs[0]); err != nil {
				return err
			}
		case "print":
			var parts []string
			if len(st.exprs) == 0 {
				parts = []string{vm.getField(0)}
			}
			for _, x := range st.exprs {
				v, err := vm.eval(x)
				if err != nil {
					return err
				}
				parts = append(parts, v.str())
			}
			vm.out.WriteString(strings.Join(parts, vm.vars["OFS"].str()) + "\n")
		case "printf":
			values := make([]awkValue, len(st.exprs))
			for i, x := range st.exprs {
				v, err := vm.eval(x)
				if err != nil {
					return err
				}
				values[i] = v
			}
			v, err := awkFormat(values[0].str(), values[1:])
			if err != nil {
				return err
			}
			vm.out.WriteString(v)
		case "block":
			if err := vm.exec(st.body); err != nil {
				return err
			}
		case "if":
			c, err := vm.eval(st.exprs[0])
			if err != nil {
				return err
			}
			branch := st.els
			if c.truthy() {
				branch = st.body
			}
			if err := vm.exec(branch); err != nil {
				return err
			}
		case "while", "for":
			if st.init != nil {
				if err := vm.exec([]*awkStmt{st.init}); err != nil {
					return err
				}
			}
			for !vm.next && !vm.exit {
				if err := vm.tick(); err != nil {
					return err
				}
				if len(st.exprs) > 0 {
					c, err := vm.eval(st.exprs[0])
					if err != nil {
						return err
					}
					if !c.truthy() {
						break
					}
				}
				if err := vm.exec(st.body); err != nil {
					return err
				}
				if st.post != nil {
					if err := vm.exec([]*awkStmt{st.post}); err != nil {
						return err
					}
				}
			}
		case "next":
			vm.next = true
		case "exit":
			if len(st.exprs) > 0 {
				v, err := vm.eval(st.exprs[0])
				if err != nil {
					return err
				}
				vm.status = int(v.num())
			}
			vm.exit = true
		}
		if vm.out.Len() > maxOutput {
			return errors.New("output exceeded 64 KiB")
		}
	}
	return nil
}

func (s *Shell) awk(cmd string, args []string, in *stream) (outcome, error) {
	vm := &awkVM{s: s, vars: map[string]awkValue{"FS": awkStr(" "), "OFS": awkStr(" ")}}
	var operands []string
	program, hasProgram := "", false
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "-F" && i+1 < len(args):
			i++
			vm.vars["FS"] = awkStr(awkSeparator(args[i]))
		case strings.HasPrefix(a, "-F") && len(a) > 2:
			vm.vars["FS"] = awkStr(awkSeparator(a[2:]))
		case a == "-v" && i+1 < len(args):
			i++
			name, value, ok := strings.Cut(args[i], "=")
			if !ok || !validName(name) {
				return failure("awk: -v needs NAME=value")
			}
			vm.vars[name] = awkInput(value)
		case a == "-f":
			return failure("awk: -f is unavailable; pass the program as an argument")
		case !hasProgram:
			program, hasProgram = a, true
		default:
			operands = append(operands, a)
		}
	}
	if !hasProgram {
		return failure("awk: usage: awk [-F sep] [-v name=value] 'program' [file ...]")
	}
	rules, err := parseAwk(program)
	if err != nil {
		return outcome{err: "awk: " + err.Error() + "\n", status: 2}, nil
	}
	fail := func(err error) (outcome, error) {
		if strings.Contains(err.Error(), "stopped by user") {
			return outcome{}, err
		}
		return outcome{out: vm.out.String(), err: "awk: " + err.Error() + "\n", status: 2}, nil
	}
	for _, r := range rules {
		if r.begin {
			if err := vm.exec(r.action); err != nil {
				return fail(err)
			}
		}
	}
	var o outcome
	hasMain := false
	for _, r := range rules {
		hasMain = hasMain || (!r.begin && !r.end)
	}
	if hasMain || anyEnd(rules) {
		for _, src := range s.inputs(operands, in) {
			if vm.exit {
				break
			}
			if src.err != nil {
				o = joinFailure(o, outcome{err: "awk: cannot open \"" + src.name + "\": " + src.err.Error() + "\n", status: 2})
				continue
			}
			vm.filename = src.name
			for _, line := range splitLines(src.data) {
				if vm.exit {
					break
				}
				vm.nr++
				vm.next = false
				vm.setRecord(line)
				for _, r := range rules {
					if r.begin || r.end || vm.next || vm.exit {
						continue
					}
					if r.pattern != nil {
						v, err := vm.eval(r.pattern)
						if err != nil {
							return fail(err)
						}
						if !v.truthy() {
							continue
						}
					}
					if !r.hasAction {
						vm.out.WriteString(vm.getField(0) + "\n")
						continue
					}
					if err := vm.exec(r.action); err != nil {
						return fail(err)
					}
				}
			}
		}
	}
	vm.exit = false
	for _, r := range rules {
		if r.end {
			if err := vm.exec(r.action); err != nil {
				return fail(err)
			}
		}
	}
	o.out = vm.out.String()
	if vm.status != 0 {
		o.status = vm.status
	}
	return o, nil
}
func anyEnd(rules []*awkRule) bool {
	for _, r := range rules {
		if r.end {
			return true
		}
	}
	return false
}
func awkSeparator(v string) string {
	if v == "t" || v == `\t` {
		return "\t"
	}
	return v
}
