#!/usr/bin/env python3
"""Prepare an external GitHub interoperability fixture outside the shipped app.
Run before the opt-in OfflineGitHubTests. Network is used only by this developer
setup; React builds, Go requests and the WebKit test use no remote runtime.
"""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
repo = root / "build/test-fixtures/react-go-gin"
commit = "08418534efed1b32290ac3b1eb1db296c4bd34ae"
repo.parent.mkdir(parents=True, exist_ok=True)
if not repo.exists():
    subprocess.run(["git", "clone", "--no-checkout", "https://github.com/jbenassi/react-go-gin", str(repo)], check=True)
subprocess.run(["git", "-C", str(repo), "cat-file", "-e", commit], check=True)
files = {'web/src/main.jsx': "import './offline.css';\nimport React from 'react';\nimport {createRoot} from 'react-dom/client';\nimport './index.css';\nimport App from './App';\ncreateRoot(document.getElementById('root')).render(<App/>);\n", 'web/index.html': '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GitHub dogs — offline</title></head><body><div id="root"></div><!-- gopherforge:assets --></body></html>', 'package.json': '{\n  "name": "github-dogs-offline",\n  "private": true,\n  "dependencies": {\n    "react": "19.3.1",\n    "react-dom": "19.3.1"\n  },\n  "scripts": {\n    "build": "gopherforge build",\n    "preview": "gopherforge preview"\n  }\n}', 'gopherforge.frontend.json': '{\n  "entry": "web/src/main.jsx",\n  "html": "web/index.html",\n  "output": "web/dist",\n  "backend": "gin-replay",\n  "backendPaths": [\n    "/dogs"\n  ],\n  "minify": true\n}', 'README.md': "# GitHub React + Gin dogs, offline study adaptation\n\nUpstream: https://github.com/jbenassi/react-go-gin/tree/08418534efed1b32290ac3b1eb1db296c4bd34ae\nMIT License, Copyright (c) 2025 Jason Benassi. See LICENSE.upstream.\n\nThe upstream React App.js and Go server/main.go are unchanged. The build entry,\nHTML and package manifest are adapted from Create React App to GopherForge's\nbundled offline compiler and React 19.3.1. Tests and web-vitals are not installed.\nGin imports use GopherForge's educational compatibility subset, not full Gin.\n\nIn Terminal: npm install --offline, npm run build, then open Output full screen.\nCreate, edit and delete dogs. Requests execute the Go handlers through httptest\nwithout TCP or network. A temporary bounded mutation log reconstructs this\nin-memory service before each request. Rebuilding or reopening the project resets state. This\nmode targets deterministic teaching APIs; it is not a persistent production\nserver, database or networking runtime. Existing limits still apply.\n\nA separate offline.css adapts the form to narrow mobile screens; App.js stays unchanged.\n", 'web/src/offline.css': 'form{flex-wrap:wrap}form>div{flex:1 1 140px}form input{width:100%;box-sizing:border-box}button{min-height:36px}td{overflow-wrap:anywhere}#root{max-width:100vw;overflow-x:auto}\n'}
hashes = {}
for original, target in [("client/src/App.js", "web/src/App.js"), ("client/src/App.css", "web/src/App.css"), ("client/src/index.css", "web/src/index.css"), ("server/main.go", "main.go"), ("LICENSE", "LICENSE.upstream")]:
    content = subprocess.check_output(["git", "-C", str(repo), "show", commit + ":" + original])
    files[target] = content.decode("utf-8")
    hashes[original] = hashlib.sha256(content).hexdigest()
output = repo.parent / "OfflineGitHubDogs.json"
output.write_text(json.dumps({"repository":"https://github.com/jbenassi/react-go-gin", "commit":commit, "upstreamSHA256":hashes, "files":files}, indent=2) + "\n")
print("Prepared developer-only external fixture:", output)
