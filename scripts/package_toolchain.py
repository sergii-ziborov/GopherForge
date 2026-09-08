#!/usr/bin/env python3
"""Bundle Go export archives as ZIP data, never loose iOS static libraries."""
import hashlib
import shutil
import zipfile
from pathlib import Path

project = Path(__file__).resolve().parent.parent
sources = sorted(p for p in (project / 'GopherForge/Resources/Toolchain').iterdir()
                 if p.is_dir() and (p / '.complete').is_file())
if len(sources) != 1:
    raise SystemExit('Expected exactly one complete Go toolchain; run fetch_toolchain.sh first')
source = sources[0]
output_root = project / 'build/Resources/Toolchain'
output_root.mkdir(parents=True, exist_ok=True)
for old in output_root.iterdir():
    if old.is_dir() and old.name != source.name:
        shutil.rmtree(old)
output = output_root / source.name
output.mkdir(exist_ok=True)
inputs = sorted(p for p in (source / 'goroot').rglob('*') if p.is_file())
if not inputs or not (source / 'goroot/LICENSE').is_file():
    raise SystemExit('Missing Go library data or license')
fingerprint = hashlib.sha256()
for path in inputs:
    fingerprint.update(path.relative_to(source).as_posix().encode() + b'\0')
    fingerprint.update(hashlib.sha256(path.read_bytes()).digest())
identity = fingerprint.hexdigest()
archive = output / 'goroot.zip'
marker = output / '.inputs-sha256'
if not archive.exists() or not marker.exists() or marker.read_text() != identity:
    temporary = output / 'goroot.zip.partial'
    with zipfile.ZipFile(temporary, 'w') as packaged:
        for path in inputs:
            info = zipfile.ZipInfo(path.relative_to(source).as_posix(), (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            packaged.writestr(info, path.read_bytes())
    temporary.replace(archive)
    marker.write_text(identity)
(output / 'goroot.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest())
for name in ['compile.wasm', 'link.wasm', 'vet.wasm', 'gofmt.wasm', 'toolchain-provenance.json', '.complete']:
    if (source / name).exists():
        shutil.copyfile(source / name, output / name)
shutil.copyfile(source / 'goroot/VERSION', output / 'VERSION')
print('Packaged Go toolchain:', output)
