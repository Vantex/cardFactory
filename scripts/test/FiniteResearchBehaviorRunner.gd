extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-finite-research.json"
const SUITE := "task27-finite-research"
const COMPARATOR := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary or not fixture.source_files.has("src/game/engine.ts") or not fixture.source_files.has("src/game/content.ts"): return _rejected("finite research source provenance missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _rejected("finite research source hash drift")
	var definitions := {}
	var required := {}
	for row in source.catalog.technologies:
		definitions[row.id] = row.definition
		var stages := ["select", "queue"] if row.definition.get("deprecated", false) else ["half_cycle", "first_payment", "last_payment", "starved", "paused", "unpowered"]
		if not row.definition.get("deprecated", false) and not row.definition.prerequisites.is_empty(): stages.append("locked")
		for stage in stages: required[row.id + ":" + stage] = true
	var seen := {}
	for row in fixture.get("cases", []):
		var identity: String = row.id + ":" + row.stage
		if not required.has(identity) or seen.has(identity): return _rejected("duplicate or unknown finite research case")
		seen[identity] = true
	if seen.size() != required.size(): return _rejected("finite research stages incomplete")
	for id in definitions:
		var key: String = "technologies:" + id
		var actual := DataManager.get_technology("dsp_" + id)
		var definition: Dictionary = definitions[id]
		_check(key, actual.get("source_id") == id and actual.get("deprecated", false) == definition.get("deprecated", false), "exact technology identity and deprecated policy")
		_check(key, actual.get("cost") == RecipeBehaviorRunner._amounts(definition.costs, true) and actual.get("prerequisites") == definition.prerequisites.map(func(parent): return "dsp_" + String(parent)), "complete finite matrix costs and prerequisite identities")
		_check(key, actual.get("name") == definition.name and actual.get("description") == definition.summary and actual.get("unlock_descriptions") == definition.unlocks, "complete source descriptions and unlock presentation")
	for row in fixture.cases:
		var key: String = "technologies:" + row.id
		var setup := _state(row, key)
		var state: GameState = setup.state
		var ticks := roundi(float(row.seconds) * 60)
		_advance(state, ticks)
		_compare(row, state, setup.lab, key)
		var technology := TechnologySystem.new(state)
		var before := GameStateCodec.to_persistent_dict(state)
		var repeated := technology.start_research("dsp_" + row.id)
		var source_changed: bool = not COMPARATOR._difference(row.expected.repeated_selection, row.expected.research).is_empty() or not COMPARATOR._difference(row.expected.repeated_construction, row.expected.construction).is_empty()
		_check(key, repeated == source_changed and _selection_matches(state, row.expected.repeated_selection), row.stage + ": repeated selection matches actual frozen command")
		_check(key, state.construction_inventory == before.construction_inventory, row.stage + ": repeated selection never grants construction again")
		if not source_changed: _check(key, GameStateCodec.to_persistent_dict(state) == before, row.stage + ": frozen no-op selection preserves all persistent ownership")
		var restored := GameStateCodec.from_persistent_dict(before)
		_check(key, restored != null and COMPARATOR._difference(GameStateCodec.to_persistent_dict(restored), before).is_empty(), row.stage + ": invested matrices and ownership survive validated codec")
		if row.stage in ["first_payment", "last_payment"]: _resume(row, key, ticks, before)
	var keys: Array[String] = []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

func _state(row: Dictionary, key: String) -> Dictionary:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	for id in row.input.campaign.completedTaskIds: state.completed_objective_ids.append("dsp_" + id)
	for id in row.input.campaign.rewardedTaskIds: state.claimed_progression_reward_ids.append("objective:dsp_" + id)
	for id in row.input.before_selection.completedTechIds: state.completed_technologies.append("dsp_" + id)
	state.construction_inventory.clear()
	for id in row.input.construction: state.construction_inventory[_construction_id(id)] = row.input.construction[id]
	for index in range(int(row.input.wind_count)): state.add_building({"type": "dsp_wind_turbine", "position": Vector2(index * 100, -100), "input_buffer": {}, "output_buffer": {}})
	var lab := state.add_building({"type": "dsp_matrix_lab", "recipe_id": "", "position": Vector2(200, 0), "speed": 1.0, "input_buffer": {}, "output_buffer": {}, "progress": 0.0})
	_check(key, state.set_entity_recipe(lab, "dsp_matrix_research"), row.stage + ": actual lab research recipe selected")
	var technology := TechnologySystem.new(state)
	if row.stage == "queue": _check(key, technology.start_research("dsp_basic_logistics"), "queue: actual eligible current research selected")
	var selected := technology.add_to_queue("dsp_" + row.id) if row.stage == "queue" else technology.start_research("dsp_" + row.id)
	var expected_selected: bool = row.input.selection.selectedTechId == row.id or row.input.selection.queuedTechIds.has(row.id)
	_check(key, selected == expected_selected, row.stage + ": actual selection/queue eligibility matches frozen command")
	if row.stage == "paused": _check(key, technology.pause_research(), "paused: actual research pause command")
	state.buildings[lab].input_buffer = row.input.subject.inputs.duplicate(true)
	for id in row.input.research.progressByTech:
		var invested: Dictionary = row.input.research.progressByTech[id].duplicate(true)
		state.research_invested_costs["dsp_" + id] = invested
		var paid := 0.0
		for item in invested: paid += float(invested[item])
		state.research_progress["dsp_" + id] = paid * float(DataManager.get_recipe("dsp_matrix_research").duration)
	return {"state": state, "lab": lab}

static func _selection_matches(state: GameState, expected: Dictionary) -> bool:
	var selected := "" if state.research_paused else state.research_current_id.trim_prefix("dsp_")
	var paused := TechnologySystem.new(state).get_paused_research().trim_prefix("dsp_")
	return selected == _nullable_id(expected.selectedTechId) and paused == _nullable_id(expected.pausedTechId) and state.research_queue.map(func(id): return String(id).trim_prefix("dsp_")) == expected.queuedTechIds

func _advance(state: GameState, ticks: int) -> void:
	var power := PowerSystem.new(state)
	var research := TechnologySystem.new(state)
	var statistics := StatisticsSystem.new(state)
	# Match the source fixture's one-second boundaries in this lab-only pipeline.
	var remaining := float(ticks) / 60.0
	while remaining > 0.0000001:
		var step := minf(remaining, 1.0)
		power.update(step)
		research.update_source_labs(step, statistics)
		remaining -= step

func _compare(row: Dictionary, state: GameState, lab: String, key: String) -> void:
	var expected: Dictionary = row.expected.research
	var selected := "" if state.research_paused else state.research_current_id.trim_prefix("dsp_")
	var paused := TechnologySystem.new(state).get_paused_research().trim_prefix("dsp_")
	_check(key, selected == _nullable_id(expected.selectedTechId) and paused == _nullable_id(expected.pausedTechId) and state.research_queue.map(func(id): return String(id).trim_prefix("dsp_")) == expected.queuedTechIds, row.stage + ": current, paused and queue state")
	var completed: Array = state.completed_technologies.map(func(id): return String(id).trim_prefix("dsp_"))
	var wanted: Array = expected.completedTechIds.duplicate()
	completed.sort()
	wanted.sort()
	_check(key, completed == wanted, row.stage + ": actual finite completion boundary")
	_check(key, COMPARATOR._difference(state.research_invested_costs.get("dsp_" + row.id, {}), expected.progressByTech.get(row.id, {})).is_empty(), row.stage + ": complete persisted matrix payment ledger", "actual=" + str(state.research_invested_costs.get("dsp_" + row.id, {})) + " expected=" + str(expected.progressByTech.get(row.id, {})))
	_check(key, COMPARATOR._difference(state.buildings[lab].input_buffer, row.expected.subject.inputs).is_empty(), row.stage + ": exact actual lab matrix consumption")
	var phase := float(state.buildings[lab].progress) / float(DataManager.get_recipe("dsp_matrix_research").duration)
	_check(key, absf(phase - float(row.expected.subject.progress)) <= float(row.phase_rounding_bound), row.stage + ": lab phase within source rounding bound")
	var stock := {}
	for id in state.construction_inventory:
		if float(state.construction_inventory[id]) > 0: stock[String(id).trim_prefix("dsp_")] = state.construction_inventory[id]
	var expected_stock := {}
	for id in row.expected.construction:
		if float(row.expected.construction[id]) > 0: expected_stock[id] = row.expected.construction[id]
	_check(key, COMPARATOR._difference(stock, expected_stock).is_empty(), row.stage + ": actual construction rewards once", "actual=" + str(stock) + " expected=" + str(expected_stock))
	_check(key, state.colonized_planet_ids == row.expected.colonized_planets, row.stage + ": actual colony unlock effect")

func _resume(row: Dictionary, key: String, ticks: int, expected_payload: Dictionary) -> void:
	var setup := _state(row, key)
	var state: GameState = setup.state
	var halfway := mini(ticks / 2, 45)
	_advance(state, halfway)
	_check(key, state.research_current_id == "dsp_" + row.id and float(state.buildings[setup.lab].progress) > 0, row.stage + ": disk interruption occurs in an unfinished lab cycle")
	var before := GameStateCodec.to_persistent_dict(state)
	var saves := SaveSystem.new("res://.godot/task27-research-saves-%d/" % Time.get_ticks_usec())
	var saved := saves.save_slot(0, state)
	var loaded := saves.load_slot(0) if saved.ok else {}
	_check(key, saved.ok and loaded.get("ok", false), row.stage + ": real research disk save and load")
	if not loaded.get("ok", false): return
	var resumed: GameState = loaded.state
	_check(key, COMPARATOR._difference(GameStateCodec.to_persistent_dict(resumed), before).is_empty(), row.stage + ": disk retains all partial payments and ownership")
	_advance(resumed, ticks - halfway)
	_check(key, COMPARATOR._difference(GameStateCodec.to_persistent_dict(resumed), expected_payload).is_empty(), row.stage + ": disk resume equals uninterrupted powered laboratory")

static func _construction_id(id: String) -> String:
	return id if DataManager.belt_definitions().has(id) else "dsp_" + id

static func _nullable_id(value: Variant) -> String:
	return "" if value == null else String(value)

static func _rejected(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}

func _check(key: String, ok: bool, assertion: String, detail: String = "") -> void:
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion + ("; " + detail if not detail.is_empty() else ""))
