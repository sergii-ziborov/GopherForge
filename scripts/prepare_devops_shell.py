#!/usr/bin/env python3
"""Build the reviewed shell into the signed app; course downloads carry no binaries."""
from pathlib import Path
import hashlib,json,os,platform,shutil,subprocess
root=Path(__file__).resolve().parents[1]
source=root/'packages/devops-shell'
out=root/'build/Resources/DevOpsShell'
inputs=sorted(source.glob('*.go'))+[source/'go.mod',source/'go.sum',Path(__file__)]
h=hashlib.sha256()
for p in inputs:h.update(p.name.encode()+b'\0'+p.read_bytes())
revision=h.hexdigest()
manifest=out/'manifest.json'
if manifest.exists():
 old=json.loads(manifest.read_text())
 if old.get('sourceSHA256')==revision and (out/'shell.wasm').exists() and hashlib.sha256((out/'shell.wasm').read_bytes()).hexdigest()==old.get('sha256'):
  print('DevOps shell is current');raise SystemExit(0)
go=os.environ.get('GOPHERFORGE_SHELL_GO') or shutil.which('go')
if not go:raise SystemExit('Go 1.27.3 is required to build the bundled DevOps shell')
version=subprocess.check_output([go,'version'],text=True)
if 'go1.27.3 ' not in version:
 arch=dict(x86_64='amd64',aarch64='arm64').get(platform.machine(),platform.machine())
 candidate=Path.home()/f'go/pkg/mod/golang.org/toolchain@v0.0.1-go1.27.3.{platform.system().lower()}-{arch}/bin/go'
 if not candidate.exists():raise SystemExit('Set GOPHERFORGE_SHELL_GO to Go 1.27.3')
 go=str(candidate)
out.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,GOOS='wasip1',GOARCH='wasm',CGO_ENABLED='0',GOTOOLCHAIN='local')
subprocess.run([go,'build','-buildvcs=false','-mod=readonly','-trimpath','-ldflags=-s -w','-o',str(out/'shell.wasm'),'.'],cwd=source,env=env,check=True)
wasm=(out/'shell.wasm').read_bytes()
manifest.write_text(json.dumps(dict(schemaVersion='1',go='1.27.3',parser='mvdan.cc/sh/v3@v3.14.1',sourceSHA256=revision,sha256=hashlib.sha256(wasm).hexdigest()),indent=2)+'\n')
module=Path.home()/'go/pkg/mod/mvdan.cc/sh/v3@v3.14.1/LICENSE'
shutil.copyfile(module,out/'PARSER-LICENSE.txt')
goroot=Path(subprocess.check_output([go,'env','GOROOT'],cwd=source,text=True).strip())
shutil.copyfile(goroot/'LICENSE',out/'GO-LICENSE.txt')
(out/'README.txt').write_text('GopherForge bounded local shell. Parser: mvdan.cc/sh/v3 v3.14.1 (BSD-3-Clause). Commands and filesystem interpreter are GopherForge source. No native processes or network handlers.\n')
print(f'Built DevOps shell: {len(wasm):,} bytes')
