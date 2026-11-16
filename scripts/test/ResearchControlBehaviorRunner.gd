extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-research-controls.json"
const SUITE := "task27-research-controls"
const REFERENCE := preload("res://scripts/test/ResearchBoundaryBehaviorRunner.gd")
const FINITE := preload("res://scripts/test/ResearchCommandBehaviorRunner.gd")
const INFINITE := preload("res://scripts/test/InfiniteResearchBehaviorRunner.gd")
const OWNERSHIP := preload("res://scripts/test/ResearchQueryBehaviorRunner.gd")
const KEYS := ["commands:engine.selectTechnology", "commands:engine.pauseCurrentResearch", "commands:engine.resumePausedResearch", "commands:engine.cancelCurrentResearch", "commands:engine.removeQueuedTechnology"]
const EXTRA := ["empty:idle", "empty:queue", "remove:paused_parent_preserved", "remove:dependent_only", "remove:deep_cascade"]

func run(fixture_override: Dictionary = {}) -> Dictionary:
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("research control provenance missing")
	for required in ["src/game/engine.ts", "src/game/content.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(required): return _reject("research control source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("research control source hash drift")
	var identities := []
	for id in FINITE.CASES: identities.append("finite:" + id)
	for id in INFINITE.COMMANDS: identities.append("infinite:" + id)
	for row in source.catalog.technologies:
		if row.definition.get("deprecated", false):
			identities.append("deprecated:" + row.id + ":idle")
			identities.append("deprecated:" + row.id + ":queue")
	identities.append_array(EXTRA)
	identities.sort()
	if not fixture.get("cases") is Array: return _reject("research control cases missing")
	var actual: Array = fixture.cases.map(func(row): return row.id)
	actual.sort()
	if actual != identities: return _reject("research control cases missing, duplicated or unknown")
	var reference := REFERENCE.new()
	reference._save_root = "res://.godot/task27-control-saves-%d/" % Time.get_ticks_usec()
	for row in fixture.cases:
		var setup: Dictionary = reference._state(row.baseline)
		var state: GameState = setup.state
		for action in row.setup: reference._check(command(state, action), row.id + ": actual setup " + str(action))
		for id in row.input.view.research.progressByTech:
			var costs: Dictionary = row.input.view.research.progressByTech[id].duplicate(true)
			state.research_invested_costs["dsp_" + id] = costs
			var paid := 0.0
			for amount in costs.values(): paid += float(amount)
			state.research_progress["dsp_" + id] = paid * 3.0
		INFINITE._set_labs(state, setup.labs, row.input.view.labs)
		reference._compare(state, setup.labs, row.input.view, row.id + ": actual input")
		if row.id.begins_with("deprecated:"):
			var id := "dsp_" + String(row.action[1])
			var definition := DataManager.get_technology(id)
			reference._check(definition.get("deprecated", false) and not state.completed_technologies.has(id), row.id + ": deprecated target is incomplete")
			reference._check(definition.get("prerequisites", []).all(func(parent): return state.completed_technologies.has(parent)), row.id + ": every target prerequisite is completed")
			reference._check(id != state.research_current_id and not state.research_queue.has(id), row.id + ": target is neither current nor already queued")
		var before := OWNERSHIP._ownership(state)
		reference._disk(state, setup.labs, row.loaded_before, row.id + ": before")
		reference._check(OWNERSHIP._ownership(state) == before, row.id + ": saving preserves raw and canonical ownership")
		reference._check(command(state, row.action) == row.changed, row.id + ": actual control acceptance or no-op")
		reference._compare(state, setup.labs, row.expected, row.id + ": output")
		if not row.changed: reference._check(OWNERSHIP._ownership(state) == before, row.id + ": no-op preserves all raw and canonical ownership")
		reference._disk(state, setup.labs, row.loaded_after, row.id + ": after")
	var claims := {}
	var keys: Array[String] = []
	var proofs := {}
	var claim: Dictionary = reference.claims.get(REFERENCE.KEYS[0], {"assertions": [], "failures": ["research controls did not run"]})
	for key in KEYS:
		claims[key] = claim.duplicate(true)
		if claim.failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claim.assertions.duplicate()}
	return {"errors": reference.errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims}

static func command(state: GameState, action: Array) -> bool:
	var finite := TechnologySystem.new(state)
	match action[0]:
		"select", "finite": return finite.start_research("" if action[1] == "" else "dsp_" + String(action[1]))
		"pause": return finite.pause_research()
		"resume": return finite.resume_research()
		"cancel": return finite.cancel_research()
		"remove": return finite.remove_from_queue("dsp_" + String(action[1]))
		"infinite": return InfiniteResearchSystem.new(state).select(action[1])
		"automatic": return InfiniteResearchSystem.new(state).set_automation(action[1])
		"tick":
			finite.update_source_labs(0.25)
			return true
	return false

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
