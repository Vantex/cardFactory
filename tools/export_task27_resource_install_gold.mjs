import assert from 'node:assert/strict';
import {isDeepStrictEqual} from 'node:util';
import {createFrozenSourceRuntime, writeFrozenFixture} from './frozen_source_runtime.mjs';

const runtime = createFrozenSourceRuntime();
try {
  const engine = await runtime.load('engine');
  const content = await runtime.load('content');
  const base = engine.createInitialState(240721, false);
  const resources = [...new Set(base.entities.filter(row => row.kind === 'vein').map(row => row.resourceId))].sort();
  const encode = value => JSON.parse(JSON.stringify(value, (_key, entry) => typeof entry === 'number' && !Number.isFinite(entry) ? {$number: String(entry)} : entry));
  const cases = [];
  const record = (id, item, current, requested, funding, locked, active = 'home', entityKind = 'vein') => {
    const state = engine.createInitialState(240721, false);
    const site = state.entities.find(row => row.kind === 'vein' && row.resourceId === item);
    const extractor = content.getExtractorBuildingId(item);
    const sourceId = site.id;
    state.activePlanetId = active;
    state.planetTrays[active] = structuredClone(state.tray);
    state.construction[extractor] = funding;
    site.minerCount = current;
    site.interactionLocked = locked;
    site.outputs[item] = 7;
    site.progress = 0.25;
    if (entityKind === 'wrong-kind') site.kind = 'machine';
    if (entityKind === 'no-resource') delete site.resourceId;
    const target = entityKind === 'missing' ? 'missing-site' : sourceId;
    const original = structuredClone(state);
    const next = engine.installMiner(state, target, requested);
    assert.ok(isDeepStrictEqual(state, original), 'Source installation mutates input: ' + id);
    const after = next.entities.find(row => row.id === sourceId);
    const expected = {count: after.minerCount, construction: next.construction[extractor], output: after.outputs[item], progress: after.progress, remaining: after.resourceRemaining, remainder: after.resourceDepletionRemainder ?? 0, active: next.activePlanetId};
    const otherBefore = structuredClone(state), otherAfter = structuredClone(next);
    for (const value of [otherBefore, otherAfter]) {
      delete value.construction[extractor];
      const entity = value.entities.find(row => row.id === sourceId);
      delete entity.minerCount; delete entity.extractorBuildingId;
      // copyState materializes these empty optional maps on every entity.
      for (const row of value.entities) for (const field of ['proliferatorBonusProgress','stationLastSupplyPeerBySlot']) {
        if (row[field] && Object.keys(row[field]).length === 0) delete row[field];
      }
    }
    assert.ok(isDeepStrictEqual(encode(otherAfter), encode(otherBefore)), 'Source installation changes unrelated state: ' + id);
    cases.push(encode({id, input: {item, planet: site.planetId, current, requested, funding, locked, active, entity_kind: entityKind, extractor}, expected, returned_original: next === state}));
  };
  for (const item of resources) for (const current of [0, 1, 3]) for (const requested of [1, 3]) for (const funding of [0, 1, 3]) for (const locked of [false, true]) {
    record([item,current,requested,funding,locked].join('-'), item, current, requested, funding, locked);
  }
  const currents = [0,-1,0.5,99999999,100000000,100000001,Number.MAX_SAFE_INTEGER,NaN,Infinity];
  const requests = [0,-1,0.5,1,3,100000000,100000001,Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER+1,NaN,Infinity,true];
  for (let i=0; i<currents.length; i++) for (let j=0; j<requests.length; j++) record(`count-guard-${i}-${j}`, 'iron_ore', currents[i], requests[j], 100000001, false);
  for (const item of resources) record('remote-'+item,item,0,3,3,false,base.entities.find(row=>row.kind==='vein'&&row.resourceId===item).planetId === 'home' ? 'ashen' : 'home');
  for (const kind of ['missing','wrong-kind','no-resource']) record('entity-'+kind,'iron_ore',1,1,3,false,'home',kind);
  assert.equal(cases.length,703);
  assert.equal(new Set(cases.map(row=>row.id)).size,cases.length);
  writeFrozenFixture(runtime,'task27-resource-install.json',{resources,cases,scope:'Actual frozen installMiner calls:16 resources, paid count1/3 additions, current0/1/3, stock0/1/3, locked/unlocked, remote active tray, unsafe/fractional/nonfinite count and missing/wrong entities. Complete source input immutable and unrelated state unchanged. Existing counts and funding are controlled; not earned manufacture or complete growth.'});
  console.log('RESOURCE INSTALL GOLD: '+cases.length+' actual commands; '+Object.keys(runtime.files).length+' loaded source modules');
} finally { runtime.close(); }
