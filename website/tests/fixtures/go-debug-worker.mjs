import {parentPort,workerData} from 'node:worker_threads';
import {readFile} from 'node:fs/promises';
import {GoBrowser} from '../../src/lib/go-browser.ts';
const manifest=JSON.parse(await readFile(new URL('../../src/lib/go-toolchain.json',import.meta.url),'utf8'));
const engine=new GoBrowser(manifest,a=>readFile(new URL('../../public'+a.url,import.meta.url)),()=>{});
const files={'go.mod':'module playground\n\ngo 1.27.1\n','main.go':'package main\n\nimport "fmt"\n\nfunc double(n int) int {\n value := n * 2\n return value\n}\n\nfunc main() {\n start := 3\n result := double(start)\n fmt.Println(result)\n}\n'};
try{const result=await engine.perform(files,'debug','',{control:new Int32Array(workerData.control),breakpoints:{'main.go':[12]},onPause:pause=>parentPort.postMessage({type:'paused',pause}),onPlan:points=>parentPort.postMessage({type:'plan',points})});parentPort.postMessage({type:'result',result})}catch(error){parentPort.postMessage({type:'error',error:String(error)})}
