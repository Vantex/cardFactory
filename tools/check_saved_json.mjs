import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=path.resolve(process.argv[2]);
const files=fs.readdirSync(path.join(root,'profile'),{recursive:true})
  .map(file=>path.join(root,'profile',file))
  .filter(file=>fs.statSync(file).isFile() && /\.json(?:\.(?:bak|emergency|snapshot_\d+|offline)(?:\.bak)?)?$/.test(file));
let saves=0, controlSaves=0;
for(const file of files){
  const envelope=JSON.parse(fs.readFileSync(file,'utf8'));
  if(!envelope.state || !envelope.metadata?.digest) continue;
  saves++;
  if(!file.includes('world-metadata-regression') || !envelope.state.source_galaxy?.planetMetadata?.ashen?.note) continue;
  const note=envelope.state.source_galaxy.planetMetadata.ashen.note;
  for(let code=1;code<32;code++) assert.ok(note.includes(String.fromCharCode(code)),file+': lost control '+code);
  assert.ok(note.includes('\\v') && note.includes('\\\\v'),file+': literal backslashes changed');
  controlSaves++;
}
if(process.argv.includes('--world')) assert.ok(controlSaves>=3,'primary, emergency and snapshot control fixtures required');
assert.ok(saves>0,'actual saved envelopes required');
console.log(`STANDARD SAVED JSON PASSED: ${saves} saved files; ${controlSaves} C0/escape recovery files; ${root}`);
