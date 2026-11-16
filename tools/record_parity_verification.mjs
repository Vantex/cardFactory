import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {validateImplementationFingerprints,validateBehaviorHarness} from './parity_implementation_files.mjs';
import {readParityRuleCases, writeParityRuleCases} from './parity_rule_cases.mjs';

const root = path.resolve(import.meta.dirname, '..');
const resolve = name => path.resolve(root, name.replace(/^res:\/\//, ''));
const read = name => JSON.parse(fs.readFileSync(resolve(name), 'utf8'));
const hash = name => crypto.createHash('sha256').update(fs.readFileSync(resolve(name))).digest('hex');
const keys = process.argv.slice(2);
assert.ok(keys.length && new Set(keys).size === keys.length, 'Specify distinct keys to record');
const report = read('.godot/task27-parity-evidence.json');
const manifest = read('tests/fixtures/parity/dsponline_single_player_manifest.json');
const rulesPath = resolve('tests/fixtures/parity/rule_cases.json');
const rules = readParityRuleCases(rulesPath);
validateBehaviorHarness(report, hash('tests/fixtures/parity/dsponline_single_player_manifest.json'));
assert.equal(report.source_commit, manifest.source_commit, 'Source revision mismatch');
assert.deepEqual(report.errors, [], 'Behavior run contains failures');
assert.equal(report.source_catalog_sha256, hash('tests/fixtures/parity/dsponline_source_catalog.json'), 'Source catalog changed');
validateImplementationFingerprints(root, report.implementation_sha256);
for (const key of keys) {
  const row = manifest.entries.find(entry => entry.key === key);
  assert.ok(row && row.status !== '在线排除' && report.verified_keys.includes(key), `No passing behavior: ${key}`);
  const proof = report.proofs[key];
  assert.ok(proof?.suite && proof.assertions.length > 0, `Missing assertions: ${key}`);
  assert.equal(proof.fixture_sha256, hash(proof.fixture), `Fixture changed: ${key}`);
  assert.ok(report.claims[key].failures.length === 0 && JSON.stringify(report.claims[key].assertions) === JSON.stringify(proof.assertions), `Partial claim: ${key}`);
  row.status = '已验证';
  row.gap = `任务 27 ${proof.suite} 实际执行冻结源对照，通过 ${proof.assertions.length} 条断言；验证范围见规则记录。`;
  if (key.startsWith('belts:')) row.target = { category: 'symbol', ids: ['scripts/game/GameState.gd::get_belt_configuration'] };
  const planningTargets = { onCreatePlan: 'create_plan', onUpdatePlan: 'update_plan', onSetPlanRecipe: 'set_recipe', onRemovePlan: 'remove_plan' };
  const planningName = key.replace('commands:StatisticsWorkspace.', '');
  if (planningTargets[planningName]) {
    row.target = { category: 'symbol', ids: [`scripts/game/ProductionPlanningSystem.gd::${planningTargets[planningName]}`] };
    row.ui_entry = '生产分析 → 计划';
    if (!(row.supporting_tests ??= []).includes('res://scenes/test/TestProductionPlanning.tscn')) row.supporting_tests.push('res://scenes/test/TestProductionPlanning.tscn');
  }
  if (!(row.supporting_tests ??= []).includes('res://scenes/test/TestDSPOnlineParity.tscn')) row.supporting_tests.push('res://scenes/test/TestDSPOnlineParity.tscn');
  if (proof.suite === 'task27-dedicated-production' && !row.supporting_tests.includes('res://scenes/test/TestParitySpecialProduction.tscn')) row.supporting_tests.push('res://scenes/test/TestParitySpecialProduction.tscn');
  if (proof.suite === 'task27-resource-manual') {
    assert.equal(key, 'commands:engine.manualMine', 'Unknown resource manual behavior key');
    row.target = {category:'symbol', ids:['scripts/game/SourceProgressionFacts.gd::mine']};
    row.ui_entry = '矿脉采集与输出 → 按住采集；源整数缓存投影，原生旧小数库存单独保持守恒';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityResourceManual.tscn')) row.supporting_tests.push('res://scenes/test/TestParityResourceManual.tscn');
  }
  if (proof.suite === 'task27-finite-research' && !row.supporting_tests.includes('res://scenes/test/TestParityFiniteResearch.tscn')) row.supporting_tests.push('res://scenes/test/TestParityFiniteResearch.tscn');
  if (proof.suite === 'task27-infinite-research') {
    const method = {selectInfiniteResearch:'select',setInfiniteResearchAutomation:'set_automation',investInfiniteResearchBudgetInPlace:'invest_budget'}[key.replace('commands:engine.', '')];
    assert.ok(method, 'Unknown infinite research behavior key');
    row.target = {category:'symbol', ids:[`scripts/game/InfiniteResearchSystem.gd::${method}`]};
    row.ui_entry = '科技 → 无限研究 / 矩阵实验室';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityInfiniteResearch.tscn')) row.supporting_tests.push('res://scenes/test/TestParityInfiniteResearch.tscn');
  }
  if (proof.suite === 'task27-research-queries') {
    const method = {canSelectTechnology:'can_select_source_technology',canQueueTechnology:'can_queue_source_technology',hasActiveResearch:'has_active_source_research',isTechnologyCompleted:'is_technology_completed'}[key.replace('commands:engine.', '')];
    assert.ok(method, 'Unknown research query behavior key');
    row.target = {category:'symbol', ids:[`scripts/game/TechnologySystem.gd::${method}`]};
    row.ui_entry = '科技 → 研究条件与当前研究查询';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityResearchQueries.tscn')) row.supporting_tests.push('res://scenes/test/TestParityResearchQueries.tscn');
  }
  if (proof.suite === 'task27-research-boundaries') {
    const method = {settleCompletedResearchBoundaries:'settle_completed_source_research',settleCompletedResearchBoundariesInPlace:'settle_completed_source_research_in_place'}[key.replace('commands:engine.', '')];
    assert.ok(method, 'Unknown research boundary behavior key');
    row.target = {category:'symbol', ids:[`scripts/game/TechnologySystem.gd::${method}`]};
    row.ui_entry = '科技 → 已付研究完成边界';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityResearchBoundaries.tscn')) row.supporting_tests.push('res://scenes/test/TestParityResearchBoundaries.tscn');
  }
  if (proof.suite === 'task27-research-controls') {
    const method = {selectTechnology:'start_research',pauseCurrentResearch:'pause_research',resumePausedResearch:'resume_research',cancelCurrentResearch:'cancel_research',removeQueuedTechnology:'remove_from_queue'}[key.replace('commands:engine.', '')];
    assert.ok(method, 'Unknown research control behavior key');
    row.target = {category:'symbol', ids:['scripts/game/TechnologySystem.gd::' + method]};
    row.ui_entry = '科技 → 选择 / 暂停 / 恢复 / 取消 / 队列移除';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityResearchControls.tscn')) row.supporting_tests.push('res://scenes/test/TestParityResearchControls.tscn');
  }
  if (proof.suite === 'task27-progression') {
    assert.ok(['campaign','achievements'].includes(row.category), 'Unknown progression definition category');
    row.ui_entry = '战役 → 主线 / 支线 / 成就';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityProgression.tscn')) row.supporting_tests.push('res://scenes/test/TestParityProgression.tscn');
  }
  if (proof.suite === 'task27-campaign-controls') {
    const method = {
      'commands:CampaignWorkspace.onClose':'_close_workspace',
      'commands:CampaignWorkspace.onNavigate':'_navigate_source',
      'commands:CampaignWorkspace.onSelectTask':'_source_action',
      'commands:GamePanels.onOpenCampaign':'_show_workspace',
      'workspaces:CampaignWorkspace':'_ready',
    }[key];
    assert.ok(method, 'Unknown campaign workspace behavior key');
    row.target = {category:'symbol', ids:['scenes/ui/CampaignWorkspace.gd::'+method]};
    row.ui_entry = '战役 → 任务跟踪 / 导航 / 主线与支线';
    for(const scene of ['TestParityCampaignControls','TestParityCampaignUI','TestCampaignPersistence']) {
      const resource='res://scenes/test/'+scene+'.tscn';
      if(!row.supporting_tests.includes(resource)) row.supporting_tests.push(resource);
    }
  }
  if (proof.suite === 'task27-world-queries') {
    const targets = {
      isPlanetColonized: ['PlanetSystem', 'is_source_planet_colonized'],
      getColonizationRequirements: ['PlanetSystem', 'get_source_colonization_requirements'],
      canColonizePlanet: ['PlanetSystem', 'can_colonize_source_planet'],
      isStarSystemUnlocked: ['GalaxySystem', 'is_source_system_unlocked'],
      canExploreStarSystem: ['GalaxySystem', 'can_explore_source_system'],
      getPlanetTrayItemLimit: ['PlanetTraySystem', 'limit'],
      getPlanetTrayItemFreeCapacity: ['PlanetTraySystem', 'free_capacity'],
    };
    const target = targets[key.replace('commands:engine.', '')];
    assert.ok(target, 'Unknown world query behavior key');
    row.target = {category:'symbol', ids:[`scripts/game/${target[0]}.gd::${target[1]}`]};
    row.ui_entry = '星图 → 勘探 / 殖民条件与行星托盘';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityWorldQueries.tscn')) row.supporting_tests.push('res://scenes/test/TestParityWorldQueries.tscn');
  }
  if (proof.suite === 'task27-world-controls') {
    const targets = {
      setPlanetIndustryRole: ['SourceGalaxySystem', 'set_role'],
      setPlanetDisplayMetadata: ['SourceGalaxySystem', 'set_metadata'],
      setStarSystemDisplayName: ['SourceGalaxySystem', 'set_metadata'],
      setPlanetTrayItemLimit: ['PlanetTraySystem', 'set_limit'],
    };
    const target = targets[key.replace('commands:engine.', '')];
    assert.ok(target, 'Unknown world control behavior key');
    row.target = {category:'symbol', ids:[`scripts/game/${target[0]}.gd::${target[1]}`]};
    row.ui_entry = '星图 → 工业角色 / 行星说明 / 星系名称 / 托盘容量';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityWorldControls.tscn')) row.supporting_tests.push('res://scenes/test/TestParityWorldControls.tscn');
  }
  if (proof.suite === 'task27-world-commands') {
    const targets = {
      exploreStarSystem: ['GalaxySystem', 'try_explore_system'],
      colonizePlanet: ['PlanetSystem', 'try_colonize_planet'],
      setActivePlanet: ['PlanetSystem', 'try_set_active_planet'],
    };
    const target = targets[key.replace('commands:engine.', '')];
    assert.ok(target, 'Unknown world command behavior key');
    row.target = {category:'symbol', ids:[`scripts/game/${target[0]}.gd::${target[1]}`]};
    row.ui_entry = '星图 → 勘探信标 / 殖民 / 前往行星';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityWorldCommands.tscn')) row.supporting_tests.push('res://scenes/test/TestParityWorldCommands.tscn');
  }
  if (proof.suite === 'task27-inventory-discard') {
    const targets = {discardPlanetTrayItems: ['PlanetTraySystem','discard_batch'], discardConstructionInventory: ['ConstructionSystem','discard_inventory']};
    const target = targets[key.replace('commands:engine.', '')];
    assert.ok(target, 'Unknown inventory discard behavior key');
    row.target = {category:'symbol', ids:['scripts/game/'+target[0]+'.gd::'+target[1]]};
    row.ui_entry = '星图 → 确认丢弃托盘 / 完整制造 → 施工设备 → 确认永久丢弃';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityInventoryDiscard.tscn')) row.supporting_tests.push('res://scenes/test/TestParityInventoryDiscard.tscn');
  }
  if (proof.suite === 'task27-effect-queries') {
    const name = key.replace('commands:engine.', '');
    const targets = {
      getMiningSpeedMultiplier:['SourceTechnologyEffects.gd::multiplier','GameModeSystem.gd::multiplier'],
      getInfiniteResourceCollectionSpeedMultiplier:['SourceTechnologyEffects.gd::multiplier'],
      getVeinConsumptionMultiplier:['SourceTechnologyEffects.gd::multiplier'],
      getLogisticsSpeedMultiplier:['SourceTechnologyEffects.gd::multiplier','GameModeSystem.gd::multiplier'],
      getRayReceiverCapacityKw:['DysonSphereSystem.gd::receiver_capacity'],
      getDysonSailAbsorptionMultiplier:['SourceTechnologyEffects.gd::multiplier'],
      getIndustrialEfficiencyMultiplier:['SourceTechnologyEffects.gd::multiplier'],
      getRecipeSpeedMultiplier:['SourceTechnologyEffects.gd::multiplier','GameModeSystem.gd::multiplier'],
    };
    assert.ok(targets[name], 'Unknown technology effect query key');
    row.target = {category:'symbol', ids:targets[name].map(id=>'scripts/game/'+id)};
    row.ui_entry = '后台科技效果查询（生产/采集/物流/戴森数值），仅受控查询证据';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityEffectQueries.tscn')) row.supporting_tests.push('res://scenes/test/TestParityEffectQueries.tscn');
  }
  if (proof.suite === 'task27-item-input-capacity') {
    assert.equal(key,'commands:engine.getEntityItemInputCapacity','Unknown per-item input capacity query key');
    row.target={category:'symbol',ids:['scripts/game/GameState.gd::get_entity_item_input_capacity','scripts/game/SourceEntityCapacitySystem.gd::item_input_capacity']};
    row.ui_entry='传送带实际物品准入容量；冻结源只读查询，付费station/spray/均分/core覆盖/native与保存边界另有专项';
    if(!row.supporting_tests.includes('res://scenes/test/TestParityItemInputCapacity.tscn'))row.supporting_tests.push('res://scenes/test/TestParityItemInputCapacity.tscn');
  }
  if (proof.suite === 'task27-slot-capacity') {
    assert.equal(key,'commands:engine.getStationSlotCapacity','Unknown station slot capacity query key');
    row.target={category:'symbol',ids:['scripts/game/StationSystem.gd::capacity_for','scripts/game/SourceEntityCapacitySystem.gd::station_slot_capacity']};
    row.ui_entry='物流站槽位容量诊断；冻结源只读查询，实际扣件/存取/量子/采集/满站派遣与保存边界另有专项证据';
    if(!row.supporting_tests.includes('res://scenes/test/TestParitySlotCapacity.tscn'))row.supporting_tests.push('res://scenes/test/TestParitySlotCapacity.tscn');
  }
  if (proof.suite === 'task27-capacity-queries') {
    const method={getEntityBufferLimit:'get_entity_buffer_limit',getEntityInputCapacity:'get_entity_input_capacity',getEntityOutputCapacity:'get_entity_output_capacity'}[key.replace('commands:engine.','')];
    assert.ok(method,'Unknown entity capacity query key');
    row.target={category:'symbol',ids:['scripts/game/GameState.gd::'+method]};
    row.ui_entry='建筑与矿脉容量后台查询；受控只读金标，存档覆盖铁矿/熔炉/仓储，不证明全部资源采集或吞吐';
    if(!row.supporting_tests.includes('res://scenes/test/TestParityCapacityQueries.tscn'))row.supporting_tests.push('res://scenes/test/TestParityCapacityQueries.tscn');
  }
  if (proof.suite === 'task27-sail-lifetime') {
    assert.equal(key, 'commands:engine.getSolarSailLifetimeSeconds', 'Unknown sail lifetime query key');
    row.target = {category:'symbol', ids:['scripts/game/SourceDysonEngineering.gd::sail_lifetime_seconds']};
    row.ui_entry = '后台戴森太阳帆寿命查询；仅受控只读查询证据';
    if (!row.supporting_tests.includes('res://scenes/test/TestParitySailLifetime.tscn')) row.supporting_tests.push('res://scenes/test/TestParitySailLifetime.tscn');
  }
  if (proof.suite === 'task27-logistics-scalars') {
    assert.ok(['getPlanetaryCargoCapacity','getInterstellarCargoCapacity','getPlanetaryTripSeconds'].includes(key.replace('commands:engine.', '')), 'Unknown logistics scalar query key');
    row.target = {category:'symbol', ids:['scripts/game/StationSystem.gd::logistics_snapshot']};
    row.ui_entry = '物流站诊断：货运容量和本地航程时间，仅受控只读查询证据';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityLogisticsScalars.tscn')) row.supporting_tests.push('res://scenes/test/TestParityLogisticsScalars.tscn');
  }
  if (proof.suite === 'task27-route-queries') {
    const method = {getInterstellarTripSeconds:'trip_seconds',getInterstellarRouteEconomics:'query_economics'}[key.replace('commands:engine.', '')];
    assert.ok(method, 'Unknown interstellar route query key');
    row.target = {category:'symbol', ids:['scripts/game/InterstellarRouteSystem.gd::'+method]};
    row.ui_entry = '后台只读航程/航线经济查询；仅受控查询证据，实际派遣继续使用独立守卫';
    if (!row.supporting_tests.includes('res://scenes/test/TestParityRouteQueries.tscn')) row.supporting_tests.push('res://scenes/test/TestParityRouteQueries.tscn');
  }
  const rule = rules[row.rule_test];
  rule.kind = 'frozen_behavior';
  rule.behavior_verified = true;
  rule.behavior_suite = proof.suite;
  rule.behavior_fixture = proof.fixture;
  rule.behavior_fixture_sha256 = proof.fixture_sha256;
  rule.behavior_assertions = proof.assertions;
  rule.acceptance = proof.assertions;
}
let matrix = fs.readFileSync(resolve('docs/CONTENT_PARITY.md'), 'utf8');
let category = '';
matrix = matrix.split('\n').map(line => {
  if (line.startsWith('### ')) category = line.slice(4).trim();
  if (!line.startsWith('| ')) return line;
  const id = line.split('|')[1].trim();
  const row = manifest.entries.find(entry => entry.key === `${category}:${id}` && keys.includes(entry.key));
  return row ? `| ${row.source_id} | ${row.name} | ${row.target.ids.join(',')} | ${row.status} | ${row.owner_task} | ${row.ui_entry} |` : line;
}).join('\n');
const counts = {};
for (const row of manifest.entries) counts[row.status] = (counts[row.status] ?? 0) + 1;
matrix = matrix.replace(/状态统计：\{[^\n]+?\}。/, `状态统计：${JSON.stringify(counts)}。`);
writeParityRuleCases(rulesPath, rules);
fs.writeFileSync(resolve('tests/fixtures/parity/dsponline_single_player_manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
fs.writeFileSync(resolve('docs/CONTENT_PARITY.md'), matrix);
console.log(`RECORDED CURRENT BEHAVIOR: ${keys.join(', ')}`);
