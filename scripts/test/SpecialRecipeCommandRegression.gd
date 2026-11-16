extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-special-recipe-changes.json"
var errors: Array[String] = []

func run() -> Array[String]:
	errors.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	_check(fixture.get("source_commit") == source.source.commit and fixture.get("cases", []).size() == 24, "twenty-four frozen special commands")
	for file in fixture.source_files: _check(fixture.source_files[file] == source.source.files.get(file), "special command source provenance: " + String(file))
	for row in fixture.cases:
		var setup := _state(row.input)
		var state: GameState = setup.state
		var subject: String = setup.ids.get(row.input.subject, "not_registered")
		var before := GameStateCodec.to_persistent_dict(state)
		var ok := state.set_energy_mode(subject, row.value) if row.operation == "mode" else state.set_entity_recipe(subject, "dsp_" + row.value)
		_check(ok == row.changed or not row.changed and row.id.ends_with("-same") and ok, row.id + ": command acceptance")
		for expected in row.expected.entities:
			var entity: Dictionary = state.buildings[setup.ids[expected.id]]
			var expected_recipe := "dsp_" + String(expected.recipeId) if expected.has("recipeId") else ""
			_check(entity.recipe_id == expected_recipe and PlanningBehaviorRunner.same(entity.input_buffer, expected.inputs) and PlanningBehaviorRunner.same(entity.output_buffer, expected.outputs), row.id + ": recipe and buffers for " + expected.id)
			_check(is_equal_approx(float(entity.progress), float(expected.progress) * float(DataManager.get_recipe(entity.recipe_id).get("duration", 1))), row.id + ": phase for " + expected.id)
			_check(PlanningBehaviorRunner.same(entity.proliferator_bonus, expected.get("proliferatorBonusProgress", {})), row.id + ": spray remainder for " + expected.id)
			if expected.has("energyMode"):
				_check(entity.energy_mode == expected.energyMode and is_equal_approx(float(entity.stored_energy_mj), float(expected.storedEnergyMj)), row.id + ": distinct mode and retained energy")
			for fields in [["powerOutputKw", "power_output"], ["powerInputKw", "power_input"], ["productionRate", "last_production_per_minute"], ["utilization", "production_utilization"]]:
				if expected.has(fields[0]): _check(is_equal_approx(float(entity.get(fields[1], 0)), float(expected[fields[0]])), row.id + ": immediate " + fields[0] + " for " + expected.id)
		_check(PlanningBehaviorRunner.same(state.get_planet_inventory("home"), row.expected.tray), row.id + ": material ownership refund")
		_check(state.connections.size() == row.expected.belts.size() and state.construction_inventory.conveyor_belt_mk1 == row.expected.construction.conveyor_belt_mk1, row.id + ": paid connections and kit ownership")
		if not row.changed: _check(GameStateCodec.to_persistent_dict(state) == before, row.id + ": rejected/repeated command is read only")
		var decoded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
		_check(decoded != null and GameStateCodec.to_persistent_dict(decoded) == GameStateCodec.to_persistent_dict(state), row.id + ": validated save round trip")
	_test_batch_and_capacity(fixture.cases.filter(func(row): return row.id == "energy-mode-switch")[0].input)
	return errors

func _state(input: Dictionary) -> Dictionary:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	state.initialize_new_game_home_inventory(true)
	state.planet_inventory.clear()
	state.planet_inventory.merge(input.tray.duplicate(true))
	state.construction_inventory.conveyor_belt_mk1 = input.construction.conveyor_belt_mk1
	for tech in input.completed_technologies: state.completed_technologies.append("dsp_" + tech)
	var ids := {}
	for source in input.entities:
		var recipe := "dsp_" + String(source.recipeId) if source.has("recipeId") else ""
		var entity := {"type": "dsp_" + String(source.buildingId), "position": Vector2(source.position.x, source.position.y), "planet_id": source.planetId, "recipe_id": recipe, "input_buffer": source.inputs.duplicate(true), "output_buffer": source.outputs.duplicate(true), "progress": float(source.progress) * float(DataManager.get_recipe(recipe).get("duration", 1)), "proliferator_bonus": source.get("proliferatorBonusProgress", {}).duplicate(true), "interaction_locked": source.get("interactionLocked", false), "last_production_per_minute": source.productionRate, "production_utilization": source.utilization}
		if source.has("storedItemId"): entity.stored_item = source.storedItemId
		if source.has("energyMode"): entity.energy_mode = source.energyMode
		if source.has("storedEnergyMj"): entity.stored_energy_mj = source.storedEnergyMj
		if source.has("powerOutputKw"): entity.power_output = source.powerOutputKw
		if source.has("powerInputKw"): entity.power_input = source.powerInputKw
		ids[source.id] = state.add_building(entity)
	for line in input.belts:
		state.add_connection({"source_id": ids[line.source], "target_id": ids[line.target], "type": "conveyor_belt_mk1", "item_id": line.itemId, "parallel_count": int(line.lanes), "construction_accounted": true})
	if int(input.structure_points) > 0:
		var system := SourceDysonEngineering.new(state).ensure(input.dyson_system)
		system.source_plan.structure_points = int(input.structure_points)
		system.rockets_launched = int(input.structure_points)
	return {"state": state, "ids": ids}

func _test_batch_and_capacity(input: Dictionary) -> void:
	for full in ["tray", "kits"]:
		var setup := _state(input)
		var state: GameState = setup.state
		var subject: String = setup.ids[input.subject]
		if full == "tray": state.planet_inventory.accumulator = PlanetTraySystem.new(state).limit("home")
		else: state.construction_inventory.conveyor_belt_mk1 = GameState.BELT_MAX_INVENTORY
		var before := GameStateCodec.to_persistent_dict(state)
		_check(not state.set_energy_mode(subject, "discharge") and GameStateCodec.to_persistent_dict(state) == before, full + ": mode refund overflow is atomic")
	var setup := _state(input)
	var state: GameState = setup.state
	var first: String = setup.ids[input.subject]
	var clone: Dictionary = state.buildings[first].duplicate(true)
	clone.position = Vector2(800, 0)
	var second := state.add_building(clone)
	state.planet_inventory.accumulator = PlanetTraySystem.new(state).limit("home") - 4
	var before := GameStateCodec.to_persistent_dict(state)
	_check(not state.try_configure_power_entities([first, second], {"energy_mode": "discharge", "power_grid_id": "grid-b"}).ok and GameStateCodec.to_persistent_dict(state) == before, "combined batch refunds preflight every entity and configuration")
	state.planet_inventory.accumulator = 0.0
	_check(state.try_configure_power_entities([first, second], {"energy_mode": "discharge", "power_grid_id": "grid-b"}).ok and state.planet_inventory.accumulator == 6 and state.planet_inventory.charged_accumulator == 4 and state.connections.is_empty(), "successful batch refunds all source buffers and paid connections")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
