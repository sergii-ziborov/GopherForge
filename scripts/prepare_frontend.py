#!/usr/bin/env python3
"""Build-time preparation only. The installed iOS app never downloads these tools."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

root = Path(__file__).resolve().parent.parent
source = root / "tools/frontend-bundler"
pins = json.loads((source / "packages.json").read_text())
out = root / "build/Resources/Frontend"
cache = root / "build/frontend-downloads"
out.mkdir(parents=True, exist_ok=True)
cache.mkdir(parents=True, exist_ok=True)
fingerprint = hashlib.sha256(b"".join(p.read_bytes() for p in sorted(source.glob("*.go"))) + b"".join((source / n).read_bytes() for n in ["go.mod", "go.sum", "packages.json", "THIRD_PARTY_NOTICES.txt"]) + Path(__file__).read_bytes()).hexdigest()
manifest = out / "manifest.json"
if manifest.exists():
    old = json.loads(manifest.read_text())
    if old.get("sourceSHA256") == fingerprint and all(
        (out / n).exists() and hashlib.sha256((out / n).read_bytes()).hexdigest() == h
        for n, h in old.get("sha256", {}).items()
    ) and len(old.get("sha256", {})) == 3:
        print("Verified offline frontend tool and packages")
        raise SystemExit(0)

packages = []
for pin in pins["packages"]:
    archive = cache / (pin["name"].replace("/", "-") + "-" + pin["version"] + ".tgz")
    if not archive.exists():
        subprocess.run(["/usr/bin/curl", "--fail", "--location", "--retry", "2", "--silent", "--show-error", "--max-time", "120", pin["url"], "--output", str(archive)], check=True)
    data = archive.read_bytes()
    algorithm, expected = pin["integrity"].split("-", 1)
    assert algorithm == "sha512" and base64.b64encode(hashlib.sha512(data).digest()).decode() == expected, pin["name"]
    files = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        for member in tar:
            if member.isdir():
                continue
            assert member.isfile() and member.name.startswith("package/")
            relative = member.name.removeprefix("package/")
            assert all(p not in ["", ".", ".."] for p in relative.split("/"))
            if Path(relative).suffix not in [".js", ".mjs", ".cjs", ".json", ".md", ".txt"] and Path(relative).name != "LICENSE":
                continue
            assert member.size <= 8 * 1024 * 1024
            files[relative] = tar.extractfile(member).read().decode("utf-8")
    assert "package.json" in files and "LICENSE" in files
    assert json.loads(files["package.json"])["version"] == pin["version"]
    packages.append({"name": pin["name"], "version": pin["version"], "integrity": pin["integrity"], "dependencies": pin["dependencies"], "files": files})
(out / "packages.json").write_text(json.dumps({"format": 1, "packages": packages}, ensure_ascii=False, separators=(",", ":")) + "\n")
shutil.copyfile(source / "THIRD_PARTY_NOTICES.txt", out / "THIRD_PARTY_NOTICES.txt")
go = os.environ.get("GOPHERFORGE_FRONTEND_GO") or shutil.which("go")
if not go:
    raise SystemExit("Go 1.24+ is required to prepare the offline frontend compiler")
environment = dict(os.environ, GOOS="wasip1", GOARCH="wasm", CGO_ENABLED="0", GOTOOLCHAIN="local")
subprocess.run([go, "build", "-mod=readonly", "-trimpath", "-ldflags=-s -w", "-o", str(out / "bundler.wasm"), "."], cwd=source, env=environment, check=True)
manifest.write_text(json.dumps({"format": 1, "esbuild": pins["esbuild"], "sourceSHA256": fingerprint, "sha256": {n: hashlib.sha256((out / n).read_bytes()).hexdigest() for n in ["bundler.wasm", "packages.json", "THIRD_PARTY_NOTICES.txt"]}}, indent=2) + "\n")
print("Prepared offline esbuild WASI compiler and React package catalog")
