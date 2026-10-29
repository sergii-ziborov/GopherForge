from pathlib import Path
from html.parser import HTMLParser
import urllib.request,urllib.error,json,sys,re,hashlib,xml.etree.ElementTree as ET
base=sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:3065'
news=sorted(json.load(open('website/src/content/news.json')),key=lambda n:n['editionDate'],reverse=True)
class Cards(HTMLParser):
 def __init__(self):super().__init__();self.card=False;self.images=[];self.links=[];self.pages=[]
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='article' and 'news-card' in a.get('class','').split():self.card=True
  if self.card and tag=='img':self.images.append(a['src'])
  if self.card and tag=='a' and 'data-news-index' in a:self.links.append(a['href'])
  if tag=='a' and a.get('aria-label','').startswith('Page '):self.pages.append(a['href'])
 def handle_endtag(self,tag):
  if tag=='article':self.card=False

def get(path):
 with urllib.request.urlopen(base+path,timeout=30) as r:return r.read(),r.headers
rows=[];all_links=[];all_images=[]
for page in range(1,5):
 path='/news' if page==1 else f'/news/page/{page}'
 raw,headers=get(path);html=raw.decode();p=Cards();p.feed(html)
 expected=news[(page-1)*9:page*9];links=['/news/'+n['slug'] for n in expected]
 assert p.links==links,(page,p.links,links)
 assert len(p.images)==len(expected) and len(p.pages)==4
 assert f'rel="canonical" href="https://gopherforge.app{path}"' in html
 collection=next(json.loads(s) for s in re.findall(r'<script type="application/ld\+json">(.*?)</script>',html) if json.loads(s).get('@type')=='CollectionPage')
 assert collection['url']=='https://gopherforge.app'+path
 assert [a['position'] for a in collection['mainEntity']['itemListElement']]==list(range((page-1)*9+1,min(page*9,33)+1))
 for src in p.images:
  body,h=get(src);assert 'image/webp' in h['Content-Type']
  assert hashlib.sha256(body).digest()==hashlib.sha256((Path('website/public')/src.lstrip('/')).read_bytes()).digest()
 all_links+=p.links;all_images+=p.images
 rows.append({'page':page,'cardsWithoutJavaScript':len(p.links),'imageResponses':'200 and SHA256 matched','selfCanonicalAndCollectionPositions':'passed'})
assert len(set(all_links))==33 and len(set(all_images))==33
assert urllib.request.urlopen(base+'/news/page/1').url==base+'/news'
for bad in ['0','5','99','02','invalid']:
 try:get('/news/page/'+bad);raise AssertionError('Invalid page accepted')
 except urllib.error.HTTPError as e:assert e.code==404,(bad,e.code)
xml,_=get('/sitemap.xml');tree=ET.fromstring(xml);urls=[e.text for e in tree.findall('.//{http://www.sitemaps.org/schemas/sitemap/0.9}loc')]
assert len(urls)==457
assert all('https://gopherforge.app/news/page/'+str(i) in urls for i in [2,3,4])
rss,_=get('/news/rss.xml');assert len(ET.fromstring(rss).findall('./channel/item'))==33
r={'base':base,'pages':rows,'uniqueArticles':33,'uniqueCardImages':33,'page1RedirectAndInvalid404':'passed','sitemapURLs':457,'RSSItems':33}
Path('docs/website/news-archive-20261029/'+('live' if base.startswith('https:') else 'local')+'-verification.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
