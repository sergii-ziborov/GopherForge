import pathlib,json,subprocess,os,statistics,re,datetime
root=pathlib.Path('build/memory-20261029');exe=root/'memlab';env={k:v for k,v in os.environ.items() if k not in ['GOGC','GOMEMLIMIT']};rows=[]
for mode,gogc,limit in [('gc','50',None),('gc','100',None),('gc','200',None),('gc','200','32MiB'),('chain','100',None),('tree','100',None),('view','100',None),('clip','100',None),('copy','100',None)]:
 for repeat in range(3):
  e={**env,'GOGC':gogc}
  if limit:e['GOMEMLIMIT']=limit
  r=json.loads(subprocess.check_output([str(exe),'-mode',mode],env=e,text=True));r['repeat']=repeat+1;rows.append(r)
profile=json.loads(subprocess.check_output([str(exe),'-mode','profile','-out',str(root/'heap.pprof')],env={**env,'GOGC':'100'},text=True))
for index in ['alloc_space','inuse_space']:
 text=subprocess.check_output(['go','tool','pprof','-top','-sample_index='+index,'-nodecount=10',str(exe),str(root/'heap.pprof')],env={**env,'GOTOOLCHAIN':'go1.27.3'},text=True,stderr=subprocess.STDOUT);(root/(index+'.txt')).write_text(text)
summary=[]
for key in [('gc','50',''),('gc','100',''),('gc','200',''),('gc','200','32MiB'),('chain','100',''),('tree','100',''),('view','100',''),('clip','100',''),('copy','100','')]:
 group=[r for r in rows if (r['mode'],r['gogc'],r['gomemlimit'])==key]
 item=dict(zip(['mode','gogc','gomemlimit'],key))
 for field in ['collections_during_loop','heap_goal_bytes','heap_after_gc_delta_bytes','scan_heap_delta_bytes','allocation_loop_ms','forced_gc_ms_median','graph_depth','token_cap']:
  if field in group[0]:item[field+'_median']=statistics.median(r[field] for r in group)
 summary.append(item)
report={'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'toolchain':'go1.27.3 darwin/arm64','gomaxprocs':2,'repeatsPerCase':3,'rows':rows,'summary':summary,'profile':profile,'method':'Each case is a fresh process. GC workload holds 12 MiB and allocates 512 x 512 KiB. Graph cases use 100,000 nodes of identical type and N-1 edges, discard construction indices, then time seven complete forced collections. Measurements are local observations, not production benchmarks, pure mark-time measurements, RSS limits, or universal graph-shape rankings.'}
p=pathlib.Path('docs/website/memory-20261029/research-results.json');p.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(summary,indent=2))
