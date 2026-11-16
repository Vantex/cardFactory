extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-infinite-research.json"
const SUITE := "task27-infinite-research"
const COMPARATOR := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
const IDS := ["matrix_compression", "vein_utilization", "galactic_logistics", "stellar_harnessing", "continuum_simulation"]
const STAGES := ["half_cycle", "first_payment", "last_payment", "last_payment_automatic", "maximum_payment", "starved", "unpowered", "locked", "completed", "funded_two_seconds", "funded_three_seconds", "funded_seventeen_seconds", "automatic_funded", "high_level_batch", "two_funded_labs", "fixed_tick_funded", "fixed_tick_high_level", "sprayed_funded", "sprayed_partial_high_level", "epsilon_boundary", "sprayed_low_power_high_level", "rounded_epsilon_boundary", "epsilon_idle"]
const BUDGET_STAGES := ["zero", "negative", "first", "exact", "excess_manual", "three_levels_automatic", "exact_boundary_zero", "excess_boundary_zero", "tenth_level", "last_manual", "last_automatic", "maximum", "entire_curve"]
const COMMANDS := ["select_infinite_idle", "repeat_infinite_preserves_phase", "infinite_alongside_finite", "finite_alongside_infinite", "queue_alongside_infinite", "pause_infinite", "cancel_infinite", "pause_both", "cancel_both", "resume_finite_alongside_infinite", "switch_infinite_resets_phases", "automatic_repeat_is_noop", "automatic_change", "select_infinite_unknown", "automatic_enable"]
const KEYS := ["commands:engine.selectInfiniteResearch", "commands:engine.setInfiniteResearchAutomation", "commands:engine.investInfiniteResearchBudgetInPlace"]
var errors: Array[String] = []
var claims := {}
var _save_root := ""

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("infinite research source provenance missing")
	for required in ["src/game/engine.ts", "src/game/infiniteResearch.ts", "src/game/endgame.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(required): return _reject("infinite research source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("infinite research source hash drift")
	var required_cases := []
	var required_budgets := []
	for id in IDS:
		for stage in STAGES: required_cases.append(id + ":" + stage)
		for stage in BUDGET_STAGES: required_budgets.append(id + ":" + stage)
	if _identities(fixture.get("cases", [])) != required_cases or _identities(fixture.get("budgets", [])) != required_budgets: return _reject("infinite research cases incomplete, duplicated or reordered")
	if fixture.get("commands", []).map(func(row): return row.id) != COMMANDS: return _reject("infinite research commands incomplete, duplicated or reordered")
	_save_root = "res://.godot/task27-infinite-saves-%d/" % Time.get_ticks_usec()
	for row in fixture.cases:
		var label: String = row.id + ":" + row.stage
		var setup := _state(row.input)
		var state: GameState = setup.state
		state.progression_facts.erase("active_infinite")
		_check(InfiniteResearchSystem.new(state).select(row.id) == row.selection_changed, label + ": actual target eligibility")
		# The source input records lab phases after selection, including stopped peers.
		_set_labs(state, setup.labs, row.input.view.labs)
		_advance(state, row.seconds, row.simulation_step)
		_compare(row.expected, state, setup.labs, label, row.phase_rounding_bound)
		_disk(state, setup.labs, row.loaded_after, label, row.phase_rounding_bound)
		if row.stage in ["half_cycle", "first_payment", "last_payment", "last_payment_automatic", "maximum_payment"]: _resume(row, GameStateCodec.to_persistent_dict(state))
	for row in fixture.commands:
		var setup := _state(row.input, row.setup)
		var state: GameState = setup.state
		_compare(row.input.view, state, setup.labs, row.id + ": actual setup")
		var before := GameStateCodec.to_persistent_dict(state)
		_check(command(state, row.action) == row.changed, row.id + ": actual command acceptance and no-op")
		_compare(row.expected, state, setup.labs, row.id)
		if not row.changed: _check(GameStateCodec.to_persistent_dict(state) == before, row.id + ": no-op preserves all persistent ownership")
		_disk(state, setup.labs, row.loaded_after, row.id)
	for row in fixture.budgets:
		var setup := _state(row.input)
		var state: GameState = setup.state
		var service := InfiniteResearchSystem.new(state)
		var label: String = row.id + ":budget:" + row.stage
		if not service.has_method("invest_budget"):
			_check(false, label + ": actual exact budget command exists")
			continue
		var consumed: Variant = service.call("invest_budget", row.id, row.requested)
		_check(consumed is String and consumed == row.consumed, label + ": exact consumed budget and remainder")
		_compare(row.expected, state, setup.labs, label)
		var settled := GameStateCodec.to_persistent_dict(state)
		_check(service.call("invest_budget", row.id, "0") == "0" and COMPARATOR._difference(GameStateCodec.to_persistent_dict(state), settled).is_empty(), label + ": repeated zero settlement never grants score again")
		_disk(state, setup.labs, row.loaded_after, label)
	_validation_and_invalid_budgets(fixture)
	var keys: Array[String] = []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

func _state(input: Dictionary, setup_actions: Variant = null) -> Dictionary:
	var view: Dictionary = input.view
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	for id in view.finite.completedTechIds: state.completed_technologies.append("dsp_" + id)
	for id in input.campaign.completedTaskIds: state.completed_objective_ids.append("dsp_" + id)
	for id in input.campaign.rewardedTaskIds: state.claimed_progression_reward_ids.append("objective:dsp_" + id)
	state.research_current_id = _prefixed(view.finite.selectedTechId)
	state.research_paused_id = _prefixed(view.finite.pausedTechId)
	state.research_queue = view.finite.queuedTechIds.map(func(id): return "dsp_" + String(id))
	for id in view.finite.progressByTech:
		state.research_invested_costs["dsp_" + id] = view.finite.progressByTech[id].duplicate(true)
		var paid := 0.0
		for amount in view.finite.progressByTech[id].values(): paid += float(amount)
		state.research_progress["dsp_" + id] = paid * 3.0
	for id in [state.research_current_id, state.research_paused_id]:
		if not id.is_empty() and not state.research_invested_costs.has(id): state.research_invested_costs[id] = {}
	state.progression_facts["infinite_research"] = {}
	for id in view.progress: state.progression_facts.infinite_research[id] = {"level": int(view.progress[id].level), "invested": view.progress[id].progress}
	state.progression_facts["active_infinite"] = _nullable(view.active)
	state.progression_facts["infinite_paused"] = false
	state.progression_facts["infinite_auto"] = view.automatic
	state.galactic_exports = GalacticExportSystem._initial_state()
	state.galactic_exports.score = view.score
	state.galactic_exports.credits = view.credits
	state.construction_inventory.clear()
	for id in view.construction: state.construction_inventory[id if DataManager.belt_definitions().has(id) else "dsp_" + id] = view.construction[id]
	for index in range(int(input.wind_count)): state.add_building({"type": "dsp_wind_turbine", "position": Vector2(index * 100, -200), "input_buffer": {}, "output_buffer": {}})
	var labs := []
	for index in range(view.labs.size()):
		var lab := state.add_building({"type": "dsp_matrix_lab", "position": Vector2(200 + index * 200, 0), "input_buffer": {}, "output_buffer": {}})
		_check(state.set_entity_recipe(lab, "dsp_matrix_research"), "actual infinite research lab configured")
		labs.append(lab)
	if setup_actions is Array:
		state.research_current_id = ""
		state.research_paused_id = ""
		state.research_queue.clear()
		state.research_invested_costs.clear()
		state.research_progress.clear()
		state.progression_facts.active_infinite = ""
		state.progression_facts.infinite_auto = true
		for action in setup_actions: _check(command(state, action), "actual finite/infinite setup command " + str(action))
	_set_labs(state, labs, view.labs)
	return {"state": state, "labs": labs}

static func command(state: GameState, action: Array) -> bool:
	var finite := TechnologySystem.new(state)
	var infinite := InfiniteResearchSystem.new(state)
	match action[0]:
		"finite": return finite.start_research("dsp_" + String(action[1]))
		"infinite": return infinite.select(action[1])
		"pause": return finite.pause_research()
		"resume": return finite.resume_research()
		"cancel": return finite.cancel_research()
		"automatic": return infinite.call("set_automation", action[1]) if infinite.has_method("set_automation") else false
	return false

static func _set_labs(state: GameState, labs: Array, expected: Array) -> void:
	for index in range(labs.size()):
		state.buildings[labs[index]].input_buffer = expected[index].inputs.duplicate(true)
		state.buildings[labs[index]].output_buffer = expected[index].outputs.duplicate(true)
		state.buildings[labs[index]].progress = float(expected[index].progress) * 3.0
		if expected[index].get("sprayCoaterInstalled", false):
			state.buildings[labs[index]].merge({"spray_coater_installed": true, "proliferator_tier": float(expected[index].proliferatorTier), "proliferator_mode": expected[index].proliferatorMode, "proliferator_points": float(expected[index].get("proliferatorPoints", 0)), "proliferator_bonus": expected[index].get("proliferatorBonusProgress", {}).duplicate(true)}, true)

static func _advance(state: GameState, seconds: float, step_limit: float = 1.0) -> void:
	var power := PowerSystem.new(state)
	var research := TechnologySystem.new(state)
	var remaining := seconds
	while remaining > 0.0000001:
		var step := minf(remaining, step_limit)
		power.update(step)
		research.update_source_labs(step)
		remaining -= step

func _compare(expected: Dictionary, state: GameState, labs: Array, label: String, phase_bound: float = 0.000000001) -> void:
	var finite := TechnologySystem.new(state)
	var infinite := InfiniteResearchSystem.new(state)
	_check(state.research_current_id == _prefixed(expected.finite.selectedTechId) and finite.get_paused_research() == _prefixed(expected.finite.pausedTechId), label + ": finite current and paused ownership")
	_check(state.research_queue.map(func(id): return String(id).trim_prefix("dsp_")) == expected.finite.queuedTechIds, label + ": complete finite queue")
	var completed: Array = state.completed_technologies.map(func(id): return String(id).trim_prefix("dsp_"))
	var wanted: Array = expected.finite.completedTechIds.duplicate()
	completed.sort()
	wanted.sort()
	_check(completed == wanted, label + ": finite completion set unchanged")
	var invested := {}
	for id in state.research_invested_costs:
		if not state.research_invested_costs[id].is_empty(): invested[String(id).trim_prefix("dsp_")] = state.research_invested_costs[id]
	var wanted_invested := {}
	for id in expected.finite.progressByTech:
		if not expected.finite.progressByTech[id].is_empty(): wanted_invested[id] = expected.finite.progressByTech[id]
	_check(COMPARATOR._difference(invested, wanted_invested).is_empty(), label + ": finite matrix ownership retained")
	_check(infinite.active() == _nullable(expected.active) and state.progression_facts.get("infinite_auto", false) == expected.automatic, label + ": active target and independent automation")
	for id in IDS: _check(infinite.level(id) == int(expected.progress[id].level) and infinite.invested(id) == expected.progress[id].progress, label + ": exact level and decimal investment " + id)
	_check(float(state.galactic_exports.get("score", 0)) == float(expected.score) and float(state.galactic_exports.get("credits", 0)) == float(expected.credits), label + ": real completion score and credits")
	var stock := {}
	for id in state.construction_inventory:
		if float(state.construction_inventory[id]) > 0: stock[String(id).trim_prefix("dsp_")] = state.construction_inventory[id]
	var expected_stock := {}
	for id in expected.construction:
		if float(expected.construction[id]) > 0: expected_stock[id] = expected.construction[id]
	_check(COMPARATOR._difference(stock, expected_stock).is_empty(), label + ": construction ownership retained")
	for index in range(labs.size()):
		var actual: Dictionary = state.buildings[labs[index]]
		_check(absf(float(actual.progress) / 3.0 - float(expected.labs[index].progress)) <= phase_bound, label + ": lab %d phase within frozen rounding bound" % index)
		_check(COMPARATOR._difference(actual.input_buffer, expected.labs[index].inputs).is_empty() and COMPARATOR._difference(actual.output_buffer, expected.labs[index].outputs).is_empty(), label + ": lab %d complete matrix ownership" % index)
		_check(float(actual.get("proliferator_points", 0)) == float(expected.labs[index].get("proliferatorPoints", 0)) and COMPARATOR._difference(actual.get("proliferator_bonus", {}), expected.labs[index].get("proliferatorBonusProgress", {})).is_empty(), label + ": lab %d complete spray ownership" % index)

func _disk(state: GameState, labs: Array, expected: Dictionary, label: String, phase_bound: float = 0.000000001) -> void:
	var before := GameStateCodec.to_persistent_dict(state)
	var saves := SaveSystem.new(_save_root + label.replace(":", "-"))
	var saved := saves.save_slot(0, state)
	var loaded := saves.load_slot(0) if saved.ok else {}
	_check(saved.ok and loaded.get("ok", false), label + ": actual disk save and load" + (" " + str(saved) + " " + str(loaded) if not loaded.get("ok", false) else ""))
	if not loaded.get("ok", false): return
	_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), before).is_empty(), label + ": disk retains complete canonical ownership")
	_compare(expected, loaded.state, labs, label + ": actual frozen storage migration", phase_bound)

func _resume(row: Dictionary, uninterrupted: Dictionary) -> void:
	var setup := _state(row.input)
	var state: GameState = setup.state
	var halfway := minf(float(row.seconds) / 2.0, 0.01)
	_advance(state, halfway)
	_check(float(state.buildings[setup.labs[0]].progress) > 0 and float(state.buildings[setup.labs[0]].input_buffer.universe_matrix) == 1, row.id + ":" + row.stage + ": disk interruption before actual payment")
	var before := GameStateCodec.to_persistent_dict(state)
	var saves := SaveSystem.new(_save_root + row.id + "-" + row.stage + "-resume")
	var saved := saves.save_slot(0, state)
	var loaded := saves.load_slot(0) if saved.ok else {}
	_check(saved.ok and loaded.get("ok", false), row.id + ":" + row.stage + ": unfinished cycle disk save and load" + (" " + str(saved) if not saved.ok else ""))
	if not loaded.get("ok", false): return
	_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), before).is_empty(), row.id + ":" + row.stage + ": partial phase and decimal ownership retained")
	_advance(loaded.state, float(row.seconds) - halfway)
	_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), uninterrupted).is_empty(), row.id + ":" + row.stage + ": disk continuation equals uninterrupted laboratory")

func _check(ok: bool, label: String) -> void:
	for key in KEYS:
		if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
		if not claims[key].assertions.has(label): claims[key].assertions.append(label)
		if not ok: claims[key].failures.append(label)
	if not ok: errors.append(label)

static func _identities(rows: Array) -> Array:
	return rows.map(func(row): return String(row.id) + ":" + String(row.stage))

func _validation_and_invalid_budgets(fixture: Dictionary) -> void:
	var setup := _state(fixture.cases[0].input)
	var state: GameState = setup.state
	var before := GameStateCodec.to_persistent_dict(state)
	var service := InfiniteResearchSystem.new(state)
	for invalid in ["01", "1.0", "invalid", "1".repeat(129)]:
		_check(service.call("invest_budget", "matrix_compression", invalid) == "0" and GameStateCodec.to_persistent_dict(state) == before, "invalid exact budget is rejected without ownership change: " + invalid.substr(0, 12))
	_check(service.call("invest_budget", "unknown", "1") == "0" and GameStateCodec.to_persistent_dict(state) == before, "unknown budget target preserves complete ownership")
	for invalid in [1.5, "1", 0, 4]:
		var malformed := before.duplicate(true)
		malformed.galactic_exports.projects.universe_archive.priority = invalid
		_check(GameStateCodec.from_persistent_dict(JSON.parse_string(JSON.stringify(malformed))) == null, "non-enumerated galactic priority still rejected: " + str(invalid))
	var legacy := before.duplicate(true)
	legacy.research_current_id = "factory_foundations"
	_check(SourceProgressionFacts.validate(legacy).has("原生教学和无限研究不能同时进行"), "native teaching and active infinite ownership remain incompatible")

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}

static func _nullable(value: Variant) -> String:
	return "" if value == null else String(value)

static func _prefixed(value: Variant) -> String:
	return "" if value == null else "dsp_" + String(value)
