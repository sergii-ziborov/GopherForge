from pathlib import Path
import tempfile,shutil,subprocess,os,json
src=Path('docs/website/reliability-20261029/examples').resolve();out=[]
cases=[('exact-reservation','invariants','if n > c.value {','if n >= c.value {','TestReserveBoundary','exact stock must be reservable'),('snapshot-ownership','invariants','return clone(v.rates)','return v.rates','TestSnapshotOwnership','snapshot leaked mutable ownership'),('payload-identity','retrykey','if old.request != req {\n\t\t\treturn Receipt{}, ErrConflict\n\t\t}','', 'TestChangedInputConflict','changed input did not conflict'),('effect-receipt-boundary','retrykey','s.records[key] = record{request: req, receipt: res}','', 'TestLostReplyReconciliation','effect and receipt missing after lost reply')]
for name,pkg,old,new,test,expected in cases:
 with tempfile.TemporaryDirectory(prefix='gopherforge-reliability-negative-') as tmp:
  lab=Path(tmp)/'lab';shutil.copytree(src,lab);p=lab/pkg/'main.go';s=p.read_text();assert old in s,(name,old);p.write_text(s.replace(old,new,1))
  r=subprocess.run(['go','test','-run','^'+test+'$','-count=1','./'+pkg],cwd=lab,env={**os.environ,'GOTOOLCHAIN':'go1.27.3'},text=True,capture_output=True,timeout=30)
  assert r.returncode!=0 and expected in r.stdout,(name,r.stdout,r.stderr)
  out.append({'case':name,'test':test,'expectedFailureObserved':True,'output':'\n'.join(r.stdout.strip().splitlines()[:6])})
Path('docs/website/reliability-20261029/negative-controls.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
