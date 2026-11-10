import test from 'node:test';
import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';
test('real Go/WASI source Debug pauses, steps into/over/out, reports locals and finishes without changing source',async()=>{
 const control=new Int32Array(new SharedArrayBuffer(20010*4)),worker=new Worker(new URL('./fixtures/go-debug-worker.mjs',import.meta.url),{workerData:{control:control.buffer}});
 const pauses=[],commands=[3,2,3,4,1];
 try{await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('Debug test timed out')),30000);worker.on('error',reject);worker.on('message',message=>{if(message.type==='error'){clearTimeout(timer);reject(new Error(message.error))}else if(message.type==='paused'){pauses.push(message.pause);const command=commands.shift();if(!command){reject(new Error('Unexpected extra debug pause'));return}Atomics.store(control,0,command);Atomics.notify(control,0)}else if(message.type==='result'){clearTimeout(timer);try{assert.equal(message.result.exitCode,0,JSON.stringify(message.result));assert.equal(message.result.stdout,'6\n');resolve()}catch(e){reject(e)}}})});
  assert.deepEqual(pauses.map(p=>p.point.line),[11,12,6,7,13]);assert.equal(pauses[1].locals.start,'3');assert.equal(pauses[2].locals.n,'3');assert.equal(pauses[3].locals.value,'6');assert.equal(pauses[4].locals.result,'6');assert.deepEqual(pauses[2].frames.map(f=>f.function),['double','main']);
 }finally{await worker.terminate()}
});
