extends Node

const FIXED_DELTA := 1.0 / 60.0

var _failures := 0

func _ready() -> void:
	print("SIMULATION CORE TESTS STARTED")
	_test_fixed_step_is_frame_rate_independent()
	_test_catch_up_budget_preserves_time()
	_test_power_controls_production_and_logistics()
	_test_generation_rules()
	_test_catalog_driven_production_rules()
	_test_first_science_chain_from_raw_ore()
	_test_phase_order_and_tick_boundaries()
	_test_research_requires_powered_matrix_lab()
	_test_tier_technology_effects_change_real_production()
	_test_extraction_boundaries()
	_test_colonized_planets_simulate_without_multiplying_global_time()
	_test_handcraft_delivery_keeps_queued_planet()

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

func _test_catalog_driven_production_rules() -> void:
	var extraction_state := GameState.new()
	_add_building(extraction_state, "solar_a", "solar_panel")
	_add_building(extraction_state, "solar_b", "solar_panel")
	_add_building(extraction_state, "solar_c", "solar_panel")
	_add_building(extraction_state, "oil", "oil_extractor")
	_run_seconds(SimulationEngine.new(extraction_state), 2.0)
	_expect(is_equal_approx(extraction_state.buildings["oil"].get("output_buffer", {}).get("crude_oil", 0.0), 1.0), "any catalog extractor uses its declared resource and rate")

	var refinery_state := GameState.new()
	_add_building(refinery_state, "generator_a", "power_generator", {"input_buffer": {"coal": 1.0}})
	_add_building(refinery_state, "generator_b", "power_generator", {"input_buffer": {"coal": 1.0}})
	_add_building(refinery_state, "refinery", "oil_refinery", {"recipe_id": "refined_oil_recipe", "input_buffer": {"crude_oil": 2.0}})
	_run_seconds(SimulationEngine.new(refinery_state), 2.0)
	_expect(refinery_state.buildings["refinery"].get("output_buffer", {}) == {"hydrogen": 1.0, "refined_oil": 1.0}, "a catalog recipe emits every declared main product and byproduct")

	var capacity_state := GameState.new()
	_add_building(capacity_state, "solar", "solar_panel")
	_add_building(capacity_state, "smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 1.0}, "output_buffer": {"iron_ingot": 24.0}})
	_run_seconds(SimulationEngine.new(capacity_state), 2.0)
	_expect(capacity_state.buildings["smelter"].get("status") == "blocked" and capacity_state.buildings["smelter"].get("output_buffer", {}).get("iron_ingot") == 24.0, "each building enforces its catalog output-buffer capacity")

	var science_state := GameState.new()
	_add_building(science_state, "generator", "power_generator", {"input_buffer": {"coal": 1.0}})
	_add_building(science_state, "lab", "matrix_lab", {"recipe_id": "basic_matrix_recipe", "input_buffer": {"circuit": 1.0, "magnetic_coil": 1.0}})
	_run_seconds(SimulationEngine.new(science_state), 4.0)
	_expect(science_state.buildings["lab"].get("output_buffer", {}).get("matrix_science_1", 0.0) == 1.0, "research equipment completes the first science-matrix recipe")

	var byproduct_connection_state := GameState.new()
	_add_building(byproduct_connection_state, "refinery", "oil_refinery", {"recipe_id": "refined_oil_recipe"})
	_add_building(byproduct_connection_state, "fractionator", "fractionator")
	var invalid_output_connection := byproduct_connection_state.try_add_connection("refinery", "fractionator", "iron_ingot")
	_expect(not invalid_output_connection.get("ok", false) and byproduct_connection_state.connections.is_empty(), "the formal connection command rejects an item the source recipe does not produce")
	var byproduct_connection := byproduct_connection_state.try_add_connection("refinery", "fractionator", "hydrogen")
	_expect(byproduct_connection.get("ok", false) and byproduct_connection_state.connections.values()[0].get("item_id", "") == "hydrogen" and byproduct_connection_state.buildings["fractionator"].get("recipe_id", "") == "deuterium_recipe", "the formal connection command routes a selected recipe byproduct")

func _test_first_science_chain_from_raw_ore() -> void:
	var state := GameState.new()
	_add_building(state, "generator_a", "power_generator", {"input_buffer": {"coal": 5.0}})
	_add_building(state, "generator_b", "power_generator", {"input_buffer": {"coal": 5.0}})
	_add_building(state, "iron_miner", "miner", {"output_item": "iron_ore", "output_rate": 3600.0})
	_add_building(state, "copper_miner", "miner", {"output_item": "copper_ore", "output_rate": 3600.0})
	_add_building(state, "iron_smelter", "smelter", {"recipe_id": "iron_ingot_recipe"})
	_add_building(state, "magnet_smelter", "smelter", {"recipe_id": "magnet_recipe"})
	_add_building(state, "copper_smelter", "smelter", {"recipe_id": "copper_ingot_recipe"})
	_add_building(state, "circuit_assembler", "assembling_machine_mk1", {"recipe_id": "circuit_recipe"})
	_add_building(state, "coil_assembler", "assembling_machine_mk1", {"recipe_id": "magnetic_coil_recipe"})
	_add_building(state, "lab", "matrix_lab", {"recipe_id": "basic_matrix_recipe"})
	_add_connection(state, "iron_to_ingot", "iron_miner", "iron_smelter", 60.0, "iron_ore")
	_add_connection(state, "iron_to_magnet", "iron_miner", "magnet_smelter", 60.0, "iron_ore")
	_add_connection(state, "copper_to_ingot", "copper_miner", "copper_smelter", 60.0, "copper_ore")
	_add_connection(state, "ingot_to_circuit", "iron_smelter", "circuit_assembler", 60.0, "iron_ingot")
	_add_connection(state, "copper_to_circuit", "copper_smelter", "circuit_assembler", 60.0, "copper_ingot")
	_add_connection(state, "copper_to_coil", "copper_smelter", "coil_assembler", 60.0, "copper_ingot")
	_add_connection(state, "magnet_to_coil", "magnet_smelter", "coil_assembler", 60.0, "magnet")
	_add_connection(state, "circuit_to_lab", "circuit_assembler", "lab", 60.0, "circuit")
	_add_connection(state, "coil_to_lab", "coil_assembler", "lab", 60.0, "magnetic_coil")
	_run_seconds(SimulationEngine.new(state), 90.0)
	_expect(float(state.buildings["lab"].get("output_buffer", {}).get("matrix_science_1", 0.0)) >= 1.0, "the catalog runs end-to-end from iron and copper ore to the mandatory research matrix")

func _test_phase_order_and_tick_boundaries() -> void:
	var state := GameState.new()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "miner", "miner", {"output_item": "iron_ore", "output_rate": 3600.0})
	_add_building(state, "smelter", "smelter", {"recipe_id": "iron_ingot_recipe"})
	_add_connection(state, "belt", "miner", "smelter", 60.0)
	var engine := SimulationEngine.new(state)
	_expect(engine.has_method("get_phase_order") and engine.get_phase_order() == ["power", "production", "handcraft", "belt", "galaxy", "research", "statistics"], "fixed ticks publish the authoritative phase order")
	engine.update(FIXED_DELTA)
	_expect(is_equal_approx(state.buildings["smelter"]["input_buffer"].get("iron_ore", 0.0), 1.0), "production runs before belts, so a miner's tick output can enter logistics")
	_expect(state.buildings["smelter"].get("progress", 0.0) == 0.0, "material delivered by belts is not consumed earlier in the same tick")
	engine.update(FIXED_DELTA)
	_expect(is_equal_approx(state.buildings["smelter"].get("progress", 0.0), FIXED_DELTA), "the next tick consumes the prior tick's delivered input exactly once")

func _test_research_requires_powered_matrix_lab() -> void:
	var state := GameState.new()
	state.planet_inventory["matrix_science_1"] = 5.0
	var research := TechnologySystem.new(state)
	_expect(research.start_research("factory_foundations"), "simulation research fixture pays an actual matrix catalog cost")
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 1.0)
	_expect(is_equal_approx(state.get_technology_progress("factory_foundations"), 0.0), "research does not advance without a legal matrix research device")
	_add_building(state, "lab", "matrix_lab")
	_run_seconds(engine, 1.0)
	_expect(is_equal_approx(state.get_technology_progress("factory_foundations"), 0.0), "an unpowered research device cannot advance paid matrix research")
	_add_building(state, "solar_a", "solar_panel")
	_add_building(state, "solar_b", "solar_panel")
	_run_seconds(engine, 1.0)
	_expect(state.get_technology_progress("factory_foundations") > 0.0, "a powered legal matrix lab advances research during the dedicated fixed-tick phase")

func _test_tier_technology_effects_change_real_production() -> void:
	# Each assertion catches one catalog tier being omitted from the real
	# ProductionSystem multiplier, rather than only checking an effect getter.
	_expect(_iron_output_after_seconds(["factory_foundations"], {}, 0.49) == 1.0, "planetary technology increases real smelter output before the base second cycle")
	_expect(_iron_output_after_seconds(["interstellar_logistics"], {}, 0.49) == 1.0, "interstellar technology increases real smelter output before the base second cycle")
	_expect(_iron_output_after_seconds(["dyson_engineering"], {}, 0.49) == 1.0, "dyson technology increases real smelter output before the base second cycle")
	_expect(_iron_output_after_seconds(["infinite_optimization"], {"infinite_optimization": 2}, 0.49) == 1.0, "second infinite level cumulatively increases real smelter output")
	var persisted := GameState.new()
	persisted.completed_technologies = ["infinite_optimization"]
	persisted.technology_levels = {"infinite_optimization": 2}
	var restored := GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(persisted))))
	_expect(restored is GameState and _iron_output_from_state(restored, 0.49) == 1.0, "loaded infinite technology levels continue to affect real production")

func _test_extraction_boundaries() -> void:
	var state := GameState.new()
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "miner", "miner", {"output_item": "iron_ore", "output_buffer": {"iron_ore": 61.0}})
	var site_before := float(state.resource_sites[state.buildings["miner"]["resource_site_id"]]["remaining"])
	ProductionSystem.new(state).update(1.0)
	_expect(state.buildings["miner"].get("status") == "blocked" and float(state.resource_sites[state.buildings["miner"]["resource_site_id"]]["remaining"]) == site_before, "over-capacity output blocks without negative production or reserve increase")
	state.buildings["miner"].erase("resource_site_id")
	state.buildings["miner"]["output_buffer"] = {}
	ProductionSystem.new(state).update(1.0)
	_expect(state.buildings["miner"].get("status") == "invalid_resource_site", "unbound extractors cannot produce for free")
	state.buildings["miner"]["power_efficiency"] = 0.0
	state.buildings["miner"]["output_buffer"] = {"iron_ore": 60.0}
	ProductionSystem.new(state).update(1.0)
	_expect(state.buildings["miner"].get("status") == "invalid_resource_site", "invalid binding has priority over no-power and full-buffer states")

func _test_colonized_planets_simulate_without_multiplying_global_time() -> void:
	var state := GameState.new()
	_prepare_frost(state)
	_add_building(state, "home_generator", "power_generator", {"planet_id": "home", "input_buffer": {"coal": 1.0}})
	_add_building(state, "home_generator_backup", "power_generator", {"planet_id": "home", "input_buffer": {"coal": 1.0}})
	_add_building(state, "home_smelter", "smelter", {"planet_id": "home", "recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 2.0}})
	_add_building(state, "home_lab", "matrix_lab", {"planet_id": "home"})
	_add_building(state, "frost_generator", "power_generator", {"planet_id": "frost", "input_buffer": {"coal": 1.0}})
	_add_building(state, "frost_smelter", "smelter", {"planet_id": "frost", "recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 2.0}})
	state.planet_inventory["matrix_science_1"] = 5.0
	_expect(TechnologySystem.new(state).start_research("factory_foundations"), "multi-planet fixture starts paid research from the active tray")
	state.exploration_missions = [{"system_id": "neutron", "progress": 0.0, "duration_seconds": 42.0}]
	var engine := SimulationEngine.new(state)
	_run_seconds(engine, 2.0)
	_expect(float(state.buildings["home_smelter"]["output_buffer"].get("iron_ingot", 0.0)) == 2.0, "active planet production advances for 120 fixed ticks")
	_expect(float(state.buildings["frost_smelter"]["output_buffer"].get("iron_ingot", 0.0)) == 2.0, "non-active planet production advances for 120 fixed ticks")
	_expect(is_equal_approx(state.elapsed_time, 2.0), "elapsed time advances once per fixed tick across two planets")
	_expect(is_equal_approx(state.get_technology_progress("factory_foundations"), 2.0), "global research advances once per fixed tick across two planets")
	_expect(is_equal_approx(float(state.exploration_missions[0]["progress"]), 2.0), "global exploration advances once per fixed tick across two planets")
	_expect(engine.statistics_system.get_history_size() == 2, "statistics seals one global sample per simulated second")

func _test_handcraft_delivery_keeps_queued_planet() -> void:
	var state := GameState.new()
	_prepare_frost(state)
	state.set_active_planet("frost")
	state.planet_inventory["iron_ingot"] = 1.0
	var handcraft := HandcraftSystem.new(state)
	var queued := handcraft.queue_craft("handcraft_gear", 1)
	_expect(queued.get("ok", false) and state.handcraft_queue[0].get("planet_id") == "frost", "handcraft captures frost when the job is queued")
	state.set_active_planet("home")
	_run_seconds(SimulationEngine.new(state), 0.5)
	_expect(float(state.get_planet_inventory("frost").get("gear", 0.0)) == 1.0, "completed handcraft output enters the queued frost tray")
	_expect(float(state.get_planet_inventory("home").get("gear", 0.0)) == 0.0, "completed frost handcraft output never enters the active home tray")

func _iron_output_after_seconds(completed: Array, levels: Dictionary, seconds: float) -> float:
	var state := GameState.new()
	state.completed_technologies = completed.duplicate()
	state.technology_levels = levels.duplicate(true)
	return _iron_output_from_state(state, seconds)

func _iron_output_from_state(state: GameState, seconds: float) -> float:
	_add_building(state, "solar", "solar_panel")
	_add_building(state, "smelter", "smelter", {"recipe_id": "iron_ingot_recipe", "speed": 2.0, "input_buffer": {"iron_ore": 10.0}})
	_run_seconds(SimulationEngine.new(state), seconds)
	return float(state.buildings["smelter"].get("output_buffer", {}).get("iron_ingot", 0.0))

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
	building["planet_id"] = String(building.get("planet_id", "home"))
	if String(definition.get("kind", "")) == "extractor":
		PlanetSystem.new(state).initialize_colonized_resource_sites()
		var output_item := String(building.get("output_item", definition.get("extraction", {}).get("item_id", "")))
		for site_id in state.resource_sites:
			var site: Dictionary = state.resource_sites[site_id]
			if String(site.get("planet_id", "")) == String(building["planet_id"]) and String(site.get("item_id", "")) == output_item:
				building["resource_site_id"] = site_id
				break
	state.buildings[id] = building

func _add_connection(state: GameState, id: String, source_id: String, target_id: String, flow_rate: float, item_id: String = "iron_ore") -> void:
	state.connections[id] = {
		"id": id,
		"source_id": source_id,
		"target_id": target_id,
		"planet_id": String(state.buildings[source_id].get("planet_id", "home")),
		"item_id": item_id,
		"flow_rate": flow_rate,
		"enabled": true,
		"active": false,
		"current_flow": 0.0,
	}

func _prepare_frost(state: GameState) -> void:
	state.explored_system_ids.append("borealis")
	state.colonized_planet_ids.append("frost")
	state.planet_inventories["frost"] = {}
	state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["frost"] = {}

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
