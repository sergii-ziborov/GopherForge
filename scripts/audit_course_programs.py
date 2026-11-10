#!/usr/bin/env python3
"""Check course programs with native Go; private fixtures stay in ignored build/.

The fixtures are exported directly from the Swift catalog, including its private
tests/verified solutions. They must never be copied into the public web export.
Pinned dependency manifests are copied from the previous audited corpus. Registry
access is disabled during verification. Native results do not prove WASI support.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/curriculum53'
GO = os.environ.get('GO', 'go')
ENV = {**os.environ, 'GOTOOLCHAIN': 'local', 'GOPROXY': 'off',
       'GOSUMDB': 'off', 'CGO_ENABLED': '0', 'GOMAXPROCS': '2', 'GOFLAGS': '-p=2'}


def invoke(args, cwd):
    return subprocess.run([GO, *args], cwd=cwd, env=ENV,
                          capture_output=True, text=True, timeout=120)


def require(result, label):
    if result.returncode:
        raise AssertionError((label, result.stdout[-3000:], result.stderr[-3000:]))


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def check_exercise(fixture):
    folder = OUT / 'exercises' / fixture['id']
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'go.mod').write_text('module lesson\n\ngo 1.27.0\n')
    (folder / 'lesson_test.go').write_text(fixture['test'])
    (folder / 'main.go').write_text(fixture['solution'])
    solution = invoke(['test', '-count=1', '-timeout=15s', '.'], folder)
    require(solution, fixture['id'] + ' solution')
    (folder / 'main.go').write_text(fixture['starter'])
    starter = invoke(['test', '-count=1', '-timeout=15s', '.'], folder)
    if starter.returncode == 0:
        raise AssertionError(fixture['id'] + ': unfinished starter passed')
    return {'id': fixture['id'], 'solution': 'passed', 'starter': 'rejected',
            'solutionSHA256': digest(fixture['solution']),
            'hiddenTestSHA256': digest(fixture['test'])}


def check_reading(item):
    lesson, index, source = item
    folder = OUT / 'corpus' / (lesson + '-' + str(index))
    folder.mkdir(exist_ok=True)
    (folder / 'main.go').write_text(source)
    require(invoke(['test', '-run', '^$', './' + folder.name], folder.parent), folder.name)
    return {'id': lesson, 'section': index, 'sourceSHA256': digest(source), 'compile': 'passed'}


EXPECTED = {
    'core.zero-values': '0 "" true 0',
    'core.constants': '0 1 2 3\n1024',
    'core.defer-stack': 'counting\ndone\n2\n1\n0',
    'structs.pointers': '1\n9',
    'structs.escape': 'a b false',
    'collections.length-capacity': '2 4\n5 8',
    'collections.runes-not-bytes': '6 5\n0:h 1:é',
    'collections.bounds': '3 8\n6 8\npanic on index',
    'collections.nil-slice': 'true 0 0\nfalse 1 1\nfalse 0',
    'interfaces.method-sets': '1',
    'interfaces.nil': 'false',
    'interfaces.embedding': 'LOUD ada\nhello from base ada',
    'generics.when-not-to': 'id-7\nid-7',
    'errors.defer': 'end 3 2 1',
    'errors.panic': 'fine\n<nil>\nrecovered: bad state',
    'modules.naming': 'GO\ntrue\nb3w4r3',
    'modules.init': 'var first\nvar second\ninit\nmain first second',
    'stdlib.json': '{"host":"localhost"}',
    'stdlib.time': '1m30s\n1.5\n36h0m0s\ntrue',
}


def check_prediction(fixture):
    lesson = fixture['id']
    folder = OUT / 'predictions' / lesson
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'go.mod').write_text('module prediction\n\ngo 1.27.0\n')
    (folder / 'main.go').write_text(fixture['source'])
    result = invoke(['run', '.'], folder)
    if lesson == 'concurrency.unbuffered-rendezvous':
        assert result.returncode != 0 and 'all goroutines are asleep - deadlock!' in result.stderr
    else:
        require(result, lesson)
        if lesson == 'concurrency.no-handle':
            # One observed outcome cannot establish which schedule must occur.
            assert '42' in result.stdout.splitlines()
            assert set(result.stdout.splitlines()) <= {'42', 'this may never print'}
        else:
            assert ' '.join(result.stdout.split()) == ' '.join(EXPECTED[lesson].split()), (lesson, result.stdout)
    return {'id': lesson, 'sourceSHA256': digest(fixture['source']), 'result': 'matched',
            'stdout': result.stdout.strip(),
            'nondeterministic': lesson == 'concurrency.no-handle',
            'expectedRuntimeFailure': lesson == 'concurrency.unbuffered-rendezvous'}


def check_internal_import():
    # Verify the actual import-tree boundary used by the non-runnable layout drill.
    base = OUT / 'internal-import'
    library = base / 'library'
    (library / 'internal/build').mkdir(parents=True, exist_ok=True)
    (library / 'go.mod').write_text('module example.com/forge\n\ngo 1.27.0\n')
    (library / 'internal/build/build.go').write_text('package build\nfunc Run() {}\n')
    for name, module, allowed in [('allowed', 'example.com/forge/client', True),
                                  ('outside', 'other.example/client', False)]:
        folder = base / name
        folder.mkdir(exist_ok=True)
        (folder / 'go.mod').write_text('module ' + module + '\n\ngo 1.27.0\nrequire example.com/forge v0.0.0\nreplace example.com/forge => ../library\n')
        (folder / 'main.go').write_text('package main\nimport "example.com/forge/internal/build"\nfunc main(){build.Run()}\n')
        result = invoke(['test', '.'], folder)
        if allowed:
            require(result, 'allowed internal importer')
        else:
            assert result.returncode != 0 and 'use of internal package' in result.stderr
    return {'id': 'modules.import-path', 'insideImportTree': 'passed', 'outsideImportTree': 'rejected'}


def main():
    readings = json.loads((ROOT / 'GopherForge/Resources/ReadingLessons.json').read_text())
    fixtures = json.loads((OUT / 'private-fixtures.json').read_text())
    corpus = OUT / 'corpus'
    corpus.mkdir(exist_ok=True)
    for filename in ['go.mod', 'go.sum']:
        shutil.copyfile(ROOT / 'build/curriculum49/corpus' / filename, corpus / filename)
    complete = [(r['id'], i, s['code']) for r in readings for i, s in enumerate(r['sections'])
                if (s.get('code') or '').startswith('package main') and 'func main()' in s['code']]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        exercises = list(pool.map(check_exercise, [f for f in fixtures if f['kind'] == 'compile']))
        print('Verified solutions and rejected starters:', len(exercises), flush=True)
        programs = list(pool.map(check_reading, complete))
        print('Compiled complete reading programs:', len(programs), flush=True)
        predictions = list(pool.map(check_prediction, [f for f in fixtures if f['kind'] == 'predict' and f['id'] != 'modules.import-path']))
    predictions.append(check_internal_import())
    assert len(exercises) == 44 and len(programs) == 98 and len(predictions) == 22
    receipt = {'date': '2026-11-06', 'toolchain': subprocess.check_output([GO, 'version'], text=True).strip(),
               'nativeGo': True, 'provesWASICompatibility': False, 'registryAccessDuringVerification': False,
               'exercises': exercises, 'readingPrograms': programs, 'predictions': predictions,
               'limits': ['Code fragments are excluded from compilation.',
                          'Reading programs are compiled here; execution assertions for the 40 advanced examples and six DevOps examples have separate receipts.',
                          'One observed nondeterministic schedule is not a guarantee of scheduling.']}
    (ROOT / 'docs/curriculum/program-audit-20261106.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('All program checks passed.', flush=True)


if __name__ == '__main__':
    main()
