extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-resource-manual.json"
const FIXTURE_SHA := "11afe4304f7e0737df415d51470df56dfa41eb706b0ce6d874d0168b5cfcff9d"
const KEY := "commands:engine.manualMine"
const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors := []
var assertions := []

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	assertions.clear()
	if FileAccess.get_sha256(FIXTURE) != FIXTURE_SHA: return _rejected("manual mining frozen fixture drift")
	var original := DSPOnlineParity.read_json(FIXTURE)
	var gold := original if fixture_override.is_empty() else fixture_override
	if JSON.stringify(gold, "", true, true) != JSON.stringify(original, "", true, true): return _rejected("manual mining source input/output drift")
	var catalog := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if gold.get("source_commit") != catalog.get("source", {}).get("commit"): return _rejected("manual mining source commit drift")
	for file in gold.source_files:
		if gold.source_files[file] != catalog.source.files.get(file): return _rejected("manual mining module hash drift")
	if gold.cases.size() != 208: return _rejected("manual mining case coverage drift")
	var ids := {}
	for row in gold.cases:
		if ids.has(row.id): return _rejected("duplicate manual mining case")
		ids[row.id] = true
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.progression_facts.infinite_research = {"vein_utilization": {"level": row.input.level, "invested": "0"}}
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		planets.initialize_colonized_resource_sites()
		state.set_resource_mode(row.input.mode)
		var site: Dictionary = {}
		for candidate in planets.get_planet_resource_sites(row.input.planet):
			if candidate.item_id == row.input.item: site = state.resource_sites[candidate.id]; break
		_check(not site.is_empty(), row.id + ": actual resource identity")
		if site.is_empty(): continue
		if row.input.count > 0:
			var type := OUTPUT.extractor_type(row.input.item)
			state.construction_inventory[type] = 1
			var placed := state.try_place_building(type, site.position)
			_check(placed.ok and state.construction_inventory[type] == 0, row.id + ": paid count-one setup")
			if not placed.ok: continue
			var building: Dictionary = state.buildings[placed.id]
			building.machine_count = row.input.count
			building.output_buffer = {row.input.item: row.input.current}
		else: site.output_buffer = {row.input.item: row.input.current}
		site.remaining = row.input.remaining
		site.depletion_remainder = row.input.remainder
		var before := OWNER._ownership(state)
		OUTPUT.amount(state, site)
		OUTPUT.manual_capacity(state, site)
		_check(before == OWNER._ownership(state), row.id + ": queries preserve all owners")
		var trays := {}
		for planet in state.colonized_planet_ids: trays[planet] = state.get_planet_inventory(planet).duplicate(true)
		var cursor := state.cursor_payload.duplicate(true)
		SourceProgressionFacts.mine(state, site.id, row.input.amount)
		var actual := {"output": OUTPUT.amount(state, site), "remaining": site.remaining, "remainder": site.get("depletion_remainder", 0), "produced": state.progression_facts.get("produced", {}).get(row.input.item, 0), "mined": state.progression_facts.get("manual_mined", 0)}
		var expected := {"output": row.expected.outputs.get(row.input.item, 0), "remaining": row.expected.remaining, "remainder": row.expected.remainder, "produced": row.expected.total_produced, "mined": row.expected.manual_mined}
		for field in actual:
			_check(OWNER._number(actual[field]) and OWNER._number(expected[field]) and float(actual[field]) == float(expected[field]), row.id + ": frozen " + field)
		for planet in trays: _check(state.get_planet_inventory(planet) == trays[planet], row.id + ": tray owner retained " + planet)
		_check(state.cursor_payload == cursor, row.id + ": cursor owner retained")
	var keys := [KEY] if errors.is_empty() and not assertions.is_empty() else []
	var claims := {KEY: {"assertions": assertions.duplicate(), "failures": errors.duplicate()}}
	var proofs := {}
	if not keys.is_empty(): proofs[KEY] = {"suite": "task27-resource-manual", "fixture": FIXTURE, "fixture_sha256": FIXTURE_SHA, "assertions": assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims, "cases": ids.size()}

func _check(ok: bool, label: String) -> void:
	assertions.append(label)
	if not ok: errors.append(label)

func _rejected(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}, "cases": 0}

static func rejection_errors() -> Array:
	var failures := []
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	for kind in ["commit", "source", "input", "expected", "missing", "duplicate"]:
		var broken := fixture.duplicate(true)
		match kind:
			"commit": broken.source_commit = "wrong"
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"input": broken.cases[0].input.amount += 1
			"expected": broken.cases[0].expected.manual_mined += 1
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases[1] = broken.cases[0].duplicate(true)
		var rejected: Dictionary = load("res://scripts/test/ResourceManualBehaviorRunner.gd").new().run(broken)
		if rejected.errors.is_empty() or not rejected.verified_keys.is_empty() or not rejected.proofs.is_empty(): failures.append("fixture drift accepted: " + kind)
	return failures
