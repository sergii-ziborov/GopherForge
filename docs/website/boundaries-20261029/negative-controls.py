from pathlib import Path
import tempfile,shutil,subprocess,os,json
src=Path('docs/website/boundaries-20261029/examples').resolve();out=[]
cases=[('size-overflow','streamio','io.LimitReader(r, max+1)','io.LimitReader(r, max)','TestLimitBoundary','input "'),('single-document','streamio',None,None,'TestSingleDocument','accepted invalid envelope'),('calendar-day','gotime','return t.AddDate(0, 0, 1)','return t.Add(24 * time.Hour)','TestCalendarAcrossDST','calendar contract'),('timer-cancellation','gotime','case <-ctx.Done():\n\t\treturn false','', 'TestWaitCancellationAndJoin','worker did not join')]
for name,pkg,old,new,test,expected in cases:
 with tempfile.TemporaryDirectory(prefix='gopherforge-boundary-negative-') as tmp:
  lab=Path(tmp)/'lab';shutil.copytree(src,lab);p=lab/pkg/'main.go';s=p.read_text()
  if name=='single-document':
   a=s.index('\tvar extra json.RawMessage');b=s.index('\tif event.ID',a);s=s[:a]+s[b:]
  else:assert old in s,(name,old);s=s.replace(old,new,1)
  p.write_text(s);r=subprocess.run(['go','test','-run','^'+test+'$','-count=1','./'+pkg],cwd=lab,env={**os.environ,'GOTOOLCHAIN':'go1.27.3'},text=True,capture_output=True,timeout=30)
  assert r.returncode!=0 and expected in r.stdout,(name,r.stdout,r.stderr)
  out.append({'case':name,'test':test,'expectedFailureObserved':True,'output':'\n'.join(r.stdout.strip().splitlines()[:6])})
Path('docs/website/boundaries-20261029/negative-controls.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
