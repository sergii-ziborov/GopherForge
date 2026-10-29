#!/usr/bin/env python3
"""Daily expiry for explicitly published learning snapshots; never visits projects."""
import datetime, json, pathlib, re
directory = pathlib.Path('/srv/apps/gopherforge/progress-shares')
now = datetime.datetime.now(datetime.timezone.utc)
removed = 0
for path in directory.glob('*.json'):
    if path.is_symlink() or not re.fullmatch(r'[a-f0-9]{32}\.json', path.name):
        continue
    try:
        expires = datetime.datetime.fromisoformat(json.loads(path.read_text())['expiresAt'].replace('Z', '+00:00'))
        if expires <= now:
            path.unlink(); removed += 1
    except (ValueError, KeyError, OSError):
        continue
print(f'Expired progress snapshots removed: {removed}')
