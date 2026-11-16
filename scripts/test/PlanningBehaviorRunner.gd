class_name PlanningBehaviorRunner
extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-planning.json"
const SUITE := "task27-planning"
const KEYS := {"create": "commands:StatisticsWorkspace.onCreatePlan", "update": "commands:StatisticsWorkspace.onUpdatePlan", "recipe": "commands:StatisticsWorkspace.onSetPlanRecipe", "remove": "commands:StatisticsWorkspace.onRemovePlan"}
var _errors: Array[String] = []
var _claims := {}

func run(fixture_override: Dictionary = {}) -> Dictionary:
	_errors.clear()
	_claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return {"errors": ["planning fixture provenance missing"], "verified_keys": [], "proofs": {}, "claims": {}}
	for required in ["src/game/content.ts", "src/game/engine.ts", "src/game/planning.ts", "src/game/statistics.ts"]:
		if not fixture.source_files.has(required): return {"errors": ["planning fixture source provenance missing"], "verified_keys": [], "proofs": {}, "claims": {}}
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return {"errors": ["planning fixture source drift"], "verified_keys": [], "proofs": {}, "claims": {}}
	var cases: Array = fixture.get("cases", [])
	_check(KEYS.create, cases.size() == 8, "eight source planning calculations present")
	for row in cases:
		var state := make_state(row.input)
		var system := ProductionPlanningSystem.new(state)
		var before := GameStateCodec.to_persistent_dict(state)
		_check(KEYS.create, same(system.get_recipe_options(row.plan.itemId), row.options), row.id + ": ordered unlocked alternatives")
		_check(KEYS.create, same(system.calculate(row.plan), row.result), row.id + ": full source requirements and aggregate result")
		_check(KEYS.create, GameStateCodec.to_persistent_dict(state) == before, row.id + ": read only calculation")
	var state := GameState.new()
	state._next_id = int(fixture.get("command_initial_id", 1))
	var system := ProductionPlanningSystem.new(state)
	var commands: Array = fixture.get("commands", [])
	_check(KEYS.create, commands.size() == 8, "eight source plan commands present")
	for index in range(commands.size()):
		var row: Dictionary = commands[index]
		var result := {}
		match row.operation:
			"create": result = system.create_plan(row.args[0], float(row.args[1]), row.args[2])
			"update": result = system.update_plan(row.args[0], row.args[1])
			"recipe": result = system.set_recipe(row.args[0], row.args[1], row.args[2])
			"remove": result = system.remove_plan(row.args[0])
		var key := String(KEYS.get(row.operation, KEYS.create))
		_check(key, result.get("ok", false) == row.changed and same(state.production_plans, row.plans) and state._next_id == int(row.next_id), "source command %d: %s" % [index, row.operation])
		var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
		_check(key, restored != null and restored.production_plans == state.production_plans, "source command %d: save round trip" % index)
	var proofs := {}
	var keys: Array[String] = []
	for key in KEYS.values():
		if _claims.has(key) and _claims[key].failures.is_empty() and not _claims[key].assertions.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": _claims[key].assertions.duplicate()}
	return {"errors": _errors, "verified_keys": keys, "proofs": proofs, "claims": _claims}

static func make_state(input: Dictionary) -> GameState:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	state.planet_inventories = input.planet_inventories.duplicate(true)
	state.planet_inventory = state.planet_inventories.home
	state.sync_active_planet_inventory()
	for id in input.completed_technologies: state.completed_technologies.append("dsp_" + id)
	state.elapsed_time = float(input.elapsed_time)
	for entity in input.machines:
		state.add_building({"id": entity.id, "type": "dsp_" + entity.buildingId, "planet_id": entity.planetId, "position": Vector2(entity.position.x, entity.position.y), "recipe_id": "dsp_" + entity.recipeId, "input_buffer": entity.inputs.duplicate(), "output_buffer": entity.outputs.duplicate(), "production_utilization": entity.utilization, "speed": DataManager.get_building("dsp_" + entity.buildingId).speed})
	state._next_id = int(input.next_id)
	return state

static func same(actual: Variant, expected: Variant) -> bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not same(actual[key], expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not same(actual[i], expected[i]): return false
		return true
	if (actual is float or actual is int) and (expected is float or expected is int): return absf(float(actual) - float(expected)) <= 0.00001 * maxf(1.0, absf(float(expected)))
	return actual == expected

func _check(key: String, value: bool, assertion: String) -> void:
	if not _claims.has(key): _claims[key] = {"assertions": [], "failures": []}
	_claims[key].assertions.append(assertion)
	if not value:
		_claims[key].failures.append(assertion)
		_errors.append(key + ": " + assertion)
