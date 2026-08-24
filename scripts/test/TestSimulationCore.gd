extends Node

const FIXED_DELTA := 1.0 / 60.0

var _failures := 0

func _ready() -> void:
	print("SIMULATION CORE TESTS STARTED")
	_test_fixed_step_is_frame_rate_independent()
	_test_catch_up_budget_preserves_time()
	_test_power_controls_production_and_logistics()
	_test_generation_rules()
	_test_phase_order_and_tick_boundaries()

	if _failures > 0:
		printerr("SIMULATION CORE TESTS FAILED")
		get_tree().quit(1)
		return
	print("SIMULATION CORE TESTS PASSED")
	get_tree().quit(0)

func _test_fixed_step_is_frame_rate_independent() -> void:
	var sixty_state := _make_powered_smelter_state()
	var ten_state := _make_powered_smelter_state()
	var hitch_state := _make_powered_smelter_state()
	var sixty_engine := SimulationEngine.new(sixty_state)
	var ten_engine := SimulationEngine.new(ten_state)
	var hitch_engine := SimulationEngine.new(hitch_state)

	for _step in range(60):
		sixty_engine.update(FIXED_DELTA)
	for _step in range(10):
		ten_engine.update(0.1)
	hitch_engine.update(1.0)
	if hitch_engine.has_method("get_pending_simulation_time"):
		_drain_pending_time(hitch_engine)

	var sixty_digest := GameStateCodec.state_digest_payload(sixty_state)
	var ten_digest := GameStateCodec.state_digest_payload(ten_state)
	var hitch_digest := GameStateCodec.state_digest_payload(hitch_state)
	_expect(sixty_digest == ten_digest and ten_digest == hitch_digest, "60x1/60, 10x0.1, and a drained 1x1 hitch reach the same authoritative state")
	_expect(sixty_state.buildings["smelter"]["output_buffer"].get("iron_ingot", 0.0) == 2.0, "one simulated second completes both half-second smelting cycles")
	_expect(is_equal_approx(sixty_state.elapsed_time, 1.0), "fixed ticks advance authoritative elapsed time by exactly one simulated second")

func _test_catch_up_budget_preserves_time() -> void:
	var state := _make_powered_smelter_state()
	var engine := SimulationEngine.new(state)
	_expect(engine.has_method("get_pending_simulation_time") and engine.has_method("get_last_step_count"), "simulation exposes bounded catch-up diagnostics")
	if not engine.has_method("get_pending_simulation_time") or not engine.has_method("get_last_step_count"):
		return
	engine.update(1.0)
	_expect(engine.get_last_step_count() <= 10, "one render frame never exceeds the fixed catch-up step budget")
	_expect(engine.get_pending_simulation_time() > 0.0, "excess hitch time remains queued instead of being discarded")
	_drain_pending_time(engine)
	_expect(is_equal_approx(state.elapsed_time, 1.0), "later frames deterministically drain all retained hitch time")

func _test_power_controls_production_and_logistics() -> void:
	var unpowered := GameState.new()
	_add_building(unpowered, "miner", "miner", {"output_item": "iron_ore"})
	var unpowered_engine := SimulationEngine.new(unpowered)
	_run_seconds(unpowered_engine, 1.0)
	_expect(unpowered.buildings["miner"].get("power_efficiency") == 0.0, "a consumer with no generation receives zero power")
	_expect(unpowered.buildings["miner"]["output_buffer"].get("iron_ore", 0.0) == 0.0, "an unpowered miner stops instead of producing for free")

	var partial := GameState.new()
	_add_building(partial, "solar", "solar_panel", {"generation_factor": 30.0 / 360.0})
	_add_building(partial, "miner", "miner", {"output_item": "iron_ore"})
	_add_building(partial, "smelter", "smelter", {"recipe_id": "iron_ingot_recipe"})
	var partial_engine := SimulationEngine.new(partial)
	_run_seconds(partial_engine, 1.0)
	_expect(is_equal_approx(partial.buildings["miner"].get("power_efficiency", 0.0), 0.5), "insufficient generation assigns the same explicit power ratio to consumers")
	_expect(is_equal_approx(partial.buildings["miner"]["output_buffer"].get("iron_ore", 0.0), 5.0 / 60.0), "partial power proportionally slows extraction")

	var recovery := GameState.new()
	_add_building(recovery, "smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "progress": 0.4, "input_buffer": {"iron_ore": 2.0}})
	var recovery_engine := SimulationEngine.new(recovery)
	_run_seconds(recovery_engine, 0.5)
	_expect(is_equal_approx(recovery.buildings["smelter"]["progress"], 0.4), "a power outage preserves in-progress work")
	_add_building(recovery, "solar", "solar_panel")
	_run_seconds(recovery_engine, 0.5)
	_expect(is_equal_approx(recovery.buildings["smelter"]["progress"], 0.9), "restored power resumes from the preserved production progress")

	var logistics := GameState.new()
	_add_building(logistics, "solar", "solar_panel", {"generation_factor": 25.0 / 360.0})
	_add_building(logistics, "source", "storage", {"output_buffer": {"iron_ore": 1.0}})
	_add_building(logistics, "target", "smelter", {"recipe_id": "iron_ingot_recipe"})
	_add_connection(logistics, "belt", "source", "target", 10.0)
	var logistics_engine := SimulationEngine.new(logistics)
	logistics_engine.update(FIXED_DELTA)
	_expect(is_equal_approx(logistics.buildings["target"]["input_buffer"].get("iron_ore", 0.0), 10.0 * FIXED_DELTA * 0.5), "belt throughput is scaled by the powered endpoint ratio")

func _test_generation_rules() -> void:
	var fueled_state := GameState.new()
	_add_building(fueled_state, "generator", "power_generator")
	_add_building(fueled_state, "miner", "miner", {"output_item": "iron_ore"})
	var fueled_engine := SimulationEngine.new(fueled_state)
	fueled_engine.update(FIXED_DELTA)
	_expect(fueled_engine.get_power_info().get("generation") == 0.0, "a fuel generator with no fuel produces no power")
	_expect(fueled_state.buildings["miner"].get("power_efficiency") == 0.0, "an empty fuel generator cannot power consumers")
	_expect(fueled_state.buildings["generator"].get("status") == "no_fuel", "an empty fuel generator exposes a visible no-fuel status")
	fueled_state.buildings["generator"]["input_buffer"]["coal"] = 1.0
	fueled_engine.update(FIXED_DELTA)
	_expect(fueled_engine.get_power_info().get("generation") == 500.0, "a compatible fuel unit starts deterministic generator output")
	_expect(fueled_state.buildings["generator"]["input_buffer"].get("coal") == 0.0 and fueled_state.buildings["generator"].get("fuel_remaining", 0.0) > 0.0, "starting a fuel cycle consumes exactly one unit and records remaining burn time")
	_expect(fueled_state.buildings["generator"].get("status") == "running", "a fueled generator exposes a running status")

	var renewable_state := GameState.new()
	_add_building(renewable_state, "solar", "solar_panel", {"generation_factor": 0.5})
	_add_building(renewable_state, "wind", "wind_turbine")
	var renewable_engine := SimulationEngine.new(renewable_state)
	renewable_engine.update(FIXED_DELTA)
	_expect(renewable_engine.get_power_info().get("generation") == 480.0, "solar and wind generation use explicit deterministic availability factors without fuel")
	_expect(renewable_state.buildings["solar"].get("status") == "running" and renewable_state.buildings["wind"].get("status") == "running", "renewable generators expose their active generation state")

func _test_phase_order_and_tick_boundaries() -> void:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "miner", "miner", {"output_item": "iron_ore", "output_rate": 3600.0})
	_add_building(state, "smelter", "smelter", {"recipe_id": "iron_ingot_recipe"})
	_add_connection(state, "belt", "miner", "smelter", 60.0)
	var engine := SimulationEngine.new(state)
	_expect(engine.has_method("get_phase_order") and engine.get_phase_order() == ["power", "production", "belt", "research", "statistics"], "fixed ticks publish the authoritative phase order")
	engine.update(FIXED_DELTA)
	_expect(is_equal_approx(state.buildings["smelter"]["input_buffer"].get("iron_ore", 0.0), 1.0), "production runs before belts, so a miner's tick output can enter logistics")
	_expect(state.buildings["smelter"].get("progress", 0.0) == 0.0, "material delivered by belts is not consumed earlier in the same tick")
	engine.update(FIXED_DELTA)
	_expect(is_equal_approx(state.buildings["smelter"].get("progress", 0.0), FIXED_DELTA), "the next tick consumes the prior tick's delivered input exactly once")

func _make_powered_smelter_state() -> GameState:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "smelter", "smelter", {
		"recipe_id": "iron_ingot_recipe",
		"speed": 2.0,
		"input_buffer": {"iron_ore": 10.0},
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

func _add_connection(state: GameState, id: String, source_id: String, target_id: String, flow_rate: float) -> void:
	state.connections[id] = {
		"id": id,
		"source_id": source_id,
		"target_id": target_id,
		"item_id": "iron_ore",
		"flow_rate": flow_rate,
		"enabled": true,
		"active": false,
		"current_flow": 0.0,
	}

func _run_seconds(engine: SimulationEngine, seconds: float) -> void:
	var tick_count := int(round(seconds / FIXED_DELTA))
	for _tick in range(tick_count):
		engine.update(FIXED_DELTA)

func _drain_pending_time(engine: SimulationEngine) -> void:
	var guard := 0
	while engine.get_pending_simulation_time() + 0.0000001 >= FIXED_DELTA and guard < 120:
		engine.update(0.0)
		guard += 1

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
