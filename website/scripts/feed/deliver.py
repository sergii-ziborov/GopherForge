#!/usr/bin/env python3
"""Copy the host's last-good cache into this site's existing tmpfs, atomically."""
import json, pathlib, subprocess, sys
base=pathlib.Path(sys.argv[1])
def run(*args): return subprocess.run(args,check=True,capture_output=True,text=True).stdout
container='gopherforge-web'
info=json.loads(run('/usr/bin/podman','container','inspect',container))[0]
if info['Config'].get('Labels',{}).get('io.hostwatch.publication')!='gopherforge-web':
    raise RuntimeError('Container ownership mismatch')
if not info['State']['Running']: raise RuntimeError('Site container is stopped')
root='/tmp/gopherforge-news-feed'
run('/usr/bin/podman','exec','--user','10001:10001',container,'node','-e',"require('fs').mkdirSync('/tmp/gopherforge-news-feed',{recursive:true})")
for name in ('feed.json','status.json'):
    path=base/name
    if not path.exists():continue
    if path.stat().st_size>12*1024*1024:raise RuntimeError('Cache exceeds budget')
    run('/usr/bin/podman','cp',str(path),container+':'+root+'/'+name+'.next')
    # /tmp is the operator profile's writable tmpfs; app root stays read-only.
    run('/usr/bin/podman','exec','--user','10001:10001',container,'node','-e',
        "require('fs').renameSync(process.argv[1]+'.next',process.argv[1])",root+'/'+name)
print(json.dumps({'delivery':'ok','container':container}))
