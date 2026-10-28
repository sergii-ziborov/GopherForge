#!/usr/bin/env python3
"""Execute the 40 complete programs added by the interview audit (Go 1.27+).

GO may select a specific native toolchain. Dependencies are pinned and prepared
before execution; examples use only local httptest sockets, with registry access off.
This validates native Go examples, not WASI compatibility or a real blockchain node.
"""
import json,pathlib,subprocess,os,hashlib,time
root=pathlib.Path(__file__).resolve().parents[1];out=root/'build/curriculum49/corpus';out.mkdir(parents=True,exist_ok=True)
go=os.environ.get('GO','go')
env=os.environ.copy();env.update(GOTOOLCHAIN='local',CGO_ENABLED='0')
(out/'go.mod').write_text('module example.com/gopherforge-curriculum-check\n\ngo 1.27.0\n')
versions=[]
for name,version in [('github.com/gin-gonic/gin','v1.12.0'),('github.com/ethereum/go-ethereum','v1.17.10'),('google.golang.org/grpc','v1.85.0')]:
 r=subprocess.run([go,'list','-m','-json',name+'@'+version],cwd=out,env=env,capture_output=True,text=True,timeout=60)
 if r.returncode:raise RuntimeError(r.stderr)
 m=json.loads(r.stdout);versions.append({'path':name,'version':m['Version'],'goVersion':m.get('GoVersion')})
 with (root/'build/curriculum49/dependencies.log').open('a') as log:
  subprocess.run([go,'get',name+'@'+m['Version']],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
 print('Verified dependency',name,m['Version'],flush=True)
(root/'build/curriculum49/dependency-versions.json').write_text(json.dumps(versions,indent=2)+'\n')
manifest=json.loads((root/'docs/audits/2026-10-28-interview-expansion.json').read_text());ids=set(manifest['lessons']);qids=set(manifest['questions']);examples={}
for r in json.loads((root/'GopherForge/Resources/ReadingLessons.json').read_text()):
 if r['id'] in ids:
  examples[r['id']]=next(s['code'] for s in r['sections'] if s.get('language')=='go')
for q in json.loads((root/'GopherForge/Resources/InterviewPrep.json').read_text())['questions']:
 if q['id'] in qids and not any(q['code']==s for s in examples.values()):examples[q['id']]=q['code']
expected={
'systems.transaction-boundary':['<nil> 3 11','invalid transfer 3 11'], 'systems.outbox-inbox':['true false 1'], 'systems.sagas':['refunding','done <nil>'], 'systems.compatibility':['Ada','A. Lovelace'], 'systems.tenant-isolation':["Ada's order","Grace's order"],
'clean-production.composition':['shared-store','close shared-store'], 'clean-production.context-contracts':['context canceled','request no longer needed','<nil> true'], 'clean-production.package-apis':['7 <nil>'], 'clean-production.time-money':['250ms 199 1000000000000000001 1000000000000000002'],
'gin.routing-middleware':['200 [before handler after]'], 'gin.binding-limits':['400'], 'gin.context-workers':{'accepted 202','work /jobs'}, 'gin.trusted-proxies':['192.0.2.10'], 'gin.errors-testing':['404 {"error":"request failed"}'], 'gin.server-lifecycle':['2s 1m0s 16384'],
'blockchain.rpc-boundaries':['1337'], 'blockchain.exact-units':['1000000000000000001 <nil>'], 'blockchain.abi-calls':['36'], 'blockchain.nonces-outcomes':['42 42 43'], 'blockchain.signing-boundaries':['1337 7 1'], 'blockchain.events-finality':['reconcile canonical ancestor before append'],
'security.identity-authorization':['true','false'], 'security.crypto-purposes':['true','false'], 'security.tls-trust':['true','200 true'], 'concurrency.atomic-snapshots':['4'], 'concurrency.lock-ownership':['1'], 'stdlib.timer-contracts':['one owner received the reset timer'], 'stdlib.http-client-budgets':['response exceeds 3 bytes'],
'systems.rpc-contracts':['true'], 'systems.messaging-offsets':['12','14'], 'systems.consistency-partitions':['false true'], 'algorithms.sort-contract':['[{second 1} {first 2} {third 2}]'], 'algorithms.dfs-cycle':['false <nil>','true <nil>'], 'algorithms.linked-cycle':['true true'], 'algorithms.rendezvous-hashing':['true'], 'testing.cancellation-barriers':['joined'], 'language.writer-contract':['2 true']}
results=[]
for id,source in examples.items():
 folder=out/id;folder.mkdir(exist_ok=True);(folder/'main.go').write_text(source+'\n')
with (root/'build/curriculum49/dependencies.log').open('a') as log:subprocess.run([go,'mod','tidy'],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
# Dependencies are prepared above. Executed examples use no public network; only the named local httptest servers open sockets.
for id,source in examples.items():
 folder=out/id;folder.mkdir(exist_ok=True);(folder/'main.go').write_text(source+'\n')
 env['GOPROXY']='off';started=time.monotonic();r=subprocess.run([go,'run','./'+id],cwd=out,env=env,capture_output=True,text=True,timeout=120)
 assert r.returncode==0,(id,r.stderr)
 lines=r.stdout.strip().splitlines()
 if id in expected:
  want=expected[id];assert (set(lines)==want if isinstance(want,set) else lines==want),(id,lines,want)
 elif id=='systems.observability':
  event=json.loads(r.stdout);assert event['operation']=='place_order' and event['reason']=='insufficient_stock'
 elif id=='blockchain.packages':assert len(lines)==5 and any('ethclient' in x for x in lines)
 elif id=='security.ssrf-egress':
  from urllib.parse import urlsplit,parse_qs
  u=urlsplit(r.stdout.strip());assert u.hostname=='api.vendor.example' and parse_qs(u.query)['id']==['http://127.0.0.1/admin']
 else:raise AssertionError('Missing semantic assertion for '+id)
 results.append({'id':id,'result':'passed','sourceSHA256':hashlib.sha256(source.encode()).hexdigest(),'seconds':round(time.monotonic()-started,3),'stdout':r.stdout.strip()})
 print('PASS',id,flush=True)
(root/'build/curriculum49/example-results.json').write_text(json.dumps({'toolchain':subprocess.check_output([go,'version'],text=True).strip(),'examples':results,'publicNetworkDuringExecution':False,'localHTTPLabs':True},indent=2)+'\n')
print('All',len(results),'new examples passed',flush=True)
# Compile every complete reading program too. Fragments remain explicitly outside
# this gate; only the new examples above are executed with output assertions.
compiled=[]
for reading in json.loads((root/'GopherForge/Resources/ReadingLessons.json').read_text()):
 for index,section in enumerate(reading['sections']):
  source=section.get('code') or ''
  if not source.startswith('package main') or 'func main()' not in source:continue
  name='reading-'+reading['id']+'-'+str(index);folder=out/name
  folder.mkdir(exist_ok=True);(folder/'main.go').write_text(source+'\n')
  r=subprocess.run([go,'test','-run','^$','./'+name],cwd=out,env=env,capture_output=True,text=True,timeout=120)
  assert r.returncode==0,(name,r.stdout,r.stderr)
  compiled.append({'lesson':reading['id'],'section':index,'sourceSHA256':hashlib.sha256(source.encode()).hexdigest()})
  print('COMPILED',name,flush=True)
(root/'build/curriculum49/reading-program-results.json').write_text(json.dumps({'toolchain':subprocess.check_output([go,'version'],text=True).strip(),'compiled':compiled,'fragmentsExcluded':True,'publicNetworkDuringExecution':False},indent=2)+'\n')
print('Compiled',len(compiled),'complete reading programs',flush=True)
