package main

import (
	"strings"
	"testing"
)

// session runs lines one at a time against shared state, like the prompt.
type session struct {
	t     *testing.T
	state State
}

func newSession(t *testing.T) *session { return &session{t: t, state: initialState()} }
func (s *session) run(line string) Result {
	r := run(line, s.state, nil)
	s.state = r.State
	return r
}
func (s *session) expect(line, stdout string) {
	s.t.Helper()
	r := s.run(line)
	if r.Status != 0 || r.Stdout != stdout {
		s.t.Fatalf("%q\nwant %q\ngot  %q (status %d, stderr %q)", line, stdout, r.Stdout, r.Status, r.Stderr)
	}
}

func TestPromptStateCarriesBetweenLines(t *testing.T) {
	s := newSession(t)
	s.expect("mkdir -p app/config && cd app", "")
	s.expect("pwd", "/lab/app\n")
	s.expect("greet() { echo \"hello, ${1:-world}\"; }", "")
	s.expect("greet; greet lab", "hello, world\nhello, lab\n")
	s.expect("COUNT=3; export MODE=dev", "")
	s.expect("echo $COUNT $MODE", "3 dev\n")
	s.expect("cd -", "/lab\n")
	s.expect("cd ~/app/config && pwd", "/lab/app/config\n")
}

func TestIncompleteInputAsksForMore(t *testing.T) {
	for _, line := range []string{"if true; then", "echo \"open", "for x in a b; do", "cat <<EOF", "greet() {"} {
		r := run(line, initialState(), nil)
		if !r.Incomplete || len(r.State.Files) != 0 {
			t.Fatalf("%q should be incomplete: %+v", line, r)
		}
	}
	if r := run("echo )", initialState(), nil); r.Incomplete || r.Status == 0 {
		t.Fatalf("a syntax error is not incomplete input: %+v", r)
	}
}

func TestExpansionsGlobsAndSubstitution(t *testing.T) {
	s := newSession(t)
	s.expect("mkdir logs; touch logs/a.log logs/b.log logs/notes.txt .hidden", "")
	s.expect("echo logs/*.log", "logs/a.log logs/b.log\n")
	s.expect("ls *", "a.log\nb.log\nnotes.txt\n")
	s.expect("echo /etc/* ../*", "/etc/* ../*\n")
	s.expect("echo $((6 * 7)) $(( 10 % 4 ))", "42 2\n")
	s.expect("n=$(ls logs | wc -l); echo \"$n files\"", "3 files\n")
	s.expect("echo `echo nested`", "nested\n")
	s.expect("x=hello; echo ${#x} ${x:1:3} ${x/l/L} ${missing:-fallback}", "5 ell heLlo fallback\n")
	s.expect("echo {a,b,c}.txt", "a.txt b.txt c.txt\n")
	s.expect("i=0; while [ $i -lt 3 ]; do i=$((i+1)); done; echo $i", "3\n")
	s.expect("for ((i=1; i<=3; i++)); do printf '%s ' $i; done; echo", "1 2 3 \n")
	s.expect("(( 5 > 3 )) && echo yes", "yes\n")
}

func TestRedirectsHeredocsAndStreams(t *testing.T) {
	s := newSession(t)
	s.expect("cat > app.env <<EOF\nPORT=8080\nMODE=$((1+1))\nEOF", "")
	s.expect("cat app.env", "PORT=8080\nMODE=2\n")
	s.expect("cat <<'EOF'\n$HOME stays literal\nEOF", "$HOME stays literal\n")
	r := s.run("cat missing 2> err.txt; cat err.txt")
	if r.Stdout != "cat: missing: No such file or directory\n" || r.Stderr != "" {
		t.Fatalf("%+v", r)
	}
	s.expect("cat missing > out.txt 2>&1; cat out.txt", "cat: missing: No such file or directory\n")
	s.expect("cat missing 2>/dev/null || echo handled", "handled\n")
	s.expect("printf 'b\\na\\nc\\n' | sort | tee sorted.txt | wc -l", "3\n")
	s.expect("while read line; do echo \"> $line\"; done < sorted.txt", "> a\n> b\n> c\n")
	s.expect("read first second <<< 'one two three'; echo $second", "two three\n")
	s.expect("echo x >&2 2>/dev/null", "")
}

func TestControlFlowCaseAndTests(t *testing.T) {
	s := newSession(t)
	s.expect("for env in dev staging prod; do case $env in prod) echo \"$env: careful\";; d*) echo \"$env: ok\";; *) echo \"$env: ?\";; esac; done", "dev: ok\nstaging: ?\nprod: careful\n")
	s.expect("touch ready; [[ -f ready && $HOME == /lab ]] && echo both", "both\n")
	s.expect("[[ 'v1.2.3' =~ ^v[0-9]+\\. ]] && echo semver", "semver\n")
	s.expect("[ 3 -gt 2 -a ! -d ready ] && echo ok", "ok\n")
	s.expect("for i in 1 2 3 4; do [ $i = 3 ] && break; echo $i; done", "1\n2\n")
	s.expect("f() { return 3; }; f; echo $?", "3\n")
	r := s.run("set -e; echo before; false; echo after")
	if r.Stdout != "before\n" || r.Status != 1 {
		t.Fatalf("set -e: %+v", r)
	}
	s.expect("set -e; false || echo recovered; if false; then :; fi; echo still", "recovered\nstill\n")
	r = s.run("set -o pipefail; false | true")
	if r.Status != 1 {
		t.Fatalf("pipefail: %+v", r)
	}
	s.expect("printf 'echo \"args: $# $1\"\\nexit 4\\n' > job.sh; ./job.sh a b; echo $?", "args: 2 a\n4\n")
	// exit in a sourced script ends the whole command line, as in Bash.
	r = s.run("x=outer; sh -c 'x=inner'; echo $x; source job.sh z; echo unreachable")
	if r.Stdout != "outer\nargs: 1 z\n" || r.Status != 4 {
		t.Fatalf("source: %+v", r)
	}
}

func TestFileUtilities(t *testing.T) {
	s := newSession(t)
	s.expect("mkdir -p a/b/c && touch a/b/c/deep.txt a/top.sh && echo hi > a/b/note", "")
	s.expect("tree a", "a\n├── b/\n│   ├── c/\n│   │   └── deep.txt\n│   └── note\n└── top.sh\n\n2 directories, 3 files\n")
	s.expect("find a -name '*.txt'", "a/b/c/deep.txt\n")
	s.expect("find . -type d", ".\n./a\n./a/b\n./a/b/c\n")
	s.expect("ls -l a", "total 2\ndrwxr-xr-x 1 lab lab  4096 b/\n-rwxr-xr-x 1 lab lab     0 top.sh\n")
	s.expect("cp -r a copy && mv copy/b/note copy/moved && ls copy copy/b", "copy:\nb/\nmoved\ntop.sh\n\ncopy/b:\nc/\n")
	r := s.run("rm copy")
	if r.Status == 0 || !strings.Contains(r.Stderr, "Is a directory") {
		t.Fatalf("%+v", r)
	}
	s.expect("cd copy/b && rm -r ../../copy && pwd", "/lab\n")
	r = s.run("rm -rf / . ..; rm -r /lab")
	if r.Status == 0 || !s.state.Dirs["/lab"] || !s.state.Dirs["/lab/a"] {
		t.Fatalf("the lab root must survive: %+v", r)
	}
	s.expect("du -s a; df | head -n 1", "1\ta\nFilesystem  Size  Used Avail Use% Mounted on\n")
}

func TestTextUtilities(t *testing.T) {
	s := newSession(t)
	s.expect("printf 'GET /api 200 12\\nPOST /login 500 340\\nGET /api 200 18\\nGET /health 503 2\\n' > access.log", "")
	s.expect("grep -c ' 5[0-9][0-9] ' access.log", "2\n")
	s.expect("grep -E 'POST|health' access.log | cut -d ' ' -f 2", "/login\n/health\n")
	s.expect("grep -in 'get /API' access.log", "1:GET /api 200 12\n3:GET /api 200 18\n")
	s.expect("awk '{ sum += $4 } END { print \"total\", sum, NR }' access.log", "total 372 4\n")
	s.expect("awk '$3 >= 500 { printf \"%s %s\\n\", $2, $3 }' access.log", "/login 500\n/health 503\n")
	s.expect("awk -F' ' 'NR == 2 { print toupper($1), length($2) }' access.log", "POST 6\n")
	s.expect("cut -d ' ' -f 2 access.log | sort | uniq -c | sort -rn | head -n 1", "      2 /api\n")
	s.expect("sed -n 's/^GET \\(\\/[a-z]*\\).*/\\1/p' access.log", "/api\n/api\n/health\n")
	s.expect("sed -E 's/[0-9]+$/<ms>/; 2d' access.log", "GET /api 200 <ms>\nGET /api 200 <ms>\nGET /health 503 <ms>\n")
	s.expect("sed -i 's/GET/get/g' access.log && head -n 1 access.log", "get /api 200 12\n")
	s.expect("echo 'Hello World' | tr 'a-z' 'A-Z' | tr -d 'O'", "HELL WRLD\n")
	s.expect("seq 3 | xargs echo n:", "n: 1 2 3\n")
	s.expect("seq -s , 1 2 7", "1,3,5,7\n")
	s.expect("printf '%-6s|%5.1f|%03d\\n' ok 3.14159 7", "ok    |  3.1|007\n")
	s.expect("echo 'a b c' | awk '{ print $NF, $(NF-1) }'", "c b\n")
	s.expect("printf 'one\\ntwo\\n' > a; printf 'one\\n2\\n' > b; diff a b || echo differ", "2c2\n< two\n---\n> 2\ndiffer\n")
	s.expect("diff -u a b | tail -n 3", " one\n-two\n+2\n")
	s.expect("echo hello | base64 | base64 -d", "hello\n")
	s.expect("wc -l a b", "      2 a\n      2 b\n      4 total\n")
}

func TestOutputKeepsTerminalOrder(t *testing.T) {
	r := run("echo one; cat missing; echo two", initialState(), nil)
	if len(r.Output) != 3 || r.Output[0].Text != "one\n" || !r.Output[1].Error || r.Output[2].Text != "two\n" {
		t.Fatalf("%+v", r.Output)
	}
}

func TestHelpAndUnavailableCommandsExplainThemselves(t *testing.T) {
	r := run("help grep", initialState(), nil)
	if !strings.Contains(r.Stdout, "usage: grep") {
		t.Fatalf("%+v", r)
	}
	r = run("docker run nginx", initialState(), nil)
	if r.Status != 127 || !strings.Contains(r.Stderr, "no container runtime") {
		t.Fatalf("%+v", r)
	}
	r = run("frobnicate", initialState(), nil)
	if r.Status != 127 || !strings.Contains(r.Stderr, "command not found") {
		t.Fatalf("%+v", r)
	}
	r = run("type ls greet if", initialState(), nil)
	if !strings.Contains(r.Stdout, "ls is a shell builtin") || !strings.Contains(r.Stdout, "if is a shell keyword") {
		t.Fatalf("%+v", r)
	}
}

func TestBudgetsStillBoundNewConstructs(t *testing.T) {
	for _, source := range []string{"f() { f; }; f", "for ((;;)); do :; done", "x=$(while true; do :; done)", "awk 'BEGIN { while (1) {} }'"} {
		r := run(source, initialState(), nil)
		if r.Status == 0 {
			t.Fatalf("unbounded %q: %+v", source, r)
		}
	}
	for _, source := range []string{"echo {1..9999999}", "echo {1..200}{1..200}", "echo {a,b}{1..9000}"} {
		if r := run(source, initialState(), nil); r.Status == 0 || !strings.Contains(r.Stderr, "brace expansion") {
			t.Fatalf("unbounded braces %q: %+v", source, r.Stderr)
		}
	}
	if r := run("echo {1..3}{a,b}", initialState(), nil); r.Stdout != "1a 1b 2a 2b 3a 3b\n" {
		t.Fatalf("%+v", r)
	}
	r := run("seq 100000", initialState(), nil)
	if r.Status == 0 {
		t.Fatalf("seq must be bounded: %+v", r.Stderr)
	}
}
