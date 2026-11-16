class_name RecipeBehaviorRunner
extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-production.json"
const SUITE := "task27-material-production"
var _errors: Array[String] = []
var _claims := {}

func run(fixture_override: Dictionary = {}) -> Dictionary:
	_errors.clear()
	_claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary or not fixture.source_files.has("src/game/engine.ts") or not fixture.source_files.has("src/game/content.ts"):
		return _rejected("material production provenance missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _rejected("material production source drift")
	var definitions := {}
	for row in source.catalog.recipes: definitions[row.id] = row.definition
	var cases: Array = fixture.get("cases", [])
	var seen := {}
	if cases.size() != 73: return _rejected("material production cases incomplete")
	for row in cases:
		var id := String(row.id)
		var key := "recipes:" + id
		if seen.has(id) or not definitions.has(id): return _rejected("duplicate or unknown material recipe")
		seen[id] = true
		var definition: Dictionary = definitions[id]
		var recipe := DataManager.get_recipe("dsp_" + id)
		_check(key, recipe.get("source_id") == id and recipe.get("building_id") == "dsp_" + definition.buildingId, "source identity and primary machine")
		_check(key, recipe.get("duration") == definition.duration and recipe.get("required_source_technology", "") == definition.get("requiredTechId", ""), "source duration and technology prerequisite")
		_check(key, _amounts(recipe.get("inputs", []), false) == _amounts(definition.inputs, true) and _amounts(recipe.get("outputs", []), false) == _amounts(definition.outputs, true), "complete source input and output definition")
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721)
		var building_id := state.add_building({"type": "dsp_" + row.input.buildingId, "recipe_id": "", "position": Vector2.ZERO, "speed": DataManager.get_building("dsp_" + row.input.buildingId).speed, "input_buffer": {}, "output_buffer": {}, "power_efficiency": 1.0})
		if definition.has("requiredTechId"):
			var before := GameStateCodec.to_persistent_dict(state)
			_check(key, not state.set_entity_recipe(building_id, "dsp_" + id) and GameStateCodec.to_persistent_dict(state) == before, "locked recipe selection is atomic")
		for tech in source.catalog.technologies: state.completed_technologies.append("dsp_" + tech.id)
		_check(key, state.set_entity_recipe(building_id, "dsp_" + id), "unlocked recipe selected through real command")
		var building: Dictionary = state.buildings[building_id]
		building.input_buffer = row.input.inputs.duplicate(true)
		building.output_buffer = row.input.outputs.duplicate(true)
		var system := ProductionSystem.new(state)
		system.update(float(row.seconds))
		_check(key, PlanningBehaviorRunner.same(building.input_buffer, row.expected.inputs), "actual source input consumption")
		_check(key, PlanningBehaviorRunner.same(building.output_buffer, row.expected.outputs), "actual source output conversion")
		var phase := float(building.get("progress", 0)) / float(recipe.duration)
		_check(key, absf(phase - float(row.expected.progress)) <= float(row.phase_rounding_bound), "normalized cycle phase within source rounding bound")
		var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
		_check(key, restored != null and restored.buildings[building_id].input_buffer == building.input_buffer and restored.buildings[building_id].output_buffer == building.output_buffer and restored.buildings[building_id].progress == building.progress, "partial cycle and ownership survive save round trip")
		building.power_efficiency = 0.0
		var before := GameStateCodec.to_persistent_dict(state)
		system.update(1.0)
		_check(key, GameStateCodec.to_persistent_dict(state) == before, "no power consumes nothing")
		building.power_efficiency = 1.0
		building.input_buffer = {}
		before = GameStateCodec.to_persistent_dict(state)
		system.update(1.0)
		_check(key, GameStateCodec.to_persistent_dict(state) == before, "missing inputs consume nothing")
		building.input_buffer = row.input.inputs.duplicate(true)
		var capacity := float(DataManager.get_building(building.type).output_buffer_capacity)
		for output in recipe.outputs: building.output_buffer[output.item_id] = capacity
		before = GameStateCodec.to_persistent_dict(state)
		system.update(1.0)
		_check(key, GameStateCodec.to_persistent_dict(state) == before, "full output buffer consumes nothing")
	var keys: Array[String] = []
	var proofs := {}
	for key in _claims:
		if _claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": _claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": _errors, "verified_keys": keys, "proofs": proofs, "claims": _claims}

static func _amounts(rows: Array, source: bool) -> Dictionary:
	var result := {}
	for row in rows: result[String(row["itemId" if source else "item_id"])] = float(row.amount)
	return result

static func _rejected(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}

func _check(key: String, value: bool, assertion: String) -> void:
	if not _claims.has(key): _claims[key] = {"assertions": [], "failures": []}
	_claims[key].assertions.append(assertion)
	if not value:
		_claims[key].failures.append(assertion)
		_errors.append(key + ": " + assertion)
