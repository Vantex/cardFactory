extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-route-queries.json"
const FUNCTIONS := ["getInterstellarTripSeconds", "getInterstellarRouteEconomics"]
const FINITE := ["logistics_engine_1", "logistics_engine_2", "logistics_capacity_1", "logistics_capacity_2"]
const PLANETS := ["home", "ashen", "giant", "frost", "boreal_giant", "magnetar", "verdant", "pelagic", "aurora_giant", "dune", "cinder", "ember_giant", "crystal", "prairie", "sirius_giant", "salt", "obsidian", "white_giant", "tempest", "inferno", "abyss", "azure_giant"]
const SYSTEMS := ["helios", "borealis", "aurora", "ember", "sirius", "white_dwarf", "neutron", "blue_giant"]
const HUB_PLANETS := ["frost", "verdant", "dune", "crystal", "salt", "magnetar"]
const PROFILES := [{"mask": 0, "level": 0}, {"mask": 1, "level": 0}, {"mask": 2, "level": 0}, {"mask": 3, "level": 0}, {"mask": 4, "level": 0}, {"mask": 8, "level": 1}, {"mask": 15, "level": 10}, {"mask": 15, "level": 1000}]
const SEEDS := [{"seed": 240721, "baseline": false}, {"seed": 42, "baseline": false}, {"seed": 240721, "baseline": true}]
const DIFFICULTIES := ["relaxed", "standard", "hard"]
const SOURCE_MODULES := ["src/game/engine.ts", "src/game/content.ts", "src/game/galaxy.ts", "src/game/galaxyCatalog.ts", "src/game/systemSpaceStation.ts", "src/game/systemHubLogistics.ts", "src/game/productionStatistics.ts", "src/game/quantityFormat.ts", "src/game/campaign.ts", "src/game/difficulty.ts", "src/game/endgame.ts", "src/game/infiniteResearch.ts", "src/game/activity.ts", "src/game/units.ts", "src/game/quantumLogisticsNetwork.ts", "src/game/recursiveCrafting.ts", "src/game/speedrun.ts", "src/game/idleSettlement.ts", "src/game/orbitalStation.ts", "src/game/progression.ts", "src/game/stationContracts.ts", "src/game/stationMath.ts", "src/game/stationDecorations.ts", "src/game/stationCargoTerminal.ts"]
const FIELDS := {"distanceLy": "distance_ly", "orbitSpan": "orbit_span", "requiresWarp": "requires_warp", "durationSeconds": "duration", "cargoPerTrip": "cargo_per_trip", "throughputPerMinute": "throughput_per_minute", "warpersPerTrip": "warpers_per_trip", "powerKw": "power_kw", "energyMjPerTrip": "energy_mj_per_trip", "routeAvailable": "available", "routeKind": "kind", "waypointStationIds": "waypoint_ids", "hopCount": "hop_count", "maxLegDistanceLy": "max_leg_distance_ly", "warpersPerVessel": "warpers_per_vessel"}
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_queries: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var catalog := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != catalog.source.commit or not fixture.get("source_files") is Dictionary: return _reject("route query provenance missing")
	var ids := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if not ids._same_ids(fixture.source_files.keys(), SOURCE_MODULES): return _reject("route query exact loaded source modules changed")
	for file in fixture.source_files:
		if fixture.source_files[file] != catalog.source.files.get(file): return _reject("route query source hash drift")
	var scenarios := _scenarios()
	if not _exact(fixture.get("functions"), FUNCTIONS) or not _exact(fixture.get("finite"), FINITE) or not _exact(fixture.get("profiles"), PROFILES) or not _exact(fixture.get("seeds"), SEEDS) or not _exact(fixture.get("difficulties"), DIFFICULTIES) or not _exact(fixture.get("scenarios"), scenarios): return _reject("route query controlled coverage changed")
	var declared := {}
	for seed in SEEDS:
		for difficulty in DIFFICULTIES:
			for profile in PROFILES:
				for scenario in scenarios:
					var id := "%d-%s-%s-%d-%d-%s" % [seed.seed, "true" if seed.baseline else "false", difficulty, profile.mask, profile.level, scenario.id]
					declared[id] = _input(seed, difficulty, profile, scenario)
	if not fixture.get("cases") is Array: return _reject("route query cases missing")
	for row in fixture.cases:
		if not row is Dictionary or not row.get("id") is String: return _reject("route query case identity malformed")
	if not ids._same_ids(fixture.cases.map(func(row): return row.id), declared.keys()): return _reject("route query cases missing or duplicated")
	for row in fixture.cases:
		if not _exact(row.get("input"), declared[row.id]): return _reject("route query strict input changed: " + row.id)
		if not row.get("expected") is Dictionary or not ids._same_ids(row.expected.keys(), FUNCTIONS): return _reject("route query output incomplete")
		var trips: Variant = row.expected.getInterstellarTripSeconds
		var economics: Variant = row.expected.getInterstellarRouteEconomics
		if not trips is Dictionary or not ids._same_ids(trips.keys(), ["normal", "warp"]) or not _number(trips.normal) or not _number(trips.warp): return _reject("route trip output malformed")
		if not economics is Dictionary or not ids._same_ids(economics.keys(), FIELDS.keys()): return _reject("route economics output malformed")
		for field in FIELDS:
			if field in ["requiresWarp", "routeAvailable"]:
				if not economics[field] is bool: return _reject("route boolean output malformed")
			elif field == "routeKind":
				if economics[field] not in ["local", "direct", "relay"]: return _reject("route kind output malformed")
			elif field == "waypointStationIds":
				if not economics[field] is Array: return _reject("route waypoint output malformed")
				for waypoint in economics[field]:
					if not waypoint is String: return _reject("route waypoint identity malformed")
			elif not _number(economics[field]): return _reject("route numeric output malformed")
	for row in fixture.cases:
		var state := _state(row.input)
		var service := InterstellarRouteSystem.new(state)
		var before := OWNER._ownership(state)
		var options := {"route_policy": row.input.options.routePolicy, "warper_budget": int(row.input.options.warperBudget)}
		var actual := service.query_economics(state.buildings[row.input.source_id], state.buildings[row.input.target_id], int(row.input.vessels), options)
		var repeated := service.query_economics(state.buildings[row.input.source_id], state.buildings[row.input.target_id], int(row.input.vessels), options)
		var trips := {"normal": service.trip_seconds(false), "warp": service.trip_seconds(true)}
		var repeated_trips := {"normal": service.trip_seconds(false), "warp": service.trip_seconds(true)}
		for warp in ["normal", "warp"]: _check(FUNCTIONS[0], _same(trips[warp], row.expected.getInterstellarTripSeconds[warp]), row.id + ": actual " + warp + " trip agrees with source")
		for field in FIELDS: _check(FUNCTIONS[1], _same(actual[FIELDS[field]], row.expected.getInterstellarRouteEconomics[field]), row.id + ": actual route " + field + " agrees with source")
		if after_queries.is_valid(): after_queries.call(row.id, state)
		_check(FUNCTIONS[0], trips == repeated_trips and OWNER._ownership(state) == before, row.id + ": repeated trip preserves raw and canonical ownership")
		_check(FUNCTIONS[1], actual == repeated and OWNER._ownership(state) == before, row.id + ": repeated route query preserves raw and canonical ownership")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-route-queries", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _scenarios() -> Array:
	var result := []
	for index in range(PLANETS.size()): result.append({"id": "planet-" + PLANETS[index], "target": PLANETS[index], "policy": "relay-preferred", "budget": 2, "vessels": 1 + index % 3, "stack": 1 + index % 2, "hubs": "none"})
	for policy in ["direct", "relay-preferred", "relay-required"]:
		for budget in [1, 2, 3, 4]: result.append({"id": "policy-%s-%d" % [policy, budget], "target": "tempest", "policy": policy, "budget": budget, "vessels": 3, "stack": 2, "hubs": "all"})
	for hubs in ["disabled", "locked", "priority", "tie", "mode-transition", "elevator"]: result.append({"id": "hubs-" + hubs, "target": "tempest", "policy": "relay-required", "budget": 4, "vessels": 2, "stack": 1, "hubs": hubs})
	for vessels in [0, 1, 7, 100]: result.append({"id": "vessels-%d" % vessels, "target": "tempest", "policy": "direct", "budget": 1, "vessels": vessels, "stack": 3, "hubs": "none"})
	return result

static func _station(id: int, planet: String, count: int) -> Dictionary:
	return {"id": "entity_%d" % id, "planet": planet, "count": count, "tier": 1, "hub_enabled": false, "hub_priority": 1, "operation_mode": "legacy", "mode_transition": null}

static func _input(seed: Dictionary, difficulty: String, profile: Dictionary, scenario: Dictionary) -> Dictionary:
	var completed := []
	for index in range(FINITE.size()):
		if (int(profile.mask) & (1 << index)) != 0: completed.append(FINITE[index])
	var stations := [_station(1, "home", scenario.stack), _station(2, scenario.target, scenario.stack)]
	if scenario.hubs != "none":
		for planet in HUB_PLANETS:
			var hub := _station(stations.size() + 1, planet, 1)
			hub.hub_enabled = scenario.hubs != "disabled"
			if scenario.hubs in ["mode-transition", "elevator"]: hub.tier = 2
			if scenario.hubs == "mode-transition": hub.mode_transition = "to-elevator"
			if scenario.hubs == "elevator": hub.operation_mode = "elevator"
			stations.append(hub)
			if scenario.hubs in ["priority", "tie"]:
				hub = _station(stations.size() + 1, planet, 2)
				hub.hub_enabled = true
				hub.hub_priority = 2 if scenario.hubs == "priority" else 1
				stations.append(hub)
	return {"seed": seed.seed, "baseline": seed.baseline, "difficulty": difficulty, "completed": completed, "level": profile.level, "unlocked": ["helios", "blue_giant"] if scenario.hubs == "locked" else SYSTEMS.duplicate(), "source_id": "entity_1", "target_id": "entity_2", "vessels": scenario.vessels, "options": {"routePolicy": scenario.policy, "warperBudget": scenario.budget}, "stations": stations}

static func _state(input: Dictionary) -> GameState:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(int(input.seed), input.baseline)
	state.difficulty = input.difficulty
	state.completed_technologies = input.completed.map(func(id): return "dsp_" + String(id))
	state.progression_facts.infinite_research = {"galactic_logistics": {"level": int(input.level), "invested": "0"}}
	state.explored_system_ids.assign(input.unlocked)
	for station in input.stations:
		var config := StationSystem.empty_station("dsp_interstellar_logistics_station")
		config.hub_enabled = station.hub_enabled
		config.hub_priority = int(station.hub_priority)
		config.operation_mode = station.operation_mode
		config.tier = int(station.tier)
		if station.mode_transition != null: config.mode_transition = "elevator"
		# Preserve source identities and paid counts for controlled queries, including gas-planet inputs.
		state.buildings[station.id] = {"id": station.id, "type": "dsp_interstellar_logistics_station", "planet_id": station.planet, "position": Vector2.ZERO, "station": config, "station_stack_count": int(station.count), "input_buffer": {}, "output_buffer": {}}
	return state

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _exact(left: Variant, right: Variant) -> bool:
	if _number(right): return _number(left) and float(left) == float(right)
	if right is Dictionary:
		if not left is Dictionary or left.size() != right.size(): return false
		for key in right:
			if not left.has(key) or not _exact(left[key], right[key]): return false
		return true
	if right is Array:
		if not left is Array or left.size() != right.size(): return false
		for index in range(right.size()):
			if not _exact(left[index], right[index]): return false
		return true
	return typeof(left) == typeof(right) and left == right

static func _same(left: Variant, right: Variant) -> bool:
	if _number(right): return _number(left) and absf(float(left) - float(right)) <= maxf(1.0, absf(float(right))) * 1.0e-12
	return left == right

func _check(function: String, ok: bool, assertion: String) -> void:
	var key := "commands:engine." + function
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
