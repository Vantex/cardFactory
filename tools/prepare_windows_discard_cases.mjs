import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=path.resolve(import.meta.dirname,'..');
const destination=path.resolve(process.argv[2]??'');
const checks=path.resolve(process.argv[3]??path.join(root,'.godot/windows-package-check'));
assert.equal(path.dirname(destination),checks,'Discard fixture must stay in its isolated package directory');
const fixture=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/parity/behavior/task27-inventory-discard.json'),'utf8'));
const catalog=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/parity/dsponline_source_catalog.json'),'utf8'));
assert.equal(fixture.source_commit,catalog.source.commit);
for(const [file,hash] of Object.entries(fixture.source_files))assert.equal(hash,catalog.source.files[file],file);
const wanted=['tray-iron_ore-home-partial','tray-iron_ore-home-duplicates','tray-iron_ore-ashen-partial','tray-logistics_drone-home-partial','tray-special-unknown_planet','tray-special-missing_remote','tray-special-fractional_stock','construction-wind_turbine-owned','construction-conveyor_belt_mk1-owned','construction-wind_turbine-zero'];
const cases=wanted.map(id=>{
  const matches=fixture.cases.filter(row=>row.id===id);
  assert.equal(matches.length,1,id);
  assert.equal(matches[0].save_eligible,true,id+' legal save input');
  return matches[0];
});
fs.writeFileSync(path.join(destination,'inventory-discard-cases.json'),JSON.stringify({source_commit:fixture.source_commit,source_files:fixture.source_files,initial:fixture.initial,cases}));
console.log('WINDOWS DISCARD FIXTURE PREPARED: 10 controlled source commands with first/repeated results and disk checks');
