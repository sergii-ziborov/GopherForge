import {build} from 'esbuild';
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const output=new URL('../../GopherForge/Resources/PlaygroundCRDT.js',import.meta.url);
await build({entryPoints:[new URL('../src/lib/native-crdt-bridge.ts',import.meta.url).pathname],outfile:output.pathname,bundle:true,format:'iife',globalName:'GopherForgeCRDT',target:'es2022',platform:'browser',minify:true,legalComments:'inline'});
const notices=[];for(const name of ['yjs','y-protocols','lib0']){const pkg=new URL('../node_modules/'+name+'/package.json',import.meta.url),json=JSON.parse(await readFile(pkg,'utf8'));notices.push(`${name} ${json.version}\n${await readFile(new URL('./LICENSE',pkg),'utf8')}`)}
await writeFile(new URL('../../GopherForge/Resources/PlaygroundCRDT-LICENSES.txt',import.meta.url),notices.join('\n\n'));
const bytes=await readFile(output);console.log(JSON.stringify({file:output.pathname,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')}));
