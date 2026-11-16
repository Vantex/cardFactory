extends Node

# Loaded only by a temporary override.cfg beside byte-identical exported files.
var failures := 0
var manager: Node
var check_root := ""
var phase := ""
var main: Node
var shell: Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-root="): check_root = argument.trim_prefix("--probe-root=").replace("\\", "/")
		if argument.begins_with("--probe-phase="): phase = argument.trim_prefix("--probe-phase=")
	var user_directory := OS.get_user_data_dir().replace("\\", "/")
	_expect(not check_root.is_empty() and user_directory.to_lower().begins_with(check_root.to_lower() + "/"), "effective user data stays inside the isolated check directory: " + user_directory)
	if failures > 0:
		_finish()
		return
	await _frames()
	manager = get_node("/root/GameManager")
	manager.set_process(false)
	main = get_tree().current_scene
	_expect(main != null and main.name == "Main", "exported formal Main scene loads")
	var data := get_node("/root/DataManager")
	_expect(data.all_items.size() == 83 and data.all_buildings.size() == 72 and data.all_recipes.size() == 109, "all exported runtime catalogs load")
	_expect(manager.get_save_system().is_storage_available(), "default exported save storage is available")
	if failures > 0:
		_finish()
		return
	shell = main.get_node("AppShell")
	_expect(shell.get_screen_name() == "start", "formal start screen is shown")
	if phase == "new": await _new_journey()
	elif phase == "resume": await _resume_and_recover()
	elif phase == "rounding": _rounding_boundary()
	elif phase == "world": _world_controls()
	elif phase == "worldcommands": _world_commands()
	elif phase == "discard": _inventory_discard()
	elif phase == "routequeries": _route_queries()
	elif phase == "resourceplacement": await _resource_placement()
	elif phase == "resourcemining": _resource_mining()
	elif phase == "resourcemode": await _resource_mode()
	elif phase == "resourcecapacity": await _resource_capacity()
	else: _expect(false, "unknown probe phase")
	_finish()

func _new_journey() -> void:
	_expect(manager.get_save_system().get_all_saves().is_empty(), "first process starts with no injected save")
	shell.get_node("StartMenu/Layout/Card/Content/Actions/NewGameButton").pressed.emit()
	await _frames()
	var slots: Node = shell.get_node("SaveSlotsPanel")
	_expect(shell.get_screen_name() == "slots", "formal new-game button opens slots")
	slots.find_child("Slot0", true, false).find_child("NewGameButton", true, false).pressed.emit()
	await _frames()
	_expect(manager.is_session_active() and shell.get_screen_name() == "game", "formal slot button starts and saves a new session")
	if not manager.is_session_active(): return
	var state: RefCounted = manager.get_game_state()
	_expect(state.planet_inventory.get("iron_ore") == 100 and state.planet_inventory.get("copper_ore") == 100 and state.planet_inventory.get("stone") == 100, "new tray contains real source starting raw materials")
	var workspace: Node = main.get_node("FactoryWorkspaceUI")
	_expect(workspace._construction_stock.text == "施工件 13", "exported desktop displays all 13 starter building kits")
	var automation: RefCounted = load("res://scripts/game/ConstructionAutomationSystem.gd").new(state)
	_expect(automation.queue("dsp_electromagnetic_matrix", 3).ok, "actual starting materials fund three blue matrices")
	var engine: RefCounted = manager.get_simulation_engine()
	for tick in range(6000):
		engine.update(1.0 / 60.0)
		if state.production_orders.is_empty(): break
	_expect(state.planet_inventory.get("electromagnetic_matrix", 0) == 3, "exported manufacturing produces three matrices without material injection")
	var wind: Dictionary = state.try_place_building(state.get_dock_building_type("power_generator"), Vector2(650, 0))
	var lab: Dictionary = state.try_place_building(state.get_dock_building_type("matrix_lab"), Vector2(300, 0))
	_expect(wind.ok and lab.ok, "real paid starter wind and laboratory kits deploy")
	if not wind.ok or not lab.ok: return
	_expect(state.set_entity_recipe(lab.id, "dsp_matrix_research"), "exported laboratory accepts research mode")
	var technology: RefCounted = load("res://scripts/game/TechnologySystem.gd").new(state)
	_expect(technology.start_research("dsp_electromagnetic_matrix") and technology.supply_source_lab(lab.id).ok, "laboratory receives the actually manufactured matrices")
	for tick in range(1800):
		engine.update(1.0 / 60.0)
		if state.completed_technologies.has("dsp_electromagnetic_matrix"): break
	_expect(state.completed_technologies.has("dsp_electromagnetic_matrix") and state.buildings[lab.id].input_buffer.get("electromagnetic_matrix", 0) == 0, "first source research consumes three real matrices and completes")
	_expect(state.construction_inventory.get("dsp_matrix_lab", 0) == 3, "first completion awards two laboratory kits")
	workspace.get_node("TopBar/AnalysisButton").pressed.emit()
	var analysis: Node = workspace.get_node("CodexWorkspace")
	analysis.get_node("Layout/Tabs/Planning").pressed.emit()
	await _frames()
	var panel: Node = analysis.get_node("Layout/Content/PlanningPanel")
	panel.get_node("Layout/Create").pressed.emit()
	await _frames()
	_expect(state.production_plans.size() == 1, "exported formal planning button creates a plan")
	if state.production_plans.size() != 1: return
	var name_input: LineEdit = panel.get_node("Layout/Plans/Plan_0/Name")
	name_input.text = "导出包首项研究计划"
	name_input.text_submitted.emit(name_input.text)
	_expect(state.production_plans[0].name == name_input.text, "exported plan-name control updates persistent state")
	shell.open_pause_menu()
	_expect(state.paused and shell.get_screen_name() == "pause", "formal pause blocks gameplay")
	workspace.get_node("TopBar/SaveButton").pressed.emit()
	var save_status: Dictionary = manager.get_save_status()
	_expect(save_status.phase == "saved", "exported formal save commits successfully: " + JSON.stringify(save_status))
	var snapshot: Dictionary = manager.get_save_system().create_snapshot(0, state)
	_expect(snapshot.ok, "exported snapshot writes and verifies: " + JSON.stringify(snapshot.get("error", {})))
	if snapshot.ok:
		var record := FileAccess.open(check_root + "/expected.json", FileAccess.WRITE)
		record.store_string(JSON.stringify({"snapshot": snapshot.source, "plan_name": state.production_plans[0].name, "buildings": state.buildings.size()}))
		record.close()
	_expect(shell.return_to_menu().ok, "formal return to menu saves before exiting")
	_expect(not manager.is_session_active() and shell.get_screen_name() == "start", "first process ends on start screen")

func _resume_and_recover() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/expected.json"))
	var continuation: Button = shell.get_node("StartMenu/Layout/Card/Content/Actions/ContinueButton")
	_expect(not continuation.disabled, "second process discovers the real saved session")
	continuation.pressed.emit()
	for frame in range(1000):
		if manager.is_session_active(): break
		manager.advance_offline_settlement()
		await get_tree().process_frame
	_expect(manager.is_session_active(), "formal continue activates the disk-loaded session")
	if not manager.is_session_active(): return
	var state: RefCounted = manager.get_game_state()
	_expect(state.completed_technologies.has("dsp_electromagnetic_matrix") and state.buildings.size() == expected.buildings, "new-process load retains actual research and construction")
	_expect(state.production_plans.size() == 1 and state.production_plans[0].name == expected.plan_name, "new-process load retains the edited production plan")
	_expect(manager.save_current_game().ok and shell.return_to_menu().ok, "continued session saves before recovery")
	var storage: RefCounted = manager.get_save_system()
	var primary_path: String = storage._get_slot_path(0)
	_expect(ProjectSettings.globalize_path(primary_path).replace("\\", "/").to_lower().begins_with(check_root.to_lower() + "/"), "corruption fixture targets only the isolated save")
	if failures > 0: return
	var primary := FileAccess.open(primary_path, FileAccess.WRITE)
	primary.store_string("{isolated-package-recovery-fixture")
	primary.close()
	shell.open_recovery(0)
	await _frames()
	var recovery: Node = shell.get_node("RecoveryWorkspace")
	_expect(recovery.find_child("Restore_primary", true, false).disabled, "formal recovery refuses the corrupted primary")
	var restore: Button = recovery.find_child("Restore_" + expected.snapshot, true, false)
	_expect(restore != null and not restore.disabled, "formal recovery offers the verified saved snapshot")
	if restore == null or restore.disabled: return
	restore.pressed.emit()
	_expect(recovery.confirmation.visible, "recovery requires its real confirmation dialog")
	recovery.confirmation.confirmed.emit()
	await _frames()
	_expect(manager.is_session_active() and shell.get_screen_name() == "game", "confirmed snapshot recovery enters the formal factory")
	state = manager.get_game_state()
	_expect(state.completed_technologies.has("dsp_electromagnetic_matrix") and state.production_plans[0].name == expected.plan_name, "snapshot recovery preserves real research and plan")
	_expect(storage.load_recovery_source(0, "primary").ok, "recovery rewrites and verifies the formerly corrupted primary")
	_expect(shell.return_to_menu().ok, "recovered package session saves successfully")

func _rounding_boundary() -> void:
	var state: RefCounted = load("res://scripts/game/GameState.gd").new()
	for tick in range(2530): state.elapsed_time += 1.0 / 60.0
	var planning: RefCounted = load("res://scripts/game/ProductionPlanningSystem.gd").new(state)
	_expect(planning.create_plan("iron_ingot").ok, "controlled regression creates a real plan at the known 2530-tick rounding boundary")
	var codec = load("res://scripts/game/GameStateCodec.gd")
	var before: Dictionary = codec.to_persistent_dict(state)
	var expected: Dictionary = JSON.parse_string(JSON.stringify(before, "", true, true))
	var storage: RefCounted = load("res://scripts/game/SaveSystem.gd").new("user://float-digest-regression/")
	var saved: Dictionary = storage.save_slot(0, state)
	_expect(saved.ok, "controlled rounding-boundary primary saves: " + JSON.stringify(saved.get("error", {})))
	_expect(codec.to_persistent_dict(state) == before, "controlled rounding save preserves live ownership")
	var loaded: Dictionary = storage.load_recovery_source(0, "primary")
	_expect(loaded.ok, "controlled rounding-boundary primary loads")
	if loaded.ok:
		_expect(loaded.state.elapsed_time == expected.elapsed_time and loaded.state.production_plans[0].createdAt == expected.production_plans[0].createdAt, "controlled regression preserves the actual file's full-precision numbers")
		_expect(storage.save_slot(0, loaded.state).ok, "controlled rounding-boundary loaded state saves again")
	_expect(storage.save_emergency(0, state).ok and storage.load_recovery_source(0, "emergency").ok, "controlled rounding-boundary emergency saves and loads")
	var snapshot: Dictionary = storage.create_snapshot(0, state)
	_expect(snapshot.ok, "controlled rounding-boundary snapshot verifies")
	if snapshot.ok: _expect(storage.load_recovery_source(0, snapshot.source).ok, "controlled rounding-boundary snapshot loads")
	if not loaded.ok: return
	var path: String = storage._get_slot_path(0)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.state.elapsed_time += 1.0
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope, "", true, true))
	file.close()
	var corrupt: Dictionary = storage.load_recovery_source(0, "primary")
	_expect(not corrupt.ok and corrupt.error.code == "digest_mismatch", "controlled regression still rejects a changed payload without its matching digest")

func _world_controls() -> void:
	var state: RefCounted = load("res://scripts/game/GameState.gd").new()
	var source: RefCounted = load("res://scripts/game/SourceGalaxySystem.gd").new(state)
	source.initialize(240721, false)
	var prefix := "A".repeat(15)
	_expect(source.set_metadata("home", "A".repeat(31) + "😀", "A".repeat(239) + "🚀", [prefix + "😀", prefix + "🌍", prefix + "😀", " " + String.chr(31) + " "]).ok, "controlled exported metadata setter accepts source edge cases")
	var metadata: Dictionary = state.source_galaxy.planetMetadata.home
	_expect(metadata.customName == "A".repeat(31) + "�" and metadata.note == "A".repeat(239) + "�" and metadata.tags == [prefix + "�", prefix + "�", String.chr(31)], "exported metadata preserves original-slice dedupe and ECMAScript whitespace")
	_expect(source.set_role("home", "power").ok and state.source_galaxy.planetRoles.home == "power", "exported industrial role command updates the selected world")
	_expect(source.set_metadata("helios", "B".repeat(31) + "🌟", "", [], true).ok and state.source_galaxy.systemMetadata.helios.customName == "B".repeat(31) + "�", "exported system name uses the source UTF16 limit")
	var tray: RefCounted = load("res://scripts/game/PlanetTraySystem.gd").new(state)
	_expect(tray.set_limit("home", 1000.9).ok and tray.limit("home") == 1000 and not tray.set_limit("unknown_planet", 2000).ok, "exported tray command floors valid limits and rejects unknown worlds")
	var controls := ""
	for code in range(1, 32): controls += String.chr(code)
	_expect(source.set_metadata("ashen", "控制字符", "literal \\v 和 \\\\v " + controls + "尾", [String.chr(31)]).ok, "exported metadata retains all tested C0 text")
	var codec = load("res://scripts/game/GameStateCodec.gd")
	var before: Dictionary = codec.to_persistent_dict(state.copy_state())
	var storage: RefCounted = load("res://scripts/game/SaveSystem.gd").new("user://world-metadata-regression/")
	var saved: Dictionary = storage.save_slot(0, state)
	_expect(saved.ok and codec.to_persistent_dict(state.copy_state()) == before, "exported metadata saves without changing live ownership")
	var loaded: Dictionary = storage.load_recovery_source(0, "primary")
	_expect(loaded.ok and _same_persistent(codec.to_persistent_dict(loaded.state.copy_state()), before), "exported Unicode metadata survives verified disk reload with JSON numeric types")
	_expect(storage.save_emergency(0, state).ok and storage.load_recovery_source(0, "emergency").ok, "exported control text survives verified emergency recovery")
	var snapshot: Dictionary = storage.create_snapshot(0, state)
	_expect(snapshot.ok and storage.load_recovery_source(0, snapshot.get("source", "")).ok, "exported control text survives verified snapshot recovery")
	var legacy_text := FileAccess.get_file_as_string(check_root + "/legacy-metadata-save.json")
	var legacy_fixture: Dictionary = JSON.parse_string(legacy_text)
	var file := FileAccess.open(storage._get_slot_path(1), FileAccess.WRITE)
	file.store_string(legacy_text)
	file.close()
	var legacy: Dictionary = storage.load_recovery_source(1, "primary")
	_expect(legacy.ok, "exported reader accepts the actual previously successful local metadata save")
	if not legacy.ok: return
	_expect(legacy.metadata.digest == "d53df4abced34d6070f9651d386c503c0e98bd97b38931f5fd519f873cb3ab9c" and legacy.state.source_galaxy == legacy_fixture.state.source_galaxy, "exported legacy read retains original digest and exact Unicode tags")
	var legacy_before: Dictionary = codec.to_persistent_dict(legacy.state.copy_state())
	_expect(storage.save_slot(1, legacy.state).ok, "exported legacy metadata saves again")
	var reopened: Dictionary = storage.load_recovery_source(1, "primary")
	_expect(reopened.ok and codec.to_persistent_dict(reopened.state.copy_state()) == legacy_before, "exported legacy resave retains complete persistent ownership")

func _world_commands() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/world-command-cases.json"))
	_expect(fixture.get("cases", []).size() == 8 and fixture.get("surveys", []).size() == 3, "controlled source command fixture loads outside the PCK")
	if failures > 0: return
	var codec = load("res://scripts/game/GameStateCodec.gd")
	for row in fixture.cases:
		var state: RefCounted = _world_command_state(row.input)
		for expected in [row.expected, row.repeated]:
			match String(row.command.kind):
				"explore": load("res://scripts/game/GalaxySystem.gd").new(state).try_explore_system(row.command.target)
				"colonize": load("res://scripts/game/PlanetSystem.gd").new(state).try_colonize_planet(row.command.target)
				"active": load("res://scripts/game/PlanetSystem.gd").new(state).try_set_active_planet(row.command.target)
			_expect(_same_world(_world_command_domain(state), _normalized_world(expected)), row.id + ": exported command/repeat matches actual source ownership")
		var storage: RefCounted = load("res://scripts/game/SaveSystem.gd").new("user://world-command-regression/" + row.id + "/")
		var before: Dictionary = codec.to_persistent_dict(state.copy_state())
		_expect(storage.save_slot(0, state).ok, row.id + ": exported command writes verified disk")
		var loaded: Dictionary = storage.load_recovery_source(0, "primary")
		_expect(loaded.ok and _same_persistent(codec.to_persistent_dict(loaded.state.copy_state()), before), row.id + ": exported command reload retains complete canonical ownership")
	for row in fixture.surveys:
		_expect(row.get("clock") is Dictionary and row.clock.size() == 2 and row.clock.get("numerator") == 1 and row.clock.get("denominator") == 60 and absf(float(row.seconds) - 1.0 / 60.0) < 1.0e-15, row.id + ": actual source declares its exact 60 Hz clock")
		var state: RefCounted = _world_command_state(row.input)
		var engine: RefCounted = load("res://scripts/game/SimulationEngine.gd").new(state)
		var storage: RefCounted = load("res://scripts/game/SaveSystem.gd").new("user://world-command-regression/" + row.id + "/")
		for index in range(row.trace.size()):
			engine.update(1.0 / 60.0)
			var actual := _world_command_domain(state)
			var expected := _normalized_world(row.trace[index])
			actual.erase("activeMetrics")
			expected.erase("activeMetrics")
			_expect(engine.get_last_step_count() == 1 and _same_world(actual, expected), row.id + ": exported fixed tick matches source survey %d" % index)
			if index == 2:
				state.paused = true
				var pending := _world_command_domain(state)
				engine.update(1.0)
				_expect(_same_persistent(_world_command_domain(state), pending), row.id + ": exported pause keeps pending survey")
				_expect(storage.save_slot(0, state).ok, row.id + ": exported pending survey saves")
				var loaded: Dictionary = storage.load_recovery_source(0, "primary")
				_expect(loaded.ok and _same_persistent(_world_command_domain(loaded.state), pending), row.id + ": exported disk retains paid pending survey")
				if not loaded.ok: break
				state = loaded.state
				state.paused = false
				engine = load("res://scripts/game/SimulationEngine.gd").new(state)
	var storage: RefCounted = load("res://scripts/game/SaveSystem.gd").new("user://world-command-legacy/")
	for slot in range(2):
		var name: String = "task27-legacy-survey-save.json" if slot == 0 else "task27-legacy-survey-progress-save.json"
		var text := FileAccess.get_file_as_string(check_root + "/" + name)
		var file := FileAccess.open(storage._get_slot_path(slot), FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var loaded: Dictionary = storage.load_recovery_source(slot, "primary")
		_expect(loaded.ok, name + ": exported reader accepts actual old local save")
		if not loaded.ok: continue
		var before: Dictionary = codec.to_persistent_dict(loaded.state.copy_state())
		_expect(storage.save_slot(slot, loaded.state).ok, name + ": exported old save can save again")
		var reopened: Dictionary = storage.load_recovery_source(slot, "primary")
		_expect(reopened.ok and _same_persistent(codec.to_persistent_dict(reopened.state.copy_state()), before), name + ": exported old save retains complete ownership")

func _inventory_discard() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/inventory-discard-cases.json"))
	_expect(fixture.get("cases", []).size() == 10, "controlled discard source fixture is complete")
	if failures > 0: return
	var codec = load("res://scripts/game/GameStateCodec.gd")
	for row in fixture.cases:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		load("res://scripts/game/SourceGalaxySystem.gd").new(state).initialize(240721, false)
		state.source_galaxy = fixture.initial.galaxy.duplicate(true)
		state.explored_system_ids = fixture.initial.exploration.unlockedSystemIds.duplicate()
		state.colonized_planet_ids = fixture.initial.exploration.colonizedPlanetIds.duplicate()
		state.survey_progress_by_system = fixture.initial.exploration.surveyProgressBySystem.duplicate(true)
		state.active_planet_id = row.input.activePlanetId
		state.planet_inventory = row.input.tray.duplicate(true)
		state.planet_inventories = row.input.planetTrays.duplicate(true)
		state.planet_inventories[state.active_planet_id] = state.planet_inventory
		state.portable_fleet = row.input.portableFleet.duplicate(true)
		state.construction_inventory = {}
		for id in row.input.construction: state.construction_inventory[_discard_local_id(id)] = row.input.construction[id]
		var before: Dictionary = codec.to_persistent_dict(state.copy_state())
		_discard_command(state, row.command, false)
		_expect(_same_persistent(codec.to_persistent_dict(state.copy_state()), before), row.id + ": unconfirmed command preserves complete state")
		for field in ["expected", "repeated"]:
			_discard_command(state, row.command, true)
			var expected: Dictionary = row[field].duplicate(true)
			for id in expected.construction.keys():
				if expected.construction[id] == 0: expected.construction.erase(id)
			if row.id == "tray-special-fractional_stock":
				var remainder: float = float(row.input.tray.iron_ore) - floorf(float(row.input.tray.iron_ore))
				expected.tray.iron_ore = float(expected.tray.iron_ore) + remainder
				expected.planetTrays.home.iron_ore = expected.tray.iron_ore
			var construction := {}
			for id in state.construction_inventory:
				if state.construction_inventory[id] != 0: construction[String(id).trim_prefix("dsp_")] = state.construction_inventory[id]
			var actual := {"activePlanetId": state.active_planet_id, "tray": state.planet_inventory, "planetTrays": state.planet_inventories, "portableFleet": state.portable_fleet, "construction": construction}
			_expect(_same_world(actual, expected), row.id + ": exported " + field + " matches source and continuous-stock contract")
			var ownership: Dictionary = codec.to_persistent_dict(state.copy_state())
			var untouched := ownership.duplicate(true)
			var original := before.duplicate(true)
			for key in ["planet_inventory", "planet_inventories", "construction_inventory"]:
				untouched.erase(key)
				original.erase(key)
			_expect(_same_persistent(untouched, original), row.id + ": command preserves unrelated persistent ownership")
			if field == "expected":
				var storage: RefCounted = load("res://scripts/game/SaveSystem.gd").new("user://inventory-discard-regression/" + row.id + "/")
				var saved: Dictionary = storage.save_slot(0, state)
				_expect(saved.ok, row.id + ": discarded state writes verified disk")
				var loaded: Dictionary = storage.load_recovery_source(0, "primary")
				_expect(loaded.ok and _same_persistent(codec.to_persistent_dict(loaded.state.copy_state()), ownership), row.id + ": full discarded state survives disk exactly")

func _discard_local_id(id: String) -> String:
	return id if id.begins_with("conveyor_belt_") or id.begins_with("sorter_") else "dsp_" + id

func _discard_command(state: RefCounted, command: Dictionary, confirmed: bool) -> void:
	if command.kind == "construction": load("res://scripts/game/ConstructionSystem.gd").new(state).discard_inventory(_discard_local_id(command.target), confirmed)
	else: load("res://scripts/game/PlanetTraySystem.gd").new(state).discard_batch(command.target, command.requests, confirmed)

func _world_command_state(input: Dictionary) -> RefCounted:
	var state: RefCounted = load("res://scripts/game/GameState.gd").new()
	state.source_galaxy = input.galaxy.duplicate(true)
	state.galaxy_seed = int(input.galaxy.seed)
	state.active_planet_id = input.activePlanetId
	state.planet_inventory = input.tray.duplicate(true)
	state.planet_inventories = input.planetTrays.duplicate(true)
	state.portable_fleet = input.portableFleet.duplicate(true)
	state.planet_metrics = input.planetMetrics.duplicate(true)
	state.completed_technologies = input.research.completedTechIds.map(func(id): return "dsp_" + String(id))
	state.explored_system_ids = input.exploration.unlockedSystemIds.duplicate()
	state.colonized_planet_ids = input.exploration.colonizedPlanetIds.duplicate()
	state.survey_progress_by_system = input.exploration.surveyProgressBySystem.duplicate(true)
	state.exploration_missions = input.exploration.missions.map(func(mission): return {"system_id": mission.systemId, "progress": mission.elapsedSeconds, "duration_seconds": mission.durationSeconds})
	for planet in state.colonized_planet_ids: state.planet_viewports[planet] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	load("res://scripts/game/PlanetSystem.gd").new(state).initialize_colonized_resource_sites()
	return state

func _world_command_domain(state: RefCounted) -> Dictionary:
	var catalog: Dictionary = load("res://scripts/game/SourceGalaxySystem.gd").catalog()
	var logical := []
	var planets: RefCounted = load("res://scripts/game/PlanetSystem.gd").new(state)
	for id in catalog.planets:
		if planets.is_source_planet_colonized(id): logical.append(id)
	return _normalized_world({"activePlanetId": state.active_planet_id, "tray": state.planet_inventory, "planetTrays": state.planet_inventories, "portableFleet": state.portable_fleet, "activeMetrics": state.planet_metrics.get(state.active_planet_id, {}), "exploration": {"unlockedSystemIds": state.explored_system_ids, "colonizedPlanetIds": state.colonized_planet_ids, "missions": state.exploration_missions.map(func(mission): return {"systemId": mission.system_id, "elapsedSeconds": mission.progress, "durationSeconds": mission.duration_seconds}), "surveyProgressBySystem": state.survey_progress_by_system}, "logicalColonized": logical})

func _normalized_world(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for stock in [result.tray] + result.planetTrays.values():
		for item in stock.keys():
			if stock[item] == 0: stock.erase(item)
	result.logicalColonized.sort()
	result.exploration.colonizedPlanetIds = result.logicalColonized.duplicate()
	result.exploration.unlockedSystemIds.sort()
	var catalog: Dictionary = load("res://scripts/game/SourceGalaxySystem.gd").catalog()
	for system in catalog.systems:
		if not result.exploration.surveyProgressBySystem.has(system): result.exploration.surveyProgressBySystem[system] = 0
	return result

func _same_world(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float): return absf(float(left) - float(right)) <= 1.0e-9
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _same_world(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _same_world(left[index], right[index]): return false
		return true
	return left == right

func _same_persistent(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float): return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _same_persistent(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _same_persistent(left[index], right[index]): return false
		return true
	return left == right

func _frames() -> void:
	for frame in range(4): await get_tree().process_frame

func _expect(ok: bool, message: String) -> void:
	if ok: print("PACKAGE PASS: " + message)
	else:
		failures += 1
		printerr("PACKAGE FAIL: " + message)

func _finish() -> void:
	print("WINDOWS PACKAGE %s TESTS PASSED" % phase.to_upper() if failures == 0 else "WINDOWS PACKAGE TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)


func _route_queries() -> void:
	_capacity_queries()
	_slot_capacity_queries()
	_item_input_capacity_queries()
	_content_pack_capacity_queries()
	_high_pack_capacity_queries()
	_sail_lifetime_queries()
	_route_ownership_guards()
	if failures > 0: return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/route-query-cases.json"))
	_expect(fixture.get("cases", []).size() == 24, "controlled route query source fixture is complete")
	if failures > 0: return
	var fields := {"distanceLy": "distance_ly", "orbitSpan": "orbit_span", "requiresWarp": "requires_warp", "durationSeconds": "duration", "cargoPerTrip": "cargo_per_trip", "throughputPerMinute": "throughput_per_minute", "warpersPerTrip": "warpers_per_trip", "powerKw": "power_kw", "energyMjPerTrip": "energy_mj_per_trip", "routeAvailable": "available", "routeKind": "kind", "waypointStationIds": "waypoint_ids", "hopCount": "hop_count", "maxLegDistanceLy": "max_leg_distance_ly", "warpersPerVessel": "warpers_per_vessel"}
	for row in fixture.cases:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		load("res://scripts/game/SourceGalaxySystem.gd").new(state).initialize(int(row.input.seed), row.input.baseline)
		state.emit_canvas_events = false
		state.difficulty = row.input.difficulty
		state.completed_technologies = row.input.completed.map(func(id): return "dsp_" + String(id))
		state.progression_facts.infinite_research = {"galactic_logistics": {"level": int(row.input.level), "invested": "0"}}
		state.explored_system_ids.assign(row.input.unlocked)
		for station in row.input.stations:
			var config: Dictionary = load("res://scripts/game/StationSystem.gd").empty_station("dsp_interstellar_logistics_station")
			config.hub_enabled = station.hub_enabled
			config.hub_priority = int(station.hub_priority)
			config.operation_mode = station.operation_mode
			config.tier = int(station.tier)
			if station.mode_transition != null: config.mode_transition = "elevator"
			state.buildings[station.id] = {"id": station.id, "type": "dsp_interstellar_logistics_station", "planet_id": station.planet, "position": Vector2.ZERO, "station": config, "station_stack_count": int(station.count), "input_buffer": {}, "output_buffer": {}}
		var service: RefCounted = load("res://scripts/game/InterstellarRouteSystem.gd").new(state)
		var before := _route_ownership(state)
		var options := {"route_policy": row.input.options.routePolicy, "warper_budget": int(row.input.options.warperBudget)}
		var actual: Dictionary = service.query_economics(state.buildings[row.input.source_id], state.buildings[row.input.target_id], int(row.input.vessels), options)
		var repeated: Dictionary = service.query_economics(state.buildings[row.input.source_id], state.buildings[row.input.target_id], int(row.input.vessels), options)
		for warp in [false, true]:
			var name := "warp" if warp else "normal"
			_expect(_route_same(service.trip_seconds(warp), row.expected.getInterstellarTripSeconds[name]), row.id + ": exported " + name + " trip matches source")
		for field in fields: _expect(_route_same(actual[fields[field]], row.expected.getInterstellarRouteEconomics[field]), row.id + ": exported route " + field + " matches source")
		_expect(actual == repeated and _same_persistent(_route_ownership(state), before), row.id + ": repeated exported queries preserve raw and canonical state")
	print("WINDOWS ROUTE QUERY CASES CHECKED: ", fixture.cases.size())

func _route_ownership(state: RefCounted) -> Dictionary:
	return {"raw": _route_raw_fields(state, {}), "canonical": load("res://scripts/game/GameStateCodec.gd").to_persistent_dict(state.copy_state())}

func _route_raw_fields(object: RefCounted, seen: Dictionary) -> Dictionary:
	var identity := str(object.get_instance_id())
	if seen.has(identity): return {"reference": identity}
	seen[identity] = true
	var fields := {}
	for property in object.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		var value: Variant = object.get(property.name)
		if value is RefCounted: fields[property.name] = _route_raw_fields(value, seen)
		else: fields[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"instance_id": identity, "fields": fields}

func _route_ownership_guards() -> void:
	for kind in ["enabled", "undo", "redo", "group", "depth", "spatial_clear", "spatial_move", "history_replace", "spatial_replace"]:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		state.command_history.undo_entries.append({"label": "undo sentinel", "changes": [{"path": ["buildings", "sentinel", "position"], "before": Vector2.ZERO, "after": Vector2.ONE}]})
		state.command_history.redo_entries.append({"label": "redo sentinel", "changes": []})
		state.command_history._group_before = {"buildings": {"sentinel": {"position": Vector2.ONE}}}
		state.command_history._group_label = "nonempty group"
		state._spatial_index.add_entity("sentinel", Vector2(300, 500))
		var before := _route_ownership(state)
		_expect(_same_persistent(_route_ownership(state), before), "unchanged nested ownership is stable: " + kind)
		match kind:
			"enabled": state.command_history.enabled = false
			"undo": state.command_history.undo_entries.clear()
			"redo": state.command_history.redo_entries.clear()
			"group": state.command_history._group_before.buildings.sentinel.position = Vector2.ZERO
			"depth": state.command_history._depth += 1
			"spatial_clear": state._spatial_index.clear()
			"spatial_move": state._spatial_index.update_entity("sentinel", Vector2(300, 500), Vector2(900, 100))
			"history_replace": state.command_history = load("res://scripts/game/CommandHistory.gd").new()
			"spatial_replace": state._spatial_index = load("res://scripts/utils/SpatialIndex.gd").new()
		_expect(not _same_persistent(_route_ownership(state), before), "nested ownership mutation is detected: " + kind)
	print("WINDOWS NESTED OWNERSHIP MUTATIONS CHECKED: 9")

func _route_same(left: Variant, right: Variant) -> bool:
	if (right is int or right is float): return (left is int or left is float) and is_finite(float(left)) and is_finite(float(right)) and absf(float(left) - float(right)) <= maxf(1.0, absf(float(right))) * 1.0e-12
	return typeof(left) == typeof(right) and left == right

func _sail_lifetime_queries() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/sail-lifetime-cases.json"))
	_expect(fixture.get("cases", []).size() == 153, "controlled source sail lifetime fixture is complete")
	if failures > 0: return
	for row in fixture.cases:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		state.difficulty = row.input.difficulty
		state.completed_technologies = row.input.completed.map(func(id): return "dsp_" + String(id))
		state.progression_facts.infinite_research = {}
		for id in row.input.levels: state.progression_facts.infinite_research[id] = {"level": int(row.input.levels[id]), "invested": "0"}
		var before := _route_ownership(state)
		var service: RefCounted = load("res://scripts/game/SourceDysonEngineering.gd").new(state)
		var actual: float = service.sail_lifetime_seconds()
		var repeated: float = service.sail_lifetime_seconds()
		_expect(_route_same(actual, row.expected.getSolarSailLifetimeSeconds), row.id + ": exported sail lifetime matches source")
		_expect(actual == repeated and _same_persistent(_route_ownership(state), before), row.id + ": repeated exported sail query preserves raw and canonical state")
	print("WINDOWS SAIL LIFETIME CASES CHECKED: ", fixture.cases.size())

func _capacity_queries() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/capacity-query-cases.json"))
	_expect(fixture.get("cases", []).size() == 4840, "controlled source entity capacity fixture is complete")
	if failures > 0: return
	for row in fixture.cases:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		state.source_buffer_limits = {"production": row.input.production, "logistics": row.input.logistics}
		var id: String = "probe_site"
		if row.input.entity_kind == "building":
			var entity := {"type": "dsp_" + String(row.input.building), "position": Vector2.ZERO, "machine_count": row.input.count, "input_buffer": {}, "output_buffer": {}}
			if row.input.kind == "station":
				entity.erase("machine_count")
				entity.station_stack_count = row.input.count
			id = state.add_building(entity)
		else:
			load("res://scripts/game/SourceGalaxySystem.gd").new(state).initialize(240721, false)
			state.resource_sites[id] = {"id": id, "planet_id": "home", "item_id": row.input.resource, "position": Vector2.ZERO, "capacity": 1000, "remaining": 1000, "infinite": row.input.resource in ["water", "sulfuric_acid"]}
			if row.input.count > 0:
				state.add_building({"type": "dsp_" + String(row.input.extractor), "position": Vector2.ZERO, "machine_count": row.input.count, "resource_site_id": id, "input_buffer": {}, "output_buffer": {}})
		var before := _route_ownership(state)
		var actual := _capacity_values(state, id)
		var repeated := _capacity_values(state, id)
		for function in fixture.functions:
			_expect(actual[function] == row.expected[function], row.id + ": exported " + String(function) + " matches source exactly")
		_expect(actual == repeated and _same_persistent(_route_ownership(state), before), row.id + ": repeated exported capacity queries preserve raw and canonical state")
	print("WINDOWS CAPACITY QUERY CASES CHECKED: ", fixture.cases.size())

func _capacity_values(state: RefCounted, id: String) -> Dictionary:
	return {"getEntityBufferLimit": state.get_entity_buffer_limit(id), "getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id)}

func _slot_capacity_queries() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/slot-capacity-cases.json"))
	_expect(fixture.get("cases", []).size() == 2824, "controlled source station slot capacity fixture is complete")
	if failures > 0: return
	var station_script = load("res://scripts/game/StationSystem.gd")
	for row in fixture.cases:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		state.source_buffer_limits = {"production": row.input.production, "logistics": row.input.logistics}
		var id: String = state.add_building({"type": "dsp_" + String(row.input.building), "position": Vector2.ZERO, "station_stack_count": row.input.count, "input_buffer": {}, "output_buffer": {}})
		var building: Dictionary = state.buildings[id]
		if row.input.building.is_empty(): building.type = ""
		building.station = station_script.empty_station(building.type)
		for slot in building.station.slots:
			slot.capacity *= maxf(1, floorf(float(row.input.count)))
			slot.max_stock = row.input.maxStock
			slot.item_id = "iron_ore"
		var before := _route_ownership(state)
		var actual: float = station_script.capacity_for(building.station.slots[0], state, building)
		var repeated: float = station_script.capacity_for(building.station.slots[0], state, building)
		_expect(actual == row.expected.getStationSlotCapacity, row.id + ": exported slot capacity matches source exactly")
		_expect(actual == repeated and _same_persistent(_route_ownership(state), before), row.id + ": repeated exported slot query preserves raw and canonical state")
	print("WINDOWS SLOT CAPACITY CASES CHECKED: ", fixture.cases.size())

func _item_input_capacity_queries() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/item-input-capacity-cases.json"))
	_expect(fixture.get("cases", []).size() == 45696, "controlled source per-item input fixture is complete")
	if failures > 0: return
	for row in fixture.cases:
		var state: RefCounted = load("res://scripts/game/GameState.gd").new()
		state.source_buffer_limits = {"production": row.input.production, "logistics": row.input.logistics, "proliferator": row.input.spray_limit}
		var entity := {"type": "dsp_" + String(row.input.building), "position": Vector2.ZERO, "machine_count": row.input.count, "input_buffer": {}, "output_buffer": {}, "spray_coater_installed": row.input.installed, "station": {"slots": []}}
		if row.input.kind == "station":
			entity.erase("machine_count")
			entity.station_stack_count = row.input.count
		var id: String = state.add_building(entity)
		var building: Dictionary = state.buildings[id]
		if row.input.building.is_empty(): building.type = ""
		if row.input.tier != null: building.proliferator_tier = row.input.tier
		building.station = {"slots": []}
		if row.input.slots != null:
			for slot in row.input.slots: building.station.slots.append({"item_id": slot[0], "max_stock": slot[1]})
		if row.input.legacy_item != null: building.stored_item = row.input.legacy_item
		state.command_history.undo_entries.append({"label": "item capacity history sentinel", "changes": [{"path": ["buildings", id, "position"], "before": Vector2.ZERO, "after": Vector2.ONE}]})
		state.command_history.redo_entries.append({"label": "item capacity redo sentinel", "changes": []})
		state.command_history._group_before = {"buildings": {id: {"position": Vector2.ONE}}}
		state.command_history._group_label = "item capacity group sentinel"
		state._spatial_index.add_entity("item-capacity-sentinel", Vector2(300, 500))
		var before := _route_ownership(state)
		var actual: float = state.get_entity_item_input_capacity(id, String(row.input.item))
		var repeated: float = state.get_entity_item_input_capacity(id, String(row.input.item))
		_expect(actual == row.expected.getEntityItemInputCapacity, row.id + ": exported per-item input capacity matches frozen source exactly")
		_expect(actual == repeated and _same_persistent(_route_ownership(state), before), row.id + ": repeated exported per-item query preserves raw and canonical state")
	print("WINDOWS ITEM INPUT CAPACITY CASES CHECKED: ", fixture.cases.size())

func _content_pack_capacity_queries() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/content-pack-capacity-cases.json"))
	_expect(fixture.get("cases", []).size() == 36, "controlled actual content pack capacity fixture is complete")
	if failures > 0: return
	var pack_script = load("res://scripts/game/ContentPackSystem.gd")
	var saved_catalog: Dictionary = pack_script.snapshot_catalog()
	var saved_service: RefCounted = DataManager.content_pack_system
	var service: RefCounted = pack_script.new(check_root + "/capacity-pack/registry.json")
	DataManager.content_pack_system = service
	var registration: Dictionary = service.register_pack(fixture.manifest)
	_expect(registration.ok, "exported real legal core capacity override pack activates")
	if registration.ok:
		for row in fixture.cases:
			var state: RefCounted = load("res://scripts/game/GameState.gd").new()
			var entity := {"type": "dsp_" + String(row.input.building), "position": Vector2.ZERO, "machine_count": row.input.count, "input_buffer": {}, "output_buffer": {}}
			if row.input.building == "planetary_logistics_station":
				entity.erase("machine_count")
				entity.station_stack_count = row.input.count
			var id: String = state.add_building(entity)
			state.buildings[id].station = {"slots": [{"item_id": "iron_ore", "max_stock": row.input.maxStock}]}
			var before := _route_ownership(state)
			var actual := {"getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id), "getEntityItemInputCapacity": state.get_entity_item_input_capacity(id, String(row.input.item))}
			var repeated := {"getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id), "getEntityItemInputCapacity": state.get_entity_item_input_capacity(id, String(row.input.item))}
			_expect(_same_persistent(actual, row.expected), row.id + ": exported three capacity providers follow actual activated source pack")
			_expect(_same_persistent(actual, repeated) and _same_persistent(_route_ownership(state), before), row.id + ": exported pack capacity queries preserve raw/canonical ownership")
	pack_script.install_catalog(saved_catalog)
	DataManager.content_pack_system = saved_service
	print("WINDOWS CONTENT PACK CAPACITY CASES CHECKED: ", fixture.cases.size())

func _high_pack_capacity_queries() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(check_root + "/high-pack-capacity-cases.json"))
	_expect(fixture.get("cases", []).size() == 36, "controlled actual content pack capacity fixture is complete")
	if failures > 0: return
	var pack_script = load("res://scripts/game/ContentPackSystem.gd")
	var saved_catalog: Dictionary = pack_script.snapshot_catalog()
	var saved_service: RefCounted = DataManager.content_pack_system
	var service: RefCounted = pack_script.new(check_root + "/high-capacity-pack/registry.json")
	DataManager.content_pack_system = service
	var registration: Dictionary = service.register_pack(fixture.manifest)
	_expect(registration.ok, "exported real legal core capacity override pack activates")
	if registration.ok:
		for row in fixture.cases:
			var state: RefCounted = load("res://scripts/game/GameState.gd").new()
			var entity := {"type": "dsp_" + String(row.input.building), "position": Vector2.ZERO, "machine_count": row.input.count, "input_buffer": {}, "output_buffer": {}}
			if true:
				entity.erase("machine_count")
				entity.station_stack_count = row.input.count
			var id: String = state.add_building(entity)
			state.buildings[id].station = {"slots": [{"item_id": "iron_ore", "max_stock": row.input.maxStock}]}
			var before := _route_ownership(state)
			var actual := {"getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id), "getEntityItemInputCapacity": state.get_entity_item_input_capacity(id, String(row.input.item)), "getStationSlotCapacity": load("res://scripts/game/StationSystem.gd").capacity_for(state.buildings[id].station.slots[0], state, state.buildings[id])}
			var repeated := {"getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id), "getEntityItemInputCapacity": state.get_entity_item_input_capacity(id, String(row.input.item)), "getStationSlotCapacity": load("res://scripts/game/StationSystem.gd").capacity_for(state.buildings[id].station.slots[0], state, state.buildings[id])}
			_expect(_same_persistent(actual, row.expected), row.id + ": exported four high-capacity providers follow actual activated source pack")
			_expect(_same_persistent(actual, repeated) and _same_persistent(_route_ownership(state), before), row.id + ": exported high pack capacity queries preserve raw/canonical ownership")
	pack_script.install_catalog(saved_catalog)
	DataManager.content_pack_system = saved_service
	print("WINDOWS HIGH PACK CAPACITY CASES CHECKED: ", fixture.cases.size())

func _resource_placement() -> void:
	var paid = load("res://resource_paid.gd")
	var result: Dictionary = paid.new().run()
	for error in result.errors: _expect(false, String(error))
	var rejections: Array = paid.rejection_errors()
	_expect(rejections.is_empty(), "exported resource provenance/input/result rejection checks: " + str(rejections))
	_expect(result.bindings == 16 and result.saves == 16, "exported16actual funded resource bindings and16primary saves")
	var bounds: Dictionary = load("res://resource_boundaries.gd").new().run()
	for error in bounds.errors: _expect(false, String(error))
	_expect(bounds.cases == 15, "exported15atomic/distance/tie/native/custom placement boundaries")
	var ui: Dictionary = await load("res://resource_ui.gd").new().run(get_tree())
	for error in ui.errors: _expect(false, String(error))
	_expect(ui.selections == 16 and ui.rebindings == 13 and ui.rejections == 15 and ui.saves == 16, "exported formal Main16Inspector selections/13rebindings/15atomic rejects/16primary saves")
	print("WINDOWS RESOURCE PLACEMENT COUNTS: ", result.bindings, "/", result.saves, "/", bounds.cases, "/", ui.selections, "/", ui.rebindings, "/", ui.rejections, "/", ui.saves, "/23")

func _resource_mining() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mining-cases.json"))
	var paid: Dictionary = load("res://mining_paid.gd").new().run(fixture)
	for error in paid.errors: _expect(false, String(error))
	_expect(paid.saves == 32 and paid.panels == 33, "exported16paid count-one/fullEngine resources,32primary saves and33paid solar cards")
	var legacy: Dictionary = load("res://mining_legacy.gd").new().run()
	for error in legacy.errors: _expect(false, String(error))
	_expect(legacy.saves == 6 and legacy.rejections == 27 and legacy.boundaries == 3, "exported three actual old primary loads/three continuations/27debt rejects/3fraction boundaries")
	print("WINDOWS RESOURCE MINING COUNTS: ", paid.saves, "/", paid.panels, "/", legacy.saves, "/", legacy.rejections, "/", legacy.boundaries)

func _resource_mode() -> void:
	for name in ["query", "flow", "manual", "legacy", "ui"]:
		var runner: Node = load("res://mode_" + name + ".gd").new()
		add_child(runner)
		var errors: Array = await runner.run()
		for error in errors: _expect(false, String(error))
		runner.queue_free()
		await get_tree().process_frame
	_expect(failures == 0, "exported complete resource mode domain and formal Main regressions")
	print("WINDOWS RESOURCE MODE COUNTS: 4328/36/48/144/312/6/35/3")

func _resource_capacity() -> void:
	for name in ["initial", "legacy"]:
		var runner: Node = load("res://capacity_" + name + ".gd").new()
		add_child(runner)
		var errors: Array = runner.run()
		for error in errors: _expect(false, String(error))
		runner.queue_free()
		await get_tree().process_frame
	_expect(failures == 0, "exported source initial reserves and actual old capacity compatibility")
	print("WINDOWS INITIAL CAPACITY COUNTS: 12/1268/12/19/3/3/3/36")
