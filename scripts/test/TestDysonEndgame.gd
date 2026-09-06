extends Node

var failures := 0

func _ready() -> void:
	_test_commands_and_lifetime()
	_test_construction_and_save()
	_test_power_isolation()
	_test_real_engine_and_production()
	await _test_ui()
	if failures > 0:
		printerr("DYSON ENDGAME TESTS FAILED")
		get_tree().quit(1)
		return
	print("DYSON ENDGAME TESTS PASSED")
	get_tree().quit(0)

func _state() -> GameState:
	var state := GameState.new()
	state.completed_technologies = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics", "dyson_engineering"]
	return state

func _place(state: GameState, type: String, position: Vector2) -> String:
	state.construction_inventory[type] = 1.0
	var result := state.try_place_building(type, position)
	_expect(result.ok, "formal placement: " + type)
	if not result.ok:
		return ""
	state.buildings[result.id].power_efficiency = 1.0
	return result.id

func _advance(dyson: DysonSphereSystem, count: int) -> void:
	for i in range(count):
		dyson.begin_tick()
		dyson.update_launches(1.0 / 60)

func _test_commands_and_lifetime() -> void:
	var state := _state()
	var dyson := DysonSphereSystem.new(state)
	state.completed_technologies.erase("dyson_engineering")
	var before := GameStateCodec.to_persistent_dict(state)
	_expect(not dyson.create_orbit("helios").ok and GameStateCodec.to_persistent_dict(state) == before, "technology gate is atomic")
	state.completed_technologies.append("dyson_engineering")
	before = GameStateCodec.to_persistent_dict(state)
	_expect(not dyson.create_orbit("helios", NAN).ok and not dyson.create_orbit("borealis").ok and GameStateCodec.to_persistent_dict(state) == before, "invalid geometry and unexplored system leave no state")
	var orbit: String = dyson.create_orbit("helios").id
	var second: String = dyson.create_orbit("helios", 20000, 45, 30).id
	var emitter := _place(state, "solar_sail_ejector", Vector2.ZERO)
	state.planet_inventory["solar_sail"] = 2.0
	_expect(dyson.configure_launcher(emitter, second).ok and dyson.load_ammo(emitter, 2).ok, "configure and load real solar sails")
	state.buildings[emitter].power_efficiency = 0
	_advance(dyson, 120)
	_expect(dyson.get_summary("helios").launched_sails == 0 and state.buildings[emitter].input_buffer.solar_sail == 2, "unpowered launcher cannot consume ammo")
	state.buildings[emitter].power_efficiency = 0.5
	_advance(dyson, 120)
	_expect(dyson.get_summary("helios").launched_sails == 1, "partial power scales launch speed")
	_expect(state.dyson_systems.helios.orbits[orbit].cohorts.is_empty() and state.dyson_systems.helios.orbits[second].cohorts.size() == 1, "launch selects exact orbit")
	dyson.configure_launcher(emitter, second, false)
	var launch_tick := state.dyson_tick
	for i in range(int(dyson.rules.sail_lifetime_ticks) - 1):
		dyson.begin_tick()
	_expect(dyson.get_summary("helios").live_sails == 1, "sail survives until its expiration tick")
	dyson.begin_tick()
	_expect(state.dyson_tick == launch_tick + int(dyson.rules.sail_lifetime_ticks) and dyson.get_summary("helios").live_sails == 0 and dyson.get_summary("helios").expired_sails == 1, "sail expires exactly once")
	before = GameStateCodec.to_persistent_dict(state)
	_expect(not dyson.load_ammo(emitter, 100).ok and GameStateCodec.to_persistent_dict(state) == before, "invalid ammo loading is atomic")
	var copy := dyson.get_system("helios")
	copy.orbits.clear()
	_expect(state.dyson_systems.helios.orbits.size() == 2, "view snapshots cannot mutate state")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "expired state remains valid")

func _test_construction_and_save() -> void:
	var state := _state()
	var dyson := DysonSphereSystem.new(state)
	var orbit: String = dyson.create_orbit("helios").id
	var layer: String = dyson.create_layer("helios", orbit).id
	_expect(not dyson.plan_shell("helios", layer).ok, "shell requires three nodes")
	for angle in [0.0, 120.0, 240.0]:
		_expect(dyson.add_node("helios", layer, angle).ok, "plan triangle node")
	_expect(not dyson.add_node("helios", layer, 120).ok, "duplicate node rejected")
	_expect(dyson.plan_shell("helios", layer).ok and not dyson.plan_shell("helios", layer).ok, "shell plan is unique")
	_expect(dyson.get_summary("helios").power_kw == 0 and dyson.get_summary("helios").missing_rockets == 6, "plans produce no free power or structure")
	var emitter := _place(state, "solar_sail_ejector", Vector2.ZERO)
	var launcher := _place(state, "dyson_sphere_launcher", Vector2(300, 0))
	state.planet_inventory["solar_sail"] = 60.0
	state.planet_inventory["small_carrier_rocket"] = 6.0
	dyson.configure_launcher(emitter, orbit)
	dyson.configure_launcher(launcher, layer)
	dyson.load_ammo(emitter, 60)
	dyson.load_ammo(launcher, 6)
	_advance(dyson, 600)
	var save := SaveSystem.new("res://.godot/task14-saves")
	var saved := save.save_slot(1, state)
	_expect(saved.ok, "real in-progress Dyson save: " + str(saved.get("error", {})))
	var loaded := save.load_slot(1)
	_expect(loaded.ok, "real Dyson save loads")
	if not loaded.ok:
		return
	var restored: GameState = loaded.state
	for building in restored.buildings.values():
		building.power_efficiency = 1.0
	var resumed := DysonSphereSystem.new(restored)
	_advance(dyson, 5400)
	_advance(resumed, 5400)
	_expect(GameStateCodec.to_persistent_dict(state) == GameStateCodec.to_persistent_dict(restored), "resumed construction matches uninterrupted state")
	var summary := dyson.get_summary("helios")
	_expect(summary.launched_sails == 60 and summary.absorbed_sails == 60 and summary.live_sails == 0 and summary.rockets_launched == 6 and summary.structure_points == 6, "rockets and sails have exactly one structural destination")
	_expect(summary.power_kw == 3000 and summary.missing_sails == 0 and summary.missing_rockets == 0, "completed shell power and deficits reflect real construction")
	var before := GameStateCodec.to_persistent_dict(state)
	_expect(not dyson.remove_plan("helios", layer, "layers").ok and GameStateCodec.to_persistent_dict(state) == before, "built layer cannot silently discard material")
	var bad := before.duplicate(true)
	bad.dyson_systems.helios.sails_launched += 1
	_expect(GameStateCodec.from_persistent_dict(bad) == null, "save rejects nonconserved sails")
	bad = before.duplicate(true)
	bad.dyson_systems.helios.layers[layer].orbit_id = "missing"
	_expect(GameStateCodec.from_persistent_dict(bad) == null, "save rejects dangling layer orbit")
	bad = before.duplicate(true)
	bad.dyson_tick = "6000"
	_expect(GameStateCodec.from_persistent_dict(bad) == null, "save rejects string tick")
	var legacy := before.duplicate(true)
	legacy.schema_version = 7
	legacy.erase("dyson_systems")
	legacy.erase("dyson_tick")
	for building in legacy.buildings.values():
		building.erase("dyson")
	var migrated := GameStateCodec.from_persistent_dict(legacy)
	_expect(migrated != null and migrated.dyson_systems.is_empty() and migrated.dyson_tick == 0, "v7 migration gives no free megastructure")

func _test_power_isolation() -> void:
	var state := _state()
	state.explored_system_ids.append("borealis")
	state.survey_progress_by_system.borealis = 1.0
	state.colonized_planet_ids.append("frost")
	state.planet_inventories.frost = {}
	state.planet_viewports.frost = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	var dyson := DysonSphereSystem.new(state)
	var orbit: String = dyson.create_orbit("helios").id
	var remote: String = dyson.create_orbit("borealis").id
	var emitter := _place(state, "solar_sail_ejector", Vector2.ZERO)
	_expect(not dyson.configure_launcher(emitter, remote).ok, "launcher rejects other system target")
	var a := _place(state, "ray_receiver", Vector2(300, 0))
	var b := _place(state, "ray_receiver", Vector2(600, 0))
	state.set_active_planet("frost")
	var c := _place(state, "ray_receiver", Vector2.ZERO)
	state.set_active_planet("home")
	var power := PowerSystem.new(state)
	power.update(0)
	_expect(state.buildings[a].power_output == 0 and state.buildings[b].power_output == 0, "receivers cannot generate free power")
	state.planet_inventory["solar_sail"] = 2.0
	dyson.configure_launcher(emitter, orbit)
	dyson.load_ammo(emitter, 2)
	state.buildings[emitter].power_efficiency = 1
	_advance(dyson, 120)
	power.update(0)
	_expect(state.buildings[a].power_output == 30 and state.buildings[b].power_output == 30 and state.buildings[c].power_output == 0, "receivers share 60 kW without cross-system leakage")
	state.set_active_planet("frost")
	var before := dyson.get_summary("helios")
	power.update(0)
	_expect(dyson.get_summary("helios") == before and state.buildings[a].power_output == 30, "view/planet switch cannot redirect Dyson energy")

func _test_real_engine_and_production() -> void:
	var state := _state()
	var dyson := DysonSphereSystem.new(state)
	var orbit: String = dyson.create_orbit("helios").id
	var emitter := _place(state, "solar_sail_ejector", Vector2.ZERO)
	var generator := _place(state, "power_generator", Vector2(300, 0))
	state.buildings[generator].fuel_remaining = 300
	state.planet_inventory["solar_sail"] = 10.0
	dyson.configure_launcher(emitter, orbit)
	dyson.load_ammo(emitter, 10)
	var copy := state.copy_state()
	var fine := SimulationEngine.new(state)
	var coarse := SimulationEngine.new(copy)
	state.paused = true
	var before := GameStateCodec.to_persistent_dict(state)
	fine.update(10)
	_expect(GameStateCodec.to_persistent_dict(state) == before, "pause freezes decay and construction")
	state.paused = false
	for i in range(600):
		fine.update(1.0 / 60)
	for i in range(100):
		coarse.update(0.1)
	_expect(GameStateCodec.to_persistent_dict(state) == GameStateCodec.to_persistent_dict(copy), "real Dyson fixed steps are frame independent")
	_expect(dyson.get_summary("helios").launched_sails > 0, "real engine launches powered sails")
	var factory := _place(state, "assembling_machine_mk1", Vector2(600, 0))
	state.buildings[factory].power_efficiency = 1.0
	_expect(state.set_entity_recipe(factory, "dyson_sail_bootstrap"), "base assembler supports sail recipe")
	state.planet_inventory["copper_ingot"] = 1.0
	state.planet_inventory["titanium_alloy"] = 1.0
	_expect(InventorySystem.new(state).try_supply_recipe(factory).ok, "real recipe supply reserves materials")
	ProductionSystem.new(state).update(10)
	_expect(state.buildings[factory].output_buffer.get("solar_sail", 0) == 2, "real production makes sail ammo")
	_expect(state.try_add_connection(factory, emitter).ok, "real belt can supply emitter")
	BeltSystem.new(state).update(1)
	_expect(state.buildings[emitter].input_buffer.get("solar_sail", 0) >= 2, "real belt transfers produced sails into launcher")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "connected Dyson production persists validly")
	for recipe_id in ["dyson_component_bootstrap", "dyson_rocket_bootstrap"]:
		var recipe := DataManager.get_recipe(recipe_id)
		state.buildings[factory].input_buffer = {}
		state.buildings[factory].output_buffer = {}
		state.buildings[factory].progress = 0.0
		_expect(state.set_entity_recipe(factory, recipe_id), "assembler accepts " + recipe_id)
		for item in recipe.inputs:
			state.planet_inventory[item.item_id] = 100.0
		state.sync_active_planet_inventory()
		_expect(InventorySystem.new(state).try_supply_recipe(factory).ok, "real inventory supplies " + recipe_id)
		ProductionSystem.new(state).update(float(recipe.duration))
		for item in recipe.outputs:
			_expect(state.buildings[factory].output_buffer.get(item.item_id, 0) >= float(item.amount), "real assembler produces " + String(item.item_id))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("DYSON: " + message)

func _test_ui() -> void:
	var state := _state()
	var emitter := _place(state, "solar_sail_ejector", Vector2.ZERO)
	state.planet_inventory["solar_sail"] = 2.0
	GameManager.replace_game_state(state)
	state.paused = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var workspace: Node = main.get_node("FactoryWorkspaceUI")
	workspace.get_node("TopBar/DysonButton").pressed.emit()
	var panel: Control = workspace.get_node("DysonPanel")
	await get_tree().process_frame
	_expect(panel.visible and workspace.is_pointer_over_ui(panel.get_global_rect().get_center()), "formal Dyson button opens input-blocking workspace")
	for child in panel.content.get_children():
		if child is Button and child.text == "创建太阳帆轨道": child.pressed.emit()
	_expect(state.dyson_systems.get("helios", {}).get("orbits", {}).size() == 1, "formal orbit control creates authoritative plan")
	panel.call("_configure", true, false)
	panel.quantity.value = 2
	for child in panel.content.get_children():
		if child is Button and child.text == "从当前行星托盘装载": child.pressed.emit()
	_expect(state.buildings[emitter].dyson.enabled and state.buildings[emitter].input_buffer.get("solar_sail") == 2, "formal launcher controls bind target and transfer real ammo")
	workspace.show_exclusive_workspace("TechnologyPanel")
	_expect(not panel.visible, "Dyson workspace is exclusive")
	workspace.show_exclusive_workspace("DysonPanel")
	GameManager.replace_game_state(GameState.new())
	_expect(not panel.visible, "save replacement closes stale Dyson workspace")
	viewport.queue_free()
	await get_tree().process_frame