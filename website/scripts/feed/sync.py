#!/usr/bin/env python3
"""Import complete, licensed Go Blog Atom bodies. No scraping or generated news."""
import argparse, datetime as dt, fcntl, hashlib, html, json, os, pathlib, re, ssl, sys
import urllib.request, urllib.parse, xml.etree.ElementTree as ET
from html.parser import HTMLParser

FEED = 'https://go.dev/blog/feed.atom'
LIMIT = 4 * 1024 * 1024
NS = {'a': 'http://www.w3.org/2005/Atom'}


def safe_url(value, base=FEED):
    url = urllib.parse.urljoin(base, value)
    p = urllib.parse.urlsplit(url)
    return url if p.scheme == 'https' and p.hostname and not p.username and not p.password else ''


class Body(HTMLParser):
    """Convert HTML into inert reader blocks while retaining full text and code."""
    def __init__(self, base):
        super().__init__(convert_charrefs=True)
        self.base, self.blocks, self.buf, self.kind, self.skip, self.pre = base, [], [], 'p', 0, False
        self.links = []

    def flush(self):
        text = ''.join(self.buf)
        if self.kind != 'pre': text = re.sub(r'\s+', ' ', text).strip()
        if text.strip(): self.blocks.append({'kind': self.kind, 'text': text})
        self.buf = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('script', 'style', 'iframe', 'object', 'svg'):
            self.skip += 1
            return
        if self.skip: return
        if tag in ('p', 'h1', 'h2', 'h3', 'h4', 'li', 'pre', 'blockquote', 'figcaption'):
            self.flush()
            self.kind = 'h2' if tag in ('h1','h2') else 'h3' if tag in ('h3','h4') else 'pre' if tag == 'pre' else 'li' if tag == 'li' else 'p'
            self.pre = tag == 'pre'
        elif tag == 'br': self.buf.append('\n' if self.pre else ' ')
        elif tag == 'a':
            url = safe_url(attrs.get('href',''), self.base)
            if url and url not in self.links: self.links.append(url)
        elif tag == 'img':
            # Third-party media is not republished; retain the descriptive text.
            if attrs.get('alt'): self.buf.append(' [Illustration: ' + attrs['alt'] + '] ')
        elif tag in ('td', 'th'): self.buf.append(' | ')

    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'iframe', 'object', 'svg'):
            self.skip = max(0, self.skip - 1)
            return
        if self.skip: return
        if tag in ('p','h1','h2','h3','h4','li','pre','blockquote','figcaption','tr'):
            self.flush(); self.kind = 'p'; self.pre = False

    def handle_data(self, data):
        if not self.skip: self.buf.append(data)


def parse(data):
    if len(data) > LIMIT or re.search(br'<!\s*(DOCTYPE|ENTITY)', data, re.I):
        raise ValueError('Unsafe or oversized Atom feed')
    root = ET.fromstring(data)
    if root.tag != '{http://www.w3.org/2005/Atom}feed': raise ValueError('Expected Atom')
    entries = []
    for e in root.findall('a:entry', NS)[:20]:
        links = e.findall('a:link', NS)
        source = next((safe_url(x.get('href','')) for x in links if x.get('rel','alternate') == 'alternate'), '')
        if urllib.parse.urlsplit(source).hostname != 'go.dev' or not urllib.parse.urlsplit(source).path.startswith('/blog/'):
            continue
        content = e.find('a:content', NS)
        if content is None: continue
        if content.get('type') not in ('html', 'xhtml'): continue
        raw = content.text or ''
        if content.get('type') == 'xhtml': raw = ''.join(ET.tostring(x, encoding='unicode') for x in content)
        if len(raw) > 300000: raise ValueError('Entry too large')
        reader = Body(source); reader.feed(raw); reader.flush()
        if not reader.blocks: continue
        date = e.findtext('a:published', None, NS) or e.findtext('a:updated', '', NS)
        parsed = dt.datetime.fromisoformat(date.replace('Z','+00:00'))
        if parsed.tzinfo is None: raise ValueError('Date lacks timezone')
        text = ' '.join(b['text'] for b in reader.blocks)
        author = ', '.join(x.text for x in e.findall('a:author/a:name', NS) if x.text) or 'The Go team'
        entries.append({'id': hashlib.sha256(source.encode()).hexdigest()[:16],
            'title': e.findtext('a:title','',NS), 'author': author, 'source': 'The Go Blog',
            'sourceURL': source, 'publishedAt': parsed.isoformat(), 'blocks': reader.blocks,
            'links': reader.links, 'wordCount': len(text.split()),
            'license': 'CC BY 4.0', 'licenseURL': 'https://creativecommons.org/licenses/by/4.0/',
            'licenseEvidence': 'https://go.dev/copyright',
            'excerpt': re.sub(r'\s+',' ', e.findtext('a:summary','',NS)).strip()[:400]})
    if not entries: raise ValueError('No complete licensed entries; retaining last good cache')
    return sorted({e['sourceURL']:e for e in entries}.values(), key=lambda e:e['publishedAt'], reverse=True)


class HTTPSOnly(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).hostname != 'go.dev' or urllib.parse.urlsplit(newurl).scheme != 'https':
            raise ValueError('Unexpected feed redirect')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch():
    context = ssl.create_default_context()
    # macOS command-line Python can lack the OS certificate bundle.
    try:
        import certifi
        context.load_verify_locations(certifi.where())
    except ImportError: pass
    opener = urllib.request.build_opener(HTTPSOnly(), urllib.request.HTTPSHandler(context=context))
    req = urllib.request.Request(FEED, headers={'User-Agent':'GopherForgeNews/1.0 (+https://gopherforge.app/news/feed)', 'Accept':'application/atom+xml'})
    with opener.open(req, timeout=20) as r:
        data = r.read(LIMIT+1)
    return data


def atomic(path, value):
    tmp = path.with_name(path.name+'.tmp')
    with open(tmp, 'w') as f:
        json.dump(value, f, ensure_ascii=False); f.write('\n'); f.flush(); os.fsync(f.fileno())
    os.chmod(tmp, 0o644); os.replace(tmp, path)


def sync(directory, fixture=None):
    directory.mkdir(parents=True,exist_ok=True)
    with open(directory/'sync.lock','w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        now = dt.datetime.now(dt.timezone.utc).isoformat()
        try:
            incoming = parse(pathlib.Path(fixture).read_bytes() if fixture else fetch())
            previous = json.loads((directory/'feed.json').read_text()) if (directory/'feed.json').exists() else {}
            merged = {x['sourceURL']: x for x in previous.get('entries',[])}
            merged.update({x['sourceURL']: x for x in incoming})
            entries = sorted(merged.values(),key=lambda e:e['publishedAt'],reverse=True)[:100]
            atomic(directory/'feed.json', {'schema':1,'checkedAt':now,'sourceFeed':FEED,'entries':entries})
            atomic(directory/'status.json', {'lastAttempt':now,'lastSuccess':now,'ok':True,'entries':len(entries)})
            return len(entries)
        except Exception:
            old = json.loads((directory/'status.json').read_text()) if (directory/'status.json').exists() else {}
            atomic(directory/'status.json', {**old,'lastAttempt':now,'ok':False})
            raise


if __name__ == '__main__':
    p=argparse.ArgumentParser(); p.add_argument('--directory',required=True); p.add_argument('--fixture')
    a=p.parse_args()
    try: print(json.dumps({'entries':sync(pathlib.Path(a.directory),a.fixture),'status':'ok'}))
    except Exception as e: print('Feed sync failed: '+type(e).__name__,file=sys.stderr); sys.exit(1)
