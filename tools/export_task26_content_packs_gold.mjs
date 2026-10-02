import fs from 'node:fs';
import crypto from 'node:crypto';
import {stripTypeScriptTypes} from 'node:module';
import {execFileSync} from 'node:child_process';

const sourceCommit = '472bf62c76b695852b5577e563c1d113192ac731';
if (execFileSync('git', ['-C', '../DSPONLINE', 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim() !== sourceCommit || execFileSync('git', ['-C', '../DSPONLINE', 'status', '--porcelain', '--untracked-files=no'], {encoding: 'utf8'}).trim()) throw new Error('Frozen source revision or working tree changed');
const frozen = JSON.parse(fs.readFileSync('tests/fixtures/parity/dsponline_source_catalog.json', 'utf8'));
const sourceFiles = {};
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
function read(name) {
  const path = `src/game/${name}.ts`;
  const text = fs.readFileSync(`../DSPONLINE/${path}`, 'utf8');
  const hash = crypto.createHash('sha256').update(text).digest('hex');
  if (frozen.source.files[path] && hash !== frozen.source.files[path]) throw new Error(`Source drift: ${path}`);
  sourceFiles[path] = hash;
  return stripTypeScriptTypes(text);
}
const contentUrl = url(read('content'));
const modsUrl = url(read('mods').replace('from "./content"', `from "${contentUrl}"`));
const mods = await import(modsUrl);
const packs = await import(url(read('contentPacks').replace('from "./content"', `from "${contentUrl}"`).replace('from "./mods"', `from "${modsUrl}"`)));
const manifest = {formatVersion: 2, id: 'gold_local_pack', name: '本地金标', version: '1.2.3', dependencies: [], items: [{id: 'gold_local_item', name: '金标材料', kind: 'solid'}], buildings: [], recipes: [], technologies: [], buildingOverrides: [], belts: []};
const mutations = [
  ['v2', x => x], ['v1', x => ({...x, formatVersion: 1})],
  ['bad_id', x => ({...x, id: 'Bad-Package'})], ['bad_version', x => ({...x, version: 'latest'})],
  ['empty_name', x => ({...x, name: ''})], ['dependency', x => ({...x, dependencies: ['other_pack@^0.2.0']})],
  ['bad_dependency', x => ({...x, dependencies: ['other_pack@*']})],
  ['unknown_reference', x => ({...x, recipes: [{id: 'gold_recipe', name: '配方', buildingId: 'assembling_machine_mk1', duration: 1, inputs: [{itemId: 'missing_material', amount: 1}], outputs: [{itemId: 'gold_local_item', amount: 1}]}]})],
  ['valid_recipe', x => ({...x, recipes: [{id: 'gold_recipe', name: '配方', buildingId: 'assembling_machine_mk1', duration: 1, inputs: [{itemId: 'iron_ingot', amount: 1}], outputs: [{itemId: 'gold_local_item', amount: 1}]}]})],
  ['valid_override', x => ({...x, buildingOverrides: [{id: 'assembling_machine_mk1', speed: 2, inputCapacity: 200}]})],
  ['bad_override', x => ({...x, buildingOverrides: [{id: 'assembling_machine_mk1', speed: 2000}]})],
  ['valid_belt', x => ({...x, belts: [{id: 'gold_belt', name: '四级带', tier: 4, speed: 100, outputAmount: 3, costs: [{itemId: 'iron_ingot', amount: 1}]}]})],
  ['bad_belt', x => ({...x, belts: [{id: 'gold_belt', name: '三级带', tier: 3, speed: 100, costs: [{itemId: 'iron_ingot', amount: 1}]}]})],
];
const cases = mutations.map(([id, mutate]) => {
  const input = mutate(structuredClone(manifest));
  return {id, input, valid: mods.validateContentPack(input).valid};
});
const ranges = [];
for (const actual of ['0.2.0', '0.8.0', '1.1.0', '1.2.3', '1.3.0', '2.0.0', '1.2.3-alpha', '1.2.3-beta']) {
  for (const range of ['', '1.2.3', '^0.2.0', '^1.1.0', '~1.2.0', '>=1.2.3', '<1.3.0', '<=1.2.3', '>1.1.0']) ranges.push({actual, range, result: mods.satisfiesContentPackVersion(actual, range)});
}
fs.writeFileSync('tests/fixtures/parity/behavior/task26-content-packs.json', JSON.stringify({source_commit: sourceCommit, source_files: sourceFiles, cases, ranges, empty_registry_fingerprint: packs.getContentPackRegistryFingerprint(packs.createContentPackRegistry())}, null, 2) + '\n');
console.log(`${cases.length} manifest cases and ${ranges.length} version-range cases executed from frozen TypeScript`);
