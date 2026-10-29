from pathlib import Path
import tempfile, shutil, subprocess, os, json
src=Path('docs/website/memory-20261029/examples').resolve(); cases=[('independent-copy','return bytes.Clone(buf[:n])','return buf[:n:n]','TestIndependentPrefix','copy retained alias'),('equivalent-format','" active="','"active="','TestFormatEquivalence','!='),('complete-graph','i+1 < n','i+1 < n-1','TestGraphShapes','count=9999')]; out=[]
for name,old,new,test,expected in cases:
 with tempfile.TemporaryDirectory(prefix='gopherforge-negative-') as d:
  shutil.copytree(src,Path(d)/'lab'); p=Path(d)/'lab/memory.go'; s=p.read_text(); assert old in s; p.write_text(s.replace(old,new,1).replace('\n\t"bytes"','') if name=='independent-copy' else s.replace(old,new,1))
  r=subprocess.run(['go','test','-run','^'+test+'$','-count=1','.'],cwd=Path(d)/'lab',env={**os.environ,'GOTOOLCHAIN':'go1.27.3'},capture_output=True,text=True,timeout=60)
  assert r.returncode!=0 and expected in r.stdout,(name,r.stdout,r.stderr)
  out.append({'case':name,'mutation':old+' → '+new,'test':test,'expectedFailureObserved':True,'output':r.stdout.strip()})
Path('docs/website/memory-20261029/negative-controls.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps(out,indent=2))
