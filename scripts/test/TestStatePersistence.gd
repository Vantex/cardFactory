extends Node

var _failures := 0

func _ready() -> void:
	print("STATE PERSISTENCE TESTS STARTED")
	_test_canonical_snapshot_and_round_trip()
	_test_validation_rejects_corrupt_state()
	_test_migrations_and_version_boundaries()
	_test_digest_is_stable_and_ignores_runtime_state()
	_test_game_manager_replaces_authoritative_state()

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

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
