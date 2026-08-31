extends Node

const FIXED_DELTA := 1.0 / 60.0

var _failures := 0

func _ready() -> void:
	print("STATISTICS CODEX TESTS STARTED")
	_test_completed_recipes_record_real_production_and_consumption()
	_test_statistics_are_frame_rate_independent()
	_test_game_state_persistence_excludes_statistics_history()
	_test_windows_are_bounded_and_use_their_covered_samples()
	_test_building_rates_keep_buildings_isolated()
	_test_invalid_record_amounts_do_not_pollute_rates()
	_test_belts_record_successful_transfers()
	_test_statistics_panel_uses_the_engine_statistics_service()
	if _failures > 0:
		printerr("STATISTICS CODEX TESTS FAILED")
		get_tree().quit(1)
		return
	print("STATISTICS CODEX TESTS PASSED")
	get_tree().quit(0)

func _test_completed_recipes_record_real_production_and_consumption() -> void:
	var state := _make_powered_smelter_state()
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 2.0)
	if not engine.statistics_system.has_method("get_item_rates"):
		_expect(false, "statistics exposes fixed-window item rates")
		return
	var rates: Dictionary = engine.statistics_system.get_item_rates("iron_ingot", 60)
	_expect(rates["produced_per_minute"] > 0.0, "completed recipes contribute real production")
	_expect(rates["consumed_per_minute"] > 0.0, "completed recipes contribute real consumption")
	_expect(is_equal_approx(rates["net_per_minute"], rates["produced_per_minute"] - rates["consumed_per_minute"]), "net rate is production minus consumption")

func _test_statistics_are_frame_rate_independent() -> void:
	var sixty_engine := SimulationEngine.new(_make_powered_smelter_state())
	var ten_engine := SimulationEngine.new(_make_powered_smelter_state())
	for _step in range(60):
		sixty_engine.update(FIXED_DELTA)
	for _step in range(10):
		ten_engine.update(0.1)
	_expect(sixty_engine.statistics_system.get_statistics_summary() == ten_engine.statistics_system.get_statistics_summary(), "60x1/60 and 10x0.1 produce identical statistics summaries")

func _test_game_state_persistence_excludes_statistics_history() -> void:
	var state := _make_powered_smelter_state()
	_run_seconds(SimulationEngine.new(state), 1.0)
	var serialized := GameStateCodec.to_persistent_dict(state)
	_expect(not _contains_key(serialized, "statistics_history"), "direct GameState serialization excludes statistics history")

func _test_windows_are_bounded_and_use_their_covered_samples() -> void:
	var stats := StatisticsSystem.new(GameState.new())
	for second in range(601):
		stats.record_produced("iron_ingot", float(second + 1))
		stats.update(1.0)
	_expect(stats.get_history_size() == 600, "statistics history is bounded")
	_expect(stats.get_item_rates("iron_ingot", 60)["produced_per_minute"] > stats.get_item_rates("iron_ingot", 600)["produced_per_minute"], "windows read only their covered samples")
	_expect(stats.get_item_rates("unknown", 60)["produced_per_minute"] == 0.0, "empty items return zero rates")

func _test_building_rates_keep_buildings_isolated() -> void:
	var state := GameState.new()
	_add_building(state, "solar_a", "solar_panel")
	_add_building(state, "solar_b", "solar_panel")
	_add_building(state, "fast_smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "speed": 2.0, "input_buffer": {"iron_ore": 10.0}})
	_add_building(state, "slow_smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 10.0}})
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 1.0)
	if not engine.statistics_system.has_method("get_building_item_rates"):
		_expect(false, "statistics exposes per-building fixed-window rates")
		return
	var fast_rates: Dictionary = engine.statistics_system.get_building_item_rates("fast_smelter", "iron_ingot", 60)
	var slow_rates: Dictionary = engine.statistics_system.get_building_item_rates("slow_smelter", "iron_ingot", 60)
	_expect(fast_rates["produced_per_minute"] > slow_rates["produced_per_minute"], "per-building rates do not combine separate producers")

func _test_invalid_record_amounts_do_not_pollute_rates() -> void:
	var stats := StatisticsSystem.new(GameState.new())
	stats.record_produced("iron_ingot", NAN, "smelter")
	stats.record_consumed("iron_ingot", INF, "smelter")
	stats.record_transferred("iron_ingot", -1.0, "belt")
	stats.record_produced("iron_ingot", 0.0, "smelter")
	stats.record_produced("iron_ingot", 2.0, "smelter")
	stats.update(1.0)
	var rates := stats.get_item_rates("iron_ingot", 60)
	_expect(is_finite(rates["produced_per_minute"]) and rates["produced_per_minute"] == 120.0, "NaN, INF, zero, and negative amounts are ignored")
	_expect(rates["consumed_per_minute"] == 0.0 and rates["transferred_per_minute"] == 0.0, "invalid amounts leave every event category unpolluted")

func _test_belts_record_successful_transfers() -> void:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "source", "storage", {"output_buffer": {"iron_ore": 10.0}})
	_add_building(state, "target", "smelter")
	_add_connection(state, "ore_belt", "source", "target", 10.0, "iron_ore")
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 1.0)
	_expect(engine.statistics_system.get_item_rates("iron_ore", 60)["transferred_per_minute"] > 0.0, "belt statistics include only successful real transfers")

func _test_statistics_panel_uses_the_engine_statistics_service() -> void:
	GameManager.replace_game_state(GameState.new())
	var shared_statistics := GameManager.get_simulation_engine().statistics_system
	var panel_script := load("res://scenes/ui/StatisticsPanel.gd")
	var panel: Variant = panel_script.new()
	add_child(panel)
	_expect(panel.stats_system == shared_statistics, "statistics panel uses the engine-owned statistics service")
	var history_size := shared_statistics.get_history_size()
	panel._process(0.0)
	_expect(shared_statistics.get_history_size() == history_size, "statistics panel does not advance statistics outside the simulation phase")
	panel.queue_free()

func _make_powered_smelter_state() -> GameState:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "smelter", "smelter", {
		"recipe_id": "iron_ingot_recipe",
		"speed": 2.0,
		"input_buffer": {"iron_ore": 10.0},
	})
	_add_building(state, "consumer", "assembling_machine_mk1", {
		"recipe_id": "circuit_recipe",
		"input_buffer": {"iron_ingot": 10.0, "copper_ingot": 10.0},
	})
	return state

func _add_building(state: GameState, id: String, type: String, overrides: Dictionary = {}) -> void:
	var definition := DataManager.get_building(type)
	var building := {
		"id": id,
		"type": type,
		"position": Vector2.ZERO,
		"status": "idle",
		"recipe_id": "",
		"progress": 0.0,
		"input_buffer": {},
		"output_buffer": {},
		"speed": definition.get("speed", 1.0),
	}
	building.merge(overrides, true)
	state.buildings[id] = building

func _add_connection(state: GameState, id: String, source_id: String, target_id: String, flow_rate: float, item_id: String) -> void:
	state.connections[id] = {
		"id": id,
		"source_id": source_id,
		"target_id": target_id,
		"item_id": item_id,
		"flow_rate": flow_rate,
		"enabled": true,
		"active": false,
		"current_flow": 0.0,
	}

func _run_seconds(engine: SimulationEngine, seconds: float) -> void:
	var tick_count := int(round(seconds / FIXED_DELTA))
	for _tick in range(tick_count):
		engine.update(FIXED_DELTA)

func _contains_key(value: Variant, key: String) -> bool:
	if value is Dictionary:
		for value_key in value:
			if String(value_key) == key or _contains_key(value[value_key], key):
				return true
	elif value is Array:
		for entry in value:
			if _contains_key(entry, key):
				return true
	return false

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
