#!/usr/bin/env python3
"""Check and execute the specialized-course readings (Gin, blockchain, security, game development).

GO must name a Go 1.27+ toolchain. `prepare` resolves the pinned dependencies
once; every later run uses GOPROXY=off and opens no public network connection.
Only local httptest recorders and in-process models run. This validates native
Go examples, not WASI compatibility, a real blockchain node or a graphics stack.

  GO=... scripts/verify_specialized_courses.py prepare
  GO=... scripts/verify_specialized_courses.py staging DIR [DIR ...]  # draft lesson files
  GO=... scripts/verify_specialized_courses.py                        # bundled ReadingLessons.json
"""
import hashlib, json, os, pathlib, re, subprocess, sys, time
from urllib.parse import urlsplit

root = pathlib.Path(__file__).resolve().parents[1]
work = root / 'build/specialized-courses'
corpus = work / 'corpus'
expectations_path = root / 'scripts/specialized-course-examples.json'
go = os.environ.get('GO', 'go')
gofmt = str(pathlib.Path(go).with_name('gofmt')) if os.sep in go else 'gofmt'
env = os.environ.copy()
env.update(GOTOOLCHAIN='local', CGO_ENABLED='0', GOFLAGS='-mod=readonly')

PINNED = [('github.com/gin-gonic/gin', 'v1.12.0'), ('github.com/ethereum/go-ethereum', 'v1.17.10'),
          ('golang.org/x/crypto', 'v0.57.0'), ('golang.org/x/time', 'v0.14.0'), ('golang.org/x/sync', 'v0.24.0')]
SEED_IMPORTS = ['github.com/gin-gonic/gin', 'github.com/gin-gonic/gin/binding', 'github.com/go-playground/validator/v10',
                'github.com/ethereum/go-ethereum/common', 'github.com/ethereum/go-ethereum/common/hexutil',
                'github.com/ethereum/go-ethereum/crypto', 'github.com/ethereum/go-ethereum/rlp',
                'github.com/ethereum/go-ethereum/accounts', 'github.com/ethereum/go-ethereum/accounts/abi',
                'github.com/ethereum/go-ethereum/core/types', 'github.com/ethereum/go-ethereum/ethclient',
                'github.com/ethereum/go-ethereum/params', 'golang.org/x/crypto/argon2', 'golang.org/x/crypto/bcrypt',
                'golang.org/x/crypto/sha3', 'golang.org/x/crypto/hkdf', 'golang.org/x/crypto/chacha20poly1305',
                'golang.org/x/time/rate', 'golang.org/x/sync/errgroup', 'golang.org/x/sync/singleflight']

UNITS = {
    'gin-foundations': 'gin', 'gin': 'gin', 'gin-project': 'gin', 'gin-data': 'gin', 'gin-edge': 'gin',
    'blockchain-foundations': 'blockchain', 'blockchain': 'blockchain',
    'security': 'security', 'security-web': 'security', 'security-operations': 'security',
    'gamedev-loop': 'gamedev', 'gamedev-systems': 'gamedev',
}
HOSTS = {"go.dev", "pkg.go.dev", "gin-gonic.com", "github.com", "redis.io", "www.postgresql.org",
         "opentelemetry.io", "geth.ethereum.org", "ethereum.org", "eips.ethereum.org", "www.rfc-editor.org",
         "owasp.org", "cheatsheetseries.owasp.org", "developer.mozilla.org", "prometheus.io", "sre.google",
         "bitcoin.org", "developer.bitcoin.org", "docs.cosmos.network", "ebitengine.org", "gafferongames.com",
         "www.redblobgames.com", "gameprogrammingpatterns.com", "martinfowler.com", "grpc.io", "protobuf.dev",
         "www.cs.columbia.edu", "raft.github.io", "kubernetes.io", "learn.microsoft.com", "docs.github.com"}
CYRILLIC = re.compile('[\\u0400-\\u04FF]')
FIELDS = {'id', 'unitID', 'title', 'objective', 'introduction', 'conceptTag', 'sections', 'takeaway', 'references',
          'reviewPrompt', 'reviewAnswer', 'question', 'wrongAnswers', 'hint', 'nuance', 'designGuide'}


def complete(source):
    return source.startswith('package main') and 'func main()' in source


def check(lesson, stdout, taken):
    e = []
    rid = lesson.get('id', '?')
    missing = FIELDS - set(lesson)
    extra = set(lesson) - FIELDS - {'afterLessonID', 'beforeLessonID'}
    if missing: e.append(f'missing fields {sorted(missing)}')
    if extra: e.append(f'unknown fields {sorted(extra)}')
    if missing: return e
    if not re.fullmatch(r'(gin|blockchain|security|gamedev)\.[a-z0-9-]+', rid): e.append('id must be <gin|blockchain|security|gamedev>.<kebab-slug>')
    if rid in taken: e.append('id already used by a lesson or interview guide')
    if lesson['conceptTag'] != rid: e.append('conceptTag must equal id')
    if lesson['unitID'] not in UNITS: e.append(f'unknown unitID {lesson["unitID"]}')
    if lesson.get('afterLessonID') or lesson.get('beforeLessonID'): e.append('specialized readings are appended; leave afterLessonID/beforeLessonID unset')
    if len(lesson['title']) > 110: e.append('title longer than 110 characters')
    if len(lesson['introduction']) <= 100: e.append('introduction must exceed 100 characters')
    if len(lesson['objective']) < 30: e.append('objective too short')
    sections = lesson['sections']
    if not 4 <= len(sections) <= 8: e.append('use 4 to 8 sections')
    for i, s in enumerate(sections):
        if set(s) - {'title', 'body', 'code', 'language', 'walkthrough'}: e.append(f'section {i}: unknown keys')
        if len(s.get('body') or '') <= 100: e.append(f'section {i}: body must exceed 100 characters')
        if s.get('code'):
            if not s.get('language'): e.append(f'section {i}: code needs language')
            if len(s.get('walkthrough') or '') <= 80: e.append(f'section {i}: code needs a walkthrough over 80 characters')
        elif s.get('language') or s.get('walkthrough'): e.append(f'section {i}: language/walkthrough without code')
    if sections and sections[0].get('body', '').strip() == lesson['introduction'].strip(): e.append('section 0 repeats the introduction verbatim')
    programs = [s['code'] for s in sections if s.get('language') == 'go' and s.get('code') and complete(s['code'])]
    if not programs: e.append('needs at least one complete Go program (package main + func main)')
    if not isinstance(stdout, list) or not stdout or not all(isinstance(x, str) for x in stdout): e.append('verify.stdout must be a non-empty list of exact output lines')
    if len(lesson['takeaway']) <= 80: e.append('takeaway must exceed 80 characters')
    refs = lesson['references']
    if not refs: e.append('needs references')
    for r in refs:
        u = urlsplit(r)
        if u.scheme != 'https' or u.hostname not in HOSTS: e.append(f'reference host not allowed: {r}')
    if len(lesson['reviewPrompt']) > 34: e.append('reviewPrompt over 34 characters')
    if len(lesson['reviewAnswer']) > 58: e.append('reviewAnswer over 58 characters')
    w = lesson['wrongAnswers']
    if len(w) != 2 or len({lesson['reviewAnswer'], *w}) != 3: e.append('need exactly two wrong answers distinct from reviewAnswer')
    if lesson['hint'].strip() == lesson['nuance'].strip(): e.append('hint and nuance must differ')
    if len(lesson['nuance']) <= 30: e.append('nuance must exceed 30 characters')
    if len(lesson['hint']) > 240 or len(lesson['nuance']) > 240: e.append('hint and nuance must each be at most 240 characters')
    g = lesson['designGuide']
    if not isinstance(g, dict) or set(g) != {'family', 'flow', 'strengths', 'cautions', 'cost', 'ratings'}: e.append('designGuide needs family, flow, strengths, cautions, cost, ratings')
    else:
        if len(g['flow']) != 4 or any(len(x) > 28 for x in g['flow']): e.append('designGuide.flow needs exactly 4 steps of at most 28 characters')
        if len(g['strengths']) < 2 or len(g['cautions']) < 2: e.append('designGuide needs at least 2 strengths and 2 cautions')
        if g['ratings'] != []: e.append('designGuide.ratings must be []')
    text = json.dumps(lesson, ensure_ascii=False)
    if CYRILLIC.search(text): e.append('contains Cyrillic text')
    # Public material: no home-directory paths. Names to refuse come from the environment.
    private = [w.lower() for w in os.environ.get('GOPHERFORGE_PRIVATE_WORDS', '').split(',') if w]
    if re.search(r'/Users/[A-Za-z0-9._-]+/', text) or any(w in text.lower() for w in private): e.append('contains a local path or a private word')
    return e


def prepare():
    corpus.mkdir(parents=True, exist_ok=True)
    (corpus / 'go.mod').write_text('module example.com/gopherforge-specialized-courses\n\ngo 1.27.0\n\nrequire (\n' +
                                   ''.join(f'\t{p} {v}\n' for p, v in PINNED) + ')\n')
    seed = corpus / 'seed'; seed.mkdir(exist_ok=True)
    (seed / 'main.go').write_text('package main\n\nimport (\n' + ''.join(f'\t_ "{p}"\n' for p in SEED_IMPORTS) + ')\n\nfunc main() {}\n')
    prep = env.copy(); prep['GOFLAGS'] = '-mod=mod'
    subprocess.run([go, 'mod', 'tidy'], cwd=corpus, env=prep, check=True, timeout=600)
    subprocess.run([go, 'build', '-o', os.devnull, './seed'], cwd=corpus, env=prep, check=True, timeout=600)
    print('Prepared', corpus / 'go.mod')


def run(lesson, stdout):
    """Execute the first complete program and compile every other one."""
    rid, errors, record = lesson['id'], [], {'id': lesson['id'], 'compiled': 0}
    programs = [(i, s['code']) for i, s in enumerate(lesson['sections']) if s.get('language') == 'go' and s.get('code') and complete(s['code'])]
    run_env = env.copy(); run_env['GOPROXY'] = 'off'
    for n, (index, source) in enumerate(programs):
        folder = corpus / (rid if n == 0 else f'{rid}--s{index}')
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / 'main.go'; path.write_text(source + '\n')
        fmt = subprocess.run([gofmt, '-l', str(path)], capture_output=True, text=True)
        if fmt.stdout.strip() or fmt.returncode: errors.append(f'section {index}: not gofmt-formatted (run gofmt)')
        vet = subprocess.run([go, 'vet', './' + folder.name], cwd=corpus, env=run_env, capture_output=True, text=True, timeout=300)
        if vet.returncode: errors.append(f'section {index}: go vet failed:\n{vet.stderr.strip()[:2000]}'); continue
        record['compiled'] += 1
        if n == 0:
            started = time.monotonic()
            r = subprocess.run([go, 'run', './' + folder.name], cwd=corpus, env=run_env, capture_output=True, text=True, timeout=300)
            if r.returncode: errors.append(f'section {index}: go run failed:\n{(r.stderr or r.stdout).strip()[:2000]}'); continue
            lines = r.stdout.rstrip('\n').split('\n') if r.stdout.strip() else []
            if lines != stdout: errors.append(f'section {index}: stdout {lines!r} != expected {stdout!r}')
            record.update(seconds=round(time.monotonic() - started, 3), stdout=r.stdout.strip(), sourceSHA256=hashlib.sha256(source.encode()).hexdigest())
    return errors, record


def existing_ids(exclude=()):
    ids = {r['id'] for r in json.loads((root / 'GopherForge/Resources/ReadingLessons.json').read_text())}
    ids |= {q['id'] for q in json.loads((root / 'GopherForge/Resources/InterviewPrep.json').read_text())['questions']}
    return ids - set(exclude)


def main(argv):
    if argv[:1] == ['prepare']: return prepare()
    if not (corpus / 'go.sum').exists(): raise SystemExit('Run `prepare` first (GO=<go1.27+> scripts/verify_specialized_courses.py prepare)')
    items = []
    if argv[:1] == ['staging']:
        taken = existing_ids()
        files = sorted(p for d in argv[1:] for p in pathlib.Path(d).glob('*.json'))
        for p in files:
            doc = json.loads(p.read_text())
            items.append((str(p.relative_to(root)) if p.is_absolute() and root in p.parents else str(p), doc.get('lesson', {}), doc.get('verify', {}).get('stdout')))
        others = {}
        for d in pathlib.Path(root / 'build/course-expansion/lessons').glob('*/*.json'):
            try: others.setdefault(json.loads(d.read_text())['lesson']['id'], []).append(d)
            except (ValueError, KeyError): pass
    else:
        expected = json.loads(expectations_path.read_text())
        readings = {r['id']: r for r in json.loads((root / 'GopherForge/Resources/ReadingLessons.json').read_text())}
        taken = existing_ids(exclude=expected)
        items = [(rid, readings.get(rid, {}), stdout) for rid, stdout in expected.items()]
        others = {}
    failed, records = 0, []
    for name, lesson, stdout in items:
        errors = check(lesson, stdout, taken)
        if len(others.get(lesson.get('id'), [])) > 1: errors.append('id duplicated in another staging file')
        if not errors:
            more, record = run(lesson, stdout); errors += more; records.append(record)
        if errors:
            failed += 1
            print('FAIL', name); [print('  -', x) for x in errors]
        else:
            print('PASS', name, flush=True)
    work.mkdir(parents=True, exist_ok=True)
    (work / 'results.json').write_text(json.dumps({'toolchain': subprocess.check_output([go, 'version'], text=True).strip(),
        'examples': records, 'publicNetworkDuringExecution': False}, indent=2) + '\n')
    print(f'{len(items) - failed} of {len(items)} lessons passed')
    if failed: raise SystemExit(1)


if __name__ == '__main__':
    main(sys.argv[1:])
