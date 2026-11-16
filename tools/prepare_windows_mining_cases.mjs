import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const root=path.resolve(import.meta.dirname,'..'),destination=path.resolve(process.argv[2]??''),checks=path.resolve(process.argv[3]??path.join(root,'.godot/windows-package-check'));
assert.equal(path.dirname(destination),checks,'Mining instrumentation stays in the isolated package directory');
const read=file=>fs.readFileSync(path.join(root,file),'utf8'),put=(file,text)=>fs.writeFileSync(path.join(destination,file),text);
const bytes=read('tests/fixtures/parity/behavior/task27-mining-live60.json');
assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),'ceacc112a723f216ba93407ef816b2ad2f8463317085ebdb6620283b6ef8fd3e');
const fixture=JSON.parse(bytes),selected=fixture.cases.filter(row=>row.input.count===1&&row.input.level===1&&row.input.mode==='finite'&&row.input.stage==='powered'&&[0.25,1].includes(row.input.seconds));
assert.equal(selected.length,32);put('mining-cases.json',JSON.stringify({...fixture,cases:selected}));
for(const name of ['iron','oil','near-full'])put('legacy-mining-'+name+'-save.json',read('tests/fixtures/task27-legacy-mining-'+name+'-save.json'));
const productify=source=>{
 source=source.replaceAll('res://scripts/test/CapacityQueryBehaviorRunner.gd','res://resource_adapter.gd').replaceAll('res://scripts/test/EffectQueryBehaviorRunner.gd','res://resource_adapter.gd');
 source=source.replaceAll(': GameState',': RefCounted');
 for(const name of ['GameState','SourceGalaxySystem','PlanetSystem','PowerSystem','SimulationEngine','StatisticsSystem','ProductionSystem','SaveSystem']){
  source=source.replaceAll(name+'.new(', 'load("res://scripts/game/'+name+'.gd").new(');
 }
 for(const [name,methods] of [['SourceGalaxySystem',['catalog']],['GameStateCodec',['to_persistent_dict']],['GameStateValidator',['validate_persistent_dict']]]){
  for(const method of methods)source=source.replaceAll(name+'.'+method+'(','load("res://scripts/game/'+name+'.gd").'+method+'(');
 }
 // Dynamic external scripts cannot infer types from the PCK's loaded providers.
 source=source.replace(/var (\w+) := /g,'var $1 = ');
 return source;
};
let paid=productify(read('scripts/test/ResourceMiningPersistenceRegression.gd')).replaceAll('res://.godot/task27-mining-paid-%d/','user://mining-paid-%d/');
put('mining_paid.gd',paid);
let legacy=productify(read('scripts/test/LegacyMiningCompatibilityRegression.gd')).replaceAll('res://.godot/task27-legacy-mining-%d/','user://mining-legacy-%d/');
for(const name of ['iron','oil','near-full'])legacy=legacy.replaceAll('res://tests/fixtures/task27-legacy-mining-'+name+'-save.json','res://legacy-mining-'+name+'-save.json');
put('mining_legacy.gd',legacy);
console.log('WINDOWS MINING INSTRUMENTATION PREPARED:32 exact source count-one horizons,32 actual paid primary roundtrips,three actual old primary fixtures andthree continuation saves;production loads from PCK');
