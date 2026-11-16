extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-progression.json"
const SUITE := "task27-progression"
const TASK_STAGES := ["zero", "below", "exact", "overshoot", "locked", "completed_unrewarded", "completed_rewarded", "reward_capacity", "reward_retry"]
const ACHIEVEMENT_STAGES := ["zero", "below", "exact", "overshoot", "already_unlocked"]
const RESEARCH := preload("res://scripts/test/ResearchBoundaryBehaviorRunner.gd")
const COMPARATOR := preload("res://scripts/test/SpecialProductionBehaviorRunner.gd")
var errors: Array[String] = []
var claims := {}
var _catalog := {}
var _save_root := ""

func run(fixture_override: Dictionary = {}) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("progression provenance missing")
	for required in ["src/game/engine.ts", "src/game/campaign.ts", "src/game/progression.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(required): return _reject("progression source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("progression source hash drift")
	var identities := []
	for category in ["campaign", "achievements"]:
		for row in source.catalog[category]:
			for stage in (TASK_STAGES if category == "campaign" else ACHIEVEMENT_STAGES): identities.append(category + ":" + row.id + ":" + stage)
	identities.sort()
	if not fixture.get("cases") is Array: return _reject("progression cases missing")
	var actual: Array = fixture.cases.map(func(row): return row.category + ":" + row.id + ":" + row.stage)
	actual.sort()
	if actual != identities: return _reject("progression cases missing, duplicated or unknown")
	var reward_ids := []
	for row in source.catalog.campaign:
		if row.definition.get("rewards", []).any(func(reward): return reward.has("itemId")): reward_ids.append(row.id)
	reward_ids.sort()
	if not fixture.get("reward_resume_cases") is Array: return _reject("pending reward resume cases missing")
	var actual_reward_ids: Array = fixture.reward_resume_cases.map(func(row): return row.id)
	actual_reward_ids.sort()
	if actual_reward_ids != reward_ids: return _reject("pending reward resume cases missing, duplicated or unknown")
	_catalog = ObjectiveSystem.load_catalog()
	for field in ["chapters", "objectives", "achievements"]:
		_catalog[field] = _catalog[field].filter(func(row): return row.has("source_id"))
	_save_root = "res://.godot/task27-progression-saves-%d/" % Time.get_ticks_usec()
	for row in fixture.cases:
		var key: String = row.category + ":" + row.id
		var label: String = row.id + ":" + row.stage
		var state := _state(row.input, key, label)
		var service := ProgressionSystem.new(state, _catalog)
		var definition := _definition(row.category, row.id)
		var before := GameStateCodec.to_persistent_dict(state)
		var progress := service.objective_system.get_progress(state, definition)
		_check(key, progress.current == row.progress.current and progress.required == row.progress.target and progress.complete == row.progress.complete, label + ": actual target boundary progress")
		_check(key, GameStateCodec.to_persistent_dict(state) == before, label + ": progress query preserves persistent ownership")
		var result := service.evaluate()
		_check(key, result.completed_achievements.map(func(id): return String(id).trim_prefix("dsp_")) == row.new_achievements, label + ": exact ordered new achievement returns")
		_compare(state, row.expected, key, label)
		var settled := GameStateCodec.to_persistent_dict(state)
		var again := service.evaluate()
		_check(key, again.completed_achievements.map(func(id): return String(id).trim_prefix("dsp_")) == row.repeated_new_achievements, label + ": repeated achievement returns")
		_compare(state, row.repeated, key, label + ": repeated")
		_check(key, GameStateCodec.to_persistent_dict(state) == settled, label + ": repeated completion never duplicates rewards")
		if row.stage in ["exact", "completed_unrewarded", "reward_capacity", "reward_retry", "already_unlocked"]: _disk(state, row.loaded_after, key, label)
	for row in fixture.reward_resume_cases: _reward_resume(row)
	var keys: Array[String] = []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	keys.sort()
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

func _state(input: Dictionary, key: String, label: String) -> GameState:
	var empty_labs := {"research": input.research, "endgame": input.endgame, "labs": [], "construction": input.construction, "exploration": input.exploration}
	var setup: Dictionary = RESEARCH.new()._state({"view": empty_labs, "campaign": input.campaign})
	var state: GameState = setup.state
	state.progression_facts["source_campaign_enabled"] = true
	state.selected_source_objective = "dsp_" + String(input.campaign.activeTaskId) if input.campaign.activeTaskId != null else ""
	for id in input.achievements.unlockedIds: state.completed_achievement_ids.append("dsp_" + String(id))
	state.progression_facts["manual_mined"] = input.manualMined
	state.progression_facts["produced"] = input.totalProduced.duplicate(true)
	state.progression_facts["station_trips"] = {}
	state.explored_system_ids = input.exploration.unlockedSystemIds.duplicate()
	state.survey_progress_by_system = input.exploration.surveyProgressBySystem.duplicate(true)
	for planet in state.colonized_planet_ids:
		state.planet_inventories[planet] = input.planetTrays.get(planet, {}).duplicate(true)
	state.active_planet_id = input.activePlanetId
	state.planet_inventory = input.tray.duplicate(true)
	if input.get("cargo") is Dictionary:
		state.cursor_payload = {"item_id": input.cargo.itemId, "amount": float(input.cargo.amount)}
	state.sync_active_planet_inventory()
	state.planet_tray_limits = {}
	for planet in state.colonized_planet_ids:
		if input.planetTrayItemLimits.has(planet): state.planet_tray_limits[planet] = input.planetTrayItemLimits[planet]
	var entities := {}
	for entity in input.entities:
		var count: int = int(entity.minerCount) if entity.kind == "vein" else int(entity.machineCount)
		var type: String = entity.get("extractorBuildingId", "mining_machine") if entity.kind == "vein" else String(entity.get("buildingId", ""))
		for index in range(count):
			var building := state.add_building({"type": "dsp_" + type, "position": Vector2(200 + state.buildings.size() * 200, 0), "planet_id": entity.planetId, "input_buffer": entity.inputs.duplicate(true) if index == 0 else {}, "output_buffer": entity.outputs.duplicate(true) if index == 0 else {}})
			if not entities.has(entity.id): entities[entity.id] = building
			if StationSystem.is_station("dsp_" + type): state.buildings[building].station = StationSystem.empty_station("dsp_" + type)
			if entity.kind == "vein": state.buildings[building].output_item = entity.resourceId
			if entity.get("recipeId") != null and DataManager.get_recipe("dsp_" + String(entity.recipeId)) != {}:
				state.buildings[building].recipe_id = "dsp_" + String(entity.recipeId)
			if entity.get("sprayCoaterInstalled", false):
				state.buildings[building].merge({"spray_coater_installed": true, "proliferator_tier": float(entity.get("proliferatorTier", 1)), "proliferator_mode": entity.get("proliferatorMode", "normal")}, true)
			if index == 0 and entity.get("stationTrips", 0) > 0: state.progression_facts.station_trips[building] = entity.stationTrips
	for belt in input.belts:
		_check(key, entities.has(belt.source) and entities.has(belt.target), label + ": real source belt endpoints mapped")
		if entities.has(belt.source) and entities.has(belt.target): state.add_connection({"source_id": entities[belt.source], "target_id": entities[belt.target], "item_id": belt.itemId, "type": "conveyor_belt_mk%d" % int(belt.tier), "tier": "conveyor_belt_mk%d" % int(belt.tier), "parallel_count": 1, "stack_size": 1})
	for planet in input.planetMetrics:
		var metric: Dictionary = input.planetMetrics[planet]
		if float(metric.demandKw) <= 0: continue
		state.planet_metrics[planet] = {"power": {"consumption": float(metric.demandKw), "efficiency": float(metric.powerFactor), "generation": float(metric.generationKw)}}
	for blueprint in input.blueprints:
		var selected := []
		for entity in blueprint.entities:
			var matches := state.buildings.keys().filter(func(id): return state.buildings[id].type == "dsp_" + String(entity.buildingId))
			if not matches.is_empty(): selected.append(matches[0])
		var captured := BlueprintSystem.new(state).capture_selection(selected)
		_check(key, captured.ok, label + ": actual blueprint capture for source count")
		if captured.ok: _check(key, BlueprintLibrary.new(state).save_definition(blueprint.name, captured.blueprint).ok, label + ": actual blueprint library save")
	var system: Dictionary = SourceDysonEngineering.new(state).ensure("helios")
	system.sails_launched = int(input.dysonSwarm.totalLaunched)
	system.rockets_launched = int(input.dysonSphere.totalRocketsLaunched)
	system.sails_expired = int(input.dysonSwarm.totalExpired)
	system.source_plan.structure_points = int(input.dysonSphere.structurePoints)
	system.source_plan.shell_sails = int(input.dysonSphere.totalSailsAbsorbed)
	var live := int(input.dysonSwarm.sailsInOrbit)
	if live > 0:
		var orbit: Dictionary = DysonSphereSystem.new(state).create_orbit("helios")
		if orbit.ok: system.orbits[orbit.id].cohorts.append({"count": live, "expires_tick": 0})
		else:
			var id := state.generate_id("orbit")
			system.orbits[id] = {"id": id, "radius": 10000, "inclination": 0, "longitude": 0, "decay_progress": 0.0, "cohorts": [{"count": live, "expires_tick": 0}]}
			system.source_plan.active_orbit = id
	state.galactic_exports.total_exported = input.endgame.totalExported
	for id in input.endgame.exportProjects:
		if state.galactic_exports.projects.has(id): state.galactic_exports.projects[id].level = int(input.endgame.exportProjects[id].level)
	return state

func _definition(category: String, id: String) -> Dictionary:
	var rows: Array = _catalog.objectives if category == "campaign" else _catalog.achievements
	for row in rows:
		if row.source_id == id: return row
	return {}

func _compare(state: GameState, expected: Dictionary, key: String, label: String, disk: bool = false) -> void:
	var completed: Array = state.completed_objective_ids.map(func(id): return String(id).trim_prefix("dsp_"))
	var wanted: Array = expected.campaign.completedTaskIds.duplicate()
	completed.sort()
	wanted.sort()
	_check(key, completed == wanted, label + ": complete task completion set")
	var rewarded := []
	for id in state.claimed_progression_reward_ids:
		if String(id).begins_with("objective:dsp_"): rewarded.append(String(id).trim_prefix("objective:dsp_"))
	wanted = expected.campaign.rewardedTaskIds.duplicate()
	rewarded.sort()
	wanted.sort()
	_check(key, rewarded == wanted, label + ": one-time task reward set")
	var unlocked: Array = state.completed_achievement_ids.map(func(id): return String(id).trim_prefix("dsp_"))
	wanted = expected.achievements.unlockedIds.duplicate()
	if disk:
		unlocked.sort()
		wanted.sort()
	_check(key, unlocked == wanted, label + ": complete achievement ownership" + (" after canonical order normalization" if disk else " in exact live order"))
	_check(key, COMPARATOR._difference(state.planet_inventory, expected.tray).is_empty(), label + ": complete active tray reward ownership")
	_check(key, COMPARATOR._difference(RESEARCH._stock(state.construction_inventory), RESEARCH._stock(expected.construction)).is_empty(), label + ": exact construction rewards")
	var service := ProgressionSystem.new(state, _catalog)
	for progress in expected.progress:
		var local := service.get_objective_progress("dsp_" + String(progress.id))
		_check(key, local.current == progress.current and local.required == progress.target and local.complete == progress.complete, label + ": current task metric " + progress.id + " actual=" + str(local.current) + " source=" + str(progress.current))
	for progress in expected.achievementProgress:
		var local := service.objective_system.get_progress(state, _definition("achievements", progress.id))
		_check(key, local.current == progress.current, label + ": current achievement metric " + progress.id + " actual=" + str(local.current) + " source=" + str(progress.current))

func _reward_resume(row: Dictionary) -> void:
	var key: String = "campaign:" + row.id
	var label: String = row.id + ":reward_resume"
	var state := _state(row.input, key, label)
	ProgressionSystem.new(state, _catalog).evaluate()
	_check(key, state.completed_objective_ids.has("dsp_" + row.id) and not state.claimed_progression_reward_ids.has("objective:dsp_" + row.id), label + ": full tray completes task while its reward remains pending")
	_compare(state, row.blocked, key, label + ": blocked")
	var loaded := _disk(state, row.loaded_blocked, key, label + ": pending")
	if loaded == null: return
	for request in row.release_requests:
		_check(key, PlanetTraySystem.new(loaded).discard(loaded.active_planet_id, request.itemId, float(request.amount), true).ok, label + ": actual confirmed tray discard frees reward space")
	_compare(loaded, row.released, key, label + ": released", true)
	var service := ProgressionSystem.new(loaded, _catalog)
	var paid := service.evaluate()
	_check(key, paid.completed_achievements.map(func(id): return String(id).trim_prefix("dsp_")) == row.new_achievements, label + ": exact new achievements after loaded pending reward")
	_compare(loaded, row.expected, key, label + ": repaid", true)
	var canonical := GameStateCodec.to_persistent_dict(loaded)
	var repeated := service.evaluate()
	_check(key, repeated.completed_achievements.map(func(id): return String(id).trim_prefix("dsp_")) == row.repeated_new_achievements, label + ": repeated repaid achievement returns")
	_compare(loaded, row.repeated, key, label + ": repeated", true)
	_check(key, GameStateCodec.to_persistent_dict(loaded) == canonical, label + ": loaded pending reward pays exactly once")
	var reopened := _disk(loaded, row.loaded_after, key, label + ": paid")
	if reopened == null: return
	var resumed := ProgressionSystem.new(reopened, _catalog).evaluate()
	_check(key, resumed.completed_achievements.map(func(id): return String(id).trim_prefix("dsp_")) == row.reopened_new_achievements, label + ": second reload repeated achievement returns")
	_compare(reopened, row.reopened_repeated, key, label + ": second reload repeated", true)

func _disk(state: GameState, expected: Dictionary, key: String, label: String) -> GameState:
	var saves := SaveSystem.new(_save_root + key.replace(":", "-") + "-" + label.replace(":", "-"))
	var canonical := GameStateCodec.to_persistent_dict(state)
	var saved := saves.save_slot(0, state)
	var loaded := saves.load_slot(0) if saved.ok else {}
	_check(key, saved.ok and loaded.get("ok", false), label + ": real progression disk save/load " + str(saved.get("error", {})))
	if not loaded.get("ok", false): return null
	_check(key, COMPARATOR._difference(GameStateCodec.to_persistent_dict(loaded.state), canonical).is_empty(), label + ": complete canonical disk roundtrip")
	_compare(loaded.state, expected, key, label + ": actual source storage migration", true)
	return loaded.state

func _check(key: String, ok: bool, assertion: String) -> void:
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
