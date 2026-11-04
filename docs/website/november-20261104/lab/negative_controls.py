from pathlib import Path
import tempfile,shutil,subprocess,json,os
root=Path(__file__).resolve().parent;go=os.environ.get('GO', 'go');results=[]
cases=[('genericlab/generic.go','nil policy changed','return nil','return make([]R, 0)','genericlab','TestNamedSliceAndNil'),('embedlab/site.go','catch-all HTML hides missing resources','GET /{$}','GET /','embedlab','TestRoutesStaySeparate'),('cachelab/cache.go','shared budget removed','context.WithTimeout(context.Background(), l.budget)','context.WithCancel(context.Background())','cachelab','TestLoaderOwnBudgetAndInvalidBudget'),('cursorlab/cursor.go','canceled request reused for cleanup','context.WithoutCancel(ctx)','ctx','cursorlab','TestCleanupAfterCancellation'),('tracelab/trace.go','outbound propagation removed','p.Inject(ctx, out)','// deliberately omitted injection','tracelab','TestParentChildPropagationAndNoBaggage'),('fuzzlab/record.go','last delimiter replaces first','strings.IndexByte','strings.LastIndexByte','fuzzlab','TestFirstDelimiterAndUTF8')]
for path,name,old,new,pkg,test in cases:
 source=(root/path).read_text();assert old in source,(name,old)
 with tempfile.TemporaryDirectory(prefix='gopherforge-november-negative-') as td:
  p=Path(td);shutil.copy(root/'go.mod',p/'go.mod');shutil.copy(root/'go.sum',p/'go.sum');shutil.copytree(root/pkg,p/pkg);(p/path).write_text(source.replace(old,new,1))
  r=subprocess.run([go,'test','-run','^'+test+'$','./'+pkg],cwd=p,env={**os.environ,'GOTOOLCHAIN':'local','GOPROXY':'off'},capture_output=True,text=True,errors='replace',timeout=30)
  assert r.returncode!=0 and '--- FAIL: '+test in r.stdout,(name,r.stdout,r.stderr)
  results.append({'mutation':name,'test':test,'expectedFailure':True})
(root/'negative-controls.json').write_text(json.dumps(results,indent=2)+'\n');print('Six intentional mutations failed their targeted tests')
