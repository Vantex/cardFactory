extends Node

var failures := 0

func run() -> int:
	_test_blueprint_preflight()
	_test_environment_and_summaries()
	_test_validator()
	await _test_formal_entry_points()
	return failures

func _expect(ok: bool, label: String) -> void:
	if ok:
		print("PASS: final review " + label)
	else:
		failures += 1
		printerr("FAIL: final review " + label)

func _miner_blueprint() -> Dictionary:
	return {"version": 1, "entities": [{"ref": "miner", "type": "miner", "position": Vector2.ZERO, "configuration": {"output_item": "iron_ore"}}], "connections": []}

func _test_blueprint_preflight() -> void:
	for scenario in ["legal", "far", "mismatch", "depleted", "other_planet"]:
		var state := GameState.new()
		PlanetSystem.new(state).initialize_colonized_resource_sites()
		var position := Vector2(-470, -250)
		if scenario == "far": position = Vector2(3000, 3000)
		if scenario == "mismatch": position = Vector2(470, -250)
		if scenario == "depleted": state.resource_sites["home_iron_1"]["remaining"] = 0.0
		if scenario == "other_planet": state.resource_sites["home_iron_1"]["planet_id"] = "ashen"
		var before := GameStateCodec.state_digest_payload(state)
		var result := BlueprintSystem.new(state).deploy(_miner_blueprint(), position)
		if scenario == "legal":
			_expect(result.get("ok", false), "legal extractor blueprint deploys")
			if result.get("ok", false):
				var miner: Dictionary = state.buildings[result.entity_ids[0]]
				ProductionSystem.new(state).update(1.0)
				_expect(miner.get("resource_site_id", "") == "home_iron_1" and float(miner.output_buffer.get("iron_ore", 0)) > 0, "blueprint binding produces ore")
		else:
			_expect(not result.get("ok", true) and result.get("reason") == "invalid_resource_site" and before == GameStateCodec.state_digest_payload(state), "blueprint %s rejects without spending kits or IDs" % scenario)

func _test_environment_and_summaries() -> void:
	var state := GameState.new()
	state.completed_technologies.append("interstellar_logistics")
	state.explored_system_ids.append("borealis")
	state.survey_progress_by_system["borealis"] = 1.0
	var expected := {"home": 180.0, "ashen": 270.0, "frost": 144.0, "giant": 0.0}
	var solar_ids := {}
	for planet_id in expected:
		if planet_id != "home":
			state.colonized_planet_ids.append(planet_id)
			state.planet_inventories[planet_id] = {}
			state.planet_viewports[planet_id] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
		var solar := state.add_building({"type": "solar_panel", "planet_id": planet_id, "position": Vector2.ZERO, "generation_factor": 0.5, "input_buffer": {}, "output_buffer": {}})
		solar_ids[planet_id] = solar
	var wind := state.add_building({"type": "wind_turbine", "planet_id": "giant", "position": Vector2(300, 0), "generation_factor": 0.5, "input_buffer": {}, "output_buffer": {}})
	var thermal := state.add_building({"type": "power_generator", "planet_id": "giant", "position": Vector2(600, 0), "input_buffer": {"coal": 1.0}, "output_buffer": {}})
	state.add_building({"type": "smelter", "planet_id": "home", "position": Vector2(300, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}})
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	var engine := SimulationEngine.new(state)
	engine.update(1.0 / 60.0)
	for planet_id in expected:
		_expect(is_equal_approx(float(state.buildings[solar_ids[planet_id]].power_output), expected[planet_id]), "owning planet solar ratio " + planet_id)
	_expect(state.buildings[wind].power_output == 150.0 and state.buildings[thermal].power_output == 0.0 and state.buildings[thermal].input_buffer.coal == 1.0, "solar environment leaves wind unchanged and idle fuel generation does not burn coal")
	state.set_active_planet("giant")
	engine.update(1.0 / 60.0)
	_expect(state.buildings[solar_ids.ashen].power_output == 270.0, "background solar generation survives active switch")
	var galaxy := GalaxySystem.new(state)
	var before := GameStateCodec.state_digest_payload(state)
	var home := galaxy.get_planet_summary("home")
	var ashen := galaxy.get_planet_summary("ashen")
	_expect(home.industry.get("running_count", -1) == 1 and home.industry.get("blocked_count", -1) == 1 and home.industry.get("generation", -1) == 180.0 and home.industry.get("demand", -1) == 50.0, "industry summary reports real running blocked generation demand")
	_expect(ashen.industry.get("generation", -1) == 270.0 and ashen.industry.get("blocked_count", -1) == 0, "different planets report different industrial state")
	_expect(home.get("resource_sites", [])[0].has("remaining") and galaxy.get_system_summary("borealis").get("distance", -1) == 4.2, "details expose distance and remaining site reserves")
	var map := GalaxyMap.new()
	add_child(map)
	map.configure(state, galaxy, PlanetSystem.new(state, galaxy))
	map.call("_on_system_selected", "helios")
	map.call("_on_planet_selected", "home")
	var text_before := String(map.get("_industry_summary").text)
	_expect("180" in text_before and "运行 1" in text_before and "阻塞 1" in text_before and "倍率" in String(map.get("_description").text) and "剩余" in String(map.get("_resource_summary").text), "GalaxyMap renders complete real details")
	map.refresh_now()
	home.industry.inventory["forged"] = 100
	_expect(before == GameStateCodec.state_digest_payload(state), "summary copies and map refresh preserve authoritative digest")
	state.buildings[solar_ids.home]["generation_factor"] = 0.0
	engine.update(1.0 / 60.0)
	map.refresh_now()
	_expect(String(map.get("_industry_summary").text) != text_before, "map industrial detail updates after fixed ticks")
	map.queue_free()

func _test_validator() -> void:
	var state := GameState.new()
	state.completed_technologies.append("interstellar_logistics")
	state.planet_inventory["space_warper"] = 7.0
	var galaxy := GalaxySystem.new(state)
	galaxy.try_explore_system("borealis")
	galaxy.update_exploration(6.0)
	var valid := GameStateCodec.to_persistent_dict(state)
	_expect(SaveMigrationRegistry.migrate_to_current(valid).get("ok", false), "valid ongoing exploration round trips")
	var cases := [
		["explored_system_ids", ["helios", "helios"], "invalid_explored_system_ids"],
		["colonized_planet_ids", ["home", "home"], "invalid_colonized_planet_ids"],
		["colonized_planet_ids", ["home", "frost"], "colonized_system_unexplored"],
		["explored_system_ids", ["helios", "neutron"], "invalid_system_prerequisite"],
		["completed_technologies", [], "invalid_exploration_mission"],
		["exploration_missions", [{"system_id": "borealis", "duration_seconds": 1.0, "progress": 0.25}], "invalid_exploration_mission"],
		["survey_progress_by_system", {"helios": 1.0, "borealis": 0.75}, "invalid_survey_progress"],
		["survey_progress_by_system", {"helios": 0.5, "borealis": 0.25}, "invalid_survey_progress"],
		["survey_progress_by_system", {"borealis": 0.25}, "invalid_survey_progress"],
	]
	for fleet in [
		{"logistics_drone": 0, "logistics_vessel": 0, "unknown": 1},
		{"logistics_drone": -1, "logistics_vessel": 0},
		{"logistics_drone": 0.5, "logistics_vessel": 0},
		{"logistics_drone": INF, "logistics_vessel": 0},
		{"logistics_drone": NAN, "logistics_vessel": 0},
		{"logistics_drone": "5", "logistics_vessel": 0},
	]:
		cases.append(["portable_fleet", fleet, "invalid_portable_fleet"])
	for case in cases:
		var payload := valid.duplicate(true)
		payload[case[0]] = case[1]
		var result := SaveMigrationRegistry.migrate_to_current(payload)
		var codes := []
		for error in GameStateValidator.validate_persistent_dict(payload): codes.append(error.code)
		_expect(not result.get("ok", true) and codes.has(case[2]), "validator rejects %s with %s" % [case[0], case[2]])
	galaxy.update_exploration(18.0)
	_expect(state.colonized_planet_ids.has("frost") and SaveMigrationRegistry.migrate_to_current(GameStateCodec.to_persistent_dict(state)).get("ok", false), "pioneer landing round trips")

func _test_formal_entry_points() -> void:
	var old_save := GameManager.get_save_system()
	GameManager.configure_save_system(SaveSystem.new("res://.godot/final_review_%d" % Time.get_ticks_usec()))
	_expect(GameManager.start_new_game(0).get("ok", false), "formal new game saves")
	var state := GameManager.get_game_state()
	var before_coal := float(state.planet_inventory.get("coal", 0))
	var generator := ConstructionSystem.new(state).try_place_building("power_generator", Vector2.ZERO)
	var placed := ConstructionSystem.new(state).try_place_building("miner", Vector2(-470, -250))
	var engine := GameManager.get_simulation_engine()
	for tick in range(60): engine.update(1.0 / 60.0)
	_expect(before_coal == 10.0 and float(state.planet_inventory.get("coal", 0)) == 0.0 and generator.get("ok", false) and placed.get("ok", false) and is_equal_approx(state.buildings[generator.id].power_output, DataManager.get_building("miner").power_demand) and float(state.buildings[placed.id].output_buffer.get("iron_ore", 0)) > 0, "new home bootstrap powers legal mining without injected inventory")
	_expect(state.planet_inventory == state.planet_inventories.home and state.planet_inventory.get("iron_ingot", 0) == 12.0, "starter tray binds home compatibility projection")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	GameManager.set_process(false)
	var workspace: Node = main.get_node("FactoryWorkspaceUI")
	var miner_id := String(placed.id)
	state.buildings[miner_id]["position"] = Vector2(470, -250)
	workspace.call("set_selected_building", miner_id)
	_press_item(workspace, "copper_ore")
	_expect(state.buildings[miner_id].get("resource_site_id", "") == "home_copper_1", "real Inspector target button atomically rebinds copper")
	ProductionSystem.new(state).update(1.0)
	_expect(float(state.buildings[miner_id].output_buffer.get("copper_ore", 0)) > 0 and GameManager.save_current_game().get("ok", false), "Inspector success produces and saves valid binding")
	var before := GameStateCodec.state_digest_payload(state)
	_press_item(workspace, "iron_ore")
	_expect(before == GameStateCodec.state_digest_payload(state), "Inspector unavailable target preserves full digest")
	# Restore a valid fixture on RED so later independent regressions still execute.
	state.buildings[miner_id]["output_item"] = "copper_ore"
	state.buildings[miner_id]["resource_site_id"] = "home_copper_1"
	var camera: Camera2D = main.get_node("WorldCamera")
	for reason in ["manual", "autosave", "exit"]:
		camera.position += Vector2(100, 75)
		camera.zoom = Vector2(1.3, 1.3)
		var wanted := {"position": camera.position, "zoom": camera.zoom}
		var result: Dictionary
		if reason == "autosave": result = GameManager.advance_autosave(200.0)
		elif reason == "exit": result = GameManager.prepare_to_quit()
		else: result = GameManager.save_current_game()
		_expect(result.get("ok", false) and GameManager.continue_game(0).get("ok", false) and camera.position == wanted.position and camera.zoom == wanted.zoom, "no-travel %s save restores camera" % reason)
	state = GameManager.get_game_state()
	state.completed_technologies.append("interstellar_logistics")
	var smelter := ConstructionSystem.new(state).try_place_building("smelter", Vector2(900, 200))
	_expect(smelter.get("ok", false), "formal new game can place its starter smelter")
	if not smelter.get("ok", false):
		viewport.queue_free()
		await get_tree().process_frame
		GameManager.end_session()
		GameManager.set_process(true)
		GameManager.configure_save_system(old_save)
		return
	var smelter_id := String(smelter.id)
	var production := ProductionSystem.new(state)
	# Obtain every additional alloy precursor from the starter miner and the shipped base smelting recipes.
	production.update(36.0)
	_expect(_collect_building_output(state, miner_id, "copper_ore", 6.0), "starter miner yields copper precursor without inventory injection")
	_expect(_run_recipe_from_inventory(state, production, smelter_id, "copper_ingot_recipe", {"copper_ore": 6.0}, "copper_ingot", 6.0, 6.0), "base smelting produces the missing copper ingots")
	state.buildings[miner_id]["position"] = Vector2(-470, -250)
	state.buildings[miner_id]["output_item"] = "iron_ore"
	_expect(PlanetSystem.new(state).try_bind_extractor(miner_id, "home_iron_1").get("ok", false), "starter miner rebinds to the iron reserve")
	production.update(54.0)
	_expect(_collect_building_output(state, miner_id, "iron_ore", 9.0), "starter miner yields iron precursor without inventory injection")
	_expect(_run_recipe_from_inventory(state, production, smelter_id, "iron_ingot_recipe", {"iron_ore": 9.0}, "iron_ingot", 9.0, 9.0), "base smelting produces the missing iron ingots")

	var alloy_recipe := DataManager.get_recipe("titanium_alloy_recipe")
	_expect(not alloy_recipe.is_empty() and DataManager.is_recipe_supported_by_building(alloy_recipe, "smelter"), "shipped catalog exposes titanium alloy as a smelter recipe")
	workspace.call("set_selected_building", smelter_id)
	_expect(_press_recipe(workspace, "titanium_alloy_recipe"), "Inspector exposes and selects the titanium alloy recipe")
	var material_actions: Node = workspace.get_node("InspectorPanel/MaterialActions")
	_expect(material_actions.visible and material_actions.has_node("SupplyRecipe") and material_actions.has_node("CollectOutput"), "Inspector exposes production material actions")
	var inventory := InventorySystem.new(state)
	var rejected_before := GameStateCodec.state_digest_payload(state)
	_expect(not inventory.try_supply_recipe(smelter_id, 1000).get("ok", true) and rejected_before == GameStateCodec.state_digest_payload(state), "oversized supply preserves inventory and buffers")
	_expect(not inventory.try_collect_output(smelter_id, "titanium_alloy", 1000).get("ok", true) and rejected_before == GameStateCodec.state_digest_payload(state), "unavailable collection preserves inventory and buffers")
	_expect(_run_selected_recipe_from_inventory(state, production, smelter_id, {"iron_ingot": 5.0, "copper_ingot": 5.0}, "titanium_alloy", 20.0, 15.0), "formal smelter production creates all twenty titanium alloy")
	var craft := HandcraftSystem.new(state)
	material_actions.get_node("CollectOutput").pressed.emit()
	_expect(float(state.planet_inventory.get("titanium_alloy", 0)) == 20.0, "repeated UI collection cannot duplicate alloy")
	_expect(craft.queue_craft("handcraft_gear", 6).get("ok", false), "formal handcraft reserves the remaining gears")
	craft.update(3.0)
	_expect(craft.queue_craft("handcraft_processor", 5).get("ok", false), "formal handcraft reserves the fleet processors")
	craft.update(10.0)
	_expect(float(state.planet_inventory.get("gear", 0)) == 10.0 and float(state.planet_inventory.get("processor", 0)) == 5.0 and float(state.planet_inventory.get("titanium_alloy", 0)) == 20.0, "reachable precursor chain leaves the exact fleet and colony inputs")
	var queued := craft.queue_craft("handcraft_logistics_drone", 5)
	_expect(queued.get("ok", false), "reachable materials can craft fleet vehicles")
	craft.update(60.0)
	_expect(float(state.planet_inventory.get("titanium_alloy", 0)) == 10.0 and float(state.planet_inventory.get("logistics_drone", 0)) == 5.0, "fleet crafting reserves alloy exactly once and leaves the colony allocation")
	var map: Node = main.get_node("FactoryWorkspaceUI/GalaxyMap")
	map.call("_on_system_selected", "helios")
	map.call("_on_planet_selected", "giant")
	var fleet_button := map.find_child("FleetButton", true, false) as Button
	_expect(fleet_button != null, "GalaxyMap exposes formal vehicle enlistment")
	if fleet_button != null:
		_expect(not fleet_button.disabled, "crafted vehicles enable enlistment")
		fleet_button.pressed.emit()
		_expect(state.portable_fleet.logistics_drone == 5 and float(state.planet_inventory.get("logistics_drone", 0)) == 0 and float(state.planet_inventory.get("titanium_alloy", 0)) == 10.0, "formal enlistment transfers vehicles exactly once without spending colony materials")
		var enlisted := GameStateCodec.state_digest_payload(state)
		fleet_button.pressed.emit()
		_expect(enlisted == GameStateCodec.state_digest_payload(state), "repeated empty enlistment is atomic")
		var colony_button: Button = map.get("_colonize_button")
		_expect(not colony_button.disabled, "enlisted fleet enables giant colonization")
		colony_button.pressed.emit()
		_expect(state.colonized_planet_ids.has("giant") and state.portable_fleet.logistics_drone == 0 and not state.planet_inventory.has("titanium_alloy") and state.planet_inventories.giant.is_empty(), "formal giant colonization consumes five vehicles and ten alloy exactly once")
		var colonized := GameStateCodec.state_digest_payload(state)
		colony_button.pressed.emit()
		_expect(colonized == GameStateCodec.state_digest_payload(state), "repeated colony intent never spends twice")
	viewport.queue_free()
	await get_tree().process_frame
	GameManager.end_session()
	GameManager.set_process(true)
	GameManager.configure_save_system(old_save)

func _press_item(workspace: Node, item_id: String) -> void:
	var list: Node = workspace.get("_recipe_list")
	for button in list.get_children():
		if button is Button and String(DataManager.get_item(item_id).name) in button.text:
			button.pressed.emit()
			return
	_expect(false, "Inspector has target " + item_id)

func _press_recipe(workspace: Node, recipe_id: String) -> bool:
	var wanted_name := String(DataManager.get_recipe(recipe_id).get("name", recipe_id))
	var list: Node = workspace.get("_recipe_list")
	for button in list.get_children():
		if button is Button and wanted_name in button.text:
			button.pressed.emit()
			return String(GameManager.get_game_state().buildings.get(workspace.get("_selected_building_id"), {}).get("recipe_id", "")) == recipe_id
	return false

func _collect_building_output(state: GameState, building_id: String, item_id: String, amount: float) -> bool:
	return InventorySystem.new(state).try_collect_output(building_id, item_id, amount).get("ok", false)

func _run_recipe_from_inventory(state: GameState, production: ProductionSystem, building_id: String, recipe_id: String, inputs: Dictionary, output_item: String, output_amount: float, seconds: float) -> bool:
	if not state.set_entity_recipe(building_id, recipe_id):
		return false
	return _run_selected_recipe_from_inventory(state, production, building_id, inputs, output_item, output_amount, seconds)

func _run_selected_recipe_from_inventory(state: GameState, production: ProductionSystem, building_id: String, inputs: Dictionary, output_item: String, output_amount: float, seconds: float) -> bool:
	var recipe := DataManager.get_recipe(String(state.buildings[building_id].get("recipe_id", "")))
	if recipe.is_empty():
		return false
	var first: Dictionary = recipe.inputs[0]
	var batches := int(float(inputs.get(first.item_id, 0.0)) / float(first.amount))
	if not InventorySystem.new(state).try_supply_recipe(building_id, batches).get("ok", false):
		return false
	production.update(seconds)
	return _collect_building_output(state, building_id, output_item, output_amount)
