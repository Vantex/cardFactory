class_name ParityBehaviorRunner
extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-basics.json"
const SUITE := "task27-belts"
const IMPLEMENTATION_ROOTS := ["autoload", "scripts/game", "scenes/ui", "data"]
const IMPLEMENTATION_CHECKS := [
	"tools/parity_rule_cases.mjs",
  "scripts/test/ResourceManualBehaviorRunner.gd", "scripts/test/TestParityResourceManual.gd", "scripts/test/TestParityResourceCollection.gd", "scripts/test/TestParityResourceOwnership.gd", "scripts/test/TestParityResourceOutputUI.gd", "scripts/test/TestParityResourceOutputBoundaries.gd", "scripts/test/TestParityResourceOutputFractions.gd", "scripts/test/TestParityResourceJourney.gd", "tests/fixtures/parity/behavior/task27-resource-manual.json", "tests/fixtures/parity/behavior/task27-resource-collection.json", "tests/fixtures/parity/behavior/task27-resource-ownership.json",
  "scripts/test/ResourceCapacityFixtureGuard.gd", "scripts/test/TestParityResourceInitialCapacity.gd", "scripts/test/TestParityResourceCapacityLegacy.gd", "tests/fixtures/parity/behavior/task27-resource-initial-capacity.json",
	"scripts/test/ResourceModeFixtureGuard.gd", "scripts/test/TestParityResourceModeFlow.gd", "scripts/test/TestParityResourceModeLegacy.gd", "scripts/test/TestParityResourceModeManual.gd", "scripts/test/TestParityResourceModeQuery.gd", "scripts/test/TestParityResourceModeUI.gd", "tests/fixtures/parity/behavior/task27-manual-reserve.json", "tests/fixtures/parity/behavior/task27-resource-mode-capacity-input.json", "tests/fixtures/parity/behavior/task27-resource-mode-flow.json", "tests/fixtures/parity/behavior/task27-resource-reserve-query.json",
	"scripts/test/ResourceMiningRegression.gd", "scripts/test/ResourceMiningPersistenceRegression.gd", "scripts/test/LegacyMiningCompatibilityRegression.gd", "scripts/test/TestParityResourceMining.gd", "tests/fixtures/parity/behavior/task27-mining-default.json", "tests/fixtures/parity/behavior/task27-mining-live60.json", "tests/fixtures/task27-legacy-mining-iron-save.json", "tests/fixtures/task27-legacy-mining-oil-save.json", "tests/fixtures/task27-legacy-mining-near-full-save.json",
	"scripts/test/ResourcePlacementRegression.gd", "scripts/test/ResourcePlacementBoundaryRegression.gd", "scripts/test/ResourceSelectionUIRegression.gd", "scripts/test/TestParityResourcePlacement.gd", "tests/fixtures/parity/behavior/task27-resource-placement.json",
	"scripts/test/HighPackSlotCapacityRegression.gd", "tests/fixtures/parity/behavior/task27-content-pack-capacity.json", "tests/fixtures/parity/behavior/task27-content-pack-high-capacity.json",
	"scripts/test/ItemInputCapacityBehaviorRunner.gd", "scripts/test/TestParityItemInputCapacity.gd", "scripts/test/ItemInputCapacityPersistenceRegression.gd", "scripts/test/ContentPackCapacityRegression.gd",
	"scripts/test/SlotCapacityBehaviorRunner.gd", "scripts/test/TestParitySlotCapacity.gd", "scripts/test/SlotCapacityPersistenceRegression.gd",
	"scripts/test/CapacityQueryBehaviorRunner.gd", "scripts/test/TestParityCapacityQueries.gd", "scripts/test/CapacityPersistenceRegression.gd",
	"scripts/test/SailLifetimeBehaviorRunner.gd", "scripts/test/TestParitySailLifetime.gd",
	"scripts/test/RouteQueryBehaviorRunner.gd", "scripts/test/TestParityRouteQueries.gd",
	"scripts/test/ParityBehaviorRunner.gd", "scripts/test/PlanningBehaviorRunner.gd",
	"scripts/test/RecipeBehaviorRunner.gd", "scripts/test/TestDSPOnlineParity.gd",
	"scripts/test/DSPOnlineParity.gd", "scripts/test/TestParityProduction.gd",
	"scripts/test/TestProductionPlanning.gd", "tools/record_parity_verification.mjs",
	"scripts/test/RecipeCommandBehaviorRunner.gd", "scripts/test/TestParityRecipeChanges.gd",
	"scripts/test/SpecialRecipeCommandRegression.gd",
	"scripts/test/SpecialProductionBehaviorRunner.gd", "scripts/test/TestParitySpecialProduction.gd",
	"scripts/test/FiniteResearchBehaviorRunner.gd", "scripts/test/TestParityFiniteResearch.gd",
	"scripts/test/ResearchCommandBehaviorRunner.gd", "scripts/test/TestParityResearchCommands.gd",
	"scripts/test/InfiniteResearchBehaviorRunner.gd", "scripts/test/TestParityInfiniteResearch.gd",
	"scripts/test/ResearchQueryBehaviorRunner.gd", "scripts/test/TestParityResearchQueries.gd",
	"scripts/test/ResearchBoundaryBehaviorRunner.gd", "scripts/test/TestParityResearchBoundaries.gd",
	"scripts/test/ResearchControlBehaviorRunner.gd", "scripts/test/TestParityResearchControls.gd",
	"scripts/test/ProgressionBehaviorRunner.gd", "scripts/test/TestParityProgression.gd",
	"scripts/test/TestProgressionParity.gd", "scripts/test/TestBlueprintPersistence.gd",
	"tests/fixtures/task27-legacy-blueprint-dyson-save.json",
	"scripts/test/CampaignControlBehaviorRunner.gd", "scripts/test/CampaignUIBehaviorRunner.gd",
	"scripts/test/TestParityCampaignControls.gd", "scripts/test/TestParityCampaignUI.gd",
	"scripts/test/TestCampaignPersistence.gd", "tests/fixtures/parity/behavior/task27-campaign-controls.json",
	"scripts/test/WorldQueryBehaviorRunner.gd", "scripts/test/TestParityWorldQueries.gd",
	"scripts/test/WorldControlBehaviorRunner.gd", "scripts/test/TestParityWorldControls.gd",
	"tests/fixtures/task27-legacy-metadata-save.json",
	"scripts/test/WorldCommandBehaviorRunner.gd", "scripts/test/TestParityWorldCommands.gd",
	"tests/fixtures/task27-legacy-survey-save.json", "tests/fixtures/task27-legacy-survey-progress-save.json",
	"scripts/test/InventoryDiscardBehaviorRunner.gd", "scripts/test/TestParityInventoryDiscard.gd",
	"scripts/test/EffectQueryBehaviorRunner.gd", "scripts/test/TestParityEffectQueries.gd",
	"scripts/test/LogisticsScalarBehaviorRunner.gd", "scripts/test/TestParityLogisticsScalars.gd",
	"scripts/test/TestSinglePlayerModes.gd",
	"scripts/test/TestSaveRecovery.gd",
	"tools/parity_implementation_files.mjs",
]

var _errors: Array[String] = []
var _claims: Dictionary = {}
var _proofs: Dictionary = {}

func run_belts(fixture_override: Dictionary = {}) -> Dictionary:
	_errors.clear()
	_claims.clear()
	_proofs.clear()
	var frozen := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	if fixture.is_empty() or fixture.get("source_commit") != frozen.get("source", {}).get("commit"):
		return {"errors": ["missing behavior fixture or wrong source revision"], "verified_keys": [], "proofs": {}, "provenance_rejected": true}
	if not fixture.get("source_files") is Dictionary or not fixture.source_files.has("src/game/content.ts") or not fixture.source_files.has("src/game/engine.ts"):
		return {"errors": ["missing behavior source provenance"], "verified_keys": [], "proofs": {}, "provenance_rejected": true}
	for file in fixture.source_files:
		if fixture.source_files[file] != frozen.get("source", {}).get("files", {}).get(file):
			return {"errors": ["behavior fixture source hash drift: " + String(file)], "verified_keys": [], "proofs": {}, "provenance_rejected": true}
	_test_belts(fixture)
	var keys: Array[String] = []
	for key in _claims:
		if _claims[key].failures.is_empty() and not _claims[key].assertions.is_empty():
			keys.append(key)
			_proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": _claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": _errors.duplicate(), "verified_keys": keys, "proofs": _proofs.duplicate(true), "claims": _claims.duplicate(true)}

func run(fixture_override: Dictionary = {}) -> Dictionary:
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var belts := run_belts(fixture)
	if belts.get("provenance_rejected", false): return belts
	var keys: Array[String] = belts.verified_keys
	var planning := PlanningBehaviorRunner.new().run()
	_errors.append_array(planning.errors)
	keys.append_array(planning.verified_keys)
	_proofs.merge(planning.proofs)
	_claims.merge(planning.claims)
	var recipes := RecipeBehaviorRunner.new().run()
	_errors.append_array(recipes.errors)
	keys.append_array(recipes.verified_keys)
	_proofs.merge(recipes.proofs)
	_claims.merge(recipes.claims)
	var dedicated: Dictionary = preload("res://scripts/test/SpecialProductionBehaviorRunner.gd").new().run()
	_errors.append_array(dedicated.errors)
	keys.append_array(dedicated.verified_keys)
	_proofs.merge(dedicated.proofs)
	_claims.merge(dedicated.claims)
	var finite: Dictionary = preload("res://scripts/test/FiniteResearchBehaviorRunner.gd").new().run()
	_errors.append_array(finite.errors)
	keys.append_array(finite.verified_keys)
	_proofs.merge(finite.proofs)
	_claims.merge(finite.claims)
	var research_commands: Dictionary = preload("res://scripts/test/ResearchCommandBehaviorRunner.gd").new().run()
	_errors.append_array(research_commands.errors)
	var infinite: Dictionary = preload("res://scripts/test/InfiniteResearchBehaviorRunner.gd").new().run()
	_errors.append_array(infinite.errors)
	keys.append_array(infinite.verified_keys)
	_proofs.merge(infinite.proofs)
	_claims.merge(infinite.claims)
	var queries: Dictionary = preload("res://scripts/test/ResearchQueryBehaviorRunner.gd").new().run()
	_errors.append_array(queries.errors)
	keys.append_array(queries.verified_keys)
	_proofs.merge(queries.proofs)
	_claims.merge(queries.claims)
	var boundaries: Dictionary = preload("res://scripts/test/ResearchBoundaryBehaviorRunner.gd").new().run()
	_errors.append_array(boundaries.errors)
	keys.append_array(boundaries.verified_keys)
	_proofs.merge(boundaries.proofs)
	_claims.merge(boundaries.claims)
	var controls: Dictionary = preload("res://scripts/test/ResearchControlBehaviorRunner.gd").new().run()
	_errors.append_array(controls.errors)
	keys.append_array(controls.verified_keys)
	_proofs.merge(controls.proofs)
	_claims.merge(controls.claims)
	var progression: Dictionary = preload("res://scripts/test/ProgressionBehaviorRunner.gd").new().run()
	_errors.append_array(progression.errors)
	keys.append_array(progression.verified_keys)
	_proofs.merge(progression.proofs)
	_claims.merge(progression.claims)
	var campaign: Dictionary = await preload("res://scripts/test/CampaignUIBehaviorRunner.gd").new().run()
	_errors.append_array(campaign.errors)
	keys.append_array(campaign.verified_keys)
	_proofs.merge(campaign.proofs)
	_claims.merge(campaign.claims)
	var world: Dictionary = preload("res://scripts/test/WorldQueryBehaviorRunner.gd").new().run()
	_errors.append_array(world.errors)
	keys.append_array(world.verified_keys)
	_proofs.merge(world.proofs)
	_claims.merge(world.claims)
	var world_controls: Dictionary = preload("res://scripts/test/WorldControlBehaviorRunner.gd").new().run()
	_errors.append_array(world_controls.errors)
	keys.append_array(world_controls.verified_keys)
	_proofs.merge(world_controls.proofs)
	_claims.merge(world_controls.claims)
	var world_commands: Dictionary = preload("res://scripts/test/WorldCommandBehaviorRunner.gd").new().run()
	_errors.append_array(world_commands.errors)
	keys.append_array(world_commands.verified_keys)
	_proofs.merge(world_commands.proofs)
	_claims.merge(world_commands.claims)
	var discard: Dictionary = preload("res://scripts/test/InventoryDiscardBehaviorRunner.gd").new().run()
	_errors.append_array(discard.errors)
	keys.append_array(discard.verified_keys)
	_proofs.merge(discard.proofs)
	_claims.merge(discard.claims)
	var effects: Dictionary = preload("res://scripts/test/EffectQueryBehaviorRunner.gd").new().run()
	_errors.append_array(effects.errors)
	keys.append_array(effects.verified_keys)
	_proofs.merge(effects.proofs)
	_claims.merge(effects.claims)
	var manual: Dictionary = preload("res://scripts/test/ResourceManualBehaviorRunner.gd").new().run()
	_errors.append_array(manual.errors)
	keys.append_array(manual.verified_keys)
	_proofs.merge(manual.proofs)
	_claims.merge(manual.claims)
	var mining := preload("res://scripts/test/ResourceMiningRegression.gd").new().run()
	_errors.append_array(mining.errors)
	var mining_rejects := preload("res://scripts/test/ResourceMiningRegression.gd").rejection_errors()
	_errors.append_array(mining_rejects.errors)
	var mining_fixture := DSPOnlineParity.read_json(preload("res://scripts/test/ResourceMiningRegression.gd").FIXTURES.live60)
	var mining_paid := preload("res://scripts/test/ResourceMiningPersistenceRegression.gd").new().run(mining_fixture)
	_errors.append_array(mining_paid.errors)
	var mining_legacy := preload("res://scripts/test/LegacyMiningCompatibilityRegression.gd").new().run()
	_errors.append_array(mining_legacy.errors)
	if mining.cases != 11520 or mining_rejects.rejections != 64 or mining_paid.saves != 32 or mining_paid.panels != 33 or mining_legacy.saves != 6 or mining_legacy.rejections != 27 or mining_legacy.boundaries != 3: _errors.append("source mining numeric/paid/legacy/rejection counts incomplete")
	var resource_runner := preload("res://scripts/test/ResourcePlacementRegression.gd")
	var resource_placement: Dictionary = resource_runner.new().run()
	_errors.append_array(resource_placement.errors)
	_errors.append_array(resource_runner.rejection_errors())
	if resource_placement.bindings != 16 or resource_placement.saves != 16: _errors.append("resource placement sixteen funded bindings/disk roundtrips incomplete")
	var resource_boundaries := preload("res://scripts/test/ResourcePlacementBoundaryRegression.gd").new().run()
	_errors.append_array(resource_boundaries.errors)
	if resource_boundaries.cases != 15: _errors.append("resource placement fifteen atomic/native/custom boundaries incomplete")
	var resource_ui: Dictionary = await preload("res://scripts/test/ResourceSelectionUIRegression.gd").new().run(Engine.get_main_loop() as SceneTree)
	_errors.append_array(resource_ui.errors)
	if resource_ui.selections != 16 or resource_ui.rebindings != 13 or resource_ui.rejections != 15 or resource_ui.saves != 16: _errors.append("resource formal Inspector selection/binding/rejection/disk roundtrip incomplete")
	var item_input_capacity: Dictionary = preload("res://scripts/test/ItemInputCapacityBehaviorRunner.gd").new().run()
	_errors.append_array(item_input_capacity.errors)
	keys.append_array(item_input_capacity.verified_keys)
	_proofs.merge(item_input_capacity.proofs)
	_claims.merge(item_input_capacity.claims)
	var slot_capacity: Dictionary = preload("res://scripts/test/SlotCapacityBehaviorRunner.gd").new().run()
	_errors.append_array(slot_capacity.errors)
	keys.append_array(slot_capacity.verified_keys)
	_proofs.merge(slot_capacity.proofs)
	_claims.merge(slot_capacity.claims)
	var capacity_queries: Dictionary = preload("res://scripts/test/CapacityQueryBehaviorRunner.gd").new().run()
	_errors.append_array(capacity_queries.errors)
	keys.append_array(capacity_queries.verified_keys)
	_proofs.merge(capacity_queries.proofs)
	_claims.merge(capacity_queries.claims)
	var sail_lifetime: Dictionary = preload("res://scripts/test/SailLifetimeBehaviorRunner.gd").new().run()
	_errors.append_array(sail_lifetime.errors)
	keys.append_array(sail_lifetime.verified_keys)
	_proofs.merge(sail_lifetime.proofs)
	_claims.merge(sail_lifetime.claims)
	var logistics_scalars: Dictionary = preload("res://scripts/test/LogisticsScalarBehaviorRunner.gd").new().run()
	_errors.append_array(logistics_scalars.errors)
	keys.append_array(logistics_scalars.verified_keys)
	_proofs.merge(logistics_scalars.proofs)
	_claims.merge(logistics_scalars.claims)
	var route_queries: Dictionary = preload("res://scripts/test/RouteQueryBehaviorRunner.gd").new().run()
	_errors.append_array(route_queries.errors)
	keys.append_array(route_queries.verified_keys)
	_proofs.merge(route_queries.proofs)
	_claims.merge(route_queries.claims)
	keys.sort()
	var implementation := {}
	var files := IMPLEMENTATION_CHECKS.duplicate()
	for root in IMPLEMENTATION_ROOTS: _implementation_files(root, files)
	files.sort()
	for file in files: implementation[file] = FileAccess.get_sha256("res://" + file)
	return {"source_commit": fixture.source_commit, "source_catalog_sha256": FileAccess.get_sha256(DSPOnlineParity.ROOT + "dsponline_source_catalog.json"), "implementation_sha256": implementation, "errors": _errors.duplicate(), "verified_keys": keys, "proofs": _proofs.duplicate(true), "claims": _claims.duplicate(true)}

func _implementation_files(directory: String, files: Array) -> void:
	for child in DirAccess.get_directories_at("res://" + directory): _implementation_files(directory + "/" + child, files)
	for file in DirAccess.get_files_at("res://" + directory):
		if file.ends_with(".gd") or file.ends_with(".json"): files.append(directory + "/" + file)

func _test_belts(fixture: Dictionary) -> void:
	for tier in [1, 2, 3]:
		var key := "belts:conveyor_belt_mk%d" % tier
		var cases: Array = fixture.get("belt_cases", []).filter(func(row): return int(row.belt.tier) == tier)
		_check(key, cases.size() == 3, "three frozen capacity cases")
		for row in cases:
			var state := GameState.new()
			var item := "iron_ore"
			var stock := 10000.0
			var source := state.add_building({"type": "miner", "position": Vector2.ZERO, "output_item": item, "output_buffer": {item: stock}, "power_efficiency": 1.0})
			var target := state.add_building({"type": "smelter", "position": Vector2(400, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "input_buffer_capacity": stock, "power_efficiency": 1.0})
			var id := state.add_connection({"source_id": source, "target_id": target, "item_id": item, "type": "conveyor_belt_mk%d" % tier, "parallel_count": int(row.belt.lanes), "stack_size": int(row.belt.stackSize), "enabled": true, "monitor_enabled": true})
			var config := state.get_belt_configuration(id)
			_check(key, config.get("rated_throughput") == row.speed and config.get("effective_throughput") == row.capacity, row.id + ": frozen rated and multiplied capacity")
			BeltSystem.new(state).update(1.0)
			_check(key, state.buildings[target].input_buffer.get(item, 0) == row.capacity and state.buildings[source].output_buffer[item] == stock - row.capacity, row.id + ": real transfer and conservation")
			state.connections[id].enabled = false
			var before: Dictionary = state.buildings[target].input_buffer.duplicate(true)
			BeltSystem.new(state).update(1.0)
			_check(key, state.buildings[target].input_buffer == before, row.id + ": disabled transfer remains stopped")
			var saved := GameStateCodec.to_persistent_dict(state)
			var restored := GameStateCodec.from_persistent_dict(saved)
			_check(key, restored != null and restored.get_belt_configuration(id) == state.get_belt_configuration(id), row.id + ": configuration save round trip")

func _check(key: String, value: bool, assertion: String) -> void:
	if not _claims.has(key): _claims[key] = {"assertions": [], "failures": []}
	_claims[key].assertions.append(assertion)
	if not value:
		_claims[key].failures.append(assertion)
		_errors.append(key + ": " + assertion)
