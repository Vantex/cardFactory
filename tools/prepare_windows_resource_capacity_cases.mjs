import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const root=path.resolve(import.meta.dirname,'..'),destination=path.resolve(process.argv[2]??''),checks=path.resolve(process.argv[3]??path.join(root,'.godot/windows-package-check'));
assert.equal(path.dirname(destination),checks,'Initial capacity instrumentation stays in the isolated package directory');
const read=file=>fs.readFileSync(path.join(root,file),'utf8'),put=(file,text)=>fs.writeFileSync(path.join(destination,file),text);
const bytes=read('tests/fixtures/parity/behavior/task27-resource-initial-capacity.json');
assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),'5bec2f902e4e452253a8678e8d85bbb2af478c7a7548a274ab7e46facad0170c');
put('task27-resource-initial-capacity.json',bytes);
assert.ok(fs.existsSync(path.join(destination,'resource_adapter.gd'))&&fs.existsSync(path.join(destination,'mining_legacy.gd')),'Prepare resource and actual old primary adapters first');
const replace=(text,from,to)=>{assert.equal(text.split(from).length,2,from);return text.replace(from,to);};
const productify=source=>{
 source=source.replaceAll('res://scripts/test/EffectQueryBehaviorRunner.gd','res://resource_adapter.gd')
  .replaceAll('res://scripts/test/CapacityQueryBehaviorRunner.gd','res://resource_adapter.gd')
  .replaceAll('res://scripts/test/ResourceCapacityFixtureGuard.gd','res://capacity_fixture_guard.gd')
  .replaceAll('res://scripts/test/LegacyMiningCompatibilityRegression.gd','res://mining_legacy.gd')
  .replaceAll('res://tests/fixtures/parity/behavior/','res://')
  .replaceAll('res://.godot/task27-initial-capacity-','user://initial-capacity-')
  .replaceAll('res://.godot/task27-capacity-legacy-','user://capacity-legacy-');
 for(const name of ['GameState','SourceGalaxySystem','GalaxySystem','PlanetSystem','SimulationEngine','SaveSystem'])source=source.replaceAll(name+'.new(','load("res://scripts/game/'+name+'.gd").new(');
 for(const [name,methods] of [['SourceGalaxySystem',['catalog']],['GameStateCodec',['to_persistent_dict']],['GameStateValidator',['validate_persistent_dict']]])for(const method of methods)source=source.replaceAll(name+'.'+method+'(','load("res://scripts/game/'+name+'.gd").'+method+'(');
 source=source.replaceAll(': GameState',': RefCounted');
 return source.replace(/var (\w+) := /g,'var $1 = ');
};
let guard=read('scripts/test/ResourceCapacityFixtureGuard.gd').replaceAll('DSPOnlineParity.','PARITY.');
guard=replace(guard,'extends RefCounted\n','extends RefCounted\n\nconst PARITY := preload("res://resource_parity_adapter.gd")\n');
put('capacity_fixture_guard.gd',productify(guard));
for(const [name,label] of [['TestParityResourceInitialCapacity','initial'],['TestParityResourceCapacityLegacy','legacy']]){
 let source=read('scripts/test/'+name+'.gd');
 source=replace(source,'func _ready() -> void:\n\tcall_deferred("_run")\n','');
 source=replace(source,'func _run() -> void:','func run() -> Array:');
 source=replace(source,'\tget_tree().quit(0 if errors.is_empty() else 1)','\treturn errors');
 source=source.replaceAll('\t\tget_tree().quit(1)\n\t\treturn','\t\terrors.append("original initial capacity fixture rejected")\n\t\treturn errors');
 source=productify(source);
 assert.doesNotMatch(source,/res:\/\/scripts\/test\/|res:\/\/tests\/|res:\/\/\.godot\/|get_tree\(\)\.quit|func _ready/);
 put('capacity_'+label+'.gd',source);
}
console.log('WINDOWS INITIAL CAPACITY INSTRUMENTATION PREPARED:full12states/1268initial reserves/12primary/19gold rejects/3actual old primary+3resaves+3continuations/36capacity rejects;controlled colony prerequisites,product providers load only from PCK');
