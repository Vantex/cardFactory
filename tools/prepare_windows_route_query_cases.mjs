import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve(import.meta.dirname,'..');
const destination=path.resolve(process.argv[2]??'');
const checks=path.resolve(process.argv[3]??path.join(root,'.godot/windows-package-check'));
assert.equal(path.dirname(destination),checks,'Route query fixture stays in its isolated package directory');
const fixture=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/parity/behavior/task27-route-queries.json'),'utf8'));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/parity/dsponline_source_catalog.json'),'utf8'));
assert.equal(fixture.source_commit,catalog.source.commit);
assert.equal(Object.keys(fixture.source_files).length,24,'Actual frozen route source modules');
for(const [file,hash] of Object.entries(fixture.source_files))assert.equal(hash,catalog.source.files[file],file);
const selectors=[
 ['240721-false-relaxed-0-0','planet-home'],['240721-false-standard-0-0','planet-giant'],['42-false-hard-15-1000','planet-azure_giant'],
 ['240721-true-standard-8-1','planet-frost'],['42-false-relaxed-1-0','planet-magnetar'],['240721-true-hard-15-10','planet-tempest'],
 ['240721-false-relaxed-0-0','policy-direct-1'],['240721-false-standard-15-1000','policy-relay-preferred-4'],
 ['240721-false-hard-3-0','policy-relay-required-1'],['240721-false-relaxed-0-0','policy-relay-required-4'],
 ['240721-false-relaxed-0-0','hubs-disabled'],['240721-false-standard-0-0','hubs-locked'],
 ['240721-false-hard-4-0','hubs-priority'],['42-false-standard-2-0','hubs-tie'],
 ['240721-false-relaxed-0-0','hubs-mode-transition'],['240721-false-relaxed-0-0','hubs-elevator'],
 ['42-false-relaxed-0-0','vessels-0'],['42-false-standard-15-10','vessels-7'],['240721-true-hard-15-1000','vessels-100'],
 ['42-false-hard-0-0','policy-relay-required-4'],['240721-true-standard-15-1000','hubs-mode-transition'],
 ['240721-true-hard-15-1000','hubs-elevator'],['240721-false-hard-15-1000','hubs-priority'],['240721-true-relaxed-0-0','hubs-locked'],
];
const cases=selectors.map(([prefix,scenario])=>{
 const id=prefix+'-'+scenario;
 const matches=fixture.cases.filter(row=>row.id===id);
 assert.equal(matches.length,1,id);
 return matches[0];
});
assert.equal(new Set(cases.map(row=>row.id)).size,24);
fs.writeFileSync(path.join(destination,'route-query-cases.json'),JSON.stringify({source_commit:fixture.source_commit,source_files:fixture.source_files,scope:'24 controlled read-only package query cases; includes deliberately invalid placement states; no legal-save, dispatched throughput or earned-growth claim.',cases}));
console.log('WINDOWS ROUTE QUERY FIXTURE PREPARED: 24 controlled source cases; three difficulties and generated/baseline environments');
