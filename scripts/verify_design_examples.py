#!/usr/bin/env python3
"""Run complete authored design examples and compare their documented output.

Only programs with a final // Output: block are executable fixtures. Existing
reading fragments are deliberately excluded. No example contacts external services.
"""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / 'GopherForge/Resources/ReadingLessons.json'


def verify(item, race):
    lesson_id, code = item
    source, output = code.rsplit('// Output:\n', 1)
    expected = '\n'.join(line.removeprefix('//').removeprefix(' ') for line in output.rstrip('\n').splitlines()) + '\n'
    env = dict(os.environ, GOWORK='off', GOTOOLCHAIN='local', GOMAXPROCS='2', GOFLAGS='-p=2')
    with tempfile.TemporaryDirectory(prefix='gopherforge-design-') as directory:
        path = Path(directory) / 'main.go'
        path.write_text(source)
        command = ['go', 'run'] + (['-race'] if race and lesson_id.startswith('patterns.') else []) + [str(path)]
        result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=90)
        if result.returncode or result.stdout != expected:
            raise AssertionError(f'{lesson_id}: exit {result.returncode}\nexpected {expected!r}\nactual {result.stdout!r}\n{result.stderr}')
    return lesson_id


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--format', action='store_true', help='Format complete programs in the catalog with gofmt first')
    parser.add_argument('--race', action='store_true', help='Use the race detector for pattern programs')
    args = parser.parse_args()
    readings = json.loads(CATALOG.read_text())
    programs = []
    for reading in readings:
        for section in reading['sections']:
            code = section.get('code') or ''
            if '// Output:\n' not in code:
                continue
            if args.format:
                formatted = subprocess.run(['gofmt'], input=code, capture_output=True, text=True, check=True)
                section['code'] = code = formatted.stdout
            programs.append((reading['id'], code))
    if args.format:
        CATALOG.write_text(json.dumps(readings, ensure_ascii=False, indent=2) + '\n')
    if not programs:
        raise AssertionError('No executable design examples found')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda item: verify(item, args.race), programs))
    print(json.dumps({'passed': len(results), 'raceDetector': args.race, 'goVersion': subprocess.check_output(['go', 'version'], text=True).strip(), 'lessons': results}, indent=2))


if __name__ == '__main__':
    main()
