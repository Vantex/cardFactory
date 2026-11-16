extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	var fixture := DSPOnlineParity.read_json(runner.FIXTURE)
	var broken := fixture.duplicate(true)
	broken.source_files["src/game/galaxy.ts"] = "wrong"
	var rejected: Dictionary = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world control source drift grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.pop_back()
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world control missing case grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.append(broken.cases[0].duplicate(true))
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("world control duplicate case grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.filter(func(row): return row.id == "metadata-home-basic")[0].expected_source_utf16.planetMetadata.home.note.utf16[0] = 70000
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("invalid original UTF16 evidence grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.filter(func(row): return row.id == "metadata-home-basic")[0].expected_source_utf16.planetMetadata.home.note.utf16[0] = 65
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("source UTF16 and portable projection mismatch grants no keys")
	broken = fixture.duplicate(true)
	broken.cases.filter(func(row): return row.id == "metadata-home-basic")[0].expected.planetMetadata.home.note += "wrong"
	rejected = runner.new().run(broken, false)
	if rejected.errors.is_empty() or rejected.verified_keys.has(runner.KEYS.planetMetadata): result.errors.append("one wrong metadata result withholds its complete key")
	rejected = runner.new().run({}, false, func(_id, state):
		state.planet_inventories.home = state.planet_inventories.home.duplicate(true)
		state.planet_inventories.home.iron_ore = float(state.planet_inventories.home.get("iron_ore", 0)) + 1)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): result.errors.append("raw inactive alias mutation withholds all control keys")
	var unknown: GameState = runner._state(fixture.cases[0].before)
	unknown.planet_tray_limits.unknown_planet = 2000
	if GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(unknown)).is_empty(): result.errors.append("unknown source planet cannot enter a valid saved capacity map")
	_legacy_metadata_fixture(result)
	await _formal_controls(fixture, result)
	for error in result.errors.slice(0, 15): printerr("FAIL: " + error)
	print("WORLD CONTROL ERRORS: ", result.errors.size(), "; verified keys: ", result.verified_keys.size(), "; disk saves: ", result.disk_saves)
	if result.errors.is_empty(): print("PARITY WORLD CONTROL TESTS PASSED")
	else: printerr("PARITY WORLD CONTROL TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)

func _legacy_metadata_fixture(result: Dictionary) -> void:
	var fixture_path := "res://tests/fixtures/task27-legacy-metadata-save.json"
	var fixture_text := FileAccess.get_file_as_string(fixture_path)
	var fixture: Dictionary = JSON.parse_string(fixture_text)
	var directory := "res://.godot/legacy-metadata-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	var service := SaveSystem.new(directory)
	var file := FileAccess.open(directory + "save_0.json", FileAccess.WRITE)
	if file == null:
		result.errors.append("legacy metadata fixture destination opens")
		return
	file.store_string(fixture_text)
	file.close()
	var loaded := service.load_recovery_source(0, "primary")
	if not loaded.ok:
		result.errors.append("previously successful Unicode whitespace metadata keeps its original verified disk")
		return
	if loaded.metadata.digest != fixture.metadata.digest or fixture.metadata.digest != "d53df4abced34d6070f9651d386c503c0e98bd97b38931f5fd519f873cb3ab9c": result.errors.append("legacy metadata retains its actual original digest")
	if loaded.state.source_galaxy != fixture.state.source_galaxy: result.errors.append("legacy metadata loads without silently normalizing existing tags")
	var runner := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var before: Dictionary = GameStateCodec.to_persistent_dict(loaded.state.copy_state())
	var saved := service.save_slot(0, loaded.state)
	if not saved.ok:
		result.errors.append("legacy metadata can be saved again")
		return
	var reopened := service.load_recovery_source(0, "primary")
	if not reopened.ok or not runner._same_value(GameStateCodec.to_persistent_dict(reopened.state.copy_state()), before): result.errors.append("legacy metadata resave and reopen retain complete persistent ownership")

func _formal_controls(fixture: Dictionary, result: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var panel := preload("res://scenes/ui/GalaxyMap.gd").new()
	viewport.add_child(panel)
	await get_tree().process_frame
	var runner := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	for index in range(SourceGalaxySystem.ROLES.size()):
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == "role-home-" + SourceGalaxySystem.ROLES[index])[0]
		var state: GameState = runner._state(row.before)
		panel.configure(state, GalaxySystem.new(state), PlanetSystem.new(state))
		panel._selected_planet_id = "home"
		panel._selected_system_id = "helios"
		panel._refresh_details()
		var before: Dictionary = runner._untouched(state)
		panel._role.select(index)
		panel._role.item_selected.emit(index)
		if runner._domain(state) != row.expected: result.errors.append(row.id + ": formal role control consumes the source setter")
		if runner._untouched(state) != before: result.errors.append(row.id + ": formal role preserves unrelated raw ownership")
	for stage in ["minimum", "maximum", "repeat"]:
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == "limit-home-" + stage)[0]
		var state: GameState = runner._state(row.before)
		panel.configure(state, GalaxySystem.new(state), PlanetSystem.new(state))
		panel._selected_planet_id = "home"
		panel._selected_system_id = "helios"
		panel._refresh_details()
		var before: Dictionary = runner._untouched(state)
		panel._tray_limit.value = row.command.value
		panel.find_child("SavePlanetTrayLimit", true, false).pressed.emit()
		if runner._domain(state) != row.expected: result.errors.append(row.id + ": formal capacity button consumes the source setter")
		if runner._untouched(state) != before: result.errors.append(row.id + ": formal capacity preserves unrelated raw ownership")
	for stage in ["basic", "empty", "unicode_space", "control_characters", "overflow", "truncated_duplicate", "emoji_even", "emoji_odd", "emoji_collision", "replacement_collision", "capped_collision"]:
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == "metadata-home-" + stage)[0]
		var state: GameState = runner._state(row.before)
		panel.configure(state, GalaxySystem.new(state), PlanetSystem.new(state))
		panel._selected_planet_id = "home"
		panel._selected_system_id = "helios"
		panel._refresh_details()
		var before: Dictionary = runner._untouched(state)
		panel._local_name.text = row.command.value.customName
		panel._local_note.text = row.command.value.note
		panel._local_tags.text = ",".join(row.command.value.tags)
		panel.find_child("SavePlanetMetadata", true, false).pressed.emit()
		if runner._domain(state) != row.expected: result.errors.append(row.id + ": formal metadata button consumes the source-normalized setter")
		if runner._untouched(state) != before: result.errors.append(row.id + ": formal metadata preserves unrelated raw ownership")
	for stage in ["empty", "unicode_space", "control_characters", "overflow", "emoji_even", "emoji_odd"]:
		var row: Dictionary = fixture.cases.filter(func(value): return value.id == "name-helios-" + stage)[0]
		var state: GameState = runner._state(row.before)
		panel.configure(state, GalaxySystem.new(state), PlanetSystem.new(state))
		panel._selected_system_id = "helios"
		panel._selected_planet_id = "home"
		panel._refresh_details()
		panel._system_name.text = row.command.value
		panel.find_child("SaveSystemMetadata", true, false).pressed.emit()
		if runner._domain(state) != row.expected: result.errors.append(row.id + ": formal system name button consumes the source-normalized setter")
	viewport.queue_free()
	await get_tree().process_frame
