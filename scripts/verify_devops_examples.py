#!/usr/bin/env python3
"""Compile and independently check the new read-only Go-for-DevOps models."""
import hashlib
import json
import os
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
output = root / 'build/devops53'
output.mkdir(parents=True, exist_ok=True)
go = os.environ.get('GO', 'go')
env = {**os.environ, 'GOTOOLCHAIN': 'local', 'GOPROXY': 'off', 'GOSUMDB': 'off', 'GOMAXPROCS': '2'}
tests = {
 'delivery-loop': (root / 'docs/examples/go-devops-capstone/main_test.go').read_text(),
 'safe-cli': r'''package main
import("bytes";"errors";"strings";"testing")
type brokenWriter struct{}
func(brokenWriter)Write([]byte)(int,error){return 0,errors.New("write failed")}
func TestInputAndOutputFailures(t *testing.T){
 for _,input:=range []string{`{"targets":[]}`,`{"targets":["a","a"]}`,`{"targets":["a"],"aply":true}`,`{"targets":["a"]} {}`,strings.Repeat(" ",4097),`{"targets":["bad\nname"]}`} {
  var out bytes.Buffer;if err:=inspect(strings.NewReader(input),&out);err==nil||out.Len()!=0{t.Fatalf("invalid input accepted: %q %v %q",input,err,out.String())}
 }
 if err:=inspect(strings.NewReader(`{"targets":["a"]}`),brokenWriter{});err==nil{t.Fatal("output failure hidden")}
 var out bytes.Buffer;if err:=inspect(strings.NewReader(`{"targets":["a","b"]}`),&out);err!=nil{t.Fatal(err)}
 if out.String()!="{\"mode\":\"dry-run\",\"count\":2}\n"{t.Fatal(out.String())}
}
''',
 'reconciliation': r'''package main
import("errors";"testing")
func TestConflictLeavesTheNewerStateUntouched(t *testing.T){
 observed:=State{Version:7,Replicas:2};change,err:=plan(3,observed);if err!=nil{t.Fatal(err)}
 current:=State{Version:8,Replicas:5};before:=current
 if !errors.Is(apply(&current,*change),ErrConflict)||current!=before{t.Fatal("lost a newer writer",current)}
 retry,err:=plan(3,current);if err!=nil{t.Fatal(err)};if err:=apply(&current,*retry);err!=nil{t.Fatal(err)}
 if current.Replicas!=3||current.Version!=9{t.Fatal(current)}
 noop,err:=plan(3,current);if err!=nil||noop!=nil{t.Fatal("did not converge")}
 for _,desired:=range []int{-1,21}{if _,err:=plan(desired,current);err==nil{t.Fatal("unbounded replicas")}}
}
''',
 'delivery-artifacts': r'''package main
import("crypto/sha256";"encoding/hex";"testing")
func TestPromotionBindsBytesAndEveryGate(t *testing.T){
 artifact:=[]byte("approved artifact");sum:=sha256.Sum256(artifact);digest:=hex.EncodeToString(sum[:]);good:=Evidence{digest,true,true,true}
 if err:=promote(artifact,good,digest);err!=nil{t.Fatal(err)}
 for _,bad:=range []Evidence{{digest,false,true,true},{digest,true,false,true},{digest,true,true,false},{"wrong",true,true,true}}{if promote(artifact,bad,digest)==nil{t.Fatal("gate was bypassed")}}
 if promote([]byte("unreviewed bytes"),good,digest)==nil{t.Fatal("approved evidence accepted another artifact")}
 if promote(artifact,good,"different approval")==nil{t.Fatal("approval identity ignored")}
}
''',
 'slo-burn': r'''package main
import("math";"testing")
func TestSLOBurnAndMissingEvidence(t *testing.T){
 high:=Window{Total:10000,Bad:200};rate,err:=burn(high,.999);if err!=nil||math.Abs(rate-20)>1e-9{t.Fatal(rate,err)}
 for _,w:=range []Window{{},{Total:1,Bad:2}}{if _,err:=burn(w,.999);err==nil{t.Fatal("invalid evidence accepted")}}
 for _,target:=range []float64{0,1,-1,math.NaN(),math.Inf(1)}{if _,err:=burn(high,target);err==nil{t.Fatal("invalid target accepted")}}
 if yes,err:=page(high,high,.999,14.4);err!=nil||!yes{t.Fatal("sustained current incident not detected")}
 if yes,err:=page(high,Window{Total:1000},.999,14.4);err!=nil||yes{t.Fatal("recovered short window still pages")}
 if _,err:=page(high,high,.999,math.NaN());err==nil{t.Fatal("invalid threshold accepted")}
}
''',
 'incident-recovery': r'''package main
import("strings";"testing")
func TestRecoveryKeepsAcceptedWritesAndChecksCompatibility(t *testing.T){
 if got:=recoveryPlan(Incident{2,1,1,true});!strings.Contains(got,"reconcile accepted writes"){t.Fatal(got)}
 if got:=recoveryPlan(Incident{2,1,1,false});!strings.Contains(got,"isolated restore"){t.Fatal(got)}
 if got:=recoveryPlan(Incident{2,1,2,true});!strings.HasPrefix(got,"candidate:"){t.Fatal(got)}
 if got:=recoveryPlan(Incident{2,3,1,false});!strings.HasPrefix(got,"reject"){t.Fatal(got)}
 if got:=recoveryPlan(Incident{0,0,1,false});!strings.HasPrefix(got,"reject"){t.Fatal(got)}
}
'''
}
expected = {
 'delivery-loop': 'not ready: 503\nready: 204\nversion: 200 {"revision":"local-review"}\n',
 'safe-cli': '{"mode":"dry-run","count":2}\n',
 'reconciliation': 'planned 41 3\napplied <nil> {42 3}\nstale true\nconverged true\n',
 'delivery-artifacts': 'approved <nil>\nchanged artifact identity mismatch\nfailed gate required gate failed\n',
 'slo-burn': 'burn 20.0x page true recovered false missing true\n',
 'incident-recovery': 'candidate: roll back binary; verify route and outcomes\nroll forward or restore separately and reconcile accepted writes\nrehearse isolated restore; do not overwrite the live writer\n'
}
readings = json.loads((root / 'GopherForge/Resources/ReadingLessons.json').read_text())
results = []
for reading in readings:
 if reading['unitID'] != 'devops':
  continue
 for section in reading['sections']:
  code = section.get('code') or ''
  if not code.startswith('package main'):
   continue
  slug = reading['id'].split('.', 1)[1]
  if slug == 'delivery-loop':
   assert code == (root / 'docs/examples/go-devops-capstone/main.go').read_text(), 'Embedded capstone drift'
  directory = output / slug
  directory.mkdir(exist_ok=True)
  (directory / 'go.mod').write_text('module example.com/gopherforge-devops-check\n\ngo 1.27.0\n')
  (directory / 'main.go').write_text(code)
  (directory / 'main_test.go').write_text(tests[slug])
  subprocess.run([go, 'fmt', './...'], cwd=directory, env=env, check=True, capture_output=True, timeout=60)
  check = subprocess.run([go, 'test', '-race', '-count=1', './...'], cwd=directory, env=env, capture_output=True, text=True, timeout=90)
  assert check.returncode == 0, (reading['id'], check.stdout, check.stderr)
  run = subprocess.run([go, 'run', '.'], cwd=directory, env=env, capture_output=True, text=True, timeout=60)
  assert run.returncode == 0 and run.stdout == expected[slug], (reading['id'], run.stdout, run.stderr)
  results.append({'id': reading['id'], 'sourceSHA256': hashlib.sha256(code.encode()).hexdigest(), 'raceTests': 'passed', 'stdout': run.stdout})
  print('PASS', reading['id'], flush=True)
assert len(results) == 6
receipt = {'toolchain': subprocess.check_output([go, 'version'], text=True).strip(), 'publicNetworkDuringExecution': False, 'examples': results}
(root / 'docs/curriculum/devops-20261106-examples.json').write_text(json.dumps(receipt, indent=2) + '\n')
print('All six DevOps examples passed independent assertions and race checks.')
