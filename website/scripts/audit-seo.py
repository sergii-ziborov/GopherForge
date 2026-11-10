#!/usr/bin/env python3
"""Inspect rendered public pages rather than inferring SEO from source exports."""
import concurrent.futures
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET

BASE = os.environ.get('SITE_URL', 'http://127.0.0.1:3053').rstrip('/')
ORIGIN = 'https://gopherforge.app'
WEB = Path(__file__).resolve().parents[1]


def fetch(path):
    with urllib.request.urlopen(BASE + path, timeout=25) as response:
        return response.read(), dict(response.headers)


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.meta = {}
        self.canonical = []
        self.title = ''
        self.in_title = False
        self.h1 = 0
        self.schemas = []
        self.schema = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'title':
            self.in_title = True
        if tag == 'h1':
            self.h1 += 1
        if tag == 'link' and attrs.get('rel') == 'canonical':
            self.canonical.append(attrs.get('href'))
        if tag == 'meta':
            self.meta[attrs.get('name', attrs.get('property'))] = attrs.get('content', '')
        if tag == 'script' and attrs.get('type') == 'application/ld+json':
            self.schema = ''

    def handle_data(self, data):
        if self.in_title:
            self.title += data
        if self.schema is not None:
            self.schema += data

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
        if tag == 'script' and self.schema is not None:
            self.schemas.append(json.loads(self.schema))
            self.schema = None


def inspect(url):
    path = urllib.parse.urlsplit(url).path or '/'
    body, headers = fetch(path)
    page = Page()
    page.feed(body.decode())
    problems = []
    for ok, label in [
        ([c.rstrip('/') for c in page.canonical] == [url.rstrip('/')], 'canonical identity'),
        (bool(page.title.strip()), 'title'),
        (bool(page.meta.get('description', '').strip()), 'description'),
        (page.meta.get('og:url', '').rstrip('/') == url.rstrip('/'), 'Open Graph URL'),
        (bool(page.meta.get('og:title')), 'Open Graph title'),
        (bool(page.meta.get('og:description')), 'Open Graph description'),
        (bool(page.meta.get('og:image')), 'share image'),
        (page.h1 == 1, 'single primary heading'),
        ('noindex' not in page.meta.get('robots', ''), 'public indexing'),
    ]:
        if not ok:
            problems.append(label)
    return {'path': path, 'title': page.title, 'canonical': page.canonical,
            'ogURL': page.meta.get('og:url'), 'jsonLDBlocks': len(page.schemas),
            'issues': problems}


def main():
    sitemap, _ = fetch('/sitemap.xml')
    urls = [e.text for e in ET.fromstring(sitemap).findall('{*}url/{*}loc')]
    assert len(urls) == len(set(urls))
    assert all((url == ORIGIN or url.startswith(ORIGIN + '/')) and '/progress/' not in url and '/mcp' != urllib.parse.urlsplit(url).path for url in urls)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        pages = list(pool.map(inspect, urls))
    titles = {}
    for page in pages:
        if page['title'] in titles:
            page['issues'].append('duplicate title with ' + titles[page['title']])
        titles[page['title']] = page['path']
    for path in ['/mcp', '/api/playground', '/api/playground/secure']:
        request = urllib.request.Request(BASE + path)
        try:
            response = urllib.request.urlopen(request, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        assert 'noindex' in response.headers.get('X-Robots-Tag', ''), path
    downloads = []
    for path in ['/downloads/gopherforge-mcp-0.1.0.tgz', '/downloads/go-devops-capstone-20261106.zip']:
        data, _ = fetch(path)
        checksum, _ = fetch(path + '.sha256')
        digest = hashlib.sha256(data).hexdigest()
        assert digest == checksum.decode().split()[0], path
        downloads.append({'path': path, 'sha256': digest, 'bytes': len(data)})
    receipt = {'base': BASE, 'pages': len(pages), 'downloads': downloads,
               'issues': [p for p in pages if p['issues']], 'results': pages}
    output = Path(os.environ.get('SEO_RECEIPT', WEB / 'build/seo-20261106.json'))
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'pages': len(pages), 'downloads': len(downloads), 'issues': receipt['issues']}, indent=2))
    assert not receipt['issues'], 'Rendered SEO issues remain'


if __name__ == '__main__':
    main()
