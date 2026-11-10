"""Publish byte-identical, complete course documents and the app's pinned index."""
from pathlib import Path
import json,hashlib,shutil,sys
root=Path(__file__).resolve().parents[1]
out=root/'website/public/downloads/courses';out.mkdir(parents=True,exist_ok=True)
labels={
 'go':('Go: language and services','Go language, runtime, service design, patterns, security and coding agents.'),
 'devops':('DevOps and reliability','Command line, containers, Kubernetes, delivery, SLOs and incident recovery.'),
 'interview':('Interview preparation','Worked interview guides and interactive algorithm walkthroughs.')}
manifest=[]
source_dir=Path(sys.argv[1]) if len(sys.argv)>1 else root/'build/Resources/CourseFixtures'
fixtures=root/'build/Resources/CourseFixtures'
fixtures.mkdir(parents=True,exist_ok=True)
for id in labels:
 candidates=list(source_dir.glob(id+'-*.gfcourse.json'))
 assert len(candidates)==1, 'Generate into a clean directory before creating the catalog'
 source=candidates[0]
 data=source.read_bytes();pack=json.loads(data);lessons=[x for u in pack['units'] for x in u['lessons']]
 kinds=[next(iter(x['task'])) for x in lessons]
 item=dict(id=id,title=labels[id][0],summary=labels[id][1],revision=pack['revision'],fileName=source.name,
  byteCount=len(data),sha256=hashlib.sha256(data).hexdigest(),lessonIDs=[x['id'] for x in lessons],
  unitCount=len(pack['units']),teachingCount=sum(x!='predict' for x in kinds),challengeCount=kinds.count('predict'),
  interviewCount=len(pack.get('interview',{}).get('questions',[])),labCount=len(pack['labs']),interviewIDs=[q['id'] for q in pack.get('interview',{}).get('questions',[])])
 manifest.append(item);shutil.copyfile(source,out/source.name)
 if source.resolve() != (fixtures/source.name).resolve():shutil.copyfile(source,fixtures/source.name)
 (out/(source.name+'.sha256')).write_text(item['sha256']+'  '+source.name+'\n')
encoded=json.dumps(manifest,indent=2,ensure_ascii=False)+'\n'
(root/'GopherForge/Resources/CourseDownloads.json').write_text(encoded)
(out/'catalog.json').write_text(encoded)
(root/'website/src/content/course-downloads.json').write_text(encoded)
print('\n'.join(f"{x['id']}: {x['byteCount']:,} bytes, {x['teachingCount']} teaching + {x['challengeCount']} challenges, {x['interviewCount']} interview guides" for x in manifest))
