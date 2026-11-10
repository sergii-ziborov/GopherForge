package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestFilesPipelinesVariablesAndScripts(t *testing.T) {
	state := initialState()
	script := "mkdir logs; printf 'ERROR z\\nINFO ok\\nERROR a\\nERROR z\\n' > logs/input; NAME=errors; grep ERROR logs/input | sort | uniq > $NAME; cat errors; wc -l errors"
	r := run(script, state, nil)
	if r.Status != 0 || r.Stdout != "ERROR a\nERROR z\n2\n" {
		t.Fatalf("%+v", r)
	}
	r = run("printf 'if test -f errors; then echo ready; else echo blocked; fi\\n' > verify.sh; sh verify.sh", r.State, nil)
	if r.Status != 0 || r.Stdout != "ready\n" {
		t.Fatalf("%+v", r)
	}
}
func TestBudgetsAndCancellation(t *testing.T) {
	for _, source := range []string{"while true; do :; done", "while true; do echo x; done"} {
		r := run(source, initialState(), nil)
		if r.Status != 2 || !strings.Contains(r.Stderr, "budget") {
			t.Fatalf("unbounded loop: %+v", r)
		}
	}
	calls := 0
	r := run("for x in a b c; do echo $x; done", initialState(), func() bool { calls++; return calls > 3 })
	if r.Status != 2 || !strings.Contains(r.Stderr, "stopped by user") {
		t.Fatalf("%+v", r)
	}
}
func TestNoHostPathsProcessesNetworkOrSyntaxEscapes(t *testing.T) {
	for _, source := range []string{"cat /etc/passwd", "cat ../../control/request.json", "echo x > /control/response.json", "cd /", "cat /lab/../control/request.json"} {
		r := run(source, initialState(), nil)
		if r.Status == 0 {
			t.Fatalf("escaped with %s: %+v", source, r)
		}
	}
	for _, source := range []string{"curl https://example.com", "docker ps", "kubectl get pods", "sudo true", "ln -s /etc/passwd leak", "eval echo x", "exec /bin/sh"} {
		r := run(source, initialState(), nil)
		if r.Status != 127 {
			t.Fatalf("unexpected executor for %s: %+v", source, r)
		}
	}
	for _, source := range []string{"echo changed > marker; echo x &", "echo changed > marker; echo $(pwd)", "echo changed > marker; (true)", "echo changed > marker; x=$((1+1))"} {
		r := run(source, initialState(), nil)
		if r.Status == 0 || len(r.State.Files) != 0 {
			t.Fatalf("unsupported syntax mutated state: %s %+v", source, r)
		}
	}
}
func TestQuotasAndCorruptState(t *testing.T) {
	s := initialState()
	s.Files["/lab/a"] = strings.Repeat("a", maxFile)
	r := run("cat a >> a", s, nil)
	if r.Status != 2 || len(r.State.Files["/lab/a"]) != maxFile {
		t.Fatal("append exceeded file quota")
	}
	s = initialState()
	s.Files["/escape"] = "secret"
	if run("ls", s, nil).Status != 2 {
		t.Fatal("invalid state accepted")
	}
	if run(strings.Repeat(" ", maxSource+1), initialState(), nil).Status != 2 {
		t.Fatal("oversized script accepted")
	}
	s = initialState()
	for i := 0; i < 96; i++ {
		s.Files["/lab/"+string(rune(0x400+i))] = ""
	}
	if run("touch excess", s, nil).Status == 0 {
		t.Fatal("file count quota ignored")
	}
}
func TestExitStatusAndFailedGate(t *testing.T) {
	r := run("if test -f ready; then echo healthy > result; else echo blocked > result; fi", initialState(), nil)
	if r.State.Files["/lab/result"] != "blocked\n" {
		t.Fatalf("%+v", r)
	}
	r = run("touch ready; if test -f ready; then echo healthy > result; fi; false && echo wrong; true || echo wrong", r.State, nil)
	if r.Status != 0 || r.Stdout != "" || r.State.Files["/lab/result"] != "healthy\n" {
		t.Fatalf("%+v", r)
	}
}
func TestEveryLabHasAGenuinePassingSolution(t *testing.T) {
	var labs []struct {
		ID      string            `json:"id"`
		Initial map[string]string `json:"initialFiles"`
		Starter string            `json:"starter"`
		Checks  []struct {
			Path     string  `json:"path"`
			Equals   *string `json:"equals"`
			SameAs   string  `json:"sameAs"`
			SHA256Of string  `json:"sha256Of"`
		} `json:"checks"`
	}
	data, e := os.ReadFile("../../GopherForge/Resources/DevOpsLabs.json")
	if e != nil {
		t.Fatal(e)
	}
	if e = json.Unmarshal(data, &labs); e != nil {
		t.Fatal(e)
	}
	repairs := map[string]string{
		"readiness-gate":      "touch health/ready.flag\n",
		"restore-with-writes": "cp backups/settings.conf live/settings.conf\n",
		"ci-evidence":         "cp src/app.conf release/app.conf\n",
	}
	for _, lab := range labs {
		t.Run(lab.ID, func(t *testing.T) {
			s := initialState()
			for p, v := range lab.Initial {
				s.Files["/lab/"+p] = v
				parts := strings.Split(p, "/")
				d := "/lab"
				for _, part := range parts[:len(parts)-1] {
					d += "/" + part
					s.Dirs[d] = true
				}
			}
			r := run(repairs[lab.ID]+lab.Starter, s, nil)
			if r.Status != 0 {
				t.Fatalf("%+v", r)
			}
			for _, check := range lab.Checks {
				value, exists := r.State.Files["/lab/"+check.Path]
				if !exists {
					t.Fatalf("missing result %s", check.Path)
				}
				switch {
				case check.Equals != nil:
					if value != *check.Equals {
						t.Fatalf("%s: wrong result", check.Path)
					}
				case check.SameAs != "":
					if value != lab.Initial[check.SameAs] {
						t.Fatalf("%s: original artifact was changed", check.Path)
					}
				case check.SHA256Of != "":
					sum := sha256.Sum256([]byte(r.State.Files["/lab/"+check.SHA256Of]))
					if strings.TrimSpace(value) != hex.EncodeToString(sum[:]) {
						t.Fatalf("%s: wrong digest", check.Path)
					}
				default:
					t.Fatal("check has no contract")
				}
			}
		})
	}
}

func TestEmptyAndScopedAssignments(t *testing.T) {
	r := run(`VALUE=; echo "$VALUE"; VALUE=outer; VALUE=inner echo "$VALUE"; echo "$VALUE"`, initialState(), nil)
	if r.Status != 0 || r.Stdout != "\nouter\nouter\n" {
		t.Fatalf("%+v", r)
	}
	r = run("HOME=/outside", initialState(), nil)
	if r.Status != 2 {
		t.Fatal("reserved HOME was accepted")
	}
}
