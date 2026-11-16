extends Node

var failures := 0

func _ready() -> void:
	var source := DSPOnlineParity.read_json("res://tests/fixtures/parity/dsponline_source_catalog.json")
	var active := 0
	var deprecated := 0
	var state := GameState.new()
	var research := TechnologySystem.new(state)
	for row in source.catalog.technologies:
		var id := "dsp_" + String(row.id)
		var actual := DataManager.get_technology(id)
		check(not actual.is_empty(), "technology mapping: " + id)
		if actual.is_empty(): continue
		check(actual.get("source_id") == row.id, "stable source identity: " + id)
		if row.definition.get("deprecated", false):
			deprecated += 1
			check(actual.get("deprecated", false), "deprecated definition retained: " + id)
			check(not research.start_research(id) and not research.add_to_queue(id), "deprecated research rejected: " + id)
		else:
			active += 1
			var costs := {}
			for cost in row.definition.costs: costs[cost.itemId] = cost.amount
			check(actual.get("cost") == costs, "frozen matrix costs: " + id)
		var prerequisites: Array = row.definition.prerequisites.map(func(parent): return "dsp_" + String(parent))
		check(actual.get("prerequisites") == prerequisites, "frozen research prerequisites: " + id)
		check(actual.get("name") == row.definition.name and actual.get("description") == row.definition.summary and actual.get("unlock_descriptions") == row.definition.unlocks, "frozen technology description and unlocks: " + id)
	check(active == 69 and deprecated == 7, "complete finite technology catalog")
	_test_effects()
	_test_campaign_facts(source)
	_test_industrial_system_counts()
	_test_power_fact_persistence()
	_test_infinite_research()
	_test_infinite_lab_transaction()
	_test_infinite_gold()
	_test_source_reward_retry()
	if failures == 0: print("PROGRESSION PARITY TESTS PASSED")
	else: printerr("PROGRESSION PARITY TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("PROGRESSION PARITY: " + message)

func _test_industrial_system_counts() -> void:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721, true)
	var galaxy := GalaxySystem.new(state)
	var home_system: String = galaxy.get_planet("home").system_id
	var distant := ""
	for id in SourceGalaxySystem.catalog().planets:
		if galaxy.get_planet(id).system_id != home_system:
			distant = id
			break
	check(not distant.is_empty(), "industrial fixture contains a second stellar system")
	var metric := {"kind": "industrial-systems"}
	check(SourceProgressionFacts.value(state, metric) == 0, "empty industry has no stellar systems")
	var miner := state.add_building({"type": "dsp_mining_machine", "position": Vector2.ZERO, "planet_id": "home"})
	check(SourceProgressionFacts.value(state, metric) == 0 and SourceProgressionFacts.value(state, metric, SourceProgressionFacts.building_snapshot(state)) == 0, "vein miners alone do not count an industrial stellar system")
	state.buildings.erase(miner)
	for index in range(20): state.add_building({"type": "smelter", "position": Vector2(index * 300, 0), "planet_id": "home"})
	check(SourceProgressionFacts.value(state, metric) == 1, "many buildings on one planet count one industrial system")
	state.add_building({"type": "smelter", "position": Vector2.ZERO, "planet_id": "ashen"})
	check(SourceProgressionFacts.value(state, metric) == 1, "two planets in the same stellar system count once")
	var remote := state.add_building({"type": "smelter", "position": Vector2.ZERO, "planet_id": distant})
	check(SourceProgressionFacts.value(state, metric) == 2, "industry on a second stellar system increases the live fact")
	state.remove_building(remote)
	check(SourceProgressionFacts.value(state, metric) == 1, "removing remote industry refreshes the fact immediately")
	state.buildings.values()[0]["spray_coater_installed"] = true
	state.progression_facts["station_trips"] = {state.buildings.keys()[0]: 3}
	var snapshot := SourceProgressionFacts.building_snapshot(state)
	for query in [metric, {"kind": "building", "buildingId": "smelter"}, {"kind": "miner"}, {"kind": "spray-coater"}, {"kind": "station-trips", "buildingId": "smelter"}]:
		check(SourceProgressionFacts.value(state, query, snapshot) == SourceProgressionFacts.value(state, query), "evaluation snapshot preserves the live fact: " + query.kind)
	var evaluator := ObjectiveSystem.new()
	var facts := {}
	check(evaluator.get_condition_progress(state, {"fact": "source_metric", "metric": {"kind": "building", "buildingId": "smelter", "target": 30}}, facts).current == 21, "one evaluation shares correct building counts")
	state.add_building({"type": "smelter", "position": Vector2(0, 400), "planet_id": "home"})
	check(evaluator.get_condition_progress(state, {"fact": "source_metric", "metric": {"kind": "building", "buildingId": "smelter", "target": 30}}, {}).current == 22, "next evaluation does not reuse stale building counts")

func _test_power_fact_persistence() -> void:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721, true)
	state.add_building({"type": "dsp_wind_turbine", "position": Vector2.ZERO})
	state.add_building({"type": "dsp_wind_turbine", "position": Vector2(800, 0)})
	state.add_building({"type": "dsp_arc_smelter", "position": Vector2(400, 0), "recipe_id": "dsp_iron_ingot", "input_buffer": {"iron_ore": 1.0}})
	var power := PowerSystem.new(state)
	power.update(0.0)
	var metric := {"kind": "power", "requireGeneration": true}
	check(SourceProgressionFacts.value(state, metric) == 1, "actual funded load records stable power")
	var disk := SaveSystem.new("res://.godot/progression-power-%d/" % Time.get_ticks_usec())
	var saved := disk.save_slot(0, state)
	var loaded := disk.load_slot(0) if saved.ok else {}
	check(saved.ok and loaded.get("ok", false), "cached power fact passes actual disk save/load")
	if loaded.get("ok", false):
		check(SourceProgressionFacts.value(loaded.state, metric) == 1, "power query survives reload before the next simulation tick")
	state.buildings.clear()
	power.update(0.0)
	check(SourceProgressionFacts.value(state, metric) == 0, "next power update clears the cached fact after all loads are removed")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.planet_metrics.home.power.efficiency = 2.0
	check(GameStateCodec.from_persistent_dict(corrupt) == null, "invalid persisted power efficiency is rejected")

func _test_effects() -> void:
	var state := GameState.new()
	for id in ["mining_speed_1", "mining_speed_2", "mining_speed_3", "research_speed_1", "research_speed_2", "research_speed_3", "logistics_engine_1", "logistics_engine_2", "logistics_capacity_1", "logistics_capacity_2", "solar_sail_life_1", "solar_sail_life_2", "ray_transmission_1", "ray_transmission_2", "dyson_absorption_1"]:
		state.completed_technologies.append("dsp_" + id)
	check(state.get_technology_effect_multiplier("mining_speed") == 3.0, "mining tiers select highest speed rather than multiply tiers")
	check(state.get_technology_effect_multiplier("research_speed") == 1.75, "research upgrades add 25 percent each")
	for effect in ["logistics_speed", "logistics_capacity", "sail_lifetime", "ray_capacity", "sail_absorption"]:
		check(state.get_technology_effect_multiplier(effect) == 2.0, "frozen effect: " + effect)
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and restored.get_technology_effect_multiplier("research_speed") == 1.75, "effects survive save round trip")

func _test_campaign_facts(source: Dictionary) -> void:
	var catalog := ObjectiveSystem.load_catalog()
	check(source.catalog.campaign.size() == 32 and source.catalog.achievements.size() == 13, "frozen progression counts")
	for category in ["campaign", "achievements"]:
		var rows: Array = catalog.objectives if category == "campaign" else catalog.achievements
		for original in source.catalog[category]:
			var matches := rows.filter(func(row): return row.get("source_id") == original.id)
			check(matches.size() == 1, "unique progression mapping: " + original.id)
			if matches.size() == 1 and category == "campaign":
				var row: Dictionary = matches[0]
				check(row.get("condition", {}).get("metric") == original.definition.metric, "frozen task domain metric: " + original.id)
				check(row.get("navigation", {}) == original.definition.get("navigation", {}), "frozen task navigation: " + original.id)
				check(row.get("prerequisites", []) == original.definition.get("prerequisites", []).map(func(parent): return "dsp_" + String(parent)), "frozen task prerequisites: " + original.id)
	var state := GameState.new()
	state.planet_inventory["electromagnetic_matrix"] = 50
	check(SourceProgressionFacts.value(state, {"kind": "produced", "itemId": "electromagnetic_matrix"}) == 0, "initial inventory never counts as production")
	SourceProgressionFacts.record_produced(state, "electromagnetic_matrix", 1)
	ProgressionSystem.new(state).evaluate()
	check(state.completed_achievement_ids.has("dsp_electromagnetic_matrix_online"), "actual production unlocks matrix achievement")
	var once := state.claimed_progression_reward_ids.duplicate()
	ProgressionSystem.new(state).evaluate()
	check(once == state.claimed_progression_reward_ids, "source achievements are idempotent")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and restored.progression_facts == state.progression_facts, "cumulative facts survive persistence")
	var invalid := GameStateCodec.to_persistent_dict(state)
	invalid.progression_facts.produced.electromagnetic_matrix = -1
	check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "negative cumulative facts rejected")
	var fresh := GameState.new()
	PlanetSystem.new(fresh).initialize_colonized_resource_sites()
	var found := false
	for site in fresh.resource_sites.values():
		if site.item_id == "iron_ore":
			found = true
			var before := float(site.remaining)
			check(SourceProgressionFacts.mine(fresh, site.id).ok, "manual mining commits real inventory and reserve")
			check(float(fresh.progression_facts.manual_mined) == 1 and float(site.remaining) == before - 1, "manual mining is a resource transaction")
			ProgressionSystem.new(fresh).evaluate()
			check(fresh.completed_objective_ids.has("dsp_mine_first_ore"), "real manual mining completes source objective")
			break
	check(found, "home planet exposes an iron ore site for manual mining")

func _test_infinite_research() -> void:
	check(DecimalCount.add("99999999999999999999999", "1") == "100000000000000000000000", "decimal carry exceeds int64 without loss")
	check(DecimalCount.subtract("100000000000000000000000", "1") == "99999999999999999999999", "decimal subtraction stays exact")
	var state := GameState.new()
	var infinite := InfiniteResearchSystem.new(state)
	check(not infinite.select("matrix_compression"), "infinite research requires universe technology")
	state.completed_technologies.append("dsp_universe_matrix")
	check(infinite.select("matrix_compression"), "infinite research can be selected after unlock")
	check(infinite.cost("matrix_compression") == "250", "first frozen infinite cost")
	check(infinite.pause(true) and not infinite.invest_one(), "paused infinite research consumes nothing")
	infinite.pause(false)
	for index in range(249): check(infinite.invest_one(), "incremental investment accepted")
	check(infinite.level("matrix_compression") == 0 and infinite.invested("matrix_compression") == "249", "boundary does not complete early")
	var restored := GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state))))
	check(restored != null and InfiniteResearchSystem.new(restored).invested("matrix_compression") == "249", "partial exact investment round trips")
	check(infinite.invest_one() and infinite.level("matrix_compression") == 1 and infinite.active().is_empty(), "last matrix completes exactly once and stops without auto")
	check(infinite.cost("matrix_compression") == "390", "next layer follows frozen nonlinear curve")
	check(is_equal_approx(state.get_technology_effect_multiplier("production_speed"), 1.04), "infinite level changes production effect")
	state.progression_facts.infinite_research["matrix_compression"] = {"level": 999, "invested": "0"}
	var final_cost := infinite.cost("matrix_compression")
	state.progression_facts.infinite_research.matrix_compression.invested = DecimalCount.subtract(final_cost, "1")
	check(infinite.select("matrix_compression", true) and infinite.invest_one(), "large final cost settles with exact last matrix")
	check(infinite.level("matrix_compression") == 1000 and infinite.active().is_empty() and not infinite.select("matrix_compression"), "maximum level cannot restart")
	check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "max-level exact state validates")

func _test_infinite_gold() -> void:
	var fixture := DSPOnlineParity.read_json("res://tests/fixtures/parity/behavior/task25-infinite-costs.json")
	var imported := DSPOnlineParity.read_json("res://data/infinite_research.json")
	check(fixture.sha256 == imported.source_files[fixture.source_file], "cost gold matches imported source hash")
	var state := GameState.new()
	var infinite := InfiniteResearchSystem.new(state)
	for row in fixture.cases:
		state.progression_facts["infinite_research"] = {String(row.id): {"level": int(row.level), "invested": "0"}}
		check(infinite.cost(row.id) == row.cost, "frozen exact cost: %s Lv.%d" % [row.id, row.level])

func _test_infinite_lab_transaction() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_universe_matrix")
	var infinite := InfiniteResearchSystem.new(state)
	var tech := TechnologySystem.new(state)
	check(infinite.select("matrix_compression"), "lab test selects unlocked infinite research")
	var lab := state.add_building({"type": "dsp_matrix_lab", "position": Vector2.ZERO, "recipe_id": "dsp_matrix_research", "input_buffer": {}, "output_buffer": {}, "progress": 0.0, "speed": 1.0})
	state.buildings[lab].power_requested = 480.0
	state.buildings[lab].power_efficiency = 1.0
	state.planet_inventory["universe_matrix"] = 2.0
	state.sync_active_planet_inventory()
	check(tech.supply_source_lab(lab).ok and state.planet_inventory.get("universe_matrix", 0) == 0, "infinite matrices move from planet stock into physical lab")
	tech.update_source_labs(3.0)
	check(infinite.invested("matrix_compression") == "1" and state.buildings[lab].input_buffer.universe_matrix == 1, "powered lab consumes exactly one universe matrix per completed research cycle")
	check(infinite.pause(true), "infinite lab target can be paused")
	tech.update_source_labs(100)
	check(infinite.invested("matrix_compression") == "1" and state.buildings[lab].input_buffer.universe_matrix == 1, "paused infinite lab consumes no matrix")
	check(infinite.pause(false), "infinite lab target can resume")
	tech.update_source_labs(3.0)
	check(infinite.invested("matrix_compression") == "2" and state.buildings[lab].input_buffer.get("universe_matrix", 0) == 0, "resumed infinite lab consumes one more matrix")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and InfiniteResearchSystem.new(restored).invested("matrix_compression") == "2", "lab investment survives save round trip")

func _test_source_reward_retry() -> void:
	var state := GameState.new()
	var objective: Dictionary = {}
	for row in ObjectiveSystem.load_catalog().objectives:
		if row.id == "dsp_mine_first_ore": objective = row
	check(not objective.is_empty(), "source reward test has frozen first task")
	state.progression_facts["manual_mined"] = 1
	state.construction_inventory["conveyor_belt_mk1"] = GameState.construction_capacity("conveyor_belt_mk1")
	var catalog := {"chapters": [{"id": "source", "objective_ids": ["dsp_mine_first_ore"]}], "objectives": [objective], "achievements": []}
	var progression := ProgressionSystem.new(state, catalog)
	var first := progression.evaluate()
	check(state.completed_objective_ids.has("dsp_mine_first_ore") and first.blocked_reward_ids.has("objective:dsp_mine_first_ore"), "source task completes even while its reward is blocked")
	check(not state.claimed_progression_reward_ids.has("objective:dsp_mine_first_ore"), "blocked reward is not claimed")
	state.construction_inventory["conveyor_belt_mk1"] -= 2
	progression.evaluate()
	check(state.claimed_progression_reward_ids.has("objective:dsp_mine_first_ore") and state.construction_inventory.conveyor_belt_mk1 == GameState.construction_capacity("conveyor_belt_mk1"), "reward pays once after stock space becomes available")
	progression.evaluate()
	check(state.construction_inventory.conveyor_belt_mk1 == GameState.construction_capacity("conveyor_belt_mk1"), "re-evaluation never double pays source reward")
