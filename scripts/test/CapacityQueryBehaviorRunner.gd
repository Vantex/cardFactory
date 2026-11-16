extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-capacity-queries.json"
const FUNCTIONS := ["getEntityBufferLimit", "getEntityInputCapacity", "getEntityOutputCapacity"]
const COUNTS := [1, 2, 3, 0, -1, 1.9, 100000000, 1000000000]
const LIMITS := [["default", 1000000, 1000000], ["minimum", 1000, 1000], ["maximum", 100000000, 100000000], ["split-production", 1000, 100000000], ["split-logistics", 100000000, 1000], ["below", -1, 999.9], ["fractional", 1234.9, 2345.9], ["above", 1.0e12, 1.0e12], ["null", null, null], ["boolean", false, true], ["string", "1000", "2000"]]
const RESOURCES := ["coal", "copper_ore", "crude_oil", "fire_ice", "fractal_silicon", "iron_ore", "kimberlite_ore", "optical_grating_crystal", "organic_crystal", "silicon_ore", "spiniform_stalagmite_crystal", "stone", "sulfuric_acid", "titanium_ore", "unipolar_magnet", "water"]
const SOURCE_MODULES := ["src/game/activity.ts", "src/game/campaign.ts", "src/game/content.ts", "src/game/difficulty.ts", "src/game/endgame.ts", "src/game/engine.ts", "src/game/galaxy.ts", "src/game/galaxyCatalog.ts", "src/game/idleSettlement.ts", "src/game/infiniteResearch.ts", "src/game/orbitalStation.ts", "src/game/productionStatistics.ts", "src/game/progression.ts", "src/game/quantityFormat.ts", "src/game/quantumLogisticsNetwork.ts", "src/game/recursiveCrafting.ts", "src/game/speedrun.ts", "src/game/stationCargoTerminal.ts", "src/game/stationContracts.ts", "src/game/stationDecorations.ts", "src/game/stationMath.ts", "src/game/systemHubLogistics.ts", "src/game/systemSpaceStation.ts", "src/game/units.ts"]
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_query: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var effects := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("capacity query provenance missing")
	if not controls._same_ids(fixture.source_files.keys(), SOURCE_MODULES): return _reject("capacity query exact source modules changed")
	for file in SOURCE_MODULES:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("capacity query frozen source hash drift")
	if not _exact(fixture.get("source_environment"), {"DEV": false, "PROD": true, "MODE": "production"}): return _reject("capacity source environment changed")
	var buildings: Array = source.catalog.buildings.map(func(row): return row.id)
	if fixture.get("functions") != FUNCTIONS or not controls._same_ids(fixture.get("buildings", []), buildings) or fixture.get("resources") != RESOURCES or not _exact(fixture.get("counts"), COUNTS) or not _exact(fixture.get("limits"), LIMITS): return _reject("capacity declared coverage changed")
	var inputs := _inputs(source.catalog.buildings)
	if not fixture.get("cases") is Array: return _reject("capacity cases missing")
	var ids := []
	for row in fixture.cases:
		if not row is Dictionary: return _reject("capacity case malformed")
		ids.append(row.get("id"))
	if not controls._same_ids(ids, inputs.keys()): return _reject("capacity cases incomplete or duplicated")
	for row in fixture.cases:
		if not _exact(row.get("input"), inputs[row.id]): return _reject("capacity controlled input changed: " + row.id)
		if not row.get("expected") is Dictionary or not controls._same_ids(row.expected.keys(), FUNCTIONS): return _reject("capacity source outputs incomplete")
		for function in FUNCTIONS:
			var value: Variant = row.expected[function]
			if not effects._number(value) or value < 0 or value > 100000000 or value != floorf(float(value)): return _reject("capacity source output is not a finite integer")
	for row in fixture.cases:
		var state := _state(row.input)
		var id: String = "probe_site" if row.input.entity_kind == "vein" else String(state.buildings.keys()[0])
		var before := effects._ownership(state)
		var actual := _query(state, id)
		var repeated := _query(state, id)
		if after_query.is_valid(): after_query.call(row.id, state)
		if effects._ownership(state) != before: return _reject("capacity query mutates raw or canonical state: " + row.id)
		for function in FUNCTIONS:
			_check(function, _exact(actual[function], row.expected[function]), row.id + ": actual entity capacity provider matches frozen source")
			_check(function, actual == repeated, row.id + ": repeated query preserves raw and canonical ownership")
	var keys := []
	var proofs := {}
	for function in FUNCTIONS:
		var key: String = "commands:engine." + String(function)
		if claims.has(key) and claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-capacity-queries", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _inputs(buildings: Array) -> Dictionary:
	var inputs := {}
	for row in buildings:
		for profile in LIMITS:
			for index in range(COUNTS.size()):
				inputs["building-%s-%s-c%d" % [row.id, profile[0], index]] = {"entity_kind": "building", "building": row.id, "kind": row.definition.kind, "count": COUNTS[index], "profile": profile[0], "production": profile[1], "logistics": profile[2]}
	for resource in RESOURCES:
		var extractor := "oil_extractor" if resource == "crude_oil" else "water_pump" if resource in ["water", "sulfuric_acid"] else "mining_machine"
		for profile in LIMITS:
			for index in range(COUNTS.size()):
				inputs["vein-%s-%s-c%d" % [resource, profile[0], index]] = {"entity_kind": "vein", "resource": resource, "extractor": extractor, "count": COUNTS[index], "profile": profile[0], "production": profile[1], "logistics": profile[2]}
	return inputs

static func _state(input: Dictionary) -> GameState:
	var state := GameState.new()
	state.source_buffer_limits = {"production": input.production, "logistics": input.logistics}
	if input.entity_kind == "building":
		var entity := {"type": "dsp_" + String(input.building), "position": Vector2.ZERO, "machine_count": input.count, "input_buffer": {}, "output_buffer": {}}
		if input.kind == "station":
			entity.erase("machine_count")
			entity.station_stack_count = input.count
		state.add_building(entity)
	else:
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.resource_sites["probe_site"] = {"id": "probe_site", "planet_id": "home", "item_id": input.resource, "position": Vector2.ZERO, "capacity": 1000, "remaining": 1000, "infinite": input.resource in ["water", "sulfuric_acid"]}
		if input.count > 0:
			state.add_building({"id": "probe", "type": "dsp_" + String(input.extractor), "position": Vector2.ZERO, "machine_count": input.count, "resource_site_id": "probe_site", "input_buffer": {}, "output_buffer": {}})
	state.command_history.undo_entries.append({"label": "capacity undo sentinel", "changes": [{"path": ["buildings", "probe", "position"], "before": Vector2.ZERO, "after": Vector2.ONE}]})
	state.command_history.redo_entries.append({"label": "capacity redo sentinel", "changes": []})
	state.command_history._group_before = {"buildings": {"probe": {"position": Vector2.ONE}}}
	state.command_history._group_label = "capacity group sentinel"
	state._spatial_index.add_entity("capacity-sentinel", Vector2(300, 500))
	return state

static func _query(state: GameState, id: String) -> Dictionary:
	return {"getEntityBufferLimit": state.get_entity_buffer_limit(id), "getEntityInputCapacity": state.get_entity_input_capacity(id), "getEntityOutputCapacity": state.get_entity_output_capacity(id)}

static func _exact(left: Variant, right: Variant) -> bool:
	var effects := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	if effects._number(left) or effects._number(right): return effects._number(left) and effects._number(right) and left == right
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _exact(left[key], right[key]): return false
		return true
	if left is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _exact(left[index], right[index]): return false
		return true
	return left == right

static func rejection_errors() -> Array[String]:
	var failures: Array[String] = []
	var runner = load("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	for kind in ["commit", "source", "missing_module", "extra_module", "environment", "function", "buildings", "resources", "counts", "limits", "missing", "duplicate", "row", "count", "count_bool", "kind", "limit", "output_shape", "output_bool"]:
		var broken := fixture.duplicate(true)
		match kind:
			"commit": broken.source_commit = "wrong"
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing_module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": broken.source_files["src/game/unknown-capacity-module.ts"] = null
			"environment": broken.source_environment.DEV = true
			"function": broken.functions.append("unknown")
			"buildings": broken.buildings.pop_back()
			"resources": broken.resources.pop_back()
			"counts": broken.counts[0] = 1.0 + 5.0e-10
			"limits": broken.limits[0][1] = 1000
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"row": broken.cases[0] = false
			"count": broken.cases[0].input.count += 5.0e-10
			"count_bool": broken.cases[0].input.count = true
			"kind": broken.cases[0].input.kind = "storage"
			"limit": broken.cases[0].input.production = true
			"output_shape": broken.cases[0].expected.erase(FUNCTIONS[0])
			"output_bool": broken.cases[0].expected[FUNCTIONS[0]] = true
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("capacity " + kind + " drift must withhold all keys")
	var broken := fixture.duplicate(true)
	broken.cases[0].expected.getEntityOutputCapacity += 1
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or rejected.verified_keys != ["commands:engine.getEntityBufferLimit", "commands:engine.getEntityInputCapacity"]: failures.append("wrong output withholds exactly its endpoint")
	for kind in ["inventory", "queue", "history", "spatial"]:
		rejected = runner.new().run({}, func(id, state):
			if id != fixture.cases[0].id: return
			if kind == "inventory": state.planet_inventory.iron_ore = float(state.planet_inventory.get("iron_ore", 0)) + 1
			elif kind == "queue": state.research_queue.append("dsp_mining_speed_2")
			elif kind == "history": state.command_history.undo_entries.clear()
			elif kind == "spatial": state._spatial_index.clear())
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("capacity " + kind + " mutation must withhold all keys")
	return failures

func _check(function: String, ok: bool, assertion: String) -> void:
	var key := "commands:engine." + function
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
