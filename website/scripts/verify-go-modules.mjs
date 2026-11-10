import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {GoBrowser,sha256} from '../src/lib/go-browser.ts';
import {prepareModules,ModuleDownloadError} from '../src/lib/go-modules.ts';
const manifest=JSON.parse(await readFile(new URL('../src/lib/go-toolchain.json',import.meta.url),'utf8'));
const engine=new GoBrowser(manifest,a=>readFile(new URL('../public'+a.url,import.meta.url)),()=>{}),records={};
const files={'go.mod':'module playground\n\ngo 1.27.1\n\nrequire github.com/google/uuid v1.6.0\n','main.go':'package main\nimport("fmt";"github.com/google/uuid")\nfunc main(){fmt.Println(uuid.MustParse("123e4567-e89b-12d3-a456-426614174000"))}\n'};
const prepared=await prepareModules(files,input=>engine.query(input),s=>process.stdout.write(s+'\n'),async(url,max)=>{
 const response=await fetch(url);if(!response.ok){records[url]='HTTP '+response.status;throw new ModuleDownloadError(response.status,url)}const bytes=new Uint8Array(await response.arrayBuffer());if(bytes.length>max)throw new Error('Oversized fixture');records[url]=Buffer.from(bytes).toString('base64');return bytes;
});
const result=await engine.perform({...files,'go.sum':prepared.goSum},'run','',{dependencies:prepared.files});if(result.exitCode!==0||result.stdout!=='123e4567-e89b-12d3-a456-426614174000\n')throw new Error(JSON.stringify(result));
const directory=new URL('../tests/fixtures/go-modules-uuid/',import.meta.url);await mkdir(directory,{recursive:true});await writeFile(new URL('responses.json',directory),JSON.stringify(records,null,2)+'\n');await writeFile(new URL('expected.json',directory),JSON.stringify({files,modules:prepared.modules,goSum:prepared.goSum,stdout:result.stdout,checkedAt:new Date().toISOString(),boundary:'Public Go proxy and signed checksum-log proof captured as deterministic test evidence; UUID archive retains its upstream LICENSE.'},null,2)+'\n');console.log(JSON.stringify({modules:prepared.modules,files:Object.keys(prepared.files).length,stdout:result.stdout,proofRequests:Object.keys(records).length}));
