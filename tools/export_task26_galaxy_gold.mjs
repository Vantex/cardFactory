import fs from 'node:fs';
import crypto from 'node:crypto';
import { stripTypeScriptTypes } from 'node:module';
import { execFileSync } from 'node:child_process';

const sourceRoot = '../DSPONLINE';
const commit = '472bf62c76b695852b5577e563c1d113192ac731';
if (execFileSync('git', ['-C', sourceRoot, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim() !== commit) throw new Error('Frozen source commit changed');
const files = {};
function read(name) {
  const text = fs.readFileSync(`${sourceRoot}/src/game/${name}.ts`, 'utf8');
  files[`src/game/${name}.ts`] = crypto.createHash('sha256').update(text).digest('hex');
  return stripTypeScriptTypes(text);
}
function url(text) { return `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`; }
const contentUrl = url(read('content'));
const templatesUrl = url(read('galaxyCatalog'));
const content = await import(contentUrl);
const templates = await import(templatesUrl);
const galaxy = await import(url(read('galaxy').replace('from "./content"', `from "${contentUrl}"`).replace('from "./galaxyCatalog"', `from "${templatesUrl}"`)));
const catalog = { source_commit: commit, source_files: files, planets: content.PLANETS, systems: content.STAR_SYSTEMS, templates: templates.PLANET_TEMPLATES, pools: templates.PLANET_TEMPLATE_POOLS, stars: templates.STAR_CLASS_TEMPLATES, positions: templates.SYSTEM_POSITIONS };
fs.mkdirSync('data/galaxy', { recursive: true });
fs.writeFileSync('data/galaxy/source_catalog.json', `${JSON.stringify(catalog, null, 2)}\n`);
const cases = [];
for (const [seed, baseline] of [[240721, true], [240721, false], [1, false], [12345, false], [4294967295, false]]) {
  const state = galaxy.createGalaxyState(seed, baseline);
  const reserves = {};
  for (const profile of Object.values(state.profiles)) for (const item of profile.resourceIds) {
    const id = `${profile.planetId}_${item}_1`;
    reserves[id] = galaxy.createVeinReserve(state, profile.planetId, item, id);
  }
  cases.push({ seed, baseline, state, reserves });
}
fs.writeFileSync('tests/fixtures/parity/behavior/task26-galaxy.json', `${JSON.stringify({ source_commit: commit, source_files: files, cases }, null, 2)}\n`);
console.log(`${Object.keys(content.PLANETS).length} planets, ${Object.keys(content.STAR_SYSTEMS).length} systems; ${cases.length} deterministic golden cases`);

const engineText = fs.readFileSync(`${sourceRoot}/src/game/engine.ts`, 'utf8');
const routeCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('export function getLogisticsSpeedMultiplier'), engineText.indexOf('function getCachedInterstellarPath'))).replaceAll('export ', '');
const constants = ['PLANETARY_CARGO_PER_DRONE', 'INTERSTELLAR_CARGO_PER_VESSEL', 'PLANETARY_TRIP_SECONDS', 'INTERSTELLAR_TRIP_SECONDS', 'WARP_TRIP_SECONDS'].map(name => engineText.match(new RegExp(`export const ${name} = [^;]+;`))[0].replace('export ', '')).join('\n');
const difficultySource = await import(url(read('difficulty')));
const getEconomics = new Function('getPlanet', 'getPlanetIndustrialProfile', 'getSystemDistanceLy', 'isStarSystemUnlocked', 'getBuilding', 'getDifficultyDefinition', 'getInfiniteResearchLevel', 'round', `${constants}\n${routeCode}\nreturn getInterstellarRouteEconomics;`)(content.getPlanet, galaxy.getPlanetIndustrialProfile, galaxy.getSystemDistanceLy, () => true, content.getBuilding, difficultySource.getDifficultyDefinition, state => state.level, (value, digits) => Math.round(value * 10 ** digits) / 10 ** digits);
const world = galaxy.createGalaxyState(240721, false);
const firstPlanets = Object.keys(content.STAR_SYSTEMS).map(system => Object.values(content.PLANETS).find(planet => planet.systemId === system && planet.kind !== 'gas-giant').id);
const hubs = firstPlanets.filter(id => id !== 'home').map((id, index) => ({ id: `hub_${index}`, planetId: id, buildingId: 'interstellar_logistics_station', machineCount: 1, stationHubEnabled: true, stationHubPriority: index % 3 }));
const routeCases = [];
for (const [targetPlanet, policy, budget, level, difficulty, count] of [
  ['ashen', 'direct', 1, 0, 'standard', 1], ['giant', 'direct', 2, 3, 'hard', 2],
  [firstPlanets.at(-1), 'direct', 1, 0, 'standard', 1],
  [firstPlanets.at(-1), 'relay-required', 1, 0, 'standard', 1],
  [firstPlanets.at(-1), 'relay-required', 4, 0, 'standard', 1],
  [firstPlanets.at(-1), 'relay-preferred', 4, 3, 'relaxed', 3],
]) {
  const source = { id: 'source', planetId: 'home', buildingId: 'interstellar_logistics_station', machineCount: 1 };
  const target = { id: 'target', planetId: targetPlanet, buildingId: 'interstellar_logistics_station', machineCount: 1 };
  const state = { galaxy: world, entities: [source, target, ...hubs], research: { completedTechIds: [] }, level, settings: { difficulty } };
  routeCases.push({ source, target, hubs, level, difficulty, count, policy, budget, expected: getEconomics(state, source, target, count, { routePolicy: policy, warperBudget: budget }) });
}
fs.writeFileSync('tests/fixtures/parity/behavior/task26-routes.json', `${JSON.stringify({ source_commit: commit, source_files: { ...files, 'src/game/engine.ts': crypto.createHash('sha256').update(engineText).digest('hex') }, seed: 240721, cases: routeCases }, null, 2)}\n`);
console.log(`${routeCases.length} frozen interstellar route economics cases`);

const stationMathUrl = url(read('stationMath'));
const contracts = await import(url(read('stationContracts').replace('from "./content"', `from "${contentUrl}"`).replace('from "./stationMath"', `from "${stationMathUrl}"`) + '\nexport { createContract };'));
const contractCases = [];
for (const enabled of [false, true]) for (const complete of [false, true]) for (const day of [0, 1, 20000, 20722, 20723]) {
  const produced = complete ? Object.fromEntries(['titanium_alloy', 'processor', 'particle_container', 'titanium_glass', 'particle_broadband', 'plastic', 'space_warper', 'frame_material', 'solar_sail', 'small_carrier_rocket', 'quantum_chip', 'antimatter_fuel_rod', 'universe_matrix'].map(item => [item, 1])) : {};
  const planets = complete ? ['home', 'ashen', 'giant', 'frost'] : ['home'];
  const state = { galaxy: { seed: 240721 }, research: { completedTechIds: [] }, totalProduced: produced, exploration: { colonizedPlanetIds: planets }, quantumLogisticsNetwork: { enabled } };
  contractCases.push({ day, enabled, produced, planets, offers: [0, 1, 2, 3].map(slot => contracts.createContract(state, day, slot)) });
}
fs.writeFileSync('tests/fixtures/parity/behavior/task26-contracts.json', `${JSON.stringify({ source_commit: commit, source_files: files, seed: 240721, cases: contractCases }, null, 2)}\n`);
console.log(`${contractCases.length * 4} frozen contract offer cases`);
const geometryCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('function normalizeDysonAngle'), engineText.indexOf('function launchDysonStructure'))).replaceAll('export ', '');
const reconcileCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('function dysonFrameComplete'), engineText.indexOf('function syncLegacySphereIntoPlans')));
const totalsCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('export function getDysonPlanTotals'), engineText.indexOf('function validDysonLaunchMode'))).replaceAll('export ', '');
const createDyson = new Function('isStarSystemUnlocked', 'isTechnologyCompleted', 'copyState', 'syncLegacySphereIntoPlans', `const DYSON_SHELL_CAPACITY_PER_STRUCTURE=40;\n${reconcileCode}\n${totalsCode}\n${geometryCode}\nreturn { createStandardDysonLayer, getDysonPlanTotals, dysonFrameRequirement };`)(() => true, (state, id) => state.research.completedTechIds.includes(id), structuredClone, () => {});
const dysonCases = [];
for (const [count, index] of [[3,0],[8,0],[16,0],[8,1],[3,7]]) {
  let state = { nextId: 1, research: { completedTechIds: ['dyson_sphere_program', 'dyson_shell'] }, dysonPlans: { helios: { structurePoints: 0, shellSails: 0, layers: Array.from({ length: index }, (_, i) => ({ id: `existing_${i}`, nodes: [], frames: [], shells: [] })) } } };
  state = createDyson.createStandardDysonLayer(state, 'helios', count);
  const layer = state.dysonPlans.helios.layers.at(-1);
  dysonCases.push({ count, index, radius: layer.radius, inclination: layer.inclination, longitude: layer.longitude, angles: layer.nodes.map(node => node.angle), requirements: layer.frames.map(frame => frame.requiredStructurePoints), capacities: layer.shells.map(shell => shell.sailCapacity), totals: createDyson.getDysonPlanTotals(state.dysonPlans.helios) });
}
const generationCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('function dysonGenerationForSystem'), engineText.indexOf('function calculateDysonReception')));
const powerCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('export function getDysonPowerMultiplier'), engineText.indexOf('function proliferatorApplies'))).replaceAll('export ', '');
const receiverCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('export function getRayReceiverCapacityKw'), engineText.indexOf('export function getDysonSailAbsorptionMultiplier'))).replaceAll('export ', '');
const powerOracle = new Function('getInfiniteResearchLevel', 'getStarLuminosity', 'SOLAR_SAIL_POWER_KW', 'DYSON_STRUCTURE_POWER_KW', 'DYSON_SHELL_SAIL_POWER_KW', 'RAY_RECEIVER_CAPACITY_KW', `${powerCode}\n${receiverCode}\n${generationCode}\nreturn {dysonGenerationForSystem,getRayReceiverCapacityKw};`)(state => state.level, galaxy.getStarLuminosity, 88, 960, 88, 6000);
const powerCases = Object.keys(content.STAR_SYSTEMS).map((id, index) => {
  const luminosity = galaxy.getStarLuminosity({ galaxy: world }, id);
  const level = index % 4;
  const points = 12, sails = 60, live = 3;
  const multiplier = 1 + level * .05;
  const powerState = { galaxy: world, level, research: { completedTechIds: ['ray_transmission_1','ray_transmission_2'] }, dysonEngineering: { orbitsBySystem: { [id]: [{ generationKw: live * 88 * multiplier * luminosity }] } }, dysonPlans: { [id]: { structurePoints: points, shellSails: sails } } };
  const result = powerOracle.dysonGenerationForSystem(powerState, id);
  const swarm = live * 88 * multiplier * luminosity;
  return { id, level, luminosity, points, sails, live, expected: swarm + Math.floor(result - swarm), receiver: powerOracle.getRayReceiverCapacityKw(powerState) };
});
fs.writeFileSync('tests/fixtures/parity/behavior/task26-dyson.json', `${JSON.stringify({ source_commit: commit, source_files: { ...files, 'src/game/engine.ts': crypto.createHash('sha256').update(engineText).digest('hex') }, seed: 240721, cases: dysonCases, power: powerCases }, null, 2)}\n`);
console.log(`${dysonCases.length} frozen Dyson geometry cases; ${powerCases.length} stellar power cases`);
const decayCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('function decayDysonSwarm'), engineText.indexOf('function dysonFrameComplete')));
const lifeCode = stripTypeScriptTypes(engineText.slice(engineText.indexOf('export function getSolarSailLifetimeSeconds'), engineText.indexOf('export function getRayReceiverCapacityKw'))).replaceAll('export ', '');
const decayOracle = new Function('syncLegacySwarmIntoOrbits', 'aggregateDysonSwarm', 'getSolarSailPowerFor', 'round', `const DYSON_SYSTEM_IDS=['helios'], SOLAR_SAIL_LIFETIME_SECONDS=1200, EPSILON=0.0001;\n${lifeCode}\n${decayCode}\nreturn decayDysonSwarm;`)(state => {const orbit=state.dysonEngineering.orbitsBySystem.helios[0];orbit.decayProgress=Math.max(0,orbit.decayProgress)%1;}, () => {}, () => 88, (value,digits)=>Math.round(value*10**digits)/10**digits);
const decayCases=[];
for(const [live, progress, seconds, steps, life] of [[1200,0,1/60,120,0],[1,.99995,.001,1,0],[100,.3,12,10,1],[2,0,1200,1,2]]) {
  const state={research:{completedTechIds: life===2?['solar_sail_life_1','solar_sail_life_2']:life===1?['solar_sail_life_1']:[]},dysonEngineering:{orbitsBySystem:{helios:[{sailsInOrbit:live,totalExpired:0,decayProgress:progress}]}}};
  for(let index=0;index<steps;index++)decayOracle(state,seconds);
  decayCases.push({live,progress,seconds,steps,life,expected:state.dysonEngineering.orbitsBySystem.helios[0]});
}
const dysonGoldPath='tests/fixtures/parity/behavior/task26-dyson.json';const dysonGold=JSON.parse(fs.readFileSync(dysonGoldPath,'utf8'));dysonGold.decay=decayCases;fs.writeFileSync(dysonGoldPath, `${JSON.stringify(dysonGold,null,2)}\n`);
console.log(`${decayCases.length} frozen sail decay cases`);
const hubGalaxyUrl = url(read('galaxy').replace('from "./content"', `from "${contentUrl}"`).replace('from "./galaxyCatalog"', `from "${templatesUrl}"`));
const hubUrl = url(read('systemHubLogistics').replace('from "./content"', `from "${contentUrl}"`).replace('from "./galaxy"', `from "${hubGalaxyUrl}"`));
const hubMath = await import(hubUrl);
const systemStations = await import(url(read('systemSpaceStation').replace('from "./content"', `from "${contentUrl}"`).replace('from "./systemHubLogistics"', `from "${hubUrl}"`).replaceAll('import.meta.env.DEV', 'false')));
const stationCases = [];
for (const technologies of [[], ['orbital_modular_assembly'], ['autonomous_station_construction']]) {
  const research = {completedTechIds: ['system_space_station_engineering', ...technologies]};
  let state = {research, entities:[{id:'platform',buildingId:'space_station_construction_launcher',planetId:'home',inputs:{titanium_alloy:4000,frame_material:2000},powerFactor:.5}], exploration:{unlockedSystemIds:['helios']},systemSpaceStations:{}};
  state = systemStations.startSystemSpaceStationConstruction(state,'helios');
  const initial=structuredClone(state.systemSpaceStations.helios);
  const requirements=systemStations.getSpaceStationPhaseRequirements(state,initial.costMultiplierBasisPoints);
  const report=systemStations.settleSpaceStationConstructionInputs(state);
  stationCases.push({technologies,initial,requirements,report,station:state.systemSpaceStations.helios,inputs:state.entities[0].inputs});
}
const moduleCases = [[0,1],[9,3],[20,12],[9000,1],[0,1000000]].map(([existing,amount])=>({existing,amount,cost:systemStations.getSpaceStationModuleCost('backbone',existing,amount)}));
fs.writeFileSync('tests/fixtures/parity/behavior/task26-system-station.json',JSON.stringify({source_commit:commit,source_files:files,cases:stationCases,modules:moduleCases},null,2)+'\n');
console.log(`${stationCases.length} construction and ${moduleCases.length} module golden cases`);
const localHubCases=[];
for(const power of [1,.5,0]){
 const stations=['station_a','station_b'].map((id,index)=>({id,buildingId:'interstellar_logistics_station',planetId:'home',stationTier:2,stationOperationMode:'elevator',machineCount:1,inputs:{iron_ingot:200},outputs:{},elevatorOutputItems:['iron_ingot',null,null,null,null],powerFactor:index===0?1:power,stationVessels:0}));
 const hub=systemStations.createEmptySystemSpaceStation('helios');hub.status='operational';hub.inventory.iron_ingot='5';
 const state={entities:stations,systemSpaceStations:{helios:hub},galacticHubNetwork:systemStations.createEmptyGalacticHubNetwork(),settings:{logisticsBufferLimit:1000000},research:{completedTechIds:[]}};
 const report=hubMath.settleSystemHubLogistics(state,5);
 localHubCases.push({power,report,inventory:hub.inventory,cursors:hub.routingCursors,stations:stations.map(station=>({id:station.id,inputs:station.inputs,outputs:station.outputs}))});
}
fs.writeFileSync('tests/fixtures/parity/behavior/task26-local-hub.json',JSON.stringify({source_commit:commit,source_files:files,cases:localHubCases},null,2)+'\n');
console.log(`${localHubCases.length} frozen local elevator settlement cases`);
const crossHubCases=[];
for(const [power,targetAmount] of [[1,'200'],[.5,'1000'],[0,'200']]){
 const hubA=systemStations.createEmptySystemSpaceStation('helios'),hubB=systemStations.createEmptySystemSpaceStation('borealis');
 for(const hub of [hubA,hubB])hub.status='operational';
 hubA.inventory.iron_ingot='1000';hubA.itemPolicies.iron_ingot={reserve:'100',target:'0',interstellarEnabled:true};
 hubB.itemPolicies.iron_ingot={reserve:'0',target:targetAmount,interstellarEnabled:true};
 const entities=[['a','home'],['b','frost']].map(([id,planetId],index)=>({id,planetId,buildingId:'interstellar_logistics_station',stationTier:2,stationOperationMode:'elevator',machineCount:1,inputs:{},outputs:{},elevatorOutputItems:[null,null,null,null,null],stationVessels:index===0?2:0,powerFactor:index===0?1:power}));
 const state={galaxy:world,entities,systemSpaceStations:{helios:hubA,borealis:hubB},galacticHubNetwork:{...systemStations.createEmptyGalacticHubNetwork(),warpers:'4'},settings:{logisticsBufferLimit:1000000},research:{completedTechIds:['unified_system_logistics_protocol']}};
 const report=hubMath.settleSystemHubLogistics(state,5);
 crossHubCases.push({power,targetAmount,report,inventories:[hubA.inventory,hubB.inventory],network:state.galacticHubNetwork});
}
const allocationCases=[{budget:'101',requests:[{key:'a',amount:'9'.repeat(256)},{key:'b',amount:'9'.repeat(256)}]},{budget:'9999999999999',requests:[{key:'a',amount:'9007199254740993'},{key:'b',amount:'123456789012345678901234567890'}]}].map(row=>({...row,expected:hubMath.allocateHubBudget(row.budget,row.requests,0)}));
fs.writeFileSync('tests/fixtures/parity/behavior/task26-cross-hub.json',JSON.stringify({source_commit:commit,source_files:files,cases:crossHubCases,allocations:allocationCases},null,2)+'\n');
console.log(`${crossHubCases.length} cross-system hub and ${allocationCases.length} large allocation cases`);
