extends Node

var _failures := 0

func _ready() -> void:
	print("STATE PERSISTENCE TESTS STARTED")
	_test_canonical_snapshot_and_round_trip()
	_test_validation_rejects_corrupt_state()
	_test_migrations_and_version_boundaries()
	_test_digest_is_stable_and_ignores_runtime_state()
	_test_durable_save_slots()
	_test_game_manager_replaces_authoritative_state()
	_test_game_session_coordinator()
	_test_session_ui_contract()

	if _failures > 0:
		printerr("STATE PERSISTENCE TESTS FAILED")
		get_tree().quit(1)
		return

	print("STATE PERSISTENCE TESTS PASSED")
	get_tree().quit(0)

func _test_canonical_snapshot_and_round_trip() -> void:
	var state := _make_fixture_state(false)
	state.buildings["building_10"]["runtime_node"] = Node.new()
	var payload := GameStateCodec.to_persistent_dict(state)

	_expect(state.get_state_version() == 1, "GameState exposes an integer schema version")
	_expect(payload.keys() == ["buildings", "completed_technologies", "connections", "construction_points", "elapsed_time", "next_id", "schema_version"], "persistent root keys use canonical order")
	_expect(payload.get("schema_version") == 1, "persistent payload contains schema version 1")
	_expect(payload.get("next_id") == 11, "persistent payload preserves the next stable ID")
	_expect(payload.get("construction_points") == 7, "persistent payload preserves construction points")
	_expect(payload.get("completed_technologies") == ["automation", "smelting"], "set-like technology IDs use stable order")
	_expect(payload.get("buildings", {}).keys() == ["building_10", "building_2"], "building dictionary keys use stable order")
	_expect(payload.get("connections", {}).keys() == ["conn_9"], "connection dictionary keys use stable order")

	var encoded_position: Variant = payload.get("buildings", {}).get("building_10", {}).get("position")
	_expect(encoded_position is Dictionary and encoded_position == {"x": 10.5, "y": -3.25}, "Vector2 positions encode as numeric x/y dictionaries")
	_expect(not payload.has("paused") and not payload.has("speed") and not payload.has("simulation_budget"), "session-only root fields are excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("status"), "derived building status is excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("interaction_locked"), "temporary interaction locks are excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("power_efficiency"), "derived power efficiency is excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("runtime_node"), "Object references are excluded")
	_expect(not payload.get("connections", {}).get("conn_9", {}).has("active"), "current-frame connection activity is excluded")
	_expect(not payload.get("connections", {}).get("conn_9", {}).has("current_flow"), "current-frame connection flow is excluded")

	var json_text := JSON.stringify(payload)
	var parsed: Variant = JSON.parse_string(json_text)
	var decoded := GameStateCodec.from_persistent_dict(parsed)
	_expect(decoded is GameState, "valid JSON payload decodes into a new GameState")
	if decoded is GameState:
		_expect(decoded != state, "decode creates a distinct GameState instance")
		_expect(decoded.buildings.get("building_10", {}).get("position") is Vector2, "decode restores Vector2 position types")
		_expect(decoded.buildings.get("building_10", {}).get("position") == Vector2(10.5, -3.25), "decode restores exact Vector2 values")
		_expect(decoded.buildings.get("building_10", {}).get("input_buffer", {}).get("iron_ore") == 4.5, "decode preserves input inventory")
		_expect(decoded.connections.get("conn_9", {}).get("enabled") == true, "decode preserves connection permission")
		_expect(decoded.connections.get("conn_9", {}).get("active") == false, "decode resets current-frame activity")
		_expect(decoded.connections.get("conn_9", {}).get("current_flow") == 0.0, "decode resets current-frame flow")
		_expect(decoded.paused == false and decoded.speed == 1.0, "decode uses fresh session controls")
		_expect(decoded.generate_id("building") == "building_11", "decoded state continues stable ID generation")
		decoded.buildings["building_10"]["input_buffer"]["iron_ore"] = 1.0
		_expect(state.buildings["building_10"]["input_buffer"]["iron_ore"] == 4.5, "decoded nested state does not alias the source state")

	state.buildings["building_10"]["runtime_node"].free()

func _test_validation_rejects_corrupt_state() -> void:
	var payload := GameStateCodec.to_persistent_dict(_make_fixture_state())

	var dangling := payload.duplicate(true)
	dangling["connections"]["conn_9"]["source_id"] = "building_missing"
	var dangling_errors := GameStateValidator.validate_persistent_dict(dangling)
	_expect(_error_codes(dangling_errors).has("dangling_connection_source"), "validator rejects dangling connection sources")

	var negative_inventory := payload.duplicate(true)
	negative_inventory["buildings"]["building_10"]["input_buffer"]["iron_ore"] = -0.5
	var inventory_errors := GameStateValidator.validate_persistent_dict(negative_inventory)
	_expect(_error_codes(inventory_errors).has("negative_inventory"), "validator rejects negative inventory")

	var mismatched_id := payload.duplicate(true)
	mismatched_id["buildings"]["building_10"]["id"] = "building_99"
	var id_errors := GameStateValidator.validate_persistent_dict(mismatched_id)
	_expect(_error_codes(id_errors).has("building_id_mismatch"), "validator rejects unstable building IDs")

	var colliding_next_id := payload.duplicate(true)
	colliding_next_id["next_id"] = 10
	var next_id_errors := GameStateValidator.validate_persistent_dict(colliding_next_id)
	_expect(_error_codes(next_id_errors).has("next_id_not_ahead"), "validator rejects a next ID that can collide with persisted IDs")

	for validation_error in dangling_errors + inventory_errors + id_errors + next_id_errors:
		_expect(validation_error is Dictionary, "validation errors use structured dictionaries")
		if validation_error is Dictionary:
			for key in ["code", "source", "id", "message"]:
				_expect(validation_error.has(key), "validation errors contain %s" % key)

func _test_migrations_and_version_boundaries() -> void:
	var legacy_payload := {
		"next_id": 1,
		"elapsed_time": 12.0,
		"construction_points": 9,
		"completed_technologies": [],
		"buildings": {},
		"connections": {},
	}
	var migration_result := SaveMigrationRegistry.migrate_to_current(legacy_payload)
	_expect(migration_result.get("ok") == true, "migration registry upgrades a known version-zero payload")
	_expect(migration_result.get("data", {}).get("schema_version") == 1, "version-zero migration advances exactly to schema version 1")
	_expect(GameStateCodec.from_persistent_dict(legacy_payload) is GameState, "codec accepts a valid migrated legacy payload")

	var future_payload := GameStateCodec.to_persistent_dict(GameState.new())
	future_payload["schema_version"] = 2
	var future_result := SaveMigrationRegistry.migrate_to_current(future_payload)
	_expect(future_result.get("ok") == false, "migration registry rejects unknown future versions")
	_expect(_error_codes(future_result.get("errors", [])).has("unsupported_future_version"), "future-version rejection has an explicit error code")
	_expect(GameStateCodec.from_persistent_dict(future_payload) == null, "codec refuses unknown future versions")

	var invalid_legacy := legacy_payload.duplicate(true)
	invalid_legacy["buildings"] = {
		"building_1": {
			"id": "building_1",
			"type": "miner",
			"position": {"x": 0.0, "y": 0.0},
			"input_buffer": {"iron_ore": -1.0},
			"output_buffer": {},
		}
	}
	invalid_legacy["next_id"] = 2
	var invalid_migration := SaveMigrationRegistry.migrate_to_current(invalid_legacy)
	_expect(invalid_migration.get("ok") == false, "migration registry validates the final migrated payload")
	_expect(_error_codes(invalid_migration.get("errors", [])).has("negative_inventory"), "post-migration validation reports corrupt inventory")

	var malformed_legacy := legacy_payload.duplicate(true)
	malformed_legacy["buildings"] = []
	var malformed_migration := SaveMigrationRegistry.migrate_to_current(malformed_legacy)
	_expect(malformed_migration.get("ok") == false, "migration registry safely rejects malformed legacy collections")
	_expect(_error_codes(malformed_migration.get("errors", [])).has("invalid_buildings"), "malformed legacy collections return a structured validation error")

	var malformed_scalar := legacy_payload.duplicate(true)
	malformed_scalar["next_id"] = {"not": "a number"}
	var malformed_scalar_migration := SaveMigrationRegistry.migrate_to_current(malformed_scalar)
	_expect(malformed_scalar_migration.get("ok") == false, "migration registry safely rejects malformed scalar fields")
	_expect(_error_codes(malformed_scalar_migration.get("errors", [])).has("invalid_next_id"), "malformed scalar fields return a structured validation error")

func _test_digest_is_stable_and_ignores_runtime_state() -> void:
	var first := _make_fixture_state()
	var second := _make_fixture_state(true)
	second.paused = false
	second.speed = 0.5
	second.simulation_budget["current_steps"] = 9
	second.buildings["building_10"]["status"] = "error"
	second.buildings["building_10"]["interaction_locked"] = false
	second.buildings["building_10"]["power_efficiency"] = 0.1
	second.connections["conn_9"]["active"] = false
	second.connections["conn_9"]["current_flow"] = 0.0

	var first_digest := GameStateCodec.state_digest_payload(first)
	var second_digest := GameStateCodec.state_digest_payload(second)
	_expect(first_digest == second_digest, "state digest ignores runtime-only values and dictionary insertion order")
	_expect(JSON.stringify(first_digest) == JSON.stringify(second_digest), "state digest has stable JSON ordering")

func _test_durable_save_slots() -> void:
	var test_path := "res://.godot/test_saves/state_persistence_%d/" % Time.get_ticks_usec()
	var save_system := SaveSystem.new(test_path)
	var required_methods := ["save_slot", "load_slot", "delete_slot", "get_slot_info"]
	for method_name in required_methods:
		_expect(save_system.has_method(method_name), "SaveSystem exposes %s" % method_name)
	if required_methods.any(func(method_name: String) -> bool: return not save_system.has_method(method_name)):
		_remove_test_save_directory(test_path)
		return

	var source := _make_fixture_state()
	var source_digest := JSON.stringify(GameStateCodec.state_digest_payload(source)).sha256_text()
	var save_result: Dictionary = save_system.save_slot(0, source, {"active_planet": "home"})
	_expect(save_result.get("ok") == true, "slot save writes a validated canonical state")
	var saved_metadata: Dictionary = save_result.get("metadata", {})
	_expect(saved_metadata.get("schema_version") == GameState.SCHEMA_VERSION, "slot metadata records the schema version")
	_expect(saved_metadata.get("elapsed_time") == source.elapsed_time, "slot metadata records played time")
	_expect(saved_metadata.get("active_planet") == "home", "slot metadata records the active planet")
	_expect(saved_metadata.get("digest") == source_digest, "slot metadata records the canonical state digest")
	_expect(float(saved_metadata.get("saved_at", 0.0)) > 0.0, "slot metadata records a wall-clock save time")

	var load_result: Dictionary = save_system.load_slot(0)
	var loaded_state: Variant = load_result.get("state")
	_expect(load_result.get("ok") == true and loaded_state is GameState, "slot load returns a fully decoded GameState")
	if loaded_state is GameState:
		_expect(GameStateCodec.state_digest_payload(loaded_state) == GameStateCodec.state_digest_payload(source), "slot round trip preserves the authoritative digest")
		_expect(loaded_state.buildings.get("building_10", {}).get("position") == Vector2(10.5, -3.25), "slot round trip restores building positions")
		_expect(loaded_state.buildings.get("building_10", {}).get("input_buffer", {}).get("iron_ore") == 4.5, "slot round trip restores inventory")
		_expect(loaded_state.completed_technologies == ["automation", "smelting"], "slot round trip restores research progress")
	_expect(save_system.get_slot_info(0).get("digest") == source_digest, "slot listing reads validated metadata")

	var invalid_save: Dictionary = save_system.save_slot(-1, source)
	var invalid_load: Dictionary = save_system.load_slot(SaveSystem.MAX_SAVES)
	_expect(_result_error_code(invalid_save) == "invalid_slot", "saving rejects an invalid slot with a structured error")
	_expect(_result_error_code(invalid_load) == "invalid_slot", "loading rejects an invalid slot with a structured error")

	_write_test_text(test_path + "save_1.json", "{broken json")
	var corrupt_result: Dictionary = save_system.load_slot(1)
	_expect(corrupt_result.get("ok") == false and _result_error_code(corrupt_result) == "invalid_json", "loading corrupt JSON fails without constructing a partial state")

	var future_envelope := {
		"format": "card_factory_save",
		"metadata": {"schema_version": GameState.SCHEMA_VERSION + 1, "saved_at": Time.get_unix_time_from_system(), "elapsed_time": 0.0, "active_planet": "home", "digest": "invalid"},
		"state": GameStateCodec.to_persistent_dict(GameState.new()),
	}
	future_envelope["state"]["schema_version"] = GameState.SCHEMA_VERSION + 1
	_write_test_text(test_path + "save_2.json", JSON.stringify(future_envelope))
	var future_result: Dictionary = save_system.load_slot(2)
	_expect(_result_error_code(future_result) == "unsupported_future_version", "loading rejects an unknown future state version")

	var metadata_payload := GameStateCodec.to_persistent_dict(source)
	var malformed_metadata_envelope := {
		"format": "card_factory_save",
		"metadata": {
			"schema_version": GameState.SCHEMA_VERSION,
			"saved_at": {"not": "a timestamp"},
			"elapsed_time": source.elapsed_time,
			"active_planet": "home",
			"digest": JSON.stringify(metadata_payload).sha256_text(),
		},
		"state": metadata_payload,
	}
	_write_test_text(test_path + "save_7.json", JSON.stringify(malformed_metadata_envelope))
	var malformed_metadata_result: Dictionary = save_system.load_slot(7)
	_expect(_result_error_code(malformed_metadata_result) == "invalid_metadata", "loading rejects malformed metadata before the slot list can consume it")

	_expect(save_system.save_slot(3, source).get("ok") == true, "interruption fixture has a valid primary save")
	_write_test_text(test_path + "save_3.json.tmp", "{interrupted write")
	var interrupted_result: Dictionary = save_system.load_slot(3)
	_expect(interrupted_result.get("ok") == true and interrupted_result.get("recovered_from_backup") == false, "an interrupted temp write never replaces a valid primary save")

	var first_generation := _make_fixture_state()
	first_generation.elapsed_time = 100.0
	var second_generation := _make_fixture_state()
	second_generation.elapsed_time = 200.0
	_expect(save_system.save_slot(4, first_generation).get("ok") == true, "backup fixture writes its first generation")
	_expect(save_system.save_slot(4, second_generation).get("ok") == true, "backup fixture rotates a second validated generation")
	_write_test_text(test_path + "save_4.json", "{corrupt primary")
	var recovered_result: Dictionary = save_system.load_slot(4)
	var recovered_state: Variant = recovered_result.get("state")
	_expect(recovered_result.get("ok") == true and recovered_result.get("recovered_from_backup") == true, "load recovers from the most recent validated backup")
	_expect(recovered_state is GameState and recovered_state.elapsed_time == 100.0, "backup recovery returns the last known-good generation")

	_expect(save_system.delete_slot(4).get("ok") == true, "slot deletion removes a populated slot")
	_expect(not FileAccess.file_exists(test_path + "save_4.json") and not FileAccess.file_exists(test_path + "save_4.json.bak") and not FileAccess.file_exists(test_path + "save_4.json.tmp"), "slot deletion removes primary, backup, and interrupted temp files")
	_remove_test_save_directory(test_path)

func _test_game_manager_replaces_authoritative_state() -> void:
	_expect(GameManager.has_method("replace_game_state"), "GameManager exposes an atomic state replacement boundary")
	if not GameManager.has_method("replace_game_state"):
		return

	var original_state: GameState = GameManager.get_game_state()
	var replacement := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(_make_fixture_state()))
	GameManager.replace_game_state(replacement)
	_expect(GameManager.get_game_state() == replacement, "GameManager installs the decoded authoritative state")
	_expect(GameManager.get_simulation_engine().game_state == replacement, "GameManager rebuilds simulation services for the replacement state")
	GameManager.replace_game_state(original_state)

func _test_game_session_coordinator() -> void:
	_expect(get_tree().auto_accept_quit == false, "window close waits for the explicit save handshake")
	var required_methods := ["configure_save_system", "get_save_system", "start_new_game", "continue_game", "save_current_game", "advance_autosave", "get_autosave_interval", "prepare_to_quit", "end_session", "is_session_active", "get_current_slot"]
	for method_name in required_methods:
		_expect(GameManager.has_method(method_name), "GameManager exposes %s" % method_name)
	if required_methods.any(func(method_name: String) -> bool: return not GameManager.has_method(method_name)):
		return

	var test_path := "res://.godot/test_saves/session_%d/" % Time.get_ticks_usec()
	var original_state: GameState = GameManager.get_game_state()
	var original_save_system: SaveSystem = GameManager.get_save_system()
	GameManager.configure_save_system(SaveSystem.new(test_path))

	var new_game_result: Dictionary = GameManager.start_new_game(5)
	_expect(new_game_result.get("ok") == true, "new game creates a validated initial slot")
	_expect(GameManager.is_session_active() and GameManager.get_current_slot() == 5, "new game activates exactly one selected slot")

	var session_state := _make_fixture_state()
	session_state.paused = true
	GameManager.replace_game_state(session_state)
	var manual_result: Dictionary = GameManager.save_current_game("manual")
	_expect(manual_result.get("ok") == true, "manual save uses the session save coordinator")
	_expect(session_state.paused == true, "saving preserves the player's pause intent")
	GameManager.set("_save_in_progress", true)
	var overlapping_result: Dictionary = GameManager.save_current_game("overlap")
	GameManager.set("_save_in_progress", false)
	_expect(_result_error_code(overlapping_result) == "save_in_progress", "the session coordinator rejects overlapping writes")

	var state_before_failed_load := GameManager.get_game_state()
	_write_test_text(test_path + "save_6.json", "{broken session")
	var failed_continue: Dictionary = GameManager.continue_game(6)
	_expect(failed_continue.get("ok") == false, "continue reports a corrupt slot failure")
	_expect(GameManager.get_game_state() == state_before_failed_load and GameManager.get_current_slot() == 5, "failed continue never installs a half-initialized session")

	GameManager.replace_game_state(GameState.new())
	var continue_result: Dictionary = GameManager.continue_game(5)
	_expect(continue_result.get("ok") == true, "continue loads the selected valid slot")
	_expect(GameManager.get_game_state().elapsed_time == 123.5, "continue atomically installs the persisted state")
	_expect(GameManager.get_simulation_engine().game_state == GameManager.get_game_state(), "continue rebuilds simulation services against the loaded state")

	GameManager.get_game_state().elapsed_time = 321.0
	GameManager.advance_autosave(GameManager.get_autosave_interval())
	var autosaved: Dictionary = GameManager.get_save_system().load_slot(5)
	_expect(autosaved.get("ok") == true and autosaved.get("state").elapsed_time == 321.0, "autosave uses the same validated slot pipeline")

	GameManager.get_game_state().elapsed_time = 654.0
	var quit_result: Dictionary = GameManager.prepare_to_quit()
	var exit_saved: Dictionary = GameManager.get_save_system().load_slot(5)
	_expect(quit_result.get("ok") == true and exit_saved.get("state").elapsed_time == 654.0, "quit handshake durably saves the active session")

	GameManager.configure_save_system(original_save_system)
	GameManager.replace_game_state(original_state)
	GameManager.end_session()
	_remove_test_save_directory(test_path)

func _test_session_ui_contract() -> void:
	var script_paths := [
		"res://scenes/ui/AppShell.gd",
		"res://scenes/ui/StartMenu.gd",
		"res://scenes/ui/SaveSlotsPanel.gd",
	]
	for script_path in script_paths:
		_expect(ResourceLoader.exists(script_path), "session UI provides %s" % script_path.get_file())
	if script_paths.any(func(script_path: String) -> bool: return not ResourceLoader.exists(script_path)):
		return

	var start_menu: Control = load("res://scenes/ui/StartMenu.gd").new()
	add_child(start_menu)
	_expect(start_menu.has_signal("new_game_requested") and start_menu.has_signal("continue_requested") and start_menu.has_signal("slots_requested"), "start menu exposes intent-only session signals")
	_expect(start_menu.get_node_or_null("Layout/Card/Content/Actions/NewGameButton") is Button, "start menu provides a new-game action")
	_expect(start_menu.get_node_or_null("Layout/Card/Content/Actions/ContinueButton") is Button, "start menu provides a continue action")
	_expect(start_menu.get_node_or_null("Layout/Card/Content/Actions/SlotsButton") is Button, "start menu provides slot management")
	start_menu.show_error("存档损坏，请选择备份或其他槽位")
	var error_label := start_menu.get_node_or_null("Layout/Card/Content/ErrorLabel") as Label
	_expect(error_label != null and error_label.visible and error_label.text.contains("存档损坏"), "start menu keeps load failures visible and actionable")
	start_menu.free()

	var slots_panel: Control = load("res://scenes/ui/SaveSlotsPanel.gd").new()
	add_child(slots_panel)
	_expect(slots_panel.has_signal("new_game_requested") and slots_panel.has_signal("continue_requested") and slots_panel.has_signal("delete_requested") and slots_panel.has_signal("back_requested"), "slot panel emits commands without mutating GameState")
	slots_panel.refresh_slots([{"slot": 2, "saved_at": 1.0, "elapsed_time": 123.0, "building_count": 2, "active_planet": "home"}])
	_expect(slots_panel.get_node_or_null("Layout/Card/Content/Slots/Slot2/Row/ContinueButton") is Button, "occupied slots expose continue")
	_expect(slots_panel.get_node_or_null("Layout/Card/Content/Slots/Slot2/Row/DeleteButton") is Button, "occupied slots expose delete")
	_expect(slots_panel.get_node_or_null("Layout/Card/Content/Slots/Slot0/Row/NewGameButton") is Button, "empty slots expose new game")
	_expect(slots_panel.get_node_or_null("DeleteConfirmation") is ConfirmationDialog, "slot deletion requires explicit confirmation")
	slots_panel.free()

func _make_fixture_state(reverse_insertion_order: bool = false) -> GameState:
	var state := GameState.new()
	state.elapsed_time = 123.5
	state.construction_points = 7
	state.completed_technologies = ["smelting", "automation"]
	state._next_id = 11
	state.paused = true
	state.speed = 3.0
	state.simulation_budget["current_steps"] = 4

	var building_10 := {
		"id": "building_10",
		"type": "smelter",
		"position": Vector2(10.5, -3.25),
		"status": "running",
		"recipe_id": "iron_ingot_recipe",
		"progress": 0.75,
		"input_buffer": {"iron_ore": 4.5},
		"output_buffer": {"iron_ingot": 2.0},
		"speed": 1.0,
		"interaction_locked": true,
		"power_efficiency": 0.4,
	}
	var building_2 := {
		"id": "building_2",
		"type": "miner",
		"position": Vector2(-20.0, 8.0),
		"status": "running",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {"iron_ore": 3.0},
		"speed": 1.0,
		"output_item": "iron_ore",
	}
	var connection := {
		"id": "conn_9",
		"source_id": "building_2",
		"target_id": "building_10",
		"type": "conveyor_belt_mk1",
		"item_id": "iron_ore",
		"enabled": true,
		"active": true,
		"current_flow": 12.0,
	}

	if reverse_insertion_order:
		state.buildings["building_10"] = building_10
		state.buildings["building_2"] = building_2
	else:
		state.buildings["building_2"] = building_2
		state.buildings["building_10"] = building_10
	state.connections["conn_9"] = connection
	return state

func _error_codes(errors: Array) -> Array:
	var codes: Array = []
	for validation_error in errors:
		if validation_error is Dictionary:
			codes.append(validation_error.get("code", ""))
	return codes

func _result_error_code(result: Dictionary) -> String:
	return String(result.get("error", {}).get("code", ""))

func _write_test_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "test fixture can write %s" % path)
		return
	file.store_string(contents)
	file.close()

func _remove_test_save_directory(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path.trim_suffix("/"))
	var directory := DirAccess.open(absolute_path)
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir():
				directory.remove(entry)
			entry = directory.get_next()
		directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
