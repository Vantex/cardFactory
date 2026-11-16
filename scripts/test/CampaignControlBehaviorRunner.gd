extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-campaign-controls.json"
const STAGES := ["zero", "exact", "locked", "completed_rewarded"]
const REFERENCE := preload("res://scripts/test/ProgressionBehaviorRunner.gd")
const COMPARATOR := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
var errors: Array[String] = []
var assertions: Array[String] = []
var _catalog := {}
var _save_root := ""

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	assertions.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("campaign control provenance missing")
	for required in ["src/game/engine.ts", "src/game/campaign.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(required): return _reject("campaign control source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("campaign control source hash drift")
	var identities := ["unknown", "empty", "unsettled_achievement", "initial", "initial_no_selection", "initial_blocked_selection", "initial_select_side", "initial_select_miner", "network_split_short", "network_split_exact"]
	for row in source.catalog.campaign:
		for stage in STAGES: identities.append(row.id + ":" + stage)
	identities.sort()
	if not fixture.get("cases") is Array: return _reject("campaign control cases missing")
	var actual: Array = fixture.cases.map(func(row): return row.id)
	actual.sort()
	if actual != identities: return _reject("campaign control cases missing, duplicated or unknown")
	_catalog = ObjectiveSystem.load_catalog()
	for field in ["chapters", "objectives", "achievements"]:
		_catalog[field] = _catalog[field].filter(func(row): return row.has("source_id"))
	_save_root = "res://.godot/task27-campaign-control-saves-%d/" % Time.get_ticks_usec()
	for row in fixture.cases:
		var state: GameState = REFERENCE.new()._state(row.input, "campaign-control", row.id)
		var service := ProgressionSystem.new(state, _catalog)
		var before := _ownership(state)
		_compare(state, row.before, row.id + ": before")
		_check(_ownership(state) == before, row.id + ": source view query preserves raw and canonical ownership")
		var accepted := service.select_objective("dsp_" + row.targetId)
		_check(accepted == row.changed, row.id + ": actual selection acceptance")
		if not accepted: _check(_ownership(state) == before, row.id + ": rejected selection preserves raw and canonical ownership")
		_compare(state, row.expected, row.id + ": selected")
		var selected := _ownership(state)
		var repeated := service.select_objective("dsp_" + row.targetId)
		_check(repeated == row.repeat_changed, row.id + ": actual repeated selection acceptance")
		_compare(state, row.repeated, row.id + ": repeated")
		_check(_ownership(state) == selected, row.id + ": repeated selection preserves exact ownership")
		_disk(state, row.loaded_after, row.id)
	# These are domain preparation results. Formal callback/UI evidence is required
	# before the batch can produce any matrix verification keys.
	return {"errors": errors.duplicate(), "assertions": assertions.duplicate(), "verified_keys": [], "proofs": {}, "claims": {}}

func _compare(state: GameState, expected: Dictionary, label: String) -> void:
	var active: Variant = null if state.selected_source_objective.is_empty() else state.selected_source_objective.trim_prefix("dsp_")
	_check(active == expected.campaign.activeTaskId, label + ": exact tracked task")
	var local := ProgressionSystem.new(state, _catalog).get_source_objectives()
	var expected_tasks: Array = expected.snapshot.chapters.reduce(func(tasks, chapter): return tasks + chapter.tasks, [])
	_check(local.size() == expected_tasks.size(), label + ": complete task query row count")
	for task in expected_tasks:
		var matches: Array = local.filter(func(row): return row.source_id == task.id)
		_check(matches.size() == 1, label + ": unique task " + task.id)
		if matches.size() != 1: continue
		var row: Dictionary = matches[0]
		var status: String = "complete" if row.status == "completed" else "active" if row.status == "available" and active == task.id else row.status
		_check(status == task.status, label + ": task status " + task.id + " actual=" + status + " source=" + task.status)
		_check(row.progress.current == task.progress.current and row.progress.required == task.progress.target and row.progress.complete == task.progress.complete, label + ": task progress " + task.id)
		_check(row.title == task.title and row.description == task.description and row.track == task.track, label + ": player-visible task content " + task.id)
		_check(COMPARATOR._difference(row.requirements, task.requirements).is_empty(), label + ": actual task material requirements " + task.id)
		var source_deficit: Array = expected.deficits.filter(func(deficit): return deficit.id == task.id)
		_check(source_deficit.size() == 1 and COMPARATOR._difference(row.deficits, source_deficit[0].items).is_empty(), label + ": actual network material deficits " + task.id)
	var chapters: Array = _catalog.chapters
	_check(chapters.size() == expected.snapshot.chapters.size(), label + ": complete source chapter count")
	for chapter in expected.snapshot.chapters:
		var matches: Array = chapters.filter(func(row): return row.source_id == chapter.id)
		_check(matches.size() == 1, label + ": unique source chapter " + chapter.id)
		if matches.size() != 1: continue
		var actual_chapter: Dictionary = matches[0]
		_check(actual_chapter.title == chapter.name and actual_chapter.summary == chapter.summary and actual_chapter.objective_ids.map(func(id): return String(id).trim_prefix("dsp_")) == chapter.taskIds, label + ": exact chapter content and task order " + chapter.id)
		var finished := local.filter(func(row): return row.chapter_id == actual_chapter.id and row.status == "completed").size()
		_check(finished == chapter.completedCount and (finished == chapter.tasks.size() and finished > 0) == chapter.complete, label + ": actual chapter progress " + chapter.id)
	_check(local.filter(func(row): return row.status == "completed").size() == expected.snapshot.completedCount and local.size() == expected.snapshot.totalCount, label + ": exact snapshot progress totals")
	var expected_active: Variant = null if expected.snapshot.activeTask == null else expected.snapshot.activeTask.id
	_check(active == expected_active, label + ": exact snapshot active task")
	var completed: Array = state.completed_objective_ids.map(func(id): return String(id).trim_prefix("dsp_"))
	var wanted: Array = expected.campaign.completedTaskIds.duplicate()
	completed.sort()
	wanted.sort()
	_check(completed == wanted, label + ": exact completion ownership")
	var rewarded := []
	for id in state.claimed_progression_reward_ids:
		if String(id).begins_with("objective:dsp_"): rewarded.append(String(id).trim_prefix("objective:dsp_"))
	wanted = expected.campaign.rewardedTaskIds.duplicate()
	rewarded.sort()
	wanted.sort()
	_check(rewarded == wanted, label + ": exact reward ownership")
	var achievements: Array = state.completed_achievement_ids.map(func(id): return String(id).trim_prefix("dsp_"))
	wanted = expected.achievements.unlockedIds.duplicate()
	achievements.sort()
	wanted.sort()
	_check(achievements == wanted, label + ": exact achievement ownership allowing canonical order")

func _disk(state: GameState, expected: Dictionary, label: String) -> void:
	var service := SaveSystem.new(_save_root + label.replace(":", "-"))
	var canonical := GameStateCodec.to_persistent_dict(state)
	var saved := service.save_slot(0, state)
	var loaded := service.load_slot(0) if saved.ok else {}
	_check(saved.ok and loaded.get("ok", false), label + ": actual disk save/load " + str(saved.get("error", {})))
	if not loaded.get("ok", false): return
	_check(COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), canonical).is_empty(), label + ": complete canonical disk roundtrip")
	_compare(loaded.state, expected, label + ": actual source storage result")

static func _ownership(state: GameState) -> Dictionary:
	var raw := {"selected": state.selected_source_objective, "completed": state.completed_objective_ids, "rewarded": state.claimed_progression_reward_ids, "achievements": state.completed_achievement_ids, "facts": state.progression_facts, "buildings": state.buildings, "connections": state.connections, "construction": state.construction_inventory, "inventories": state.planet_inventories, "cargo": state.cursor_payload}.duplicate(true)
	return {"raw": raw, "canonical": GameStateCodec.to_persistent_dict(state)}

func _check(ok: bool, label: String) -> void:
	assertions.append(label)
	if not ok: errors.append(label)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "assertions": [], "verified_keys": [], "proofs": {}, "claims": {}}
