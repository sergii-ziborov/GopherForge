#!/usr/bin/env python3
"""Operator-only additive setup for the existing primary Hostwatch agent.

Run over authorized SSH after building the exact image. Preserves unrelated
configuration and governance. Registry auth must already cover the repository.
"""
import json, os, shutil, sys, tempfile, time
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else '/etc/hostwatch/agent.json')
config = json.loads(path.read_text())
assert any(r['id'] == 'podman-main' and r['engine'] == 'podman'
           for r in config.get('runtimes', [])), 'Expected local Podman runtime missing'
existing = next((t for t in config.get('imagePublishTargets', [])
                 if t.get('id') == 'applydjin-page-cache-bootstrap'), None)
assert existing and existing['destination'].startswith('localhost:5001/'), 'Inspect registry configuration'
site = {'id':'gopherforge','name':'GopherForge','domains':['gopherforge.app','www.gopherforge.app'],
        'runtimeId':'podman-main','composeProjects':[],
        'systemdUnits':['gopherforge-web.service'],
        'storagePaths':['/srv/apps/gopherforge'],
        'nginxConfig':'/etc/nginx/sites-available/gopherforge'}
target = {'id':'gopherforge-web','runtimeId':'podman-main',
          'source':'localhost/gopherforge-web:2.0.0',
          'destination':'localhost:5001/gopherforge/web:2.0.0',
          'deployment':{'containerName':'gopherforge-web','ports':['127.0.0.1:3047:3000'],
                        'user':'10001:10001','memoryMb':256,'cpus':0.5,
                        'healthUrl':'http://127.0.0.1:3047/api/health'}}
for key in ['registryAuthFile','registryCaFile']:
    if key in existing: target[key] = existing[key]
for key, entry in [('sites',site),('imagePublishTargets',target)]:
    old = next((x for x in config.get(key,[]) if x.get('id') == entry['id']),None)
    assert old is None or old == entry, f'{key} entry exists with different settings; inspect before replacing'
    if old is None: config.setdefault(key,[]).append(entry)
assert config.get('imagePublishStatePath'), 'Preserve the configured job state path'
backup = path.with_name(path.name+'.pre-gopherforge-'+time.strftime('%Y%m%d-%H%M%S'))
shutil.copy2(path,backup)
text = json.dumps(config,indent=2)+'\n';json.loads(text)
fd,name=tempfile.mkstemp(prefix='.gopherforge-',dir=path.parent)
try:
    with os.fdopen(fd,'w') as f:
        f.write(text);f.flush();os.fsync(f.fileno())
    st=path.stat();os.chmod(name,st.st_mode & 0o777);os.chown(name,st.st_uid,st.st_gid)
    os.replace(name,path)
finally:
    if os.path.exists(name):os.unlink(name)
print(json.dumps({'backup':str(backup),'siteId':site['id'],'targetId':target['id']}))
