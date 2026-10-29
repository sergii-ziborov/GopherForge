from pathlib import Path
import tempfile,shutil,subprocess,json,os
root=Path(__file__).resolve().parent;results=[]
go=os.environ.get('GO', 'go')
cases=[('textlab','byte boundary correction removed','\tfor end > 0 && !utf8.RuneStart(s[end]) {\n\t\tend--\n\t}','', 'TestBytePrefixAtEveryBoundary'),('textlab','valid replacement character rejected','value == utf8.RuneError && width == 1','value == utf8.RuneError','TestInvalidVersusReplacement'),('textlab','rune prefix off by one','count == n','count+1 == n','TestPrefixRunes'),('textlab','non-ASCII bytes allowed in wire key',"\t\tc := s[i]","\t\tc := s[i]\n\t\tif c >= 128 { continue }",'TestWireKeyAndSimpleFolding'),('normlab','compatibility normalization substituted','return norm.NFC.String(s), nil','return norm.NFKC.String(s), nil','TestCanonicalNotCompatibility'),('normlab','invalid UTF-8 rejection removed','if !utf8.ValidString(s) {','if false && !utf8.ValidString(s) {','TestInvalidAndConfusable')]
for mod,name,old,new,test in cases:
 source=(root/mod/'main.go').read_text();assert old in source
 with tempfile.TemporaryDirectory(prefix='gopherforge-unicode-negative-') as td:
  p=Path(td)
  if mod=='textlab':
   shutil.copy(root/'go.mod',p/'go.mod');shutil.copytree(root/mod,p/mod);target=p/mod/'main.go';pkg='./textlab'
  else:
   shutil.copytree(root/mod,p,dirs_exist_ok=True);target=p/'main.go';pkg='.'
  target.write_text(source.replace(old,new,1))
  r=subprocess.run([go,'test','-run','^'+test+'$',pkg],cwd=p,env={**os.environ,'GOTOOLCHAIN':'local','GOPROXY':'off'},capture_output=True,text=True,errors="replace",timeout=30)
  assert r.returncode!=0 and '--- FAIL: '+test in r.stdout,(name,r.stdout,r.stderr)
  results.append({'mutation':name,'test':test,'expectedFailure':True})
(root/'negative-controls.json').write_text(json.dumps(results,indent=2)+'\n');print('6 intended failures confirmed')
