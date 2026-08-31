extends Node

var _failures := 0

func _ready() -> void:
	print("STATE PERSISTENCE TESTS STARTED")
	_test_canonical_snapshot_and_round_trip()
	_test_validation_rejects_corrupt_state()
	_test_research_validation_invariants()
	_test_research_queue_command_closure()
	_test_migrations_and_version_boundaries()
	_test_research_state_copy_and_compatibility_load()
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
	state.buildings["building_10"]["power_output"] = 500.0
	var payload := GameStateCodec.to_persistent_dict(state)

	_expect(state.get_state_version() == 5, "GameState exposes the current integer schema version")
	_expect(payload.keys() == ["buildings", "claimed_progression_reward_ids", "completed_achievement_ids", "completed_objective_ids", "completed_technologies", "connections", "construction_inventory", "cursor_payload", "elapsed_time", "handcraft_queue", "next_id", "planet_inventory", "research_current_id", "research_invested_costs", "research_paused", "research_progress", "research_queue", "research_queue_wait_reason", "schema_version", "technology_levels", "unlocked_progression_ids"], "persistent root keys use canonical order")
	_expect(payload.get("schema_version") == 5, "persistent payload contains schema version 5")
	_expect(payload.get("next_id") == 11, "persistent payload preserves the next stable ID")
	_expect(payload.get("planet_inventory") == {"gear": 2.0, "iron_ingot": 7.0}, "persistent payload preserves the planet tray")
	_expect(payload.get("construction_inventory").get("miner") == 2.0, "persistent payload preserves construction items")
	_expect(payload.get("cursor_payload") == {"amount": 3.0, "item_id": "coal"}, "persistent payload preserves cursor ownership")
	_expect(payload.get("handcraft_queue")[0].get("progress") == 0.25, "persistent payload preserves handcraft progress")
	_expect(payload.get("completed_technologies") == ["factory_foundations", "fluid_handling"], "set-like technology IDs use stable order")
	_expect(payload.get("buildings", {}).keys() == ["building_10", "building_2"], "building dictionary keys use stable order")
	_expect(payload.get("connections", {}).keys() == ["conn_9"], "connection dictionary keys use stable order")

	var encoded_position: Variant = payload.get("buildings", {}).get("building_10", {}).get("position")
	_expect(encoded_position is Dictionary and encoded_position == {"x": 10.5, "y": -3.25}, "Vector2 positions encode as numeric x/y dictionaries")
	_expect(not payload.has("paused") and not payload.has("speed") and not payload.has("simulation_budget"), "session-only root fields are excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("status"), "derived building status is excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("interaction_locked"), "temporary interaction locks are excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("power_efficiency"), "derived power efficiency is excluded")
	_expect(not payload.get("buildings", {}).get("building_10", {}).has("power_output"), "derived generator output is excluded")
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
		_expect(decoded.planet_inventory == {"gear": 2.0, "iron_ingot": 7.0} and decoded.construction_inventory.get("miner") == 2.0, "decode restores authoritative inventories")
		_expect(decoded.cursor_payload == {"amount": 3.0, "item_id": "coal"} and decoded.handcraft_queue[0].get("progress") == 0.25, "decode restores cursor ownership and queued work")
		_expect(decoded.paused == false and decoded.speed == 1.0, "decode uses fresh session controls")
		_expect(decoded.generate_id("building") == "building_11", "decoded state continues stable ID generation")
		decoded.buildings["building_10"]["input_buffer"]["iron_ore"] = 1.0
		_expect(state.buildings["building_10"]["input_buffer"]["iron_ore"] == 4.5, "decoded nested state does not alias the source state")

	state.buildings["building_10"]["runtime_node"].free()

	var repeatable_state := GameState.new()
	repeatable_state.completed_technologies = ["infinite_optimization"]
	repeatable_state.research_queue_wait_reason = "等待矩阵成本"
	repeatable_state.technology_levels = {"infinite_optimization": 2}
	var repeatable_payload := GameStateCodec.to_persistent_dict(repeatable_state)
	var repeatable_decoded := GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(repeatable_payload)))
	_expect(repeatable_decoded is GameState and repeatable_decoded.research_queue_wait_reason == "等待矩阵成本", "research queue wait reason survives JSON save/load")
	_expect(repeatable_decoded is GameState and repeatable_decoded.get_technology_level("infinite_optimization") == 2, "repeatable technology levels survive JSON save/load")

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

	var invalid_power_state := payload.duplicate(true)
	invalid_power_state["buildings"]["building_10"]["fuel_remaining"] = -1.0
	invalid_power_state["buildings"]["building_10"]["generation_factor"] = 1.5
	var power_state_errors := GameStateValidator.validate_persistent_dict(invalid_power_state)
	_expect(_error_codes(power_state_errors).has("invalid_fuel_remaining"), "validator rejects negative persisted fuel time")
	_expect(_error_codes(power_state_errors).has("invalid_generation_factor"), "validator rejects renewable generation factors outside zero-to-one")

	var invalid_authoritative_inventory := payload.duplicate(true)
	invalid_authoritative_inventory["planet_inventory"]["iron_ingot"] = -1.0
	invalid_authoritative_inventory["construction_inventory"]["miner"] = 100.0
	invalid_authoritative_inventory["cursor_payload"] = {"item_id": "gear", "amount": 0.0}
	invalid_authoritative_inventory["handcraft_queue"][0]["quantity_remaining"] = 0
	var authoritative_inventory_errors := GameStateValidator.validate_persistent_dict(invalid_authoritative_inventory)
	_expect(_error_codes(authoritative_inventory_errors).has("negative_inventory"), "validator rejects negative planet inventory")
	_expect(_error_codes(authoritative_inventory_errors).has("inventory_overflow"), "validator rejects construction inventory overflow")
	_expect(_error_codes(authoritative_inventory_errors).has("invalid_cursor_ownership"), "validator rejects cursor items without owned quantity")
	_expect(_error_codes(authoritative_inventory_errors).has("invalid_handcraft_remaining"), "validator rejects completed jobs left inside the persistent queue")

	var invalid_handcraft_progress := payload.duplicate(true)
	invalid_handcraft_progress["handcraft_queue"][0]["progress"] = NAN
	var handcraft_progress_errors := GameStateValidator.validate_persistent_dict(invalid_handcraft_progress)
	_expect(_error_codes(handcraft_progress_errors).has("invalid_handcraft_progress"), "validator rejects non-finite handcraft progress")

	var unknown_technology_level := payload.duplicate(true)
	unknown_technology_level["technology_levels"] = {"unknown_technology": 1}
	var unknown_level_errors := GameStateValidator.validate_persistent_dict(unknown_technology_level)
	_expect(_error_codes(unknown_level_errors).has("unknown_technology_level"), "validator rejects levels for unknown technology IDs")
	for invalid_level in [0, -1, 1.5]:
		var invalid_technology_level := payload.duplicate(true)
		invalid_technology_level["technology_levels"] = {"infinite_optimization": invalid_level}
		var invalid_level_errors := GameStateValidator.validate_persistent_dict(invalid_technology_level)
		_expect(_error_codes(invalid_level_errors).has("invalid_technology_level"), "validator rejects non-positive or fractional technology level %s" % invalid_level)

	var non_repeatable_level := payload.duplicate(true)
	non_repeatable_level["technology_levels"] = {"factory_foundations": 1}
	var non_repeatable_errors := GameStateValidator.validate_persistent_dict(non_repeatable_level)
	_expect(_error_codes(non_repeatable_errors).has("non_repeatable_technology_level"), "validator rejects levels for non-repeatable technology")

	var uncompleted_repeatable_level := payload.duplicate(true)
	uncompleted_repeatable_level["technology_levels"] = {"infinite_optimization": 1}
	var uncompleted_level_errors := GameStateValidator.validate_persistent_dict(uncompleted_repeatable_level)
	_expect(_error_codes(uncompleted_level_errors).has("technology_level_not_completed"), "validator rejects a repeatable level absent from completed technologies")

	var valid_repeatable_level := payload.duplicate(true)
	valid_repeatable_level["completed_technologies"].append("infinite_optimization")
	valid_repeatable_level["technology_levels"] = {"infinite_optimization": 2}
	var valid_level_errors := GameStateValidator.validate_persistent_dict(valid_repeatable_level)
	_expect(valid_level_errors.is_empty(), "validator accepts a completed repeatable technology with a positive integer level")

	for validation_error in dangling_errors + inventory_errors + id_errors + next_id_errors + power_state_errors + authoritative_inventory_errors + handcraft_progress_errors:
		_expect(validation_error is Dictionary, "validation errors use structured dictionaries")
		if validation_error is Dictionary:
			for key in ["code", "source", "id", "message"]:
				_expect(validation_error.has(key), "validation errors contain %s" % key)

func _test_research_validation_invariants() -> void:
	var valid_in_flight := GameState.new()
	valid_in_flight.research_current_id = "factory_foundations"
	valid_in_flight.research_progress = {"factory_foundations": 4.0}
	valid_in_flight.research_invested_costs = {"factory_foundations": {"matrix_science_1": 5.0}}
	var payload := GameStateCodec.to_persistent_dict(valid_in_flight)
	_expect(GameStateValidator.validate_persistent_dict(payload).is_empty(), "validator accepts a fully paid catalog-backed in-flight research state")

	var unknown_completed := payload.duplicate(true)
	unknown_completed["completed_technologies"] = ["unknown_technology"]
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(unknown_completed)).has("unknown_completed_technology"), "validator rejects unknown completed technology IDs")

	var unknown_current := payload.duplicate(true)
	unknown_current["research_current_id"] = "unknown_technology"
	unknown_current["research_progress"] = {"unknown_technology": 1.0}
	unknown_current["research_invested_costs"] = {"unknown_technology": {"matrix_science_1": 1.0}}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(unknown_current)).has("unknown_research_current"), "validator rejects an unknown current research ID")

	var unknown_queue := payload.duplicate(true)
	unknown_queue["research_queue"] = ["unknown_technology"]
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(unknown_queue)).has("unknown_research_queue"), "validator rejects unknown queued research IDs")

	var unknown_progress := payload.duplicate(true)
	unknown_progress["research_progress"] = {"unknown_technology": 1.0}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(unknown_progress)).has("unknown_research_progress"), "validator rejects unknown research progress IDs")

	var unknown_invested := payload.duplicate(true)
	unknown_invested["research_invested_costs"] = {"unknown_technology": {"matrix_science_1": 1.0}}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(unknown_invested)).has("unknown_research_investment"), "validator rejects unknown invested-cost IDs")

	var duplicated_current := payload.duplicate(true)
	duplicated_current["research_queue"] = ["factory_foundations"]
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(duplicated_current)).has("research_current_queued"), "validator rejects the current research duplicated inside the FIFO queue")

	var paused_without_current := payload.duplicate(true)
	paused_without_current["research_current_id"] = ""
	paused_without_current["research_paused"] = true
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(paused_without_current)).has("research_pause_without_current"), "validator rejects a paused flag without current research")

	var excessive_progress := payload.duplicate(true)
	excessive_progress["research_progress"]["factory_foundations"] = 10.5
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(excessive_progress)).has("invalid_research_progress"), "validator rejects research progress beyond the catalog duration")

	var missing_payment := payload.duplicate(true)
	missing_payment["research_invested_costs"] = {}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(missing_payment)).has("research_cost_not_paid"), "validator rejects a save that bypasses the current research matrix cost")

	var wrong_payment_amount := payload.duplicate(true)
	wrong_payment_amount["research_invested_costs"]["factory_foundations"]["matrix_science_1"] = 1.0
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(wrong_payment_amount)).has("invalid_research_invested_cost"), "validator rejects an invested matrix amount below the exact catalog cost")

	var wrong_payment_keys := payload.duplicate(true)
	wrong_payment_keys["research_invested_costs"]["factory_foundations"]["iron_ore"] = 5.0
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(wrong_payment_keys)).has("invalid_research_invested_cost"), "validator rejects invested cost keys beyond the exact catalog cost")

	var progress_without_payment := payload.duplicate(true)
	progress_without_payment["research_current_id"] = ""
	progress_without_payment["research_invested_costs"] = {}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(progress_without_payment)).has("research_progress_without_investment"), "validator rejects cancelled progress without retained payment")

	var reversed_queue := GameStateCodec.to_persistent_dict(GameState.new())
	reversed_queue["research_queue"] = ["fluid_handling", "factory_foundations"]
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(reversed_queue)).has("invalid_research_queue_prerequisite"), "validator rejects a queue whose prerequisite appears after its dependent")

	var completed_non_repeatable := GameStateCodec.to_persistent_dict(GameState.new())
	completed_non_repeatable["completed_technologies"] = ["factory_foundations"]
	completed_non_repeatable["research_queue"] = ["factory_foundations"]
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(completed_non_repeatable)).has("ineligible_research_queue"), "validator rejects completed non-repeatable technology in the queue")

	var completed_repeatable := GameStateCodec.to_persistent_dict(GameState.new())
	completed_repeatable["completed_technologies"] = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics", "dyson_engineering", "infinite_optimization"]
	completed_repeatable["technology_levels"] = {"infinite_optimization": 1}
	completed_repeatable["research_queue"] = ["infinite_optimization"]
	_expect(GameStateValidator.validate_persistent_dict(completed_repeatable).is_empty(), "validator accepts an eligible completed repeatable technology in the queue")

	var missing_repeatable_level := completed_repeatable.duplicate(true)
	missing_repeatable_level["research_queue"] = []
	missing_repeatable_level["technology_levels"] = {}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(missing_repeatable_level)).has("missing_repeatable_technology_level"), "validator requires a persistent level for every completed repeatable technology")

func _test_research_queue_command_closure() -> void:
	var cancel_state := GameState.new()
	cancel_state.planet_inventory["matrix_science_1"] = 5.0
	var cancel_service := TechnologySystem.new(cancel_state)
	cancel_service.start_research("factory_foundations")
	cancel_service.update_research(2.0)
	_expect(cancel_service.cancel_research(), "a legal cancel command succeeds without dependent queued work")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(cancel_state)).is_empty(), "a successful cancel persists a validator-valid state")

	var remove_state := GameState.new()
	var remove_service := TechnologySystem.new(remove_state)
	remove_service.add_to_queue("factory_foundations")
	remove_state.research_queue_wait_reason = "等待矩阵成本：factory_foundations"
	_expect(remove_service.remove_from_queue("factory_foundations") and remove_state.research_queue_wait_reason.is_empty(), "a legal queue removal clears the stale wait reason")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(remove_state)).is_empty(), "a successful queue removal persists a validator-valid state")

	var rejected_state := GameState.new()
	var rejected_service := TechnologySystem.new(rejected_state)
	rejected_service.add_to_queue("factory_foundations")
	rejected_service.add_to_queue("fluid_handling")
	var before := GameStateCodec.state_digest_payload(rejected_state)
	var events: Array = []
	var observer := func(_queue: Array) -> void: events.append("queue_changed")
	EventBus.technology_research_queue_changed.connect(observer)
	var removed := rejected_service.remove_from_queue("factory_foundations")
	EventBus.technology_research_queue_changed.disconnect(observer)
	_expect(not removed and GameStateCodec.state_digest_payload(rejected_state) == before and events.is_empty(), "an invalidating queue removal is rejected without state or events")
	_expect(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(rejected_state)).is_empty(), "a rejected queue removal retains a validator-valid state")

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
	_expect(migration_result.get("data", {}).get("schema_version") == 5, "version-zero migration advances through every registered step to schema version 5")
	_expect(migration_result.get("data", {}).get("construction_inventory", {}).get("legacy_credit") == 9.0, "legacy construction points become migration-only credit")
	_expect(GameStateCodec.from_persistent_dict(legacy_payload) is GameState, "codec accepts a valid migrated legacy payload")

	var future_payload := GameStateCodec.to_persistent_dict(GameState.new())
	future_payload["schema_version"] = GameState.SCHEMA_VERSION + 1
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

	var version_four_repeatable := GameStateCodec.to_persistent_dict(GameState.new())
	version_four_repeatable["schema_version"] = 4
	version_four_repeatable.erase("research_queue_wait_reason")
	version_four_repeatable.erase("technology_levels")
	version_four_repeatable["completed_technologies"] = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics", "dyson_engineering", "infinite_optimization"]
	var repeatable_migration := SaveMigrationRegistry.migrate_to_current(version_four_repeatable)
	_expect(repeatable_migration.get("ok") == true and repeatable_migration.get("data", {}).get("technology_levels", {}).get("infinite_optimization") == 1, "v4 to v5 migration initializes every completed repeatable technology at level one")
	var migrated_repeatable := GameStateCodec.from_persistent_dict(version_four_repeatable)
	if migrated_repeatable is GameState:
		migrated_repeatable.planet_inventory["matrix_science_1"] = 50.0
		var migrated_research := TechnologySystem.new(migrated_repeatable)
		var started_again := migrated_research.start_research("infinite_optimization")
		migrated_research.update_research(60.0)
		_expect(started_again and migrated_repeatable.get_technology_level("infinite_optimization") == 2, "a migrated level-one repeatable technology completes again as level two")
		_expect(is_equal_approx(migrated_repeatable.get_technology_effect_multiplier("production_speed"), 1.39107397275), "the migrated repeatable technology keeps its cumulative level-two production effect")
	else:
		_expect(false, "a valid v4 repeatable save decodes after the continuous v3 to v4 to v5 migration chain")

func _test_research_state_copy_and_compatibility_load() -> void:
	var source := GameState.new()
	source.completed_technologies = ["infinite_optimization"]
	source.research_current_id = "factory_foundations"
	source.research_queue = ["fluid_handling"]
	source.research_progress = {"factory_foundations": 3.5}
	source.research_invested_costs = {"factory_foundations": {"matrix_science_1": 5.0}}
	source.research_paused = true
	source.research_queue_wait_reason = "等待资源后重试"
	source.technology_levels = {"infinite_optimization": 2}

	var copied := source.copy_state()
	_expect(copied.research_current_id == source.research_current_id and copied.research_queue == source.research_queue and copied.research_progress == source.research_progress and copied.research_invested_costs == source.research_invested_costs, "GameState copy preserves current, queue, progress, and invested research costs")
	_expect(copied.research_paused == source.research_paused and copied.research_queue_wait_reason == source.research_queue_wait_reason and copied.technology_levels == source.technology_levels and copied.completed_technologies == source.completed_technologies, "GameState copy preserves pause, wait reason, levels, and completed technology IDs")
	var copied_has_research := copied.research_progress.has("factory_foundations") and copied.research_invested_costs.has("factory_foundations") and copied.technology_levels.has("infinite_optimization")
	if copied_has_research:
		copied.research_queue.append("advanced_materials")
		copied.research_progress["factory_foundations"] = 9.0
		copied.research_invested_costs["factory_foundations"]["matrix_science_1"] = 1.0
		copied.technology_levels["infinite_optimization"] = 99
		copied.completed_technologies.append("factory_foundations")
		_expect(source.research_queue == ["fluid_handling"] and source.research_progress["factory_foundations"] == 3.5 and source.research_invested_costs["factory_foundations"]["matrix_science_1"] == 5.0, "GameState research collections are deep-copied without nested aliases")
		_expect(source.technology_levels["infinite_optimization"] == 2 and source.completed_technologies == ["infinite_optimization"], "GameState level and completion collections do not alias their copy")
	else:
		_expect(false, "GameState research collections are deep-copied without nested aliases")
		_expect(false, "GameState level and completion collections do not alias their copy")

	var test_path := "res://.godot/test_saves/research_compat_%d_%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	var save_system := SaveSystem.new(test_path)
	var target := GameState.new()
	var compatibility_save := save_system.save_slot(0, source)
	if not compatibility_save.get("ok", false):
		printerr("COMPATIBILITY SAVE ERROR: %s" % compatibility_save.get("error", {}))
	_expect(compatibility_save.get("ok", false), "compatibility load fixture writes a valid non-empty research save")
	_expect(save_system.load_game(0, target), "compatibility load installs a persisted research state")
	_expect(target.research_current_id == source.research_current_id and target.research_queue == source.research_queue and target.research_progress == source.research_progress and target.research_invested_costs == source.research_invested_costs, "compatibility load preserves all active and retained research facts")
	_expect(target.research_paused == source.research_paused and target.research_queue_wait_reason == source.research_queue_wait_reason, "compatibility load preserves pause and queue wait reason")
	_expect(target.technology_levels == source.technology_levels and target.completed_technologies == source.completed_technologies, "compatibility load preserves technology levels and completion facts")
	_remove_test_save_directory(test_path)

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

	var serialized_digest: Variant = JSON.parse_string(JSON.stringify(first_digest))
	var migrated_digest := SaveMigrationRegistry.migrate_to_current(serialized_digest)
	_expect(migrated_digest.get("ok") == true, "serialized digest payload remains a valid current save")
	if migrated_digest.get("ok") == true:
		var before_json := JSON.stringify(first_digest)
		var after_json := JSON.stringify(migrated_digest.get("data", {}))
		_expect(before_json == after_json, "state digest survives a JSON write/read round trip")

func _test_durable_save_slots() -> void:
	var test_path := "res://.godot/test_saves/state_persistence_%d_%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	var save_system := SaveSystem.new(test_path)
	var required_methods := ["save_slot", "load_slot", "delete_slot", "get_slot_info"]
	for method_name in required_methods:
		_expect(save_system.has_method(method_name), "SaveSystem exposes %s" % method_name)
	if required_methods.any(func(method_name: String) -> bool: return not save_system.has_method(method_name)):
		_remove_test_save_directory(test_path)
		return

	var source := _make_fixture_state()
	var source_payload := GameStateCodec.state_digest_payload(source)
	var source_digest := JSON.stringify(source_payload).sha256_text()
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
		_expect(loaded_state.completed_technologies == ["factory_foundations", "fluid_handling"], "slot round trip restores research progress")
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

	var legacy_state := {
		"buildings": {},
		"completed_technologies": [],
		"connections": {},
		"construction_points": 7,
		"elapsed_time": 42.0,
		"next_id": 1,
		"schema_version": 1,
	}
	var legacy_envelope := {
		"format": "card_factory_save",
		"metadata": {
			"schema_version": 1,
			"saved_at": Time.get_unix_time_from_system(),
			"elapsed_time": 42.0,
			"active_planet": "home",
			"digest": JSON.stringify(legacy_state).sha256_text(),
		},
		"state": legacy_state,
	}
	_write_test_text(test_path + "save_6.json", JSON.stringify(legacy_envelope))
	var legacy_envelope_result: Dictionary = save_system.load_slot(6)
	_expect(legacy_envelope_result.get("ok") == true, "a valid version-one envelope verifies before migration and loads")
	if legacy_envelope_result.get("ok") == true:
		_expect(legacy_envelope_result.get("state").construction_inventory.get("legacy_credit") == 7.0, "a verified version-one envelope migrates its construction credit")

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

	var test_path := "res://.godot/test_saves/session_%d_%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
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
	state.planet_inventory = {"gear": 2.0, "iron_ingot": 7.0}
	state.construction_inventory = {"assembling_machine_mk1": 1.0, "miner": 2.0, "power_generator": 1.0, "smelter": 1.0}
	state.cursor_payload = {"item_id": "coal", "amount": 3.0}
	state.handcraft_queue = [{
		"id": "craft_8",
		"recipe_id": "handcraft_miner",
		"quantity_total": 2,
		"quantity_remaining": 1,
		"progress": 0.25,
	}]
	state.completed_technologies = ["fluid_handling", "factory_foundations"]
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
