extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-logistics-scalars.json"
const FUNCTIONS := ["getPlanetaryCargoCapacity", "getInterstellarCargoCapacity", "getPlanetaryTripSeconds"]
const FINITE := ["logistics_engine_1", "logistics_engine_2", "logistics_capacity_1", "logistics_capacity_2"]
const LEVELS := [0, 1, 2, 9, 10, 11, 99, 999, 1000]
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_queries: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("logistics scalar provenance missing")
	for file in ["src/game/engine.ts", "src/game/endgame.ts", "src/game/difficulty.ts"]:
		if not fixture.source_files.has(file): return _reject("logistics scalar module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("logistics scalar source hash drift")
	if fixture.get("functions") != FUNCTIONS or fixture.get("finite") != FINITE or not _declared_levels(fixture.get("levels")): return _reject("logistics scalar controlled coverage changed")
	var declared := {}
	for difficulty in ["relaxed", "standard", "hard"]:
		for mask in range(16):
			var completed := []
			for index in range(FINITE.size()):
				if (mask & (1 << index)) != 0: completed.append(FINITE[index])
			for level in LEVELS: declared["%s-%d-%d" % [difficulty, mask, level]] = {"difficulty": difficulty, "completed": completed, "level": level}
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if not fixture.get("cases") is Array or not controls._same_ids(fixture.cases.map(func(row): return row.get("id")), declared.keys()): return _reject("logistics scalar cases missing or duplicated")
	for row in fixture.cases:
		if not row.get("input") is Dictionary or row.input.size() != 3 or not row.input.get("completed") is Array: return _reject("logistics scalar input missing")
		var input: Dictionary = row.input
		var wanted: Dictionary = declared[row.id]
		if input.get("difficulty") != wanted.difficulty or not controls._same_ids(input.completed, wanted.completed) or not _number(input.get("level")) or input.level < 0 or input.level > 1000 or floorf(float(input.level)) != float(input.level) or float(input.level) != float(wanted.level): return _reject("logistics scalar strict input changed")
		if not row.get("expected") is Dictionary or not controls._same_ids(row.expected.keys(), FUNCTIONS): return _reject("logistics scalar output incomplete")
		for function in FUNCTIONS:
			if not _number(row.expected[function]): return _reject("logistics scalar output malformed")
	for row in fixture.cases:
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.difficulty = row.input.difficulty
		state.completed_technologies = row.input.completed.map(func(id): return "dsp_" + String(id))
		state.progression_facts["infinite_research"] = {"galactic_logistics": {"level": int(row.input.level), "invested": "0"}}
		state.construction_inventory.dsp_planetary_logistics_station = 1.0
		var placed := ConstructionSystem.new(state).try_place_building("dsp_planetary_logistics_station", Vector2.ZERO)
		if not placed.ok:
			for function in FUNCTIONS: _check(function, false, row.id + ": funded station setup places a real paid entity")
			continue
		var owner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
		var before: Dictionary = owner._ownership(state)
		var service := StationSystem.new(state)
		var snapshot := service.logistics_snapshot(placed.id)
		var repeated := service.logistics_snapshot(placed.id)
		var actual := {"getPlanetaryCargoCapacity": snapshot.local_cargo_capacity, "getInterstellarCargoCapacity": snapshot.remote_cargo_capacity, "getPlanetaryTripSeconds": snapshot.local_trip_seconds}
		for function in FUNCTIONS: _check(function, _same(actual[function], row.expected[function]), row.id + ": actual station snapshot agrees with source scalar including rounding and difficulty")
		if after_queries.is_valid(): after_queries.call(row.id, state)
		for function in FUNCTIONS: _check(function, snapshot == repeated and owner._ownership(state) == before, row.id + ": repeated query preserves all raw and canonical ownership")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-logistics-scalars", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _declared_levels(value: Variant) -> bool:
	if not value is Array or value.size() != LEVELS.size(): return false
	for index in range(LEVELS.size()):
		if not _number(value[index]) or float(value[index]) != float(LEVELS[index]): return false
	return true

static func _same(left: float, right: float) -> bool:
	return absf(left - right) <= maxf(1.0, absf(right)) * 1.0e-12

func _check(function: String, ok: bool, assertion: String) -> void:
	var key := "commands:engine." + function
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
