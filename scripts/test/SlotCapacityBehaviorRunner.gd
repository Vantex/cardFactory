extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-slot-capacity.json"
const KEY := "commands:engine.getStationSlotCapacity"
const CAPACITY := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const STOCKS := [-1, 0, 1, 59.9, 600, 1200, 100000000, 1.0e12]
var errors: Array[String] = []
var assertions: Array[String] = []
var failures: Array[String] = []

func run(fixture_override: Dictionary = {}, after_query: Callable = Callable()) -> Dictionary:
	errors.clear()
	assertions.clear()
	failures.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	var owner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("slot capacity provenance missing")
	if not controls._same_ids(fixture.source_files.keys(), CAPACITY.SOURCE_MODULES): return _reject("slot capacity exact source modules changed")
	for file in CAPACITY.SOURCE_MODULES:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("slot capacity source hash drift")
	if not CAPACITY._exact(fixture.get("source_environment"), {"DEV": false, "PROD": true, "MODE": "production"}): return _reject("slot capacity source environment changed")
	var buildings: Array = source.catalog.buildings.filter(func(row): return row.definition.kind == "station").map(func(row): return row.id)
	buildings.sort()
	if fixture.get("functions") != ["getStationSlotCapacity"] or not controls._same_ids(fixture.get("buildings", []), buildings) or not CAPACITY._exact(fixture.get("counts"), CAPACITY.COUNTS) or not CAPACITY._exact(fixture.get("limits"), CAPACITY.LIMITS) or not CAPACITY._exact(fixture.get("stocks"), STOCKS): return _reject("slot capacity coverage changed")
	var inputs := _inputs(buildings)
	if not fixture.get("cases") is Array: return _reject("slot capacity cases missing")
	var ids := []
	for row in fixture.cases:
		if not row is Dictionary: return _reject("slot capacity case malformed")
		ids.append(row.get("id"))
	if not controls._same_ids(ids, inputs.keys()): return _reject("slot capacity cases incomplete or duplicated")
	for row in fixture.cases:
		if not CAPACITY._exact(row.get("input"), inputs[row.id]): return _reject("slot capacity input changed: " + row.id)
		if not row.get("expected") is Dictionary or row.expected.keys() != ["getStationSlotCapacity"]: return _reject("slot capacity output shape changed")
		var value: Variant = row.expected.getStationSlotCapacity
		if not owner._number(value) or value < 0 or value > 100000000: return _reject("slot capacity output must be finite and bounded")
	for row in fixture.cases:
		var state := _state(row.input)
		var before := owner._ownership(state)
		var actual := _query(state)
		var repeated := _query(state)
		if after_query.is_valid(): after_query.call(row.id, state)
		if owner._ownership(state) != before: return _reject("slot capacity query mutates raw/canonical ownership: " + row.id)
		_check(CAPACITY._exact(actual, row.expected.getStationSlotCapacity), row.id + ": actual slot capacity matches frozen rated/stock limit")
		_check(actual == repeated, row.id + ": repeated slot query preserves raw and canonical ownership")
	var keys := []
	var proofs := {}
	if failures.is_empty():
		keys.append(KEY)
		proofs[KEY] = {"suite": "task27-slot-capacity", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": {KEY: {"assertions": assertions.duplicate(), "failures": failures.duplicate()}}}

static func _inputs(buildings: Array) -> Dictionary:
	var inputs := {}
	for building in buildings:
		for profile in CAPACITY.LIMITS:
			for count_index in range(CAPACITY.COUNTS.size()):
				for stock_index in range(STOCKS.size()):
					inputs["%s-%s-c%d-s%d" % [building, profile[0], count_index, stock_index]] = {"building": building, "count": CAPACITY.COUNTS[count_index], "profile": profile[0], "production": profile[1], "logistics": profile[2], "maxStock": STOCKS[stock_index]}
	for index in range(STOCKS.size()): inputs["missing-building-s%d" % index] = {"building": "", "count": 1, "profile": "default", "production": 1000000, "logistics": 1000000, "maxStock": STOCKS[index]}
	return inputs

static func _state(input: Dictionary) -> GameState:
	var state := CAPACITY._state({"entity_kind": "building", "building": input.building, "kind": "station", "count": input.count, "production": input.production, "logistics": input.logistics})
	var building: Dictionary = state.buildings[state.buildings.keys()[0]]
	if input.building.is_empty(): building.type = ""
	building.station = StationSystem.empty_station(building.type)
	for slot in building.station.slots:
		slot.capacity *= maxf(1, floorf(float(input.count)))
		slot.max_stock = input.maxStock
		slot.item_id = "iron_ore"
	return state

static func _query(state: GameState) -> float:
	var building: Dictionary = state.buildings[state.buildings.keys()[0]]
	return StationSystem.capacity_for(building.station.slots[0], state, building)

func _check(ok: bool, message: String) -> void:
	assertions.append(message)
	if not ok:
		failures.append(message)
		errors.append(KEY + ": " + message)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}

static func rejection_errors() -> Array[String]:
	var failures: Array[String] = []
	var runner = load("res://scripts/test/SlotCapacityBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	for kind in ["commit", "source", "missing_module", "extra_module", "environment", "function", "buildings", "counts", "limits", "stocks", "missing", "duplicate", "row", "count", "count_bool", "stock", "stock_bool", "limit", "output_shape", "output_bool"]:
		var broken := fixture.duplicate(true)
		match kind:
			"commit": broken.source_commit = "wrong"
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing_module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": broken.source_files["src/game/unknown-slot-capacity.ts"] = null
			"environment": broken.source_environment.DEV = true
			"function": broken.functions.append("unknown")
			"buildings": broken.buildings.pop_back()
			"counts": broken.counts[0] = 1.0 + 5.0e-10
			"limits": broken.limits[0][1] = 1000
			"stocks": broken.stocks[0] = 0
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"row": broken.cases[0] = []
			"count": broken.cases[0].input.count = 1.0 + 5.0e-10
			"count_bool": broken.cases[0].input.count = true
			"stock": broken.cases[0].input.maxStock = -1.0 + 5.0e-10
			"stock_bool": broken.cases[0].input.maxStock = false
			"limit": broken.cases[0].input.logistics = 999
			"output_shape": broken.cases[0].expected.extra = 0
			"output_bool": broken.cases[0].expected.getStationSlotCapacity = true
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("slot capacity " + kind + " drift grants a key")
	var broken := fixture.duplicate(true)
	broken.cases[0].expected.getStationSlotCapacity += 1
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("wrong slot output grants its key")
	for kind in ["inventory", "queue", "history", "spatial"]:
		rejected = runner.new().run({}, func(id, state):
			if id != "interstellar_logistics_station-default-c0-s0": return
			match kind:
				"inventory": state.construction_inventory.dsp_interstellar_logistics_station = 7
				"queue": state.research_queue.append("dsp_mining_speed_2")
				"history": state.command_history.undo_entries[0].label = "changed"
				"spatial": state._spatial_index.clear()
		)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("slot capacity " + kind + " ownership mutation grants a key")
	return failures
