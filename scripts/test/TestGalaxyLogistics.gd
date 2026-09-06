extends Node

var _failures := 0

func _ready() -> void:
	var station_tests := preload("res://scripts/test/StationLogisticsRegression.gd").new()
	add_child(station_tests)
	_failures += await station_tests.run()
	station_tests.queue_free()
	var final_review_tests := preload("res://scripts/test/FinalReviewRegression.gd").new()
	add_child(final_review_tests)
	_failures += await final_review_tests.run()
	final_review_tests.queue_free()
	_test_schema_v6_defaults()
	_test_catalog_is_strict_and_deterministic()
	_test_v5_migration_is_lossless()
	_test_v6_ownership_and_validator_boundaries()
	_test_planet_commands_are_atomic()
	_test_resource_sites_bind_and_deplete()
	_test_planet_boundaries_preserve_state()
	_test_resource_site_ties_and_terminal_depletion()
	_test_power_and_belt_boundaries_are_planet_local()
	_test_exploration_update_advances_each_mission_once()
	_test_exploration_transactions_are_atomic_and_fixed_time()
	_test_galaxy_search_and_summaries_are_read_only()
	_test_objectives_read_only_the_active_planet_inventory()
	_test_input_handler_routes_connection_through_active_planet_boundary()
	await _test_main_travel_restores_camera_and_cleans_canvas_state()
	if _failures > 0:
		printerr("GALAXY LOGISTICS TESTS FAILED")
		get_tree().quit(1)
		return
	print("GALAXY LOGISTICS TESTS PASSED")
	get_tree().quit(0)

func _test_schema_v6_defaults() -> void:
	var state := GameState.new()
	_expect(GameState.SCHEMA_VERSION == 9, "planet saves use schema v9")
	_expect(state.active_planet_id == "home", "home starts active")
	_expect(state.explored_system_ids == ["helios"], "helios starts explored")
	_expect(state.colonized_planet_ids == ["home"], "home starts colonized")
	_expect(state.planet_inventories.has("home"), "home tray exists")
	_expect(state.planet_inventory == state.get_active_planet_inventory(), "compatibility tray mirrors active planet")

func _test_catalog_is_strict_and_deterministic() -> void:
	var state := GameState.new()
	var galaxy := GalaxySystem.new(state)
	_expect(galaxy.get_catalog_errors().is_empty(), "shipped galaxy catalog is valid")
	_expect(galaxy.get_all_system_ids() == ["borealis", "helios", "neutron"], "system ids are stable and sorted")
	_expect(galaxy.get_all_planet_ids() == ["ashen", "boreal_giant", "frost", "giant", "home", "magnetar"], "six planet ids are stable")
	var first := galaxy.build_resource_sites_for_planet("home", 240721)
	var same := galaxy.build_resource_sites_for_planet("home", 240721)
	var changed := galaxy.build_resource_sites_for_planet("home", 240722)
	_expect(first == same, "same seed creates identical reserves")
	_expect(_has_changed_finite_reserve(first, changed), "a different seed changes a finite reserve")
	var copied_planet := galaxy.get_planet("home")
	copied_planet["name"] = "mutated"
	copied_planet["resource_sites"][0]["id"] = "mutated_site"
	_expect(galaxy.get_planet("home").get("name") == "澄海 I" and galaxy.get_planet("home").get("resource_sites", [])[0].get("id") == "home_iron_1", "catalog query returns a deep copy")
	_test_invalid_catalog_errors(state)

func _test_invalid_catalog_errors(state: GameState) -> void:
	var cases := [
		{"name": "duplicate", "catalog": {"systems": [{"id": "helios", "distance_ly": 0, "planet_ids": []}, {"id": "helios", "distance_ly": 0, "planet_ids": []}], "planets": []}, "code": "duplicate_system_id"},
		{"name": "item", "catalog": {"systems": [{"id": "helios", "distance_ly": 0, "planet_ids": [], "exploration_cost": [{"item_id": "missing", "amount": 1}]}], "planets": []}, "code": "unknown_item_reference"},
		{"name": "tech", "catalog": {"systems": [{"id": "helios", "distance_ly": 0, "planet_ids": [], "required_technology_id": "missing"}], "planets": []}, "code": "unknown_technology_reference"},
		{"name": "prerequisite", "catalog": {"systems": [{"id": "helios", "distance_ly": 0, "planet_ids": [], "prerequisite_system_id": "missing"}], "planets": []}, "code": "unknown_prerequisite_system"},
		{"name": "distance", "catalog": {"systems": [{"id": "helios", "distance_ly": -1, "planet_ids": []}], "planets": []}, "code": "invalid_distance"},
		{"name": "cost", "catalog": {"systems": [{"id": "helios", "distance_ly": 0, "planet_ids": [], "exploration_cost": [{"item_id": "iron_ore", "amount": -1}]}], "planets": []}, "code": "invalid_cost"},
	]
	for case_value in cases:
		var case_data: Dictionary = case_value
		var path := "res://.godot/galaxy_catalog_%s_%d.json" % [case_data["name"], Time.get_ticks_usec()]
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(case_data["catalog"]))
		file.close()
		var invalid := GalaxySystem.new(state, path)
		_expect(_catalog_has_error(invalid.get_catalog_errors(), String(case_data["code"])), "catalog rejects %s with a stable error" % case_data["name"])

func _test_v5_migration_is_lossless() -> void:
	var v5_payload := {
		"schema_version": 5,
		"next_id": 4,
		"elapsed_time": 12.5,
		"planet_inventory": {"iron_ore": 7.0},
		"construction_inventory": {}, "cursor_payload": {"item_id": "", "amount": 0.0},
		"handcraft_queue": [{"id": "craft_3", "recipe_id": "handcraft_miner", "quantity_total": 1, "quantity_remaining": 1, "progress": 0.0}],
		"completed_technologies": [], "research_current_id": "", "research_queue": [], "research_progress": {}, "research_invested_costs": {}, "research_paused": false, "research_queue_wait_reason": "", "technology_levels": {},
		"completed_objective_ids": [], "claimed_progression_reward_ids": [], "completed_achievement_ids": [], "unlocked_progression_ids": [],
		"buildings": {"building_1": {"id": "building_1", "type": "miner", "position": {"x": 0.0, "y": 0.0}, "recipe_id": "", "input_buffer": {}, "output_buffer": {}, "output_item": "iron_ore"}, "building_2": {"id": "building_2", "type": "smelter", "position": {"x": 1.0, "y": 0.0}, "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}}},
		"connections": {"connection_2": {"id": "connection_2", "source_id": "building_1", "target_id": "building_2", "type": "conveyor_belt_mk1", "item_id": "iron_ore", "enabled": true}}
	}
	var result := SaveMigrationRegistry.migrate_to_current(v5_payload)
	_expect(result["ok"], "v5 save migrates")
	if not result["ok"]:
		return
	var data: Dictionary = result["data"]
	_expect(data["planet_inventories"]["home"] == v5_payload["planet_inventory"], "legacy tray moves to home")
	_expect(not data.has("planet_inventory"), "v6 does not persist the compatibility alias")
	_expect(data["buildings"]["building_1"]["planet_id"] == "home", "legacy building belongs to home")
	_expect(data["connections"]["connection_2"]["planet_id"] == "home", "legacy belt belongs to home")
	_expect(data["handcraft_queue"][0]["planet_id"] == "home", "legacy handcraft job belongs to home")
	_expect(data["next_id"] == v5_payload["next_id"], "migration preserves the next stable id")
	var decoded := GameStateCodec.from_persistent_dict(data)
	var encoded := GameStateCodec.to_persistent_dict(decoded)
	_expect(encoded == data, "v6 migration survives decode and encode without loss")
	_expect(not encoded.has("planet_inventory"), "round trip does not persist compatibility alias")

func _test_v6_ownership_and_validator_boundaries() -> void:
	var handcraft_state := GameState.new()
	handcraft_state.planet_inventory = {"iron_ingot": 2.0, "gear": 1.0}
	_prepare_ashen(handcraft_state)
	var queued := HandcraftSystem.new(handcraft_state).queue_craft("handcraft_miner", 1)
	_expect(queued.get("ok", false), "home handcraft fixture queues one job")
	handcraft_state.set_active_planet("ashen")
	_expect(handcraft_state.handcraft_queue[0].get("planet_id", "") == "home", "handcraft ownership is captured when queued")
	_expect(GameStateCodec.to_persistent_dict(handcraft_state)["handcraft_queue"][0].get("planet_id", "") == "home", "saving does not rewrite a handcraft job to the active planet")

	var connection_state := GameState.new()
	_prepare_ashen(connection_state)
	var source := connection_state.add_building({"type": "miner", "planet_id": "ashen", "position": Vector2.ZERO, "recipe_id": "", "input_buffer": {}, "output_buffer": {}, "output_item": "iron_ore"})
	var target := connection_state.add_building({"type": "smelter", "planet_id": "ashen", "position": Vector2(20, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}})
	var connected := connection_state.try_add_connection(source, target)
	_expect(connected.get("ok", false), "same non-active planet endpoints can be connected")
	_expect(connection_state.connections.get(connected.get("id", ""), {}).get("planet_id", "") == "ashen", "new connection keeps its endpoints planet")

	var resource_state := GameState.new()
	resource_state.resource_sites = GalaxySystem.new(resource_state).build_resource_sites_for_planet("home", resource_state.galaxy_seed)
	var forged_payload := GameStateCodec.to_persistent_dict(resource_state)
	forged_payload["resource_sites"]["forged_iron"] = {"id": "forged_iron", "planet_id": "home", "item_id": "iron_ore", "position": {"x": 0.0, "y": 0.0}, "capacity": 1, "remaining": 1, "infinite": false}
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(forged_payload)).has("invalid_resource_site"), "validator rejects a forged catalog resource site")

	var viewport_payload := GameStateCodec.to_persistent_dict(GameState.new())
	viewport_payload["planet_viewports"]["home"]["zoom"]["x"] = 0.0
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(viewport_payload)).has("invalid_planet_viewport"), "validator rejects a zero viewport zoom")

	var exploration_payload := GameStateCodec.to_persistent_dict(GameState.new())
	exploration_payload["exploration_missions"] = [{"system_id": "helios", "progress": 1.0, "duration_seconds": 1.0}]
	exploration_payload["survey_progress_by_system"] = {"unknown": 0.5}
	var exploration_errors := _error_codes(GameStateValidator.validate_persistent_dict(exploration_payload))
	_expect(exploration_errors.has("invalid_exploration_mission"), "validator rejects exploration missions for explored systems")
	_expect(exploration_errors.has("invalid_survey_progress"), "validator rejects survey progress for unknown systems")

func _test_planet_commands_are_atomic() -> void:
	var state := GameState.new()
	var planets := PlanetSystem.new(state)
	_expect(planets.try_colonize_planet("unknown").get("reason") == "unknown_planet", "unknown planets have a stable rejection")
	_expect(planets.try_colonize_planet("frost").get("reason") == "system_locked", "unexplored systems are locked")
	state.explored_system_ids.append("borealis")
	_expect(planets.try_colonize_planet("frost").get("reason") == "technology_locked", "planet technology gates colonization")
	state.completed_technologies.append("interstellar_logistics")
	state.planet_inventory = {"titanium_alloy": 2.0}
	var before_vehicle := GameStateCodec.state_digest_payload(state)
	_expect(planets.try_colonize_planet("frost").get("reason") == "missing_vehicle", "vehicle shortages have a stable rejection")
	_expect(GameStateCodec.state_digest_payload(state) == before_vehicle, "vehicle rejection leaves every persisted field unchanged")
	state.portable_fleet["logistics_vessel"] = 1.0
	state.planet_inventory = {}
	_expect(planets.try_colonize_planet("frost").get("reason") == "missing_materials", "active planet materials pay colonization costs")
	state.planet_inventory = {"titanium_alloy": 2.0}
	var fleet_before := float(state.portable_fleet["logistics_vessel"])
	var colonize: Dictionary = planets.try_colonize_planet("frost")
	_expect(colonize["ok"], "ready planet colonizes")
	_expect(state.colonized_planet_ids.has("frost"), "target becomes colonized")
	_expect(state.planet_inventories.has("frost"), "target tray initializes")
	_expect(state.planet_viewports.has("frost"), "target viewport initializes")
	_expect(float(state.portable_fleet["logistics_vessel"]) == fleet_before - 1.0, "vehicle is charged once")
	_expect(planets.try_colonize_planet("frost").get("reason") == "already_colonized", "colonized planets cannot be colonized twice")
	_expect(planets.try_set_active_planet("ashen").get("reason") == "not_colonized", "uncolonized planets cannot become active")
	_expect(planets.try_set_active_planet("frost")["ok"], "colonized target becomes active")
	_expect(state.active_planet_id == "frost", "authority records the active planet")

func _test_resource_sites_bind_and_deplete() -> void:
	var state := GameState.new()
	var planets := PlanetSystem.new(state)
	planets.initialize_colonized_resource_sites()
	state.explored_system_ids.append("borealis")
	state.completed_technologies.append("interstellar_logistics")
	state.planet_inventory = {"titanium_alloy": 2.0}
	state.portable_fleet["logistics_vessel"] = 1.0
	planets.try_colonize_planet("frost")
	var home_miner := state.add_building({"type": "miner", "planet_id": "home", "position": Vector2(-470, -250), "output_item": "iron_ore", "input_buffer": {}, "output_buffer": {}})
	_expect(planets.try_bind_extractor(home_miner, "frost_iron_1").get("reason") == "invalid_resource_site", "cross-planet resource sites cannot bind")
	_expect(planets.try_bind_extractor(home_miner, "home_copper_1").get("reason") == "resource_mismatch", "extractors only bind matching resources")
	state.resource_sites["home_iron_1"]["remaining"] = 0.0
	_expect(planets.try_bind_extractor(home_miner, "home_iron_1").get("reason") == "resource_depleted", "empty finite sites reject bindings")
	state.resource_sites["home_iron_1"]["remaining"] = 1.0
	_expect(planets.try_bind_extractor(home_miner, "home_iron_1")["ok"], "matching live resource sites bind")
	var production := ProductionSystem.new(state)
	var before := float(state.resource_sites["home_iron_1"]["remaining"])
	var output_before := float(state.buildings[home_miner]["output_buffer"].get("iron_ore", 0.0))
	production.update(60.0)
	var produced := float(state.buildings[home_miner]["output_buffer"].get("iron_ore", 0.0)) - output_before
	_expect(is_equal_approx(float(state.resource_sites["home_iron_1"]["remaining"]), before - produced), "actual output depletes the reserve")
	_expect(float(state.resource_sites["home_iron_1"]["remaining"]) >= 0.0, "reserve never becomes negative")
	var water_miner := state.add_building({"type": "miner", "planet_id": "home", "position": Vector2(0, -360), "output_item": "water", "input_buffer": {}, "output_buffer": {}})
	_expect(planets.try_bind_extractor(water_miner, "home_water_1")["ok"], "infinite water sites bind")
	var water_before := float(state.resource_sites["home_water_1"]["remaining"])
	production.update(60.0)
	_expect(float(state.resource_sites["home_water_1"]["remaining"]) == water_before, "infinite water remains unchanged after production")

func _test_planet_boundaries_preserve_state() -> void:
	var state := GameState.new()
	var before_sites := state.resource_sites.duplicate(true)
	var planets := PlanetSystem.new(state)
	_expect(state.resource_sites == before_sites, "constructing PlanetSystem is read-only")
	state.explored_system_ids.append("borealis")
	state.completed_technologies.append("interstellar_logistics")
	state.planet_inventory = {"titanium_alloy": 2.0}
	var inventories_before := state.planet_inventories.duplicate(true)
	var active_before := state.planet_inventory.duplicate(true)
	_expect(planets.try_colonize_planet("frost").get("reason") == "missing_vehicle", "missing vehicle still rejects colonization")
	_expect(state.planet_inventories == inventories_before and state.planet_inventory == active_before, "failed colonization does not synchronize or mutate either tray view")
	state.colonized_planet_ids.append("frost")
	state.planet_inventories["frost"] = {}
	state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.explored_system_ids.erase("borealis")
	var active_digest := GameStateCodec.state_digest_payload(state)
	_expect(planets.try_set_active_planet("frost").get("reason") == "system_locked", "active switching respects explored systems")
	_expect(GameStateCodec.state_digest_payload(state) == active_digest, "locked active switching leaves state unchanged")

func _test_resource_site_ties_and_terminal_depletion() -> void:
	var state := GameState.new()
	var planets := PlanetSystem.new(state)
	state.resource_sites = {
		"a_site": {"id": "a_site", "planet_id": "home", "item_id": "iron_ore", "position": Vector2(-100, 0), "capacity": 2, "remaining": 2, "infinite": false},
		"b_site": {"id": "b_site", "planet_id": "home", "item_id": "iron_ore", "position": Vector2(100, 0), "capacity": 2, "remaining": 2, "infinite": false},
	}
	_expect(planets.find_nearest_resource_site("home", "iron_ore", Vector2.ZERO).get("id", "") == "a_site", "equal-distance compatible sites choose the smaller stable ID")
	var miner := state.add_building({"type": "miner", "planet_id": "home", "position": Vector2.ZERO, "output_item": "iron_ore", "resource_site_id": "a_site", "input_buffer": {}, "output_buffer": {}})
	state.resource_sites["a_site"]["remaining"] = 0.01
	var production := ProductionSystem.new(state)
	production.update(60.0)
	var output_after_depletion := float(state.buildings[miner]["output_buffer"].get("iron_ore", 0.0))
	production.update(60.0)
	_expect(state.buildings[miner].get("status", "") == "resource_depleted" and float(state.resource_sites["a_site"]["remaining"]) == 0.0 and float(state.buildings[miner]["output_buffer"].get("iron_ore", 0.0)) == output_after_depletion, "a second depleted tick is stable and produces nothing")

func _test_power_and_belt_boundaries_are_planet_local() -> void:
	var state := GameState.new()
	_prepare_frost(state)
	var home_generator := state.add_building({"type": "power_generator", "planet_id": "home", "position": Vector2.ZERO, "input_buffer": {"coal": 1.0}, "output_buffer": {}})
	var home_smelter := state.add_building({"type": "smelter", "planet_id": "home", "position": Vector2(20, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}})
	var frost_smelter := state.add_building({"type": "smelter", "planet_id": "frost", "position": Vector2(40, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}})
	var power := PowerSystem.new(state)
	power.update(1.0 / 60.0)
	_expect(float(state.buildings[home_smelter]["power_efficiency"]) > 0.0, "home generator powers home")
	_expect(float(state.buildings[frost_smelter]["power_efficiency"]) == 0.0, "home power does not cross planets")
	var supports_planet_query := _method_argument_count(power, "get_power_info") == 1
	_expect(supports_planet_query, "power summaries accept an explicit planet query")
	if supports_planet_query:
		var home_power: Dictionary = power.call("get_power_info", "home")
		var frost_power: Dictionary = power.call("get_power_info", "frost")
		_expect(float(home_power["generation"]) == 500.0 and float(frost_power["generation"]) == 0.0, "power summaries can query each planet explicitly")

	var belt_pieces_before := float(state.construction_inventory["conveyor_belt_mk1"])
	var next_id_before: int = state.get("_next_id")
	var belts := BeltSystem.new(state)
	_expect(belts.create_belt(home_smelter, frost_smelter, "iron_ingot") == "", "belt command rejects a cross-planet edge")
	_expect(float(state.construction_inventory["conveyor_belt_mk1"]) == belt_pieces_before and state.connections.is_empty() and int(state.get("_next_id")) == next_id_before, "cross-planet rejection consumes no construction pieces or ids")
	var forged := state.add_connection({"source_id": home_smelter, "target_id": frost_smelter, "planet_id": "home", "item_id": "iron_ingot", "type": "conveyor_belt_mk1"})
	var payload := GameStateCodec.to_persistent_dict(state)
	_expect(_error_codes(GameStateValidator.validate_persistent_dict(payload)).has("cross_planet_connection"), "validator rejects a cross-planet edge")
	state.buildings[home_smelter]["output_buffer"] = {"iron_ingot": 1.0}
	belts.update(1.0)
	_expect(float(state.buildings[frost_smelter]["input_buffer"].get("iron_ingot", 0.0)) == 0.0, "runtime ignores a forged cross-planet edge")
	_expect(ProductionDiagnostics.new(state).get_all_diagnostics().any(func(entry): return entry.get("entity_id") == forged and entry.get("code") == "cross_planet_connection" and entry.get("building_id") == frost_smelter and entry.get("planet_id") == "frost" and entry.get("world_position") == Vector2(40, 0)), "runtime reports and locates a forged cross-planet edge on its target planet")

	state.connections.clear()
	var frost_source := state.add_building({"type": "smelter", "planet_id": "frost", "position": Vector2(60, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {"iron_ingot": 1.0}})
	var frost_target := state.add_building({"type": "assembling_machine_mk1", "planet_id": "frost", "position": Vector2(80, 0), "recipe_id": "circuit_recipe", "input_buffer": {}, "output_buffer": {}})
	_expect(belts.create_belt(frost_source, frost_target, "iron_ingot") == "", "belt command rejects endpoints outside the active planet")
	state.set_active_planet("frost")
	var legal := belts.create_belt(frost_source, frost_target, "iron_ingot")
	_expect(not legal.is_empty() and state.connections[legal].get("planet_id") == "frost", "legal belt persists the common endpoint planet")

func _test_exploration_update_advances_each_mission_once() -> void:
	var state := GameState.new()
	state.exploration_missions = [{"system_id": "borealis", "progress": 23.5, "duration_seconds": 24.0}]
	var galaxy := GalaxySystem.new(state)
	_expect(galaxy.has_method("update_exploration"), "galaxy exposes the fixed-tick exploration phase")
	if not galaxy.has_method("update_exploration"):
		return
	galaxy.call("update_exploration", 0.25)
	_expect(is_equal_approx(float(state.exploration_missions[0]["progress"]), 23.75) and is_equal_approx(float(state.survey_progress_by_system["borealis"]), 23.75 / 24.0), "galaxy phase advances an existing mission by exactly delta")
	galaxy.call("update_exploration", 0.25)
	_expect(state.exploration_missions.is_empty() and state.explored_system_ids.has("borealis") and float(state.survey_progress_by_system["borealis"]) == 1.0, "galaxy phase completes and removes a finished mission")

func _test_exploration_transactions_are_atomic_and_fixed_time() -> void:
	var contract_probe := GalaxySystem.new(GameState.new())
	var has_contract := contract_probe.has_method("get_exploration_requirements") and contract_probe.has_method("try_explore_system") and contract_probe.has_method("get_exploration_duration")
	_expect(has_contract, "galaxy exposes the exploration transaction contract")
	if not has_contract:
		return
	var unknown_state := _exploration_ready_state()
	_expect_exploration_failure_unchanged(unknown_state, "missing", "unknown_system")

	var technology_state := GameState.new()
	technology_state.planet_inventory["space_warper"] = 2.0
	technology_state.sync_active_planet_inventory()
	_expect_exploration_failure_unchanged(technology_state, "borealis", "technology_locked")

	var prerequisite_state := _exploration_ready_state()
	_expect_exploration_failure_unchanged(prerequisite_state, "neutron", "prerequisite_locked")

	var material_state := GameState.new()
	material_state.completed_technologies.append("interstellar_logistics")
	_expect_exploration_failure_unchanged(material_state, "borealis", "missing_materials")

	var running_state := _exploration_ready_state()
	running_state.exploration_missions = [{"system_id": "borealis", "progress": 1.0, "duration_seconds": 24.0}]
	running_state.survey_progress_by_system["borealis"] = 1.0 / 24.0
	_expect_exploration_failure_unchanged(running_state, "borealis", "mission_running")

	var explored_state := _exploration_ready_state()
	_expect_exploration_failure_unchanged(explored_state, "helios", "already_explored")

	var sixty_hz_state := _exploration_ready_state()
	var sixty_hz_galaxy := GalaxySystem.new(sixty_hz_state)
	var inventory_before := sixty_hz_state.planet_inventory.duplicate(true)
	var started: Dictionary = sixty_hz_galaxy.call("try_explore_system", "borealis")
	_expect(started.get("ok", false), "ready system starts surveying")
	_expect(sixty_hz_state.exploration_missions.size() == 1, "one background mission is created")
	_expect(float(sixty_hz_state.planet_inventory.get("space_warper", 0.0)) == float(inventory_before.get("space_warper", 0.0)) - 2.0, "survey charges the active planet tray exactly once")
	_expect(sixty_hz_state.planet_inventories["home"] == sixty_hz_state.planet_inventory, "survey cost keeps the active tray compatibility view synchronized")
	var repeat_digest := GameStateCodec.state_digest_payload(sixty_hz_state)
	var repeated: Dictionary = sixty_hz_galaxy.call("try_explore_system", "borealis")
	_expect(not repeated.get("ok", true) and repeated.get("reason", "") == "mission_running" and GameStateCodec.state_digest_payload(sixty_hz_state) == repeat_digest, "repeated survey requests neither charge again nor create another mission")
	var duration := float(sixty_hz_galaxy.call("get_exploration_duration", "borealis"))
	var coarse_state := _exploration_ready_state()
	var coarse_galaxy := GalaxySystem.new(coarse_state)
	coarse_galaxy.call("try_explore_system", "borealis")
	var sixty_hz_engine := SimulationEngine.new(sixty_hz_state)
	var coarse_engine := SimulationEngine.new(coarse_state)
	_run_fixed_seconds(sixty_hz_engine, duration / 2.0, 1.0 / 60.0)
	_run_fixed_seconds(coarse_engine, duration / 2.0, 5.0 / 60.0)
	_expect(is_equal_approx(float(sixty_hz_state.survey_progress_by_system["borealis"]), 0.5) and sixty_hz_state.survey_progress_by_system == coarse_state.survey_progress_by_system and sixty_hz_state.exploration_missions == coarse_state.exploration_missions, "survey progress is identical midway across different frame partitions")
	_run_fixed_seconds(sixty_hz_engine, duration / 2.0, 1.0 / 60.0)
	_run_fixed_seconds(coarse_engine, duration / 2.0, 5.0 / 60.0)
	_expect(sixty_hz_state.survey_progress_by_system == coarse_state.survey_progress_by_system and sixty_hz_state.exploration_missions == coarse_state.exploration_missions, "survey completion is identical across different frame partitions")
	_expect(sixty_hz_state.explored_system_ids.has("borealis"), "survey completes on simulation time")
	_expect(sixty_hz_state.colonized_planet_ids.has("frost"), "first planet becomes a pioneer landing")
	_expect(sixty_hz_state.planet_inventories.has("frost") and sixty_hz_state.planet_viewports.has("frost") and sixty_hz_state.planet_metrics.has("frost"), "pioneer landing creates the planet runtime records")
	_expect(sixty_hz_state.resource_sites.has("frost_iron_1"), "pioneer landing initializes catalog resource sites")

func _test_galaxy_search_and_summaries_are_read_only() -> void:
	var state := _exploration_ready_state()
	state.buildings["frost_factory"] = {"id": "frost_factory", "type": "smelter", "planet_id": "frost", "position": Vector2.ZERO}
	var galaxy := GalaxySystem.new(state)
	var has_contract := galaxy.has_method("search") and galaxy.has_method("get_system_summary") and galaxy.has_method("get_planet_summary") and _method_argument_count(galaxy, "get_system_distance") == 2
	_expect(has_contract, "galaxy exposes search, summary, and pairwise distance queries")
	if not has_contract:
		return
	var digest_before := GameStateCodec.state_digest_payload(state)
	var code_results: Dictionary = galaxy.call("search", "冰晶恒星系")
	var id_results: Dictionary = galaxy.call("search", "BOREALIS")
	var resource_results: Dictionary = galaxy.call("search", "IRON_ORE")
	var environment_results: Dictionary = galaxy.call("search", "永冻")
	_expect(code_results.get("system_ids", []) == ["borealis"] and id_results.get("system_ids", []) == ["borealis"], "search is case insensitive across system code and id")
	_expect(resource_results.get("planet_ids", []) == ["ashen", "frost", "home", "magnetar"], "resource search returns planets in stable catalog id order")
	_expect(environment_results.get("planet_ids", []) == ["frost"], "environment search matches planet type")
	var system_summary: Dictionary = galaxy.call("get_system_summary", "borealis")
	var planet_summary: Dictionary = galaxy.call("get_planet_summary", "frost")
	_expect(system_summary.get("planet_ids", []) == ["frost", "boreal_giant"] and system_summary.has("exploration"), "system summary combines catalog and exploration facts")
	_expect(planet_summary.get("resource_item_ids", []) == ["copper_ore", "iron_ore", "stone", "water"] and planet_summary.has("colonization") and planet_summary.get("industry", {}).get("building_count") == 1, "planet summary exposes resource, colonization, and industrial facts")
	if not system_summary.is_empty():
		system_summary["planet_ids"].append("mutated")
	if not planet_summary.is_empty():
		planet_summary["industry"]["inventory"]["forged"] = 1.0
	_expect(GameStateCodec.state_digest_payload(state) == digest_before, "search and summary queries do not advance missions or mutate domain state")
	_expect(not galaxy.call("get_system_summary", "borealis").get("planet_ids", []).has("mutated") and not galaxy.call("get_planet_summary", "frost").get("industry", {}).get("inventory", {}).has("forged"), "summary results are deep copies")
	_expect(is_equal_approx(float(galaxy.call("get_system_distance", "helios", "borealis")), 4.2), "system distance measures catalog positions")

func _test_objectives_read_only_the_active_planet_inventory() -> void:
	var state := GameState.new()
	_prepare_frost(state)
	state.planet_inventory["iron_ingot"] = 1.0
	state.get_planet_inventory("frost")["iron_ingot"] = 100.0
	state.add_building({"type": "storage", "planet_id": "home", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {"iron_ingot": 2.0}})
	state.add_building({"type": "storage", "planet_id": "frost", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {"iron_ingot": 100.0}})
	var progress := ObjectiveSystem.new().get_condition_progress(state, {"fact": "item_amount", "item_id": "iron_ingot", "at_least": 4.0})
	_expect(float(progress["current"]) == 3.0 and not progress["complete"], "active home objectives ignore frost tray and building buffers")

func _test_input_handler_routes_connection_through_active_planet_boundary() -> void:
	var state := GameState.new()
	_prepare_frost(state)
	var frost_source := state.add_building({"type": "smelter", "planet_id": "frost", "position": Vector2.ZERO, "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}})
	var frost_target := state.add_building({"type": "assembling_machine_mk1", "planet_id": "frost", "position": Vector2(20, 0), "recipe_id": "", "input_buffer": {}, "output_buffer": {}})
	GameManager.replace_game_state(state)
	var input_handler: Node = load("res://scripts/input/InputHandler.gd").new()
	var pieces_before := float(state.construction_inventory["conveyor_belt_mk1"])
	input_handler.call("start_connection", frost_source)
	var connected := bool(input_handler.call("complete_connection", frost_target))
	_expect(not connected, "real input handler rejects same-planet endpoints outside the active planet")
	_expect(state.connections.is_empty() and float(state.construction_inventory["conveyor_belt_mk1"]) == pieces_before and String(state.buildings[frost_target].get("recipe_id", "")).is_empty(), "input rejection preserves lines, construction pieces, and target recipe")
	input_handler.queue_free()

func _test_main_travel_restores_camera_and_cleans_canvas_state() -> void:
	var state := GameState.new()
	_prepare_frost(state)
	state.planet_inventories["home"] = {"iron_ore": 1.0}
	state.planet_inventory = state.planet_inventories["home"]
	state.planet_inventories["frost"] = {"copper_ore": 99.0}
	state.planet_viewports["home"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_viewports["frost"] = {"position": Vector2(820, 460), "zoom": Vector2(0.75, 0.75)}
	state.cursor_payload = {"item_id": "iron_ore", "amount": 7.0}
	var home_a := state.add_building({"type": "miner", "planet_id": "home", "position": Vector2(100, 100), "input_buffer": {}, "output_buffer": {}})
	var home_b := state.add_building({"type": "smelter", "planet_id": "home", "position": Vector2(500, 100), "input_buffer": {}, "output_buffer": {}})
	state.add_building({"type": "miner", "planet_id": "frost", "position": Vector2(100, 100), "input_buffer": {}, "output_buffer": {}})
	GameManager.replace_game_state(state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var camera: Camera2D = main.get_node("WorldCamera")
	var input_handler: Node = main.get_node("InputHandler")
	var workspace: Node = main.get_node("FactoryWorkspaceUI")
	camera.global_position = Vector2(320, 240)
	camera.zoom = Vector2(1.25, 1.25)
	input_handler.call("set_selected_entities", [home_a, home_b])
	input_handler.call("start_placing_card", "miner")
	input_handler.call("set_selected_entities", [home_a, home_b])
	input_handler.set("connecting_source_id", home_a)
	input_handler.set("dragging_building_id", home_a)
	input_handler.set("press_candidate_building_id", home_b)
	input_handler.set("drag_start_positions", {home_a: Vector2(100, 100)})
	input_handler.set("selection_box_start", Vector2(20, 20))
	input_handler.set("selection_box_end", Vector2(600, 300))
	var travel_events: Array[String] = []
	var has_travel_contract := main.has_method("try_travel_to_planet") and EventBus.has_signal("active_planet_changed")
	_expect(has_travel_contract, "Main and EventBus expose the unique travel loop")
	if not has_travel_contract:
		viewport.queue_free()
		await get_tree().process_frame
		return
	var observer := func(planet_id: String) -> void: travel_events.append(planet_id)
	EventBus.active_planet_changed.connect(observer)
	var cursor_before := state.cursor_payload.duplicate(true)
	var frost_result: Dictionary = main.call("try_travel_to_planet", "frost")
	_expect(frost_result.get("ok", false) and state.active_planet_id == "frost", "Main travels only through the planet domain boundary")
	_expect(state.planet_viewports["home"] == {"position": Vector2(320, 240), "zoom": Vector2(1.25, 1.25)}, "successful travel saves the old planet camera first")
	_expect(camera.global_position == Vector2(820, 460) and camera.zoom == Vector2(0.75, 0.75), "successful travel restores the target planet camera")
	_expect(input_handler.call("get_mode_name") == "idle" and input_handler.call("get_selected_entity_ids").is_empty() and String(input_handler.get("connecting_source_id")).is_empty() and String(input_handler.get("dragging_building_id")).is_empty() and input_handler.get("drag_start_positions").is_empty() and input_handler.get("selection_box_start") == Vector2.ZERO and input_handler.get("selection_box_end") == Vector2.ZERO, "successful travel cancels placement, connection, drag, marquee, and selection state")
	_expect(state.cursor_payload == cursor_before, "successful travel preserves the global cursor payload")
	workspace.call("refresh_now")
	var summary: Label = workspace.get_node("ResourceRail/Summary")
	var stock: Label = workspace.get_node("ResourceRail/Stock")
	_expect("BUILDINGS  01" in summary.text and "copper_ore 99.0" in stock.text and not "iron_ore 1.0" in stock.text, "workspace inventory and building counts project the active planet")
	_expect(travel_events == ["frost"], "successful travel emits one active-planet change after projection refresh")
	camera.global_position = Vector2(910, 510)
	camera.zoom = Vector2(0.9, 0.9)
	input_handler.call("start_placing_card", "smelter")
	var failed_camera := {"position": camera.global_position, "zoom": camera.zoom}
	var failed_digest := GameStateCodec.state_digest_payload(state)
	var failed_result: Dictionary = main.call("try_travel_to_planet", "ashen")
	_expect(not failed_result.get("ok", true) and failed_result.get("reason", "") == "not_colonized", "travel rejects an uncolonized target without implicit colonization")
	_expect(input_handler.call("get_mode_name") == "placing" and camera.global_position == failed_camera.position and camera.zoom == failed_camera.zoom and GameStateCodec.state_digest_payload(state) == failed_digest and travel_events == ["frost"], "failed travel preserves the active operation, both cameras, state digest, and event stream")
	input_handler.call("cancel_operation")
	var home_result: Dictionary = main.call("try_travel_to_planet", "home")
	_expect(home_result.get("ok", false) and camera.global_position == Vector2(320, 240) and camera.zoom == Vector2(1.25, 1.25), "return travel restores the saved home camera")
	EventBus.active_planet_changed.disconnect(observer)
	viewport.queue_free()
	await get_tree().process_frame

func _prepare_ashen(state: GameState) -> void:
	state.colonized_planet_ids.append("ashen")
	state.planet_inventories["ashen"] = {}
	state.planet_viewports["ashen"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["ashen"] = {}

func _prepare_frost(state: GameState) -> void:
	state.explored_system_ids.append("borealis")
	state.colonized_planet_ids.append("frost")
	state.planet_inventories["frost"] = {}
	state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["frost"] = {}

func _exploration_ready_state() -> GameState:
	var state := GameState.new()
	state.completed_technologies.append("interstellar_logistics")
	state.planet_inventory["space_warper"] = 7.0
	state.sync_active_planet_inventory()
	return state

func _expect_exploration_failure_unchanged(state: GameState, system_id: String, reason: String) -> void:
	var galaxy := GalaxySystem.new(state)
	var digest_before := GameStateCodec.state_digest_payload(state)
	var result: Dictionary = galaxy.call("try_explore_system", system_id)
	_expect(not result.get("ok", true) and result.get("reason", "") == reason, "exploration rejects %s with a stable reason" % reason)
	_expect(GameStateCodec.state_digest_payload(state) == digest_before, "exploration failure %s preserves the complete digest" % reason)

func _run_fixed_seconds(engine: SimulationEngine, seconds: float, frame_delta: float) -> void:
	var frame_count := roundi(seconds / frame_delta)
	for _frame in range(frame_count):
		engine.update(frame_delta)

func _has_changed_finite_reserve(first: Dictionary, changed: Dictionary) -> bool:
	for site_id in first:
		if not bool(first[site_id].get("infinite", false)) and first[site_id].get("remaining") != changed.get(site_id, {}).get("remaining"):
			return true
	return false

func _catalog_has_error(errors: Array, expected_code: String) -> bool:
	for error_value in errors:
		if error_value is Dictionary and error_value.get("code") == expected_code:
			return true
	return false

func _error_codes(errors: Array) -> Array:
	var codes: Array = []
	for error_value in errors:
		if error_value is Dictionary:
			codes.append(String(error_value.get("code", "")))
	return codes

func _method_argument_count(target: Object, method_name: String) -> int:
	for method_value in target.get_method_list():
		if String(method_value.get("name", "")) == method_name:
			return method_value.get("args", []).size()
	return -1

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
