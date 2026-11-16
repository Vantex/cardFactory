extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-recipe-changes.json"
const KEY := "commands:engine.setEntityRecipe"
var _errors: Array[String] = []
var _assertions: Array[String] = []

func run() -> Dictionary:
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	_errors.clear()
	_assertions.clear()
	_check(fixture.get("source_commit") == source.source.commit and fixture.get("cases", []).size() == 5, "five frozen recipe commands")
	for file in fixture.source_files: _check(fixture.source_files[file] == source.source.files.get(file), "source provenance: " + String(file))
	for row in fixture.cases:
		var state := _state(fixture.input, row.interaction_locked)
		var before := GameStateCodec.to_persistent_dict(state)
		var subject := String(state.buildings.keys()[0])
		var ok := state.set_entity_recipe(subject, "dsp_" + row.recipe_id)
		var entity: Dictionary = state.buildings[subject]
		_check(ok == bool(row.changed) or not row.changed and row.id == "same" and ok, row.id + ": command acceptance")
		_check(entity.recipe_id == "dsp_" + row.expected.machine.recipeId and PlanningBehaviorRunner.same(entity.input_buffer, row.expected.machine.inputs) and PlanningBehaviorRunner.same(entity.output_buffer, row.expected.machine.outputs), row.id + ": recipe and material buffers")
		_check(is_equal_approx(float(entity.progress), float(row.expected.machine.progress) * float(DataManager.get_recipe(entity.recipe_id).duration)), row.id + ": cycle phase")
		_check(PlanningBehaviorRunner.same(state.get_planet_inventory("home"), row.expected.tray), row.id + ": source material refund")
		_check(state.connections.size() == row.expected.belts.size() and int(state.construction_inventory.conveyor_belt_mk1) == int(row.expected.construction.conveyor_belt_mk1), row.id + ": paid lanes refunded and connections removed")
		if not row.changed: _check(GameStateCodec.to_persistent_dict(state) == before, row.id + ": no ownership mutation")
		var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
		_check(restored != null and GameStateCodec.to_persistent_dict(restored) == GameStateCodec.to_persistent_dict(state), row.id + ": schema v9 round trip")
	_test_capacity(fixture.input)
	_test_locked_connection(fixture.input)
	var claim := {"assertions": _assertions.duplicate(), "failures": _errors.duplicate()}
	var proof := {"suite": "task27-recipe-commands", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": _assertions.duplicate()}
	return {"errors": _errors.duplicate(), "verified_keys": [KEY] if _errors.is_empty() else [], "claims": {KEY: claim}, "proofs": {KEY: proof} if _errors.is_empty() else {}}

func _state(input: Dictionary, locked: bool = false) -> GameState:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	state.initialize_new_game_home_inventory(true)
	state.planet_inventory.clear()
	state.planet_inventory.merge(input.tray.duplicate(true))
	state.construction_inventory.conveyor_belt_mk1 = input.construction.conveyor_belt_mk1
	var entity: Dictionary = input.machine
	var subject := state.add_building({"type": "dsp_arc_smelter", "position": Vector2(200, 0), "planet_id": "home", "recipe_id": "dsp_" + entity.recipeId, "input_buffer": entity.inputs.duplicate(true), "output_buffer": entity.outputs.duplicate(true), "progress": float(entity.progress) * float(DataManager.get_recipe("dsp_" + entity.recipeId).duration), "interaction_locked": locked})
	var feed := state.add_building({"type": "dsp_storage_mk1", "position": Vector2.ZERO, "planet_id": "home", "stored_item": "iron_ore"})
	var receive := state.add_building({"type": "dsp_storage_mk1", "position": Vector2(400, 0), "planet_id": "home", "stored_item": "iron_ingot"})
	for line in input.belts:
		state.add_connection({"source_id": feed if line.target == entity.id else subject, "target_id": subject if line.target == entity.id else receive, "type": "conveyor_belt_mk1", "item_id": line.itemId, "parallel_count": int(line.lanes), "construction_accounted": true})
	return state

func _test_capacity(input: Dictionary) -> void:
	for full in ["tray", "kits"]:
		var state := _state(input)
		if full == "tray": state.planet_inventory.iron_ore = PlanetTraySystem.new(state).limit("home")
		else: state.construction_inventory.conveyor_belt_mk1 = GameState.BELT_MAX_INVENTORY
		var before := GameStateCodec.to_persistent_dict(state)
		_check(not state.set_entity_recipe(String(state.buildings.keys()[0]), "dsp_copper_ingot") and GameStateCodec.to_persistent_dict(state) == before, full + ": conservation adaptation rejects refund overflow atomically")

func _test_locked_connection(input: Dictionary) -> void:
	var state := _state(input)
	var subject := String(state.buildings.keys()[0])
	var feed := String(state.buildings.keys()[1])
	state.connections.clear()
	state.buildings[subject].recipe_id = ""
	state.buildings[subject].input_buffer = {}
	state.buildings[subject].output_buffer = {}
	state.set_entities_interaction_locked([subject], true)
	var before := GameStateCodec.to_persistent_dict(state)
	var result := state.try_add_connection(feed, subject, "iron_ore")
	_check(not result.ok and GameStateCodec.to_persistent_dict(state) == before, "locked automatic recipe selection rejects connection without consuming kits")

func _check(ok: bool, assertion: String) -> void:
	_assertions.append(assertion)
	if not ok: _errors.append(assertion)
