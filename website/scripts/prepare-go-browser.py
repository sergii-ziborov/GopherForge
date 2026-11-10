#!/usr/bin/env python3
"""Package the app's pinned Go/WASI compiler for browser use, without downloads."""
import gzip, hashlib, json, os, pathlib, zipfile
root = pathlib.Path(__file__).resolve().parents[2]
site = root / 'website'
toolchain = root / 'GopherForge/Resources/Toolchain/go1.27.1-wasm-1'
out = site / 'public/toolchain'
out.mkdir(parents=True, exist_ok=True)
manifest_path = site / 'src/lib/go-toolchain.json'
previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
manifest = {'version': 'Go 1.27.1', 'target': 'wasip1/wasm', 'assets': {}}
def hash_bytes(raw): return hashlib.sha256(raw).hexdigest()
def reusable(name):
    item = previous.get('assets', {}).get(name)
    if not item: return None
    path = site / 'public' / item['url'].lstrip('/')
    return item if path.exists() and hash_bytes(path.read_bytes()) == item['sha256'] else None
def asset(name, raw, ext='gz'):
    old = reusable(name)
    if old and old['expandedSHA256'] == hash_bytes(raw):
        manifest['assets'][name] = old
        return
    data = gzip.compress(raw, mtime=0) if ext == 'gz' else raw
    sha = hash_bytes(data)
    filename = f'{name}-{sha[:16]}.{ext}'
    (out / filename).write_bytes(data)
    manifest['assets'][name] = {'url': '/toolchain/' + filename, 'sha256': sha, 'bytes': len(data), 'expandedBytes': len(raw), 'expandedSHA256': hash_bytes(raw)}
for name in ['compile', 'link']:
    asset(name, (toolchain / f'{name}.wasm').read_bytes())
asset('planner', (site / 'build/planner.wasm').read_bytes())
files = [p for p in sorted((toolchain / 'goroot').rglob('*')) if p.is_file()]
def tree_hash(items):
    h=hashlib.sha256()
    for name, contents in items:
        h.update(name.encode()); h.update(b'\0'); h.update(hashlib.sha256(contents).digest())
    return h.hexdigest()
source_hash=tree_hash((p.relative_to(toolchain/'goroot').as_posix(), p.read_bytes()) for p in files)
archive=site/'build/browser-goroot.zip'
old_std=reusable('stdlib')
can_reuse=bool(old_std and previous.get('stdlibSourceSHA256') == source_hash)
if old_std and not can_reuse and archive.exists() and hash_bytes(archive.read_bytes()) == old_std['expandedSHA256']:
    with zipfile.ZipFile(archive) as z:
        can_reuse=tree_hash((n,z.read(n)) for n in sorted(z.namelist()) if not n.endswith('/')) == source_hash
if can_reuse: manifest['assets']['stdlib']=old_std
else:
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in files:
            info=zipfile.ZipInfo(p.relative_to(toolchain/'goroot').as_posix(),date_time=(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,p.read_bytes(),compresslevel=9)
    asset('stdlib',archive.read_bytes(),'zip')
manifest['stdlibSourceSHA256']=source_hash
manifest['standard']=sorted(p.relative_to(toolchain/'goroot/pkg/wasip1_wasm').as_posix()[:-2] for p in (toolchain/'goroot/pkg/wasip1_wasm').rglob('*.a'))
manifest['planner']={'sourceSHA256':tree_hash((p.name,p.read_bytes()) for p in sorted((site/'toolchain').glob('*')) if p.is_file()),'goVersion':os.environ['GOPHERFORGE_PLANNER_VERSION'],'modules':{'golang.org/x/mod':'v0.28.0'}}
manifest['provenance']=json.loads((toolchain/'toolchain-provenance.json').read_text())
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
for notice in ['LICENSE','PATENTS']:(out/notice).write_bytes((toolchain/'goroot'/notice).read_bytes())
print(json.dumps({k:v['bytes'] for k,v in manifest['assets'].items()}))
