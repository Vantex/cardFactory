extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-research-boundaries.json"
const SUITE := "task27-research-boundaries"
const KEYS := ["commands:engine.settleCompletedResearchBoundaries", "commands:engine.settleCompletedResearchBoundariesInPlace"]
const COMPARATOR := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
const STAGES := ["partial", "exact", "overshoot", "fractional_below", "fractional_paid", "already_completed"]
const COMMAND_STAGES := ["idle", "unknown_current", "completed_current", "blocked_queue", "paid_chain", "paid_three_chain", "paused_paid", "finite_infinite_paid", "infinite_only", "missing_cost"]
var errors: Array[String] = []
var claims := {}
var _save_root := ""

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("research boundary provenance missing")
	for required in ["src/game/engine.ts", "src/game/content.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(required): return _reject("research boundary source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("research boundary source hash drift")
	var identities := []
	for row in source.catalog.technologies:
		for stage in STAGES: identities.append(row.id + ":" + stage)
	for stage in COMMAND_STAGES: identities.append("command:" + stage)
	identities.sort()
	if not fixture.get("cases") is Array: return _reject("research boundary cases missing")
	var actual: Array = fixture.cases.map(func(row): return row.id + ":" + row.stage)
	actual.sort()
	if actual != identities: return _reject("research boundary cases missing, duplicated or unknown")
	_save_root = "res://.godot/task27-boundary-saves-%d/" % Time.get_ticks_usec()
	for row in fixture.cases:
		var label: String = row.id + ":" + row.stage
		var setup := _state(row.input)
		var state: GameState = setup.state
		var research := TechnologySystem.new(state, false)
		var before: Dictionary = preload("res://scripts/test/ResearchQueryBehaviorRunner.gd")._ownership(state)
		if not research.has_method("settle_completed_source_research") or not research.has_method("settle_completed_source_research_in_place"):
			_check(false, label + ": actual public pure and in-place boundary methods exist")
			continue
		var events := []
		var observer := func(id): events.append(id)
		var queue_observer := func(queue): events.append(queue.duplicate())
		EventBus.technology_research_completed.connect(observer)
		EventBus.technology_unlocked.connect(observer)
		EventBus.technology_research_queue_changed.connect(queue_observer)
		var copied: GameState = TechnologySystem.new(state).call("settle_completed_source_research")
		EventBus.technology_research_completed.disconnect(observer)
		EventBus.technology_unlocked.disconnect(observer)
		EventBus.technology_research_queue_changed.disconnect(queue_observer)
		_check(events.is_empty(), label + ": pure result emits no live completion events")
		_check((copied != state) == row.pure_changed, label + ": pure changed or original object identity")
		_check(preload("res://scripts/test/ResearchQueryBehaviorRunner.gd")._ownership(state) == before, label + ": pure preserves raw and canonical input ownership")
		_compare(copied, setup.labs, row.pure_expected, label + ": pure output")
		var repeated: GameState = TechnologySystem.new(copied, false).call("settle_completed_source_research")
		_check((repeated != copied) == row.pure_repeated_changed, label + ": repeated pure identity")
		_compare(repeated, setup.labs, row.pure_repeated_expected, label + ": repeated pure output")
		var completed: Variant = research.call("settle_completed_source_research_in_place")
		_check(completed is Array and completed.map(func(id): return String(id).trim_prefix("dsp_")) == row.inplace_completed, label + ": exact ordered in-place completion return")
		_compare(state, setup.labs, row.inplace_expected, label + ": in-place output")
		var settled: Dictionary = preload("res://scripts/test/ResearchQueryBehaviorRunner.gd")._ownership(state)
		_check(research.call("settle_completed_source_research_in_place") == [], label + ": repeated in-place completion list empty")
		_check(preload("res://scripts/test/ResearchQueryBehaviorRunner.gd")._ownership(state) == settled, label + ": repeated in-place preserves all ownership and rewards")
		if row.stage in ["exact", "overshoot", "fractional_paid"] or row.id == "command": _disk(state, setup.labs, row.loaded_after, label)
	var keys: Array[String] = []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _mapped(view: Dictionary) -> Dictionary:
	return {"finite": view.research, "active": view.endgame.activeInfiniteResearchId, "automatic": view.endgame.autoResearch, "progress": view.endgame.infiniteResearch, "score": view.endgame.galacticScore, "credits": view.endgame.galacticCredits, "labs": view.labs, "construction": view.construction}

func _state(input: Dictionary) -> Dictionary:
	var setup: Dictionary = preload("res://scripts/test/InfiniteResearchBehaviorRunner.gd").new()._state({"view": _mapped(input.view), "campaign": input.campaign, "wind_count": 0})
	var state: GameState = setup.state
	state.colonized_planet_ids = input.view.exploration.colonizedPlanetIds.duplicate()
	for planet in state.colonized_planet_ids:
		if not state.planet_inventories.has(planet): state.planet_inventories[planet] = {}
		if not state.planet_viewports.has(planet): state.planet_viewports[planet] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
		if not state.planet_metrics.has(planet): state.planet_metrics[planet] = {}
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	if not state.research_current_id.is_empty() and DataManager.get_technology(state.research_current_id).is_empty(): state.research_invested_costs.erase(state.research_current_id)
	return setup

func _compare(state: GameState, labs: Array, expected: Dictionary, label: String) -> void:
	_check(state.research_current_id == _id(expected.research.selectedTechId) and state.research_paused_id == _id(expected.research.pausedTechId), label + ": raw current and paused references")
	_check(state.research_queue == expected.research.queuedTechIds.map(func(id): return _id(id)), label + ": exact queue order and blocked ownership")
	var completed: Array = state.completed_technologies.map(func(id): return String(id).trim_prefix("dsp_"))
	var wanted: Array = expected.research.completedTechIds.duplicate()
	completed.sort()
	wanted.sort()
	_check(completed == wanted, label + ": complete finite completion set")
	var costs := {}
	for id in state.research_invested_costs:
		if not state.research_invested_costs[id].is_empty(): costs[String(id).trim_prefix("dsp_")] = state.research_invested_costs[id]
	_check(COMPARATOR._difference(costs, expected.research.progressByTech).is_empty(), label + ": all nonempty raw matrix ledgers")
	for id in costs:
		var sum := 0.0
		for amount in costs[id].values(): sum += float(amount)
		_check(absf(state.get_technology_progress(_id(id)) - sum * 3.0) < 0.000000001, label + ": local progress tracks exactly paid matrices " + id)
	_check(COMPARATOR._difference(_stock(state.construction_inventory), _stock(expected.construction)).is_empty(), label + ": exact one-time construction rewards")
	_check(state.colonized_planet_ids == expected.exploration.colonizedPlanetIds, label + ": exact colony unlock rewards")
	_check(InfiniteResearchSystem.new(state).active() == ("" if expected.endgame.activeInfiniteResearchId == null else expected.endgame.activeInfiniteResearchId), label + ": infinite target preserved")
	_check(state.progression_facts.get("infinite_auto", false) == expected.endgame.autoResearch, label + ": independent automation preserved")
	for id in expected.endgame.infiniteResearch:
		var service := InfiniteResearchSystem.new(state)
		_check(service.level(id) == int(expected.endgame.infiniteResearch[id].level) and service.invested(id) == expected.endgame.infiniteResearch[id].progress, label + ": infinite level and decimal ledger preserved " + id)
	_check(float(state.galactic_exports.get("score", 0)) == expected.endgame.galacticScore and float(state.galactic_exports.get("credits", 0)) == expected.endgame.galacticCredits, label + ": galactic ownership preserved")
	for index in range(labs.size()):
		var lab: Dictionary = state.buildings[labs[index]]
		_check(absf(float(lab.progress) / 3.0 - expected.labs[index].progress) < 0.000000001, label + ": exact lab phase %d" % index)
		_check(COMPARATOR._difference(lab.input_buffer, expected.labs[index].inputs).is_empty() and COMPARATOR._difference(lab.output_buffer, expected.labs[index].outputs).is_empty(), label + ": complete lab buffers %d" % index)

func _disk(state: GameState, labs: Array, expected: Dictionary, label: String) -> void:
	var saves := SaveSystem.new(_save_root + label.replace(":", "-"))
	var canonical := GameStateCodec.to_persistent_dict(state)
	var saved := saves.save_slot(0, state)
	var loaded := saves.load_slot(0) if saved.ok else {}
	_check(saved.ok and loaded.get("ok", false), label + ": real settled boundary disk save/load " + str(saved.get("error", {})))
	if not loaded.get("ok", false): return
	_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), canonical).is_empty(), label + ": complete canonical disk roundtrip")
	_compare(loaded.state, labs, expected, label + ": actual frozen storage migration")

static func _stock(stock: Dictionary) -> Dictionary:
	var result := {}
	for id in stock:
		if float(stock[id]) > 0: result[String(id).trim_prefix("dsp_")] = stock[id]
	return result

static func _id(value: Variant) -> String:
	return "" if value == null or value == "" else "dsp_" + String(value)

func _check(ok: bool, assertion: String) -> void:
	for key in KEYS:
		if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
		claims[key].assertions.append(assertion)
		if not ok: claims[key].failures.append(assertion)
	if not ok: errors.append(assertion)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
