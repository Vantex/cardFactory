import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {taskFor} from './parity_task_ownership.mjs';
import {readParityRuleCases} from './parity_rule_cases.mjs';
const cases = [
 ['engine.setBeltRouteMode',23],['engine.setEnergyMode',21],
 ['BlueprintWorkspace.onModeChange',24],['engine.getDysonEngineeringSnapshot',26],
 ['engine.refreshTimeWarpPowerSnapshot',26],['OperationsWorkspace.onExportModTemplate',26],
 ['OperationsWorkspace.onRegister',26],['LogisticsManagementPanel.onSlotModeChange',26],
 ['engine.handcraftRecipe',22],['engine.setEntityGenerationPriority',21]
];
const manifest=JSON.parse(readFileSync(new URL('../tests/fixtures/parity/dsponline_single_player_manifest.json',import.meta.url),'utf8'));
const rules=readParityRuleCases(new URL('../tests/fixtures/parity/rule_cases.json',import.meta.url));
for(const [id,expected] of cases){assert.equal(taskFor('commands',id),expected,id);const row=manifest.entries.find(e=>e.key==='commands:'+id);assert.ok(row,id);assert.equal(row.owner_task,expected,id);assert.equal(rules[row.rule_test].owner_task,expected,id);}
console.log('PARITY OWNERSHIP TESTS PASSED');
