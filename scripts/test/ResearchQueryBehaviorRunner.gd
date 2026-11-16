extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-research-queries.json"
const SUITE := "task27-research-queries"
const CASES := ["fresh", "eligible_idle", "finite_current", "finite_current_queue", "finite_paused", "paused_with_current", "paused_parent_waiting_child", "paused_parent_queueable_child", "blocked_queue_after_cancel", "infinite_current", "finite_and_infinite", "finite_paused_and_infinite", "all_completed", "infinite_raw_locked", "infinite_raw_maximum"]
const KEYS := {"select": "commands:engine.canSelectTechnology", "queue": "commands:engine.canQueueTechnology", "active": "commands:engine.hasActiveResearch", "completed": "commands:engine.isTechnologyCompleted"}
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_queries: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("research query provenance missing")
	for required in ["src/game/engine.ts", "src/game/content.ts"]:
		if not fixture.source_files.has(required): return _reject("research query source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("research query source hash drift")
	if not fixture.get("cases") is Array or fixture.cases.map(func(row): return row.id) != CASES: return _reject("research query states missing, duplicated or reordered")
	var ids: Array = source.catalog.technologies.map(func(row): return row.id)
	ids.append_array(["unknown_research", ""])
	ids.sort()
	for row in fixture.cases:
		if not row.get("expected", {}).get("technologies") is Array: return _reject("research query technology rows missing")
		var actual_ids: Array = row.expected.technologies.map(func(item): return item.id)
		actual_ids.sort()
		if actual_ids != ids: return _reject("research query technologies missing, duplicated or unknown")
	for row in fixture.cases:
		var state := _state(row.input)
		var research := TechnologySystem.new(state)
		var before := _ownership(state)
		_check("active", research.has_active_source_research() == row.expected.active, row.id + ": actual active research query")
		for wanted in row.expected.technologies:
			var id := _id(wanted.id)
			var label: String = row.id + ":" + wanted.id
			_check("select", research.can_select_source_technology(id) == wanted.select, label + ": actual finite selection query")
			_check("queue", research.can_queue_source_technology(id) == wanted.queue, label + ": actual planned prerequisites query")
			_check("completed", research.is_technology_completed(id) == wanted.completed, label + ": actual completion query")
		if after_queries.is_valid(): after_queries.call(row.id, state)
		for kind in KEYS: _check(kind, _ownership(state) == before, row.id + ": queries preserve raw and canonical ownership")
	var keys: Array[String] = []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _state(input: Dictionary) -> GameState:
	var state := GameState.new()
	for id in input.research.completedTechIds: state.completed_technologies.append("dsp_" + String(id))
	state.research_current_id = _id(input.research.selectedTechId)
	state.research_paused_id = _id(input.research.pausedTechId)
	state.research_queue = input.research.queuedTechIds.map(func(id): return _id(id))
	for id in input.research.progressByTech:
		var costs: Dictionary = input.research.progressByTech[id].duplicate(true)
		state.research_invested_costs[_id(id)] = costs
		var paid := 0.0
		for amount in costs.values(): paid += float(amount)
		state.research_progress[_id(id)] = paid * 3.0
	state.progression_facts["active_infinite"] = "" if input.endgame.activeInfiniteResearchId == null else input.endgame.activeInfiniteResearchId
	state.progression_facts["infinite_auto"] = input.endgame.autoResearch
	state.progression_facts["infinite_research"] = {}
	for id in input.endgame.infiniteResearch: state.progression_facts.infinite_research[id] = {"level": int(input.endgame.infiniteResearch[id].level), "invested": input.endgame.infiniteResearch[id].progress}
	return state

static func _ownership(state: GameState) -> Dictionary:
	var raw := {"current": state.research_current_id, "paused_id": state.research_paused_id, "paused": state.research_paused, "queue": state.research_queue, "wait": state.research_queue_wait_reason, "completed": state.completed_technologies, "progress": state.research_progress, "invested": state.research_invested_costs, "facts": state.progression_facts}.duplicate(true)
	return {"raw": raw, "canonical": GameStateCodec.to_persistent_dict(state)}

static func _id(value: Variant) -> String:
	return "" if value == null or value == "" else "dsp_" + String(value)

func _check(kind: String, ok: bool, assertion: String) -> void:
	var key: String = KEYS[kind]
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
