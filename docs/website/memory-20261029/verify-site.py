import json,re,urllib.request,xml.etree.ElementTree as ET,sys,pathlib,hashlib,io,zipfile
base=sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:3065'; ns=json.load(open('website/src/content/news.json'));posts=[n for n in ns if n['imagePrefix'] in ['gcpacer','heapgraph','alloclab']];links=set();checks=[]
def get(p):
 with urllib.request.urlopen(base+p,timeout=30) as r:return r.read(),dict(r.headers)
for n in posts:
 path='/news/'+n['slug'];raw,headers=get(path);html=raw.decode();canonical='https://gopherforge.app'+path
 assert '<h1>'+n['title']+'</h1>' in html
 assert 'rel="canonical" href="'+canonical+'"' in html
 blocks=[json.loads(t) for t in re.findall(r'<script type="application/ld\+json">(.*?)</script>',html)];article=next(t for t in blocks if t.get('@type')=='TechArticle')
 assert article['mainEntityOfPage']==canonical and article['datePublished']=='2026-10-29T00:00:00Z' and len(article['image'])==3 and article['wordCount']==n['wordCount']
 assert n['editionDate'] in html and 'Published' in html
 assert n['description'].replace('&','&amp;') in html
 for suffix in ['hero','detail','infographic']:
  im='/images/news/'+n['imagePrefix']+'-'+suffix+'.webp';data,h=get(im);assert len(data)>10000 and 'image/webp' in h['Content-Type']
 for s in n['sections']:
  for match in re.finditer(r'\]\((/[^)#]+)(?:#[^)]*)?\)',s['body']):links.add(match[1])
 checks.append({'edition':n['editionDate'],'slug':n['slug'],'proseWords':n['wordCount'],'SEO':'canonical + TechArticle + dates + description + three images passed'})
for path in sorted(links):assert get(path)[0],path
xml,_=get('/sitemap.xml');sitemap=ET.fromstring(xml);urls=sitemap.findall('{http://www.sitemaps.org/schemas/sitemap/0.9}url');assert len(urls)==445
for n in posts:
 u=next(u for u in urls if u.find('{http://www.sitemaps.org/schemas/sitemap/0.9}loc').text.endswith(n['slug']));assert len(u.findall('{http://www.google.com/schemas/sitemap-image/1.1}image'))==3
rss,_=get('/news/rss.xml');assert len(ET.fromstring(rss).findall('./channel/item'))==24
archive,_=get('/news');assert all(n['slug'].encode() in archive for n in posts)
zipdata,_=get('/downloads/go-memory-lab-20261029.zip'); z=zipfile.ZipFile(io.BytesIO(zipdata)); hashes=json.loads(z.read('source-hashes.json'));assert all(hashlib.sha256(z.read(p)).hexdigest()==h for p,h in hashes.items())
health,_=get('/api/health');assert json.loads(health)
result={'base':base,'articles':checks,'internalLinksChecked':len(links),'generatedImages':9,'sitemapURLs':len(urls),'RSSItems':24,'downloadSourceHashes':'passed','health':'passed','emptyEditions':'2026-10-04 through 2026-10-12'}
print(json.dumps(result,indent=2));pathlib.Path('docs/website/memory-20261029/'+('live' if base.startswith('https:') else 'local')+'-verification.json').write_text(json.dumps(result,indent=2)+'\n')
