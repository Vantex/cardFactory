extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-sail-lifetime.json"
const FUNCTION := "getSolarSailLifetimeSeconds"
const KEY := "commands:engine.getSolarSailLifetimeSeconds"
const SOLAR_TECHNOLOGIES := ["solar_sail_life_1", "solar_sail_life_2"]
const SOURCE_MODULES := ["src/game/activity.ts","src/game/campaign.ts","src/game/content.ts","src/game/difficulty.ts","src/game/endgame.ts","src/game/engine.ts","src/game/galaxy.ts","src/game/galaxyCatalog.ts","src/game/idleSettlement.ts","src/game/infiniteResearch.ts","src/game/orbitalStation.ts","src/game/productionStatistics.ts","src/game/progression.ts","src/game/quantityFormat.ts","src/game/quantumLogisticsNetwork.ts","src/game/recursiveCrafting.ts","src/game/speedrun.ts","src/game/stationCargoTerminal.ts","src/game/stationContracts.ts","src/game/stationDecorations.ts","src/game/stationMath.ts","src/game/systemHubLogistics.ts","src/game/systemSpaceStation.ts","src/game/units.ts"]
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_query: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var effects := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("sail lifetime provenance missing")
	if not controls._same_ids(fixture.source_files.keys(), SOURCE_MODULES): return _reject("sail lifetime exact source modules changed")
	for file in SOURCE_MODULES:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("sail lifetime source hash drift")
	if fixture.get("source_environment") != {"DEV": false, "PROD": true, "MODE": "production"}: return _reject("sail lifetime source environment changed")
	if fixture.get("functions") != [FUNCTION] or fixture.get("finite") != effects.FINITE + SOLAR_TECHNOLOGIES or fixture.get("infinite") != effects.INFINITE: return _reject("sail lifetime declared coverage changed")
	var inputs := _inputs(source.catalog.technologies.map(func(row): return row.id))
	if not fixture.get("cases") is Array or not controls._same_ids(fixture.cases.map(func(row): return row.get("id")), inputs.keys()): return _reject("sail lifetime cases missing or duplicated")
	for row in fixture.cases:
		if not row.get("input") is Dictionary or not row.input.get("completed") is Array: return _reject("sail lifetime input missing")
		var wanted: Dictionary = inputs[row.id]
		if row.input.size() != wanted.size() or row.input.get("difficulty") != wanted.difficulty or not controls._same_ids(row.input.completed, wanted.completed) or not effects._levels_match(row.input.get("levels"), wanted.levels): return _reject("sail lifetime controlled input changed")
		if not row.get("expected") is Dictionary or not controls._same_ids(row.expected.keys(), [FUNCTION]) or not effects._number(row.expected.get(FUNCTION)): return _reject("sail lifetime source output malformed")
	for row in fixture.cases:
		var state := effects._state(row.input)
		var before := effects._ownership(state)
		var engineering := SourceDysonEngineering.new(state)
		var actual := engineering.sail_lifetime_seconds()
		var repeated := engineering.sail_lifetime_seconds()
		_check(effects._same(actual, row.expected[FUNCTION]), row.id + ": actual Dyson lifetime provider matches frozen source")
		if after_query.is_valid(): after_query.call(row.id, state)
		_check(actual == repeated and effects._ownership(state) == before, row.id + ": repeated query preserves all raw and canonical state")
	var keys := []
	var proofs := {}
	if claims.has(KEY) and claims[KEY].failures.is_empty():
		keys.append(KEY)
		proofs[KEY] = {"suite": "task27-sail-lifetime", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[KEY].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _inputs(technologies: Array) -> Dictionary:
	var effects := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	var inputs := effects._inputs(technologies)
	for difficulty in ["relaxed", "standard", "hard"]:
		for technology in SOLAR_TECHNOLOGIES:
			var levels := {}
			for id in effects.INFINITE: levels[id] = 0
			inputs[difficulty + "-finite-" + technology] = {"difficulty": difficulty, "completed": [technology], "levels": levels}
	return inputs

static func rejection_errors() -> Array[String]:
	var failures: Array[String] = []
	var runner = load("res://scripts/test/SailLifetimeBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	for kind in ["source", "missing_module", "extra_module", "environment", "function", "finite", "infinite", "missing", "duplicate", "input", "sub_epsilon", "negative_epsilon", "bool", "completed", "output", "wrong_output"]:
		var broken := fixture.duplicate(true)
		match kind:
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing_module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": broken.source_files["src/game/unknown-sail-module.ts"] = null
			"environment": broken.source_environment.DEV = true
			"function": broken.functions.append("unknown")
			"finite": broken.finite.pop_back()
			"infinite": broken.infinite.pop_back()
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"input": broken.cases[0].input.levels.vein_utilization = 0.5
			"sub_epsilon": broken.cases[0].input.levels.vein_utilization = 5.0e-10
			"negative_epsilon": broken.cases[0].input.levels.vein_utilization = -5.0e-10
			"bool": broken.cases[0].input.levels.vein_utilization = false
			"completed": broken.cases[0].input.completed.append("solar_sail_life_1")
			"output": broken.cases[0].expected[FUNCTION] = false
			"wrong_output": broken.cases[0].expected[FUNCTION] += 1
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("sail lifetime " + kind + " drift must withhold its key")
	for kind in ["inventory", "queue", "history", "spatial"]:
		var rejected: Dictionary = runner.new().run({}, func(id, state):
			if id != "relaxed-none": return
			if kind == "inventory": state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 1
			elif kind == "queue": state.research_queue.append("dsp_mining_speed_2")
			elif kind == "history": state.command_history.enabled = false
			elif kind == "spatial": state._spatial_index.add_entity("query-injected", Vector2(900, 100)))
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("sail lifetime " + kind + " mutation must withhold its key")
	return failures

func _check(ok: bool, assertion: String) -> void:
	if not claims.has(KEY): claims[KEY] = {"assertions": [], "failures": []}
	claims[KEY].assertions.append(assertion)
	if not ok:
		claims[KEY].failures.append(assertion)
		errors.append(KEY + ": " + assertion)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
