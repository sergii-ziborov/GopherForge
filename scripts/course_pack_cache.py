from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
inputs=sorted(set([*[p for p in root.glob('GopherForge/Learn/**/*.swift') if p.parent.name not in ['Downloads'] and p.name not in ['LearningProgressStore.swift','LessonDraftStore.swift','LessonAttempt.swift','ReviewScheduler.swift']],*root.glob('scripts/*course_pack*'),root/'scripts/build_course_packs.sh',root/'GopherForge/Learn/Downloads/CoursePackage.swift',*(root/'GopherForge/Resources').glob('*Lessons.json'),root/'GopherForge/Resources/LessonGuides.json',root/'GopherForge/Resources/InterviewPrep.json',root/'GopherForge/Resources/DevOpsLabs.json']))
h=hashlib.sha256()
for p in inputs:
 if p.is_file():h.update(str(p.relative_to(root)).encode()+b'\0'+p.read_bytes())
key=h.hexdigest();stamp=root/'build/course-pack-cache.json'
if sys.argv[-1]=='--check':
 try:
  old=json.loads(stamp.read_text());assert old['source']==key
  for name,digest in old['files'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest
 except (OSError,ValueError,KeyError,AssertionError):raise SystemExit(1)
 print('Complete course packs are current');raise SystemExit(0)
manifest=json.loads((root/'GopherForge/Resources/CourseDownloads.json').read_text())
files=[root/'GopherForge/Resources/CourseDownloads.json',root/'website/public/downloads/courses/catalog.json',root/'website/src/content/course-downloads.json']
for item in manifest:
 files.extend([root/'build/Resources/CourseFixtures'/item['fileName'],root/'website/public/downloads/courses'/item['fileName'],root/'website/public/downloads/courses'/(item['fileName']+'.sha256')])
stamp.write_text(json.dumps(dict(source=key,files={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}),indent=2)+'\n')
