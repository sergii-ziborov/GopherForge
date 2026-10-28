#!/usr/bin/env python3
"""Prepare an isolated QA Info.plist after xcodegen, before an AuditQA build."""
import pathlib
import plistlib
root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'GopherForge/Resources/Info.plist'
data = plistlib.loads(source.read_bytes())
data['UIFileSharingEnabled'] = True  # Only this separate app exposes disposable fixtures.
data.pop('CFBundleDocumentTypes', None)
data.pop('UTExportedTypeDeclarations', None)
target = root / 'build/AuditQA/Info.plist'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(plistlib.dumps(data, sort_keys=False))
print('Prepared isolated AuditQA document-provider fixtures configuration')
