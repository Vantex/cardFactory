extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-item-input-capacity.json"
const KEY := "commands:engine.getEntityItemInputCapacity"
const CAPACITY := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const CONTROLS := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
const ITEMS := ["iron_ore", "proliferator_mk1", "proliferator_mk2", "proliferator_mk3", "", "unknown"]
const STOCKS := [-1, 0, 1, 59.9, 600, 1200, 100000000, 1.0e12]
const SPRAY_LIMITS := [["default", 600], ["minimum", 1], ["maximum", 100000000], ["below", -1], ["fractional", 59.9], ["above", 1.0e12], ["null", null], ["boolean-false", false], ["boolean-true", true], ["string", "600"]]
var errors: Array[String] = []
var assertions: Array[String] = []
var failures: Array[String] = []

func run(fixture_override: Dictionary = {}, after_query: Callable = Callable()) -> Dictionary:
	errors.clear()
	assertions.clear()
	failures.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("item input provenance missing")
	if not CONTROLS._same_ids(fixture.source_files.keys(), CAPACITY.SOURCE_MODULES): return _reject("item input exact source modules changed")
	for file in CAPACITY.SOURCE_MODULES:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("item input frozen source hash drift")
	if not CAPACITY._exact(fixture.get("source_environment"), {"DEV": false, "PROD": true, "MODE": "production"}): return _reject("item input source environment changed")
	var buildings: Array = source.catalog.buildings.map(func(row): return row.id)
	buildings.sort()
	var stations: Array = source.catalog.buildings.filter(func(row): return row.definition.kind == "station").map(func(row): return row.id)
	stations.sort()
	if fixture.get("functions") != ["getEntityItemInputCapacity"] or not CONTROLS._same_ids(fixture.get("buildings", []), buildings) or not CONTROLS._same_ids(fixture.get("stations", []), stations) or not CAPACITY._exact(fixture.get("counts"), CAPACITY.COUNTS) or not CAPACITY._exact(fixture.get("limits"), CAPACITY.LIMITS) or not CAPACITY._exact(fixture.get("spray_limits"), SPRAY_LIMITS) or not CAPACITY._exact(fixture.get("stocks"), STOCKS) or fixture.get("items") != ITEMS: return _reject("item input declared coverage changed")
	var inputs := _inputs(source.catalog.buildings)
	if inputs.size() != 45696 or not fixture.get("cases") is Array: return _reject("item input expected coverage missing")
	var ids := []
	for row in fixture.cases:
		if not row is Dictionary: return _reject("item input case malformed")
		ids.append(row.get("id"))
	if not CONTROLS._same_ids(ids, inputs.keys()): return _reject("item input cases incomplete or duplicated")
	for row in fixture.cases:
		if not CAPACITY._exact(row.get("input"), inputs[row.id]): return _reject("item input controlled input changed: " + row.id)
		if not row.get("expected") is Dictionary or row.expected.keys() != ["getEntityItemInputCapacity"]: return _reject("item input output shape changed")
		var value: Variant = row.expected.getEntityItemInputCapacity
		if not OWNER._number(value) or value < 0 or value > 100000000 or value != floorf(float(value)): return _reject("item input source output must be a finite bounded integer")
	for row in fixture.cases:
		var state := _state(row.input)
		var id: String = state.buildings.keys()[0]
		var before := OWNER._ownership(state)
		var actual := state.get_entity_item_input_capacity(id, String(row.input.item))
		var repeated := state.get_entity_item_input_capacity(id, String(row.input.item))
		if after_query.is_valid(): after_query.call(row.id, state)
		if OWNER._ownership(state) != before: return _reject("item input query mutates raw/canonical ownership: " + row.id)
		_check(CAPACITY._exact(actual, row.expected.getEntityItemInputCapacity), row.id + ": actual per-item capacity matches frozen source")
		_check(actual == repeated, row.id + ": repeated query preserves raw and canonical ownership")
	var keys := []
	var proofs := {}
	if failures.is_empty():
		keys.append(KEY)
		proofs[KEY] = {"suite": "task27-item-input-capacity", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": {KEY: {"assertions": assertions.duplicate(), "failures": failures.duplicate()}}}

static func _input(building: String, kind: String, count: float = 1, profile: Array = CAPACITY.LIMITS[0], item: String = "iron_ore", extra: Dictionary = {}) -> Dictionary:
	var result := {"building": building, "kind": kind, "count": count, "profile": profile[0], "production": profile[1], "logistics": profile[2], "item": item, "installed": false, "tier": null, "spray_profile": "default", "spray_limit": 600, "slots": null, "legacy_item": null}
	result.merge(extra, true)
	return result

static func _inputs(buildings: Array) -> Dictionary:
	var inputs := {}
	var kinds := {}
	for row in buildings: kinds[row.id] = row.definition.kind
	for building in kinds:
		for profile in CAPACITY.LIMITS:
			for ci in range(CAPACITY.COUNTS.size()):
				for ii in range(ITEMS.size()): inputs["base-%s-%s-c%d-i%d" % [building, profile[0], ci, ii]] = _input(building, kinds[building], CAPACITY.COUNTS[ci], profile, ITEMS[ii])
		for count in [1, 3]:
			for tier in [null, 1, 2, 3]:
				for spray in SPRAY_LIMITS:
					for ii in range(ITEMS.size()): inputs["spray-%s-c%d-t%s-%s-i%d" % [building, count, "unset" if tier == null else str(tier), spray[0], ii]] = _input(building, kinds[building], count, CAPACITY.LIMITS[0], ITEMS[ii], {"installed": true, "tier": tier, "spray_profile": spray[0], "spray_limit": spray[1]})
		if kinds[building] != "station": continue
		for profile in CAPACITY.LIMITS:
			for ci in range(CAPACITY.COUNTS.size()):
				for si in range(STOCKS.size()):
					for ii in range(2): inputs["slot-%s-%s-c%d-s%d-i%d" % [building, profile[0], ci, si, ii]] = _input(building, "station", CAPACITY.COUNTS[ci], profile, ["iron_ore", "proliferator_mk1"][ii], {"slots": [["iron_ore", STOCKS[si]]]})
		for spray in SPRAY_LIMITS:
			for si in range(STOCKS.size()):
				for ii in range(2): inputs["priority-%s-%s-s%d-i%d" % [building, spray[0], si, ii]] = _input(building, "station", 3, CAPACITY.LIMITS[0], ["proliferator_mk1", "proliferator_mk2"][ii], {"installed": true, "tier": 1, "spray_profile": spray[0], "spray_limit": spray[1], "slots": [["proliferator_mk1", STOCKS[si]]]})
		for ci in range(CAPACITY.COUNTS.size()):
			for ii in range(2): inputs["legacy-%s-c%d-i%d" % [building, ci, ii]] = _input(building, "station", CAPACITY.COUNTS[ci], CAPACITY.LIMITS[0], ["iron_ore", "proliferator_mk1"][ii], {"legacy_item": "iron_ore"})
		for si in range(STOCKS.size()): inputs["duplicate-%s-s%d" % [building, si]] = _input(building, "station", 2, CAPACITY.LIMITS[0], "iron_ore", {"slots": [["iron_ore", STOCKS[si]], ["iron_ore", 1200]]})
	for si in range(STOCKS.size()):
		for ii in range(2): inputs["missing-building-s%d-i%d" % [si, ii]] = _input("", "station", 1, CAPACITY.LIMITS[0], ["iron_ore", "proliferator_mk1"][ii], {"slots": [["iron_ore", STOCKS[si]]]})
	return inputs

static func _state(input: Dictionary) -> GameState:
	var state := CAPACITY._state({"entity_kind": "building", "building": input.building, "kind": input.kind, "count": input.count, "production": input.production, "logistics": input.logistics})
	state.source_buffer_limits.proliferator = input.spray_limit
	var building: Dictionary = state.buildings[state.buildings.keys()[0]]
	if input.building.is_empty(): building.type = ""
	building.spray_coater_installed = input.installed
	if input.tier != null: building.proliferator_tier = input.tier
	building.station = {"slots": []}
	if input.slots != null:
		for slot in input.slots: building.station.slots.append({"item_id": slot[0], "max_stock": slot[1]})
	if input.legacy_item != null: building.stored_item = input.legacy_item
	return state

func _check(ok: bool, message: String) -> void:
	assertions.append(message)
	if not ok:
		failures.append(message)
		errors.append(KEY + ": " + message)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}

static func rejection_errors() -> Array[String]:
	var failures: Array[String] = []
	var runner = load("res://scripts/test/ItemInputCapacityBehaviorRunner.gd")
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	for kind in ["commit", "source", "missing_module", "extra_module", "environment", "function", "buildings", "stations", "counts", "limits", "spray_limits", "items", "stocks", "missing", "duplicate", "row", "count", "count_bool", "installed", "item", "tier", "spray_limit", "output_shape", "output_bool"]:
		var broken := fixture.duplicate(true)
		match kind:
			"commit": broken.source_commit = "wrong"
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing_module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": broken.source_files["src/game/unknown-item-input.ts"] = null
			"environment": broken.source_environment.DEV = true
			"function": broken.functions.append("unknown")
			"buildings": broken.buildings.pop_back()
			"stations": broken.stations.pop_back()
			"counts": broken.counts[0] = 1.0 + 5.0e-10
			"limits": broken.limits[0][1] = 1000
			"spray_limits": broken.spray_limits[0][1] = 1
			"items": broken.items[0] = "copper_ore"
			"stocks": broken.stocks[0] = 0
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"row": broken.cases[0] = []
			"count": broken.cases[0].input.count = 1.0 + 5.0e-10
			"count_bool": broken.cases[0].input.count = true
			"installed": broken.cases[0].input.installed = 0
			"item": broken.cases[0].input.item = "copper_ore"
			"tier": broken.cases[0].input.tier = 1
			"spray_limit": broken.cases[0].input.spray_limit = "600"
			"output_shape": broken.cases[0].expected.extra = 0
			"output_bool": broken.cases[0].expected.getEntityItemInputCapacity = true
		var rejected: Dictionary = runner.new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("item input " + kind + " drift grants a key")
	var broken := fixture.duplicate(true)
	broken.cases[0].expected.getEntityItemInputCapacity += 1
	var rejected: Dictionary = runner.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("wrong item input output grants its key")
	for kind in ["inventory", "queue", "history", "spatial"]:
		rejected = runner.new().run({}, func(id, state):
			if id != fixture.cases[0].id: return
			match kind:
				"inventory": state.construction_inventory.dsp_interstellar_logistics_station = 7
				"queue": state.research_queue.append("dsp_mining_speed_2")
				"history": state.command_history.undo_entries[0].label = "changed"
				"spatial": state._spatial_index.clear()
		)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty(): failures.append("item input " + kind + " ownership mutation grants a key")
	return failures
