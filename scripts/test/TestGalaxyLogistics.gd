extends Node

var _failures := 0

func _ready() -> void:
	_test_schema_v6_defaults()
	_test_catalog_is_strict_and_deterministic()
	_test_v5_migration_is_lossless()
	_test_v6_ownership_and_validator_boundaries()
	_test_planet_commands_are_atomic()
	_test_resource_sites_bind_and_deplete()
	_test_planet_boundaries_preserve_state()
	_test_resource_site_ties_and_terminal_depletion()
	if _failures > 0:
		printerr("GALAXY LOGISTICS TESTS FAILED")
		get_tree().quit(1)
		return
	print("GALAXY LOGISTICS TESTS PASSED")
	get_tree().quit(0)

func _test_schema_v6_defaults() -> void:
	var state := GameState.new()
	_expect(GameState.SCHEMA_VERSION == 6, "planet saves use schema v6")
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

func _prepare_ashen(state: GameState) -> void:
	state.colonized_planet_ids.append("ashen")
	state.planet_inventories["ashen"] = {}
	state.planet_viewports["ashen"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["ashen"] = {}

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

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures += 1
	printerr("FAIL: %s" % description)
