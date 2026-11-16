extends RefCounted

const MINING := preload("res://scripts/test/ResourceMiningRegression.gd")
const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const FIXTURE := "res://tests/fixtures/parity/behavior/task27-mining-live60.json"
const RESOURCES := ["coal", "copper_ore", "crude_oil", "fire_ice", "fractal_silicon", "iron_ore", "kimberlite_ore", "optical_grating_crystal", "organic_crystal", "silicon_ore", "spiniform_stalagmite_crystal", "stone", "sulfuric_acid", "titanium_ore", "unipolar_magnet", "water"]
const EXTRACTORS := ["mining_machine", "oil_extractor", "water_pump"]
var errors := []
var claims := {}

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var invalid := MINING.validation_errors(fixture, "live60")
	if not invalid.is_empty(): return {"errors": invalid, "verified_keys": [], "proofs": {}, "claims": {}, "cases": 0}
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	for item in RESOURCES:
		var expected: Dictionary = source.catalog.items.filter(func(row): return row.id == item)[0].definition
		var actual := DataManager.get_item(item)
		for field in expected: _check("items:" + item, actual.get(field) == expected[field], "frozen item definition " + field)
	for id in EXTRACTORS:
		var expected: Dictionary = source.catalog.buildings.filter(func(row): return row.id == id)[0].definition
		var actual := DataManager.get_building("dsp_" + id)
		var fields := {"name": "name", "description": "description", "speed": "speed", "powerDemandKw": "power_demand", "inputCapacity": "source_input_capacity", "outputCapacity": "source_output_capacity"}
		for field in fields: _check("buildings:" + id, actual.get(fields[field]) == expected.get(field, 0), "frozen extractor definition " + field)
		_check("buildings:" + id, actual.get("source_id") == id and actual.get("kind") == "extractor" and expected.kind == "miner", "source miner maps to native extractor")
	var cases := 0
	var coverage := {}
	for row in fixture.cases:
		if row.input.count != 1 or row.input.level != 0 or row.input.mode != "finite": continue
		var item_key := "items:" + String(row.input.item)
		var building_key := "buildings:" + String(row.input.extractor)
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		planets.initialize_colonized_resource_sites()
		var site: Dictionary = {}
		for candidate in planets.get_planet_resource_sites(row.input.planet):
			if candidate.item_id == row.input.item: site = state.resource_sites[candidate.id]; break
		_check(item_key, not site.is_empty(), row.id + ": actual resource identity")
		if site.is_empty(): continue
		var type := "dsp_" + String(row.input.extractor)
		state.construction_inventory[type] = 1
		var installed: Dictionary = preload("res://scripts/game/SourceMinerSystem.gd").new(state).install(site.id)
		for key in [item_key, building_key]: _check(key, installed.ok and state.construction_inventory[type] == 0 and OUTPUT.miner_count(state, site) == 1, row.id + ": actual paid extractor mapping")
		if not installed.ok: continue
		var building: Dictionary = OUTPUT.extractors(state, String(site.id))[0]
		building.power_efficiency = 0.0 if row.input.stage == "unpowered" else 1.0
		building.output_buffer = {row.input.item: row.input.output}
		building.progress = row.input.progress
		site.remaining = row.input.remaining
		site.capacity = row.input.capacity
		site.depletion_remainder = row.input.remainder
		var before := OWNER._ownership(state)
		var capacity := state.get_entity_output_capacity(building.id)
		_check(building_key, capacity == DataManager.get_building(type).source_output_capacity and before == OWNER._ownership(state), row.id + ": rated output capacity is pure")
		var production := ProductionSystem.new(state, StatisticsSystem.new(state))
		for tick in range(int(row.input.fixed_ticks)): production.update(1.0 / 60)
		var actual := {"output": building.output_buffer.get(row.input.item, 0), "progress": building.progress, "remaining": site.remaining, "remainder": site.depletion_remainder, "power_factor": building.power_efficiency, "utilization": building.get("production_utilization", 0), "production_rate": building.get("last_production_per_minute", 0), "total_produced": state.progression_facts.get("produced", {}).get(row.input.item, 0)}
		for field in actual:
			for key in [item_key, building_key]: _check(key, MINING.numbers_match(actual[field], row.expected[field]), row.id + ": frozen mining effect " + field)
		coverage[row.input.item] = int(coverage.get(row.input.item, 0)) + 1
		cases += 1
	for item in RESOURCES: _check("items:" + item, coverage.get(item, 0) == 15, "five power/cache/reserve stages at three elapsed times")
	if cases != 240: errors.append("resource definition mining coverage incomplete")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty() and not claims[key].assertions.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-resource-definitions", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true), "cases": cases}

func _check(key: String, ok: bool, label: String) -> void:
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(label)
	if not ok:
		claims[key].failures.append(label)
		errors.append(key + ": " + label)
