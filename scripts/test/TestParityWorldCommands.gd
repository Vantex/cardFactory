extends Node

func _ready() -> void:
	await get_tree().process_frame
	var runner := preload("res://scripts/test/WorldCommandBehaviorRunner.gd")
	if OS.get_cmdline_user_args().has("--world-commands-clock-only"):
		var clock_errors := _clock_rejections()
		for error in clock_errors: printerr("FAIL: " + error)
		print("PARITY WORLD COMMAND CLOCK TESTS PASSED" if clock_errors.is_empty() else "PARITY WORLD COMMAND CLOCK TESTS FAILED")
		get_tree().quit(0 if clock_errors.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--world-commands-resume-only"):
		var resume_errors := _survey_engine_resume()
		for error in resume_errors: printerr("FAIL: " + error)
		print("PARITY WORLD COMMAND RESUME TESTS PASSED" if resume_errors.is_empty() else "PARITY WORLD COMMAND RESUME TESTS FAILED")
		get_tree().quit(0 if resume_errors.is_empty() else 1)
		return
	var formal_errors: Array = await _formal_world_commands()
	if OS.get_cmdline_user_args().has("--world-commands-ui-only"):
		for error in formal_errors: printerr("FAIL: " + error)
		print("PARITY WORLD COMMAND UI TESTS PASSED" if formal_errors.is_empty() else "PARITY WORLD COMMAND UI TESTS FAILED")
		get_tree().quit(0 if formal_errors.is_empty() else 1)
		return
	var disk := not OS.get_cmdline_user_args().has("--world-commands-no-disk")
	var result: Dictionary = runner.new().run({}, disk)
	result.errors.append_array(formal_errors)
	result.errors.append_array(_clock_rejections())
	result.errors.append_array(_survey_engine_resume())
	_legacy_survey(result)
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var broken := fixture.duplicate(true)
	broken.source_files["src/game/engine.ts"] = "wrong"
	var rejected: Dictionary = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world command source drift grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.pop_back()
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world command missing case grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.append(broken.cases[0].duplicate(true))
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world command duplicate case grants no keys")
	broken = fixture.duplicate(true)
	broken.surveys[0].trace = []
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("missing source survey trace grants no keys")
	broken = fixture.duplicate(true)
	broken.surveys[0].trace[0].exploration.missions = []
	rejected = runner.new().run(broken, false, func(id, state):
		if id in ["colonize-boreal_giant-ready-240721-false", "active-ashen-computed-240721-false"]:
			state.planet_inventories.home.iron_ore = float(state.planet_inventories.home.get("iron_ore", 0)) + 1
			state.research_queue.append("dsp_electromagnetic_matrix"))
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("single wrong source survey and raw unrelated/alias ownership drift withhold all command keys")
	for error in result.errors.slice(0, 18): printerr("FAIL: " + error)
	print("WORLD COMMAND ERRORS: ", result.errors.size(), "; verified keys: ", result.verified_keys.size(), "; disk saves: ", result.disk_saves)
	if result.errors.is_empty(): print("PARITY WORLD COMMAND TESTS PASSED")
	else: printerr("PARITY WORLD COMMAND TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)

func _clock_rejections() -> Array:
	var errors := []
	var runner := preload("res://scripts/test/WorldCommandBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var checks := 0
	for stage in runner.SURVEY_STAGES:
		var broken := fixture.duplicate(true)
		var rows: Array = broken.surveys.filter(func(row): return row.stage == stage)
		if rows.is_empty():
			errors.append("clock rejection source stage exists: " + stage)
			continue
		var row: Dictionary = rows[0]
		row.clock = {"numerator": 1, "denominator": 60} if stage in ["zero", "half", "overshoot"] else null
		var rejected: Dictionary = runner.new().run(broken, false)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): errors.append("unexpected or missing exact clock withholds all keys: " + stage)
		checks += 1
	for alteration in ["raw_seconds", "denominator", "extra_field", "steps"]:
		var broken := fixture.duplicate(true)
		var row: Dictionary = broken.surveys.filter(func(value): return value.stage == "sixty_hz")[0]
		match alteration:
			"raw_seconds": row.seconds = 1.0
			"denominator": row.clock.denominator = 30
			"extra_field": row.clock.extra = 1
			"steps": row.steps = 8
		var rejected: Dictionary = runner.new().run(broken, false)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): errors.append("invalid exact clock withholds all keys: " + alteration)
		checks += 1
	print("WORLD COMMAND CLOCK REJECTIONS: ", checks, "; errors: ", errors.size())
	return errors

func _survey_engine_resume() -> Array:
	var errors := []
	var runner := preload("res://scripts/test/WorldCommandBehaviorRunner.gd")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var rows: Array = fixture.surveys.filter(func(row): return row.stage == "sixty_hz")
	if rows.size() != 21: errors.append("all seeded source systems have a 60 Hz resume case")
	var root := "res://.godot/world-command-resume-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	var reopened_count := 0
	for row in rows:
		var state: GameState = runner._state(row.input)
		var engine := SimulationEngine.new(state)
		var storage := SaveSystem.new(root + row.id + "/")
		for index in range(row.trace.size()):
			engine.update(SimulationEngine.FIXED_DELTA)
			if engine.get_last_step_count() != 1: errors.append(row.id + ": exact one fixed tick after resume")
			var actual: Dictionary = runner._domain(state)
			var expected: Dictionary = runner._comparison(row.trace[index])
			# Other simulation phases refresh metrics and campaign facts. This checks
			# source survey/ownership only, not full factory simulation equivalence.
			actual.erase("activeMetrics")
			expected.erase("activeMetrics")
			if not controls._same_value(actual, expected): errors.append(row.id + ": actual engine survey matches source tick %d" % index)
			if index == 2:
				state.paused = true
				var pending: Dictionary = runner._domain(state)
				engine.update(1.0)
				if runner._domain(state) != pending or engine.get_last_step_count() != 0: errors.append(row.id + ": pause retains paid pending survey")
				if not storage.save_slot(0, state).ok:
					errors.append(row.id + ": fixed-step checkpoint saves")
					break
				var loaded := storage.load_recovery_source(0, "primary")
				if not loaded.ok:
					errors.append(row.id + ": fixed-step pending survey reopens")
					break
				if not controls._same_value(runner._domain(loaded.state), pending): errors.append(row.id + ": disk preserves pending survey exactly after pause")
				state = loaded.state
				state.paused = false
				engine = SimulationEngine.new(state)
				reopened_count += 1
	print("WORLD COMMAND FIXED-STEP RESUMES: ", reopened_count, "; errors: ", errors.size())
	return errors

func _legacy_survey(result: Dictionary) -> void:
	var fixture_path := "res://tests/fixtures/task27-legacy-survey-save.json"
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var path := "res://.godot/legacy-survey-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	var storage := SaveSystem.new(path)
	var file := FileAccess.open(storage._get_slot_path(0), FileAccess.WRITE)
	if file == null:
		result.errors.append("actual legacy survey destination opens")
		return
	file.store_string(FileAccess.get_file_as_string(fixture_path))
	file.close()
	var loaded := storage.load_recovery_source(0, "primary")
	if not loaded.ok:
		result.errors.append("previous valid delayed survey loads with original digest")
		return
	if original.metadata.digest != "ca53bc0584ed70634ce8917d17989129c3b92e83a31813706f4547e9ef3886aa" or FileAccess.get_sha256(fixture_path) != "ff2587150e9780672e5bf4178e9af8241d760b7401c751dfb7bf4df48dd75167": result.errors.append("legacy survey fixture retains its original disk digest and bytes")
	if loaded.metadata.digest != "0156f21cfc6ca82d398cae003d335c50a554e863632f766b809f0422a7742541": result.errors.append("legacy survey keeps the existing migrated-reader return digest")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var before: Dictionary = GameStateCodec.to_persistent_dict(loaded.state.copy_state())
	if not storage.save_slot(0, loaded.state).ok:
		result.errors.append("legacy pending survey can save again")
		return
	var reopened := storage.load_recovery_source(0, "primary")
	if not reopened.ok:
		result.errors.append("legacy pending survey reopens")
		return
	if not controls._same_value(GameStateCodec.to_persistent_dict(reopened.state.copy_state()), before): result.errors.append("legacy survey full persistent ownership survives resave")
	var state: GameState = reopened.state
	var stock: Dictionary = state.planet_inventory.duplicate(true)
	var fleet: Dictionary = state.portable_fleet.duplicate(true)
	var galaxy := GalaxySystem.new(state)
	galaxy.update_exploration(galaxy.get_exploration_duration("borealis") / 2.0)
	if not state.explored_system_ids.has("borealis") or not state.exploration_missions.is_empty() or state.survey_progress_by_system.borealis != 1.0: result.errors.append("legacy half survey resumes and finishes exactly once")
	if state.planet_inventory != stock or state.portable_fleet != fleet: result.errors.append("resuming a previously paid survey charges no extra materials or fleet")
	if not storage.save_slot(0, state).ok: result.errors.append("completed legacy survey saves successfully")
	var after := storage.load_recovery_source(0, "primary")
	if not after.ok or not after.state.exploration_missions.is_empty() or not after.state.explored_system_ids.has("borealis"): result.errors.append("completed legacy survey reopens with unlocked beacon")
	print("LEGACY SURVEY ORIGINAL DIGEST CHECKED: ", loaded.metadata.digest)
	var near_path := "res://tests/fixtures/task27-legacy-survey-progress-save.json"
	var near_file := FileAccess.open(storage._get_slot_path(1), FileAccess.WRITE)
	near_file.store_string(FileAccess.get_file_as_string(near_path))
	near_file.close()
	var near := storage.load_recovery_source(1, "primary")
	if not near.ok:
		result.errors.append("actual old near-one survey save remains accepted")
		return
	if near.state.survey_progress_by_system.helios != 0.999999: result.errors.append("old near-one survey value remains unchanged")
	if not storage.save_slot(1, near.state).ok or not storage.load_recovery_source(1, "primary").ok: result.errors.append("old near-one survey save can save and reopen")
	var invalid: Dictionary = GameStateCodec.to_persistent_dict(near.state)
	invalid.survey_progress_by_system.helios = 0.9
	if GameStateValidator.validate_persistent_dict(invalid).is_empty(): result.errors.append("legacy genuinely incomplete unlocked progress remains rejected")

func _formal_world_commands() -> Array:
	var errors := []
	var runner := preload("res://scripts/test/WorldCommandBehaviorRunner.gd")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var original := {}
	var fields: Array = preload("res://scripts/test/CampaignUIBehaviorRunner.gd").MANAGER_FIELDS
	for field in fields: original[field] = GameManager.get(field)
	var original_processing := GameManager.is_processing()
	var original_settings := LocalSettings.values.duplicate(true)
	var original_path := LocalSettings.path
	var root := "res://.godot/world-command-ui-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
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
	var panel: Control = main.galaxy_map
	var pioneer: String = GalaxySystem.new(runner._state(fixture.cases[0].input)).get_system_planets("borealis")[0]
	var probes := ["explore-borealis-exact", "explore-borealis-prerequisite", "explore-borealis-technology", "explore-borealis-below", "explore-borealis-mission_running", "colonize-boreal_giant-ready", "colonize-boreal_giant-fleet_missing", "colonize-boreal_giant-remote_only", "active-ashen-computed", "active-" + pioneer + "-computed", "active-boreal_giant-not_colonized", "active-home-already_active"]
	for id in probes:
		var candidates: Array = fixture.cases.filter(func(value): return value.id == id + "-240721-false")
		if candidates.size() != 1:
			errors.append(id + ": formal source case exists exactly once")
			continue
		var row: Dictionary = candidates[0]
		var state: GameState = runner._state(row.input)
		GameManager.game_state = state
		GameManager.simulation_engine = SimulationEngine.new(state)
		GameManager.performance_monitor.game_state = state
		main._galaxy_system = GalaxySystem.new(state)
		main._planet_system = PlanetSystem.new(state, main._galaxy_system)
		main.card_renderer.set_game_state(state)
		main.connection_renderer.set_game_state(state)
		main.get_node("WorldCamera").position = Vector2.ZERO
		main.get_node("WorldCamera").zoom = Vector2.ONE
		panel.configure(state, main._galaxy_system, main._planet_system)
		var target: String = row.command.target
		var kind: String = row.command.kind
		panel._selected_system_id = target if kind == "explore" else main._galaxy_system.get_planet(target).system_id
		panel._selected_planet_id = main._galaxy_system.get_system_planets(target)[0] if kind == "explore" else target
		panel._refresh_details()
		var button: Button = panel._explore_button if kind == "explore" else panel._colonize_button if kind == "colonize" else panel._travel_button
		var changed: bool = row.expected.exploration.unlockedSystemIds != row.input.exploration.unlockedSystemIds if kind == "explore" else row.expected.logicalColonized != row.input.logicalColonized if kind == "colonize" else row.expected.activePlanetId != row.input.activePlanetId
		if button.disabled == changed: errors.append(id + ": formal button availability matches actual source command")
		if not button.disabled: button.pressed.emit()
		if not controls._same_value(runner._domain(state), runner._comparison(row.expected)): errors.append(id + ": formal Main signal reaches actual source command result")
	viewport.queue_free()
	await get_tree().process_frame
	for field in fields: GameManager.set(field, original[field])
	GameManager.set_process(original_processing)
	LocalSettings.path = original_path
	LocalSettings.values = original_settings
	for field in fields:
		if GameManager.get(field) != original[field]: errors.append("world UI restores original manager field " + field)
	print("WORLD COMMAND FORMAL UI ERRORS: ", errors.size(), "; controls: ", probes.size())
	return errors
