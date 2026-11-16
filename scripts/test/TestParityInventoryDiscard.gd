extends Node

func _ready() -> void:
	await get_tree().process_frame
	var runner := preload("res://scripts/test/InventoryDiscardBehaviorRunner.gd")
	if OS.get_cmdline_user_args().has("--discard-ui-only"):
		var formal_errors: Array = await _formal_discard()
		formal_errors.append_array(_placed_and_queued_ownership())
		for error in formal_errors: printerr("FAIL: " + error)
		print("PARITY INVENTORY DISCARD UI TESTS PASSED" if formal_errors.is_empty() else "PARITY INVENTORY DISCARD UI TESTS FAILED")
		get_tree().quit(0 if formal_errors.is_empty() else 1)
		return
	var result: Dictionary = runner.new().run({}, not OS.get_cmdline_user_args().has("--discard-no-disk"))
	if not OS.get_cmdline_user_args().has("--discard-positive-only"):
		result.errors.append_array(await _formal_discard())
		result.errors.append_array(_placed_and_queued_ownership())
		var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
		for kind in ["source", "missing", "duplicate", "save_scope", "marker"]:
			var broken := fixture.duplicate(true)
			match kind:
				"source": broken.source_files["src/game/engine.ts"] = "wrong"
				"missing": broken.cases.pop_back()
				"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
				"save_scope": broken.cases[0].save_eligible = false
				"marker": broken.cases[0].input.construction.wind_turbine = {"$number": "invalid"}
			var rejected: Dictionary = runner.new().run(broken, false)
			if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("discard " + kind + " rejection withholds all keys")
		var broken := fixture.duplicate(true)
		broken.cases[0].expected.tray.iron_ore += 1
		var rejected: Dictionary = runner.new().run(broken, false, func(id, state):
			if id in ["tray-iron_ore-home-partial", "construction-wind_turbine-owned"]:
				state.portable_fleet.logistics_drone += 1
				state.research_queue.append("dsp_electromagnetic_matrix"))
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("discard source result and unrelated ownership mutations withhold both keys")
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("INVENTORY DISCARD ERRORS: ", result.errors.size(), "; verified keys: ", result.verified_keys.size(), "; disk saves: ", result.disk_saves)
	print("PARITY INVENTORY DISCARD TESTS PASSED" if result.errors.is_empty() else "PARITY INVENTORY DISCARD TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)

func _placed_and_queued_ownership() -> Array:
	var errors := []
	var runner := preload("res://scripts/test/InventoryDiscardBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var row: Dictionary = fixture.cases.filter(func(value): return value.id == "construction-wind_turbine-owned")[0]
	var state: GameState = runner._state(row.input, fixture.initial)
	state.completed_technologies.append("dsp_electromagnetism")
	state.construction_inventory.dsp_construction_center = 1.0
	var constructor := ConstructionSystem.new(state)
	var machine := constructor.try_place_building("dsp_arc_smelter", Vector2.ZERO)
	var center := constructor.try_place_building("dsp_construction_center", Vector2(500, 0))
	if not machine.ok or not center.ok: return ["discard ownership probe places paid source entities: " + str([machine, center])]
	state.buildings[machine.id].input_buffer = {"iron_ore": 17.0}
	state.buildings[machine.id].output_buffer = {"iron_ingot": 3.0}
	var automation := ConstructionAutomationSystem.new(state)
	var configured := automation.configure_center(center.id, "dsp_wind_turbine", 9)
	var queued := automation.queue("dsp_wind_turbine", 1, true, "home", center.id)
	if not configured.ok or not queued.ok: return ["discard ownership probe creates real manufacturing target and reserved work: " + str([configured, queued])]
	var before := GameStateCodec.to_persistent_dict(state.copy_state())
	var result := constructor.discard_inventory("dsp_wind_turbine", true)
	var expected := before.duplicate(true)
	expected.construction_inventory.dsp_wind_turbine = 0.0
	if not result.ok or not runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), expected): errors.append("whole stack deletion retains nonempty placed entities buffers manufacturing targets reserved materials and queued work")
	var root := "res://.godot/task27-discard-placed-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	var storage := SaveSystem.new(root)
	var saved := storage.save_slot(0, state)
	if not saved.ok: errors.append("nonempty discard writes verified disk: " + str(saved.get("error")))
	else:
		var loaded := storage.load_recovery_source(0, "primary")
		if not loaded.ok or not runner._exact(GameStateCodec.to_persistent_dict(loaded.state.copy_state()), expected): errors.append("nonempty discard disk round trip retains paid entities targets and queued work exactly")
	print("INVENTORY DISCARD NONEMPTY OWNERSHIP ERRORS: ", errors.size())
	return errors

func _formal_discard() -> Array:
	var errors := []
	var runner := preload("res://scripts/test/InventoryDiscardBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var fields: Array = preload("res://scripts/test/CampaignUIBehaviorRunner.gd").MANAGER_FIELDS
	var original := {}
	for field in fields: original[field] = GameManager.get(field)
	var processing := GameManager.is_processing()
	var settings := LocalSettings.values.duplicate(true)
	var settings_path := LocalSettings.path
	var root := "res://.godot/task27-discard-ui-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(root)
	LocalSettings.path = root + "settings.cfg"
	LocalSettings.values = SettingsSystem.DEFAULTS.duplicate(true)
	GameManager.set_process(false)
	GameManager.game_state = GameState.new()
	GameManager.simulation_engine = SimulationEngine.new(GameManager.game_state)
	GameManager.performance_monitor = PerformanceSystem.new()
	GameManager.performance_monitor.game_state = GameManager.game_state
	GameManager._save_queue = []
	GameManager.configure_save_system(SaveSystem.new(root + "slots/"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	main.set_process(false)
	var shell: FactoryWorkspaceUI = main.factory_workspace_ui
	var map: Control = main.galaxy_map
	var catalog: Control = shell.get_node("ProductionCatalogWorkspace")
	var tray_ids := ["tray-iron_ore-home-partial", "tray-iron_ore-ashen-partial", "tray-iron_ore-home-fractional_request", "tray-special-fractional_stock", "tray-logistics_drone-home-partial", "tray-special-empty_remote"]
	for id in tray_ids:
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == id)[0]
		var state: GameState = runner._state(row.input, fixture.initial)
		_bind(main, state)
		shell.show_exclusive_workspace("GalaxyMap")
		map._selected_system_id = GalaxySystem.new(state).get_planet(row.command.target).system_id
		map._selected_planet_id = row.command.target
		map._refresh_details()
		for index in range(map._discard_item.item_count):
			if map._discard_item.get_item_metadata(index) == row.command.requests[0].itemId: map._discard_item.select(index)
		map._discard_amount.value = floorf(float(row.command.requests[0].amount))
		var before := GameStateCodec.to_persistent_dict(state.copy_state())
		map.find_child("DiscardTrayStock", true, false).pressed.emit()
		if not map._discard_dialog.visible or not runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), before): errors.append(id + ": tray button only opens confirmation")
		map._discard_dialog.get_cancel_button().pressed.emit()
		if id == tray_ids[0]: print("DISCARD CANCEL BEFORE FRAME: visible=", map._discard_dialog.visible, "; ownership_equal=", runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), before))
		await get_tree().process_frame
		if id == tray_ids[0]: print("DISCARD CANCEL AFTER FRAME: visible=", map._discard_dialog.visible, "; ownership_equal=", runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), before))
		if map._discard_dialog.visible or not runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), before): errors.append(id + ": cancel button retains full persistent state")
		map.find_child("DiscardTrayStock", true, false).pressed.emit()
		map._discard_dialog.get_ok_button().pressed.emit()
		await get_tree().process_frame
		if not runner._same(runner._domain(state), runner._expected(row, "expected")): errors.append(id + ": confirmed tray button reaches source command and fractional conservation")
	for id in fixture.constructions:
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == "construction-" + id + "-owned")[0]
		var state: GameState = runner._state(row.input, fixture.initial)
		_bind(main, state)
		shell.get_node("ConstructionDock/FullProduction").pressed.emit()
		catalog.navigate_to({"kind": "construction", "constructionId": id})
		var before := GameStateCodec.to_persistent_dict(state.copy_state())
		if catalog.discard_button.disabled: errors.append(id + ": owned stack has a formal delete button")
		catalog.discard_button.pressed.emit()
		if not catalog.discard_dialog.visible or not runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), before): errors.append(id + ": construction button requires confirmation")
		catalog.discard_dialog.get_cancel_button().pressed.emit()
		await get_tree().process_frame
		if catalog.discard_dialog.visible or not runner._exact(GameStateCodec.to_persistent_dict(state.copy_state()), before): errors.append(id + ": formal cancellation retains the stack")
		catalog.discard_button.pressed.emit()
		catalog.discard_dialog.get_ok_button().pressed.emit()
		await get_tree().process_frame
		if not runner._same(runner._domain(state), runner._expected(row, "expected")): errors.append(id + ": formal confirmation deletes whole source stack including canonical belt stock")
		if not catalog.discard_button.disabled: errors.append(id + ": empty stack disables repeated deletion")
	var row: Dictionary = fixture.cases.filter(func(value): return value.id == "construction-wind_turbine-owned")[0]
	var pending: GameState = runner._state(row.input, fixture.initial)
	_bind(main, pending)
	shell.show_exclusive_workspace("ProductionCatalogWorkspace")
	catalog.navigate_to({"kind": "construction", "constructionId": "wind_turbine"})
	catalog.discard_button.pressed.emit()
	pending.construction_inventory.dsp_wind_turbine = 0.0
	var empty := GameStateCodec.to_persistent_dict(pending.copy_state())
	catalog.discard_dialog.get_ok_button().pressed.emit()
	await get_tree().process_frame
	if not runner._exact(GameStateCodec.to_persistent_dict(pending.copy_state()), empty): errors.append("confirmation rechecks stock that changed while dialog was open")
	pending.construction_inventory.dsp_wind_turbine = 7.0
	catalog._preview()
	catalog.discard_button.pressed.emit()
	var replacement: GameState = runner._state(row.input, fixture.initial)
	var replacement_before := GameStateCodec.to_persistent_dict(replacement.copy_state())
	_bind(main, replacement)
	catalog.discard_dialog.get_ok_button().pressed.emit()
	await get_tree().process_frame
	if not runner._exact(GameStateCodec.to_persistent_dict(replacement.copy_state()), replacement_before) or pending.construction_inventory.dsp_wind_turbine != 7: errors.append("pending construction confirmation cannot delete in replaced game session")
	map._selected_system_id = "helios"
	map._selected_planet_id = "home"
	map._refresh_details()
	shell.show_exclusive_workspace("GalaxyMap")
	for index in range(map._discard_item.item_count):
		if map._discard_item.get_item_metadata(index) == "iron_ore": map._discard_item.select(index)
	map._discard_amount.value = 3
	if replacement.planet_inventory.get("iron_ore", 0) < 3: errors.append("stale tray confirmation has real owned material before switching sessions")
	map.find_child("DiscardTrayStock", true, false).pressed.emit()
	var new_session: GameState = runner._state(row.input, fixture.initial)
	var new_before := GameStateCodec.to_persistent_dict(new_session.copy_state())
	_bind(main, new_session)
	map._discard_dialog.get_ok_button().pressed.emit()
	await get_tree().process_frame
	if not runner._exact(GameStateCodec.to_persistent_dict(new_session.copy_state()), new_before): errors.append("pending tray confirmation cannot delete in replaced game session")
	viewport.queue_free()
	await get_tree().process_frame
	for field in fields: GameManager.set(field, original[field])
	GameManager.set_process(processing)
	LocalSettings.path = settings_path
	LocalSettings.values = settings
	for field in fields:
		if GameManager.get(field) != original[field]: errors.append("discard formal UI restores manager field " + field)
	print("INVENTORY DISCARD FORMAL UI ERRORS: ", errors.size(), "; source tray and construction controls: ", tray_ids.size() + fixture.constructions.size(), "; stale confirmations: 3")
	return errors

func _bind(main: Node, state: GameState) -> void:
	GameManager.game_state = state
	GameManager.simulation_engine = SimulationEngine.new(state)
	GameManager.performance_monitor.game_state = state
	main._galaxy_system = GalaxySystem.new(state)
	main._planet_system = PlanetSystem.new(state, main._galaxy_system)
	main.card_renderer.set_game_state(state)
	main.connection_renderer.set_game_state(state)
	main.galaxy_map.configure(state, main._galaxy_system, main._planet_system)
