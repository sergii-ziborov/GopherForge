#!/usr/bin/env python3
"""Copy the native course export and owned media into the web build."""
import json, pathlib, shutil, hashlib
web=pathlib.Path(__file__).resolve().parents[1]
root=web.parent
target=web/'src/content'; target.mkdir(parents=True,exist_ok=True)
release=json.loads((target/'releases.json').read_text())
curriculum=release.get('curriculum',release['next'])
source=root/'docs/website/lessons.json'
units=json.loads(source.read_text())
assert len({l['id'] for u in units for l in u['lessons']})==sum(len(u['lessons']) for u in units)
shutil.copyfile(source,target/'course.json')
shutil.copyfile(root/'GopherForge/Resources/InterviewPrep.json',target/'interview.json')
(target/'course-version.json').write_text(json.dumps({'source':'Native GoCourseCatalog + ReadingLessons.json','appVersion':curriculum['version']+' — '+curriculum['status'],'publicAppVersion':release['public']['version'],'catalogSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'units':len(units),'lessons':sum(len(u['lessons']) for u in units),'readings':sum(l['kind']=='reading' for u in units for l in u['lessons'])},indent=2)+'\n')
media=web/'public/images'; media.mkdir(parents=True,exist_ok=True)
for src,name in [('GopherForge/Resources/Assets.xcassets/AppIcon.appiconset/GopherForgeIcon-1024.png','app-icon.png'),('docs/app-store/screenshots/iphone-6.9/00-code.png','workbench.png'),('docs/screenshots/next/architecture-comparison.png','architecture-comparison.png'),('docs/screenshots/next/architecture-landscape.png','architecture-landscape.png')]:
 shutil.copyfile(root/src,media/name)
shutil.copyfile(media/'app-icon.png',web/'src/app/icon.png')
print(f'Synced {len(units)} units and {sum(len(u["lessons"]) for u in units)} lessons from native source.')
