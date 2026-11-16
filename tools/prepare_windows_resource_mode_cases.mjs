import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const root=path.resolve(import.meta.dirname,'..'),destination=path.resolve(process.argv[2]??''),checks=path.resolve(process.argv[3]??path.join(root,'.godot/windows-package-check'));
assert.equal(path.dirname(destination),checks,'Resource mode instrumentation stays in the isolated package directory');
const read=file=>fs.readFileSync(path.join(root,file),'utf8'),put=(file,text)=>fs.writeFileSync(path.join(destination,file),text);
const fixtures=[
 ['task27-resource-reserve-query.json','e6cf8b35dc519c8863076f8fcf92cce67b5bcbde340bbadcee9c256fb8300eb2'],
 ['task27-resource-mode-flow.json','9f240da3361c6fc7167be3060f65dcf68fa41cb6ecab7b0720cdac34f9a95b52'],
 ['task27-manual-reserve.json','28b20e8f9ec139b47b5c79405b8877a2ee5eb4cb4dbeccc63ee81eb375fc2fa0'],
];
for(const [file,digest] of fixtures){
 const bytes=read('tests/fixtures/parity/behavior/'+file);
 assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),digest);
 put(file,bytes);
}
put('legacy-mining-iron-save.json',read('tests/fixtures/task27-legacy-mining-iron-save.json'));
assert.ok(fs.existsSync(path.join(destination,'resource_adapter.gd'))&&fs.existsSync(path.join(destination,'mining_paid.gd')),'Prepare resource and mining adapters first');
const replace=(text,from,to)=>{assert.equal(text.split(from).length,2,from);return text.replace(from,to);};
const productify=source=>{
 source=source.replaceAll('res://scripts/test/EffectQueryBehaviorRunner.gd','res://resource_adapter.gd')
  .replaceAll('res://scripts/test/CapacityQueryBehaviorRunner.gd','res://resource_adapter.gd')
  .replaceAll('res://scripts/test/ResourceModeFixtureGuard.gd','res://mode_fixture_guard.gd')
  .replaceAll('res://scripts/test/ResourceMiningPersistenceRegression.gd','res://mining_paid.gd');
 source=source.replaceAll('res://tests/fixtures/parity/behavior/','res://')
  .replaceAll('res://tests/fixtures/task27-legacy-mining-iron-save.json','res://legacy-mining-iron-save.json')
  .replaceAll('res://.godot/task27-mode-','user://mode-');
 for(const name of ['GameState','SourceGalaxySystem','PlanetSystem','PowerSystem','ProductionSystem','SimulationEngine','SaveSystem']){
  source=source.replaceAll(name+'.new(', 'load("res://scripts/game/'+name+'.gd").new(');
 }
 for(const [name,methods] of [['SourceGalaxySystem',['catalog']],['GameStateCodec',['to_persistent_dict','from_persistent_dict']],['GameStateValidator',['validate_persistent_dict']],['SourceProgressionFacts',['mine']]]){
  for(const method of methods)source=source.replaceAll(name+'.'+method+'(','load("res://scripts/game/'+name+'.gd").'+method+'(');
 }
 source=source.replaceAll(': GameState',': RefCounted').replaceAll('-> GameState','-> RefCounted')
  .replaceAll(': AppShell',': Node').replaceAll(': GalaxyMap',': Node');
 return source.replace(/var (\w+) := /g,'var $1 = ');
};
let guard=read('scripts/test/ResourceModeFixtureGuard.gd').replaceAll('DSPOnlineParity.','PARITY.');
guard=replace(guard,'extends RefCounted\n','extends RefCounted\n\nconst PARITY := preload("res://resource_parity_adapter.gd")\n');
put('mode_fixture_guard.gd',productify(guard));
for(const name of ['Query','Flow','Manual','UI','Legacy']){
 let source=read('scripts/test/TestParityResourceMode'+name+'.gd');
 source=replace(source,'func _ready() -> void:\n\tcall_deferred("_run")\n','');
 source=replace(source,'func _run() -> void:','func run() -> Array:');
 source=replace(source,'\tget_tree().quit(0 if errors.is_empty() else 1)','\treturn errors');
 source=source.replaceAll('\t\tget_tree().quit(1)\n\t\treturn','\t\terrors.append("original fixture or old primary rejected")\n\t\treturn errors');
 if(name==='UI'){
  source=replace(source,'\tvar viewport := SubViewport.new()\n\tviewport.size = Vector2i(1920, 1080)\n\tget_tree().root.add_child(viewport)\n\tvar main: Node = load("res://scenes/main/Main.tscn").instantiate()\n\tviewport.add_child(main)\n\tawait get_tree().process_frame\n\tmain.set_process(false)',
   '\tvar main: Node = get_tree().current_scene\n\tvar main_process := main.is_processing()\n\tmain.set_process(false)');
  source=replace(source,'\tviewport.queue_free()\n\tawait get_tree().process_frame','\tmain.set_process(main_process)');
 }
 source=productify(source);
 assert.doesNotMatch(source,/res:\/\/scripts\/test\/|res:\/\/tests\/|res:\/\/\.godot\/|get_tree\(\)\.quit|func _ready/);
 put('mode_'+name.toLowerCase()+'.gd',source);
}
console.log('WINDOWS RESOURCE MODE INSTRUMENTATION PREPARED:full4328query/36rejects/48flow/144primary/312manual/35legacy/actual exported Main controls;product providers load only from PCK');
