import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

export const implementationRoots = ['autoload', 'scripts/game', 'scenes/ui', 'data'];
export const implementationChecks = [
  'tools/parity_rule_cases.mjs',
  "scripts/test/ResourceManualBehaviorRunner.gd", "scripts/test/TestParityResourceManual.gd", "scripts/test/TestParityResourceCollection.gd", "scripts/test/TestParityResourceOwnership.gd", "scripts/test/TestParityResourceOutputUI.gd", "scripts/test/TestParityResourceOutputBoundaries.gd", "scripts/test/TestParityResourceOutputFractions.gd", "scripts/test/TestParityResourceJourney.gd", "tests/fixtures/parity/behavior/task27-resource-manual.json", "tests/fixtures/parity/behavior/task27-resource-collection.json", "tests/fixtures/parity/behavior/task27-resource-ownership.json",
  "scripts/test/ResourceCapacityFixtureGuard.gd", "scripts/test/TestParityResourceInitialCapacity.gd", "scripts/test/TestParityResourceCapacityLegacy.gd", "tests/fixtures/parity/behavior/task27-resource-initial-capacity.json",
  "scripts/test/ResourceModeFixtureGuard.gd", "scripts/test/TestParityResourceModeFlow.gd", "scripts/test/TestParityResourceModeLegacy.gd", "scripts/test/TestParityResourceModeManual.gd", "scripts/test/TestParityResourceModeQuery.gd", "scripts/test/TestParityResourceModeUI.gd", "tests/fixtures/parity/behavior/task27-manual-reserve.json", "tests/fixtures/parity/behavior/task27-resource-mode-capacity-input.json", "tests/fixtures/parity/behavior/task27-resource-mode-flow.json", "tests/fixtures/parity/behavior/task27-resource-reserve-query.json",
  "scripts/test/ResourceMiningRegression.gd", "scripts/test/ResourceMiningPersistenceRegression.gd", "scripts/test/LegacyMiningCompatibilityRegression.gd", "scripts/test/TestParityResourceMining.gd", "tests/fixtures/parity/behavior/task27-mining-default.json", "tests/fixtures/parity/behavior/task27-mining-live60.json", "tests/fixtures/task27-legacy-mining-iron-save.json", "tests/fixtures/task27-legacy-mining-oil-save.json", "tests/fixtures/task27-legacy-mining-near-full-save.json",
  "scripts/test/ResourcePlacementRegression.gd", "scripts/test/ResourcePlacementBoundaryRegression.gd", "scripts/test/ResourceSelectionUIRegression.gd", "scripts/test/TestParityResourcePlacement.gd", "tests/fixtures/parity/behavior/task27-resource-placement.json",
  'scripts/test/HighPackSlotCapacityRegression.gd', 'tests/fixtures/parity/behavior/task27-content-pack-capacity.json', 'tests/fixtures/parity/behavior/task27-content-pack-high-capacity.json',
  'scripts/test/ItemInputCapacityBehaviorRunner.gd', 'scripts/test/TestParityItemInputCapacity.gd', 'scripts/test/ItemInputCapacityPersistenceRegression.gd', 'scripts/test/ContentPackCapacityRegression.gd',
  'scripts/test/SlotCapacityBehaviorRunner.gd', 'scripts/test/TestParitySlotCapacity.gd', 'scripts/test/SlotCapacityPersistenceRegression.gd',
  'scripts/test/CapacityQueryBehaviorRunner.gd', 'scripts/test/TestParityCapacityQueries.gd', 'scripts/test/CapacityPersistenceRegression.gd',
  'scripts/test/SailLifetimeBehaviorRunner.gd', 'scripts/test/TestParitySailLifetime.gd',
  'scripts/test/RouteQueryBehaviorRunner.gd', 'scripts/test/TestParityRouteQueries.gd',
  'scripts/test/ParityBehaviorRunner.gd', 'scripts/test/PlanningBehaviorRunner.gd',
  'scripts/test/RecipeBehaviorRunner.gd', 'scripts/test/TestDSPOnlineParity.gd',
  'scripts/test/DSPOnlineParity.gd', 'scripts/test/TestParityProduction.gd',
  'scripts/test/TestProductionPlanning.gd', 'tools/record_parity_verification.mjs',
  'scripts/test/RecipeCommandBehaviorRunner.gd', 'scripts/test/TestParityRecipeChanges.gd',
  'scripts/test/SpecialRecipeCommandRegression.gd',
  'scripts/test/SpecialProductionBehaviorRunner.gd', 'scripts/test/TestParitySpecialProduction.gd',
  'scripts/test/FiniteResearchBehaviorRunner.gd', 'scripts/test/TestParityFiniteResearch.gd',
  'scripts/test/ResearchCommandBehaviorRunner.gd', 'scripts/test/TestParityResearchCommands.gd',
  'scripts/test/InfiniteResearchBehaviorRunner.gd', 'scripts/test/TestParityInfiniteResearch.gd',
  'scripts/test/ResearchQueryBehaviorRunner.gd', 'scripts/test/TestParityResearchQueries.gd',
  'scripts/test/ResearchBoundaryBehaviorRunner.gd', 'scripts/test/TestParityResearchBoundaries.gd',
  'scripts/test/ResearchControlBehaviorRunner.gd', 'scripts/test/TestParityResearchControls.gd',
  'scripts/test/ProgressionBehaviorRunner.gd', 'scripts/test/TestParityProgression.gd',
  'scripts/test/TestProgressionParity.gd', 'scripts/test/TestBlueprintPersistence.gd',
  'tests/fixtures/task27-legacy-blueprint-dyson-save.json',
  'scripts/test/CampaignControlBehaviorRunner.gd', 'scripts/test/CampaignUIBehaviorRunner.gd',
  'scripts/test/TestParityCampaignControls.gd', 'scripts/test/TestParityCampaignUI.gd',
  'scripts/test/TestCampaignPersistence.gd', 'tests/fixtures/parity/behavior/task27-campaign-controls.json',
  'scripts/test/WorldQueryBehaviorRunner.gd', 'scripts/test/TestParityWorldQueries.gd',
  'scripts/test/WorldControlBehaviorRunner.gd', 'scripts/test/TestParityWorldControls.gd',
  'tests/fixtures/task27-legacy-metadata-save.json',
  'scripts/test/WorldCommandBehaviorRunner.gd', 'scripts/test/TestParityWorldCommands.gd',
  'tests/fixtures/task27-legacy-survey-save.json', 'tests/fixtures/task27-legacy-survey-progress-save.json',
  'scripts/test/InventoryDiscardBehaviorRunner.gd', 'scripts/test/TestParityInventoryDiscard.gd',
  'scripts/test/EffectQueryBehaviorRunner.gd', 'scripts/test/TestParityEffectQueries.gd',
  'scripts/test/LogisticsScalarBehaviorRunner.gd', 'scripts/test/TestParityLogisticsScalars.gd',
  'scripts/test/TestSinglePlayerModes.gd',
  'scripts/test/TestSaveRecovery.gd',
  'tools/parity_implementation_files.mjs',
];

export function implementationFiles(root) {
  const result = [...implementationChecks];
  const visit = directory => {
    for (const entry of fs.readdirSync(path.join(root, directory), {withFileTypes:true})) {
      const name = `${directory}/${entry.name}`;
      if (entry.isDirectory()) visit(name);
      else if (entry.isFile() && /\.(gd|json)$/.test(entry.name)) result.push(name);
    }
  };
  implementationRoots.forEach(visit);
  assert.equal(new Set(result).size, result.length, 'Duplicate implementation dependency');
  return result.sort();
}

export function validateImplementationFingerprints(root, fingerprints) {
  assert.ok(fingerprints && typeof fingerprints === 'object' && !Array.isArray(fingerprints), 'Missing implementation fingerprints');
  assert.deepEqual(Object.keys(fingerprints).sort(), implementationFiles(root), 'Incomplete or unexpected implementation fingerprint set');
  for (const [file, expected] of Object.entries(fingerprints)) {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
    assert.equal(actual, expected, `Stale implementation: ${file}`);
  }
}

export function validateBehaviorHarness(report, manifestSha256) {
  assert.equal(report?.harness?.passed, true, 'Full behavior harness did not pass');
  assert.equal(report.harness.failures, 0, 'Behavior harness contains failed checks');
  assert.equal(report.harness.rejections_checked, true, 'Behavior rejection checks were skipped');
  assert.equal(report.harness.manifest, 'res://tests/fixtures/parity/dsponline_single_player_manifest.json', 'Evidence uses another manifest');
  assert.equal(report.harness.manifest_sha256, manifestSha256, 'Evidence manifest changed');
}
