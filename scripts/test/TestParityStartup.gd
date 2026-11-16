extends Node

var failures := 0

func _ready() -> void:
	var fixture := DSPOnlineParity.read_json(ParityBehaviorRunner.FIXTURE)
	var old_storage := GameManager.get_save_system()
	GameManager.configure_save_system(SaveSystem.new("res://.godot/task27-startup-%d" % Time.get_ticks_usec()))
	GameManager.set_process(false)
	for mode in ["normal", "speedrun"]:
		for difficulty in ["relaxed", "standard", "hard"]:
			var result := GameManager.start_new_game(0, mode, difficulty)
			check(result.ok, "real new game saves: " + mode + "/" + difficulty)
			if not result.ok: continue
			var state := GameManager.get_game_state()
			check(state.planet_inventory == fixture.initial_economy.tray, "frozen starting tray: " + mode + "/" + difficulty)
			check(_positive_source_stock(state) == _positive(fixture.initial_economy.construction), "frozen starting construction: " + mode + "/" + difficulty)
			var workspace := FactoryWorkspaceUI.new()
			check(workspace._construction_item_total(state) == 13, "source starter building kits appear in desktop stock total")
			workspace.free()
			check(state.colonized_planet_ids == fixture.initial_economy.colonies, "frozen starting colonies")
			var loaded := GameManager.get_save_system().load_slot(0)
			check(loaded.ok and loaded.state.planet_inventory == state.planet_inventory and loaded.state.construction_inventory == state.construction_inventory, "new economy survives real disk round trip")
	GameManager.end_session()
	_test_beginner_journey()
	GameManager.end_session()
	GameManager.configure_save_system(old_storage)
	_test_rewards(fixture)
	GameManager.set_process(true)
	if failures == 0: print("PARITY STARTUP TESTS PASSED")
	else: printerr("PARITY STARTUP TESTS FAILED: ", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _test_beginner_journey() -> void:
	check(GameManager.start_new_game(1).ok, "clean beginner session starts")
	var state := GameManager.get_game_state()
	var engine := GameManager.get_simulation_engine()
	var order := ConstructionAutomationSystem.new(state).queue("dsp_electromagnetic_matrix", 3)
	check(order.ok, "starting raw materials fund first blue matrices without injected items")
	if not order.ok: return
	for tick in range(6000):
		engine.update(1.0 / 60.0)
		if state.production_orders.is_empty(): break
	check(state.planet_inventory.get("electromagnetic_matrix", 0) == 3, "real manufacturing produces first three matrices")
	var wind := state.try_place_building(state.get_dock_building_type("power_generator"), Vector2(650, 0))
	var lab := state.try_place_building(state.get_dock_building_type("matrix_lab"), Vector2(300, 0))
	check(wind.ok and lab.ok, "source starter kits deploy wind and laboratory before their manufacturing research")
	if not lab.ok: return
	check(state.set_entity_recipe(lab.id, "dsp_matrix_research"), "starter laboratory accepts research mode")
	var technology := TechnologySystem.new(state)
	check(technology.start_research("dsp_electromagnetic_matrix") and technology.supply_source_lab(lab.id).ok, "first research consumes real manufactured matrices")
	for tick in range(1800):
		engine.update(1.0 / 60.0)
		if state.completed_technologies.has("dsp_electromagnetic_matrix"): break
	check(state.completed_technologies.has("dsp_electromagnetic_matrix") and state.buildings[lab.id].input_buffer.get("electromagnetic_matrix", 0) == 0, "first source research finishes through fixed simulation")
	check(state.construction_inventory.get("dsp_matrix_lab", 0) == 3, "first real completion grants two laboratory kits")
	check(GameManager.save_current_game().ok, "beginner production and research save to disk")
	var legacy := GameState.new()
	legacy.initialize_new_game_home_inventory()
	var before := GameStateCodec.to_persistent_dict(legacy)
	var loaded := GameStateCodec.from_persistent_dict(before)
	check(loaded != null and loaded.planet_inventory == GameState.NEW_GAME_HOME_INVENTORY and loaded.construction_inventory.miner == 1 and loaded.get_dock_building_type("miner") == "miner", "legacy tray and construction remain unchanged on load")

func _test_rewards(fixture: Dictionary) -> void:
	for row in fixture.research_rewards:
		var state := GameState.new()
		state.construction_inventory.clear()
		SourceGalaxySystem.new(state).initialize(240721, false)
		var technology := TechnologySystem.new(state)
		technology._complete_research("dsp_" + row.tech_id)
		check(_positive_source_stock(state) == _positive(row.once), "frozen first research reward: " + row.tech_id)
		var once := state.construction_inventory.duplicate(true)
		technology._complete_research("dsp_" + row.tech_id)
		check(state.construction_inventory == once and _positive_source_stock(state) == _positive(row.twice), "frozen repeated reward is idempotent: " + row.tech_id)
		check(state.colonized_planet_ids == row.colonies, "frozen research colony effect: " + row.tech_id)
		var loaded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
		check(loaded != null and loaded.construction_inventory == state.construction_inventory, "reward boundary remains save-valid: " + row.tech_id)

func _positive_source_stock(state: GameState) -> Dictionary:
	var result := {}
	for id in state.construction_inventory:
		if float(state.construction_inventory[id]) <= 0: continue
		var source_id := String(id).trim_prefix("dsp_") if String(id).begins_with("dsp_") else String(id) if String(id).begins_with("conveyor_belt_") else "legacy:" + String(id)
		result[source_id] = state.construction_inventory[id]
	return result

func _positive(stock: Dictionary) -> Dictionary:
	var result := {}
	for id in stock:
		if float(stock[id]) > 0: result[id] = stock[id]
	return result

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		if failures <= 12: printerr("FAIL: " + label)
