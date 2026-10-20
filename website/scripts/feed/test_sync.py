import importlib.util, pathlib, tempfile, unittest, json
spec=importlib.util.spec_from_file_location('sync',pathlib.Path(__file__).with_name('sync.py'))
sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)
ATOM=b'''<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Example</title><published>2026-10-20T10:00:00Z</published><author><name>A. Author</name></author><link href="https://go.dev/blog/example"/><content type="html">&lt;h2&gt;Heading&lt;/h2&gt;&lt;p&gt;Whole explanation &amp;amp; detail.&lt;/p&gt;&lt;pre&gt;x := 1\nfmt.Println(x)&lt;/pre&gt;&lt;script&gt;steal()&lt;/script&gt;&lt;p&gt;Final paragraph.&lt;/p&gt;</content></entry></feed>'''
class FeedTest(unittest.TestCase):
 def test_complete_text_code_and_attribution(self):
  e=sync.parse(ATOM)[0]
  self.assertEqual(e['author'],'A. Author');self.assertEqual(e['license'],'CC BY 4.0')
  self.assertEqual(e['blocks'][1]['text'],'Whole explanation & detail.')
  self.assertEqual(e['blocks'][2],{'kind':'pre','text':'x := 1\nfmt.Println(x)'})
  self.assertEqual(e['blocks'][-1]['text'],'Final paragraph.')
  self.assertNotIn('steal',json.dumps(e))
 def test_rejects_entities_oversize_wrong_source_and_empty_feed(self):
  for data in (b'<!DOCTYPE feed>'+ATOM,b'x'*(sync.LIMIT+1),ATOM.replace(b'go.dev/blog/',b'evil.example/blog/'),b'<feed xmlns="http://www.w3.org/2005/Atom"/>'):
   with self.assertRaises(ValueError):sync.parse(data)
 def test_last_good_cache_survives_error(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);fixture=root/'feed.xml';fixture.write_bytes(ATOM)
   self.assertEqual(sync.sync(root,fixture),1);good=(root/'feed.json').read_bytes()
   fixture.write_bytes(b'broken')
   with self.assertRaises(Exception):sync.sync(root,fixture)
   self.assertEqual((root/'feed.json').read_bytes(),good)
   self.assertFalse(json.loads((root/'status.json').read_text())['ok'])
 def test_no_unsafe_links_or_redirects(self):
  self.assertEqual(sync.safe_url('javascript:alert(1)'), '')
  self.assertEqual(sync.safe_url('https://user:password@go.dev/'), '')
  with self.assertRaises(ValueError):sync.HTTPSOnly().redirect_request(None,None,302,'',{},'https://127.0.0.1/')
if __name__=='__main__':unittest.main()
