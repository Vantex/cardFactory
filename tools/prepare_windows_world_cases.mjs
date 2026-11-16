import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=path.resolve(import.meta.dirname,'..');
const destination=path.resolve(process.argv[2]??'');
const checks=path.resolve(process.argv[3]??path.join(root,'.godot','windows-package-check'));
assert.equal(path.dirname(destination),checks,'World probe fixture must stay in its isolated package directory');
const fixture=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/parity/behavior/task27-world-commands.json'),'utf8'));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/parity/dsponline_source_catalog.json'),'utf8'));
assert.equal(fixture.source_commit,catalog.source.commit);
for(const [file,hash] of Object.entries(fixture.source_files))assert.equal(hash,catalog.source.files[file],file);
const wanted=['explore-borealis-exact','explore-borealis-below','colonize-boreal_giant-ready','colonize-boreal_giant-fleet_missing','colonize-boreal_giant-remote_only','active-ashen-computed','active-frost-computed','active-boreal_giant-not_colonized'].map(id=>id+'-240721-false');
const cases=wanted.map(id=>{
  const matches=fixture.cases.filter(row=>row.id===id);
  assert.equal(matches.length,1,id);
  return matches[0];
});
const surveys=fixture.surveys.filter(row=>row.systemId==='borealis'&&row.stage==='sixty_hz');
assert.equal(surveys.length,3);
fs.writeFileSync(path.join(destination,'world-command-cases.json'),JSON.stringify({source_commit:fixture.source_commit,source_files:fixture.source_files,cases,surveys}));
for(const name of ['task27-legacy-survey-save.json','task27-legacy-survey-progress-save.json'])fs.copyFileSync(path.join(root,'tests/fixtures',name),path.join(destination,name));
console.log('WINDOWS WORLD COMMAND FIXTURE PREPARED: 8 controlled source commands, 3 exact-clock surveys and 2 actual old local saves');
