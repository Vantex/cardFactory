extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-world-commands.json"
const KEYS := {"explore": "commands:engine.exploreStarSystem", "colonize": "commands:engine.colonizePlanet", "active": "commands:engine.setActivePlanet"}
const SEEDS := [[240721, false], [42, false], [240721, true]]
const EXPLORE_STAGES := ["technology", "prerequisite", "below", "exact", "overshoot", "already_unlocked", "mission_running"]
const COLONIZE_STAGES := ["locked", "ready", "below", "remote_only", "fleet_missing", "already_colonized"]
const ACTIVE_STAGES := ["locked", "not_colonized", "computed", "explicit", "already_active"]
const SURVEY_STAGES := ["zero", "half", "round_fraction", "eps_before", "eps_complete", "exact", "overshoot", "sixty_hz"]
var errors: Array[String] = []
var claims := {}
var disk_saves := 0

func run(fixture_override: Dictionary = {}, save_round_trips: bool = false, after_command: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	disk_saves = 0
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("world command provenance missing")
	for file in ["src/game/engine.ts", "src/game/galaxy.ts", "src/game/storage.ts"]:
		if not fixture.source_files.has(file): return _reject("world command source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("world command source drift")
	var catalog := SourceGalaxySystem.catalog()
	var wanted := []
	for seed in SEEDS:
		var tag := "%d-%s" % [seed[0], "true" if seed[1] else "false"]
		for system in catalog.systems:
			if system != "helios":
				for stage in EXPLORE_STAGES: wanted.append("explore-%s-%s-%s" % [system, stage, tag])
		for planet in catalog.planets:
			for stage in COLONIZE_STAGES: wanted.append("colonize-%s-%s-%s" % [planet, stage, tag])
			for stage in ACTIVE_STAGES: wanted.append("active-%s-%s-%s" % [planet, stage, tag])
		wanted.append("active-unknown-" + tag)
		wanted.append("explore-unknown-" + tag)
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if not fixture.get("cases") is Array or not controls._same_ids(fixture.cases.map(func(row): return row.id), wanted): return _reject("world command cases missing duplicated or unknown")
	var wanted_surveys := []
	for seed in SEEDS:
		for system in catalog.systems:
			if system == "helios": continue
			for stage in SURVEY_STAGES: wanted_surveys.append("survey-%s-%s-%d-%s" % [system, stage, seed[0], "true" if seed[1] else "false"])
	if not fixture.get("surveys") is Array or not controls._same_ids(fixture.surveys.map(func(row): return row.id), wanted_surveys): return _reject("source survey cases missing duplicated or unknown")
	for row in fixture.surveys:
		if not row.get("trace") is Array or row.trace.size() != (9 if row.get("stage") == "sixty_hz" else 1): return _reject("source survey trace is incomplete")
		if row.get("steps") != row.trace.size() or not (row.get("seconds") is int or row.get("seconds") is float) or not is_finite(float(row.seconds)) or float(row.seconds) < 0: return _reject("source survey clock input is invalid")
		if row.stage in ["round_fraction", "eps_before", "eps_complete", "exact", "sixty_hz"]:
			if not row.get("clock") is Dictionary or row.clock.size() != 2 or row.clock.get("numerator") != 1 or row.clock.get("denominator") != 60 or absf(float(row.seconds) - 1.0 / 60.0) > 1.0e-15: return _reject("declared exact source survey clock missing")
		elif row.get("clock") != null: return _reject("unexpected source survey rational clock")
	var root := "res://.godot/task27-world-commands-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	for row in fixture.cases:
		var state := _state(row.input)
		var before := _untouched(state)
		var binding_before := {"sites": state.resource_sites.duplicate(true), "viewports": state.planet_viewports.duplicate(true), "metrics": state.planet_metrics.duplicate(true)}
		var kind: String = row.command.kind
		if not KEYS.has(kind): return _reject("unknown world command kind")
		_invoke(state, row.command)
		_check(kind, controls._same_value(_domain(state), _comparison(row.expected)), row.id + ": actual source command ownership and world availability")
		if after_command.is_valid(): after_command.call(row.id, state)
		_check(kind, _untouched(state) == before and _bindings_retained(state, binding_before), row.id + ": unrelated raw and persistent ownership retained")
		_invoke(state, row.command)
		_check(kind, controls._same_value(_domain(state), _comparison(row.repeated)), row.id + ": actual source repeated command result")
		_check(kind, _untouched(state) == before and _bindings_retained(state, binding_before), row.id + ": repeat retains unrelated ownership")
		var decoded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state.copy_state()))
		_check(kind, decoded != null and controls._same_value(_stored_world_ownership(_domain(decoded)), _stored_world_ownership(_comparison(row.loaded_after))), row.id + ": actual source storage inventory and computed world ownership agree")
		_check(kind, decoded != null and controls._same_value(_domain(decoded), _local_saved_domain(state)), row.id + ": local codec retains pending surveys and canonical command state")
		if save_round_trips:
			var storage := SaveSystem.new(root + row.id + "/")
			var saved := storage.save_slot(0, state)
			_check(kind, saved.ok, row.id + ": actual disk save succeeds " + str(saved.get("error", {})))
			_check(kind, _untouched(state) == before and _bindings_retained(state, binding_before), row.id + ": save retains live ownership")
			if saved.ok:
				disk_saves += 1
				var loaded := storage.load_recovery_source(0, "primary")
				_check(kind, loaded.ok and controls._same_value(_domain(loaded.state), _local_saved_domain(state)), row.id + ": disk reload retains canonical source command state and pending work")
				_check(kind, loaded.ok and controls._same_value(_stored_world_ownership(_domain(loaded.state)), _stored_world_ownership(_comparison(row.loaded_after))), row.id + ": disk agrees with source storage inventory and computed ownership")
				_check(kind, loaded.ok and controls._same_value(_untouched(loaded.state).canonical, before.canonical), row.id + ": disk retains unrelated persistent ownership")
	_run_surveys(fixture.surveys, root, save_round_trips)
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": "task27-world-commands", "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true), "disk_saves": disk_saves}

func _run_surveys(rows: Array, root: String, save_round_trips: bool) -> void:
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	for row in rows:
		var state := _state(row.input)
		var before := _untouched(state)
		var bindings := {"sites": state.resource_sites.duplicate(true), "viewports": state.planet_viewports.duplicate(true), "metrics": state.planet_metrics.duplicate(true)}
		var galaxy := GalaxySystem.new(state)
		var seconds := 1.0 / 60.0 if row.get("clock") is Dictionary else float(row.seconds)
		for index in range(row.trace.size()):
			galaxy.update_exploration(seconds)
			_check("explore", controls._same_value(_domain(state), _comparison(row.trace[index])), row.id + ": actual source simulation survey trace step %d" % index)
			_check("explore", _untouched(state) == before and _bindings_retained(state, bindings), row.id + ": survey step preserves unrelated raw ownership")
		var decoded := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state.copy_state()))
		_check("explore", decoded != null and controls._same_value(_domain(decoded), _local_saved_domain(state)), row.id + ": codec preserves survey elapsed time and exact pending progress")
		_check("explore", decoded != null and controls._same_value(_stored_world_ownership(_domain(decoded)), _stored_world_ownership(_comparison(row.loaded_after))), row.id + ": source storage inventory and computed availability agree")
		if save_round_trips:
			var storage := SaveSystem.new(root + row.id + "/")
			var saved := storage.save_slot(0, state)
			_check("explore", saved.ok, row.id + ": exact source survey boundary writes verified disk " + str(saved.get("error", {})))
			if saved.ok:
				disk_saves += 1
				var loaded := storage.load_recovery_source(0, "primary")
				_check("explore", loaded.ok and controls._same_value(_domain(loaded.state), _local_saved_domain(state)), row.id + ": disk retains exact pending survey state")

static func _state(input: Dictionary) -> GameState:
	var state := GameState.new()
	state.source_galaxy = input.galaxy.duplicate(true)
	state.galaxy_seed = int(input.galaxy.seed)
	state.active_planet_id = input.activePlanetId
	state.planet_inventory = input.tray.duplicate(true)
	state.planet_inventories = input.planetTrays.duplicate(true)
	state.portable_fleet = input.portableFleet.duplicate(true)
	state.planet_metrics = input.planetMetrics.duplicate(true)
	state.completed_technologies = input.research.completedTechIds.map(func(id): return "dsp_" + String(id))
	state.explored_system_ids = input.exploration.unlockedSystemIds.duplicate()
	state.colonized_planet_ids = input.exploration.colonizedPlanetIds.duplicate()
	state.survey_progress_by_system = input.exploration.surveyProgressBySystem.duplicate(true)
	state.exploration_missions = input.exploration.missions.map(func(mission): return {"system_id": mission.systemId, "progress": mission.elapsedSeconds, "duration_seconds": mission.durationSeconds})
	for planet in state.colonized_planet_ids:
		state.planet_viewports[planet] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	return state

static func _invoke(state: GameState, command: Dictionary) -> void:
	match String(command.kind):
		"explore": GalaxySystem.new(state).try_explore_system(command.target)
		"colonize": PlanetSystem.new(state).try_colonize_planet(command.target)
		"active": PlanetSystem.new(state).try_set_active_planet(command.target)

static func _clean_stock(stock: Dictionary) -> Dictionary:
	var result := {}
	for item in stock:
		if stock[item] != 0: result[item] = stock[item]
	return result

static func _comparison(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.tray = _clean_stock(result.tray)
	for planet in result.planetTrays: result.planetTrays[planet] = _clean_stock(result.planetTrays[planet])
	result.logicalColonized.sort()
	result.exploration.colonizedPlanetIds = result.logicalColonized.duplicate()
	result.exploration.unlockedSystemIds.sort()
	for system in SourceGalaxySystem.catalog().systems:
		if not result.exploration.surveyProgressBySystem.has(system): result.exploration.surveyProgressBySystem[system] = 0
	return result

static func _domain(state: GameState) -> Dictionary:
	var logical := []
	var planets := PlanetSystem.new(state)
	for id in SourceGalaxySystem.catalog().planets:
		if planets.is_source_planet_colonized(id): logical.append(id)
	var missions := state.exploration_missions.map(func(mission): return {"systemId": mission.system_id, "elapsedSeconds": mission.progress, "durationSeconds": mission.duration_seconds})
	return _comparison({"activePlanetId": state.active_planet_id, "tray": state.planet_inventory, "planetTrays": state.planet_inventories, "portableFleet": state.portable_fleet, "activeMetrics": state.planet_metrics.get(state.active_planet_id, {}), "exploration": {"unlockedSystemIds": state.explored_system_ids, "colonizedPlanetIds": state.colonized_planet_ids, "missions": missions, "surveyProgressBySystem": state.survey_progress_by_system}, "logicalColonized": logical})

static func _local_saved_domain(state: GameState) -> Dictionary:
	var result := _domain(state)
	# Both actual readers synchronize the active tray alias during persistence.
	result.planetTrays[result.activePlanetId] = result.tray.duplicate(true)
	return result

static func _stored_world_ownership(value: Dictionary) -> Dictionary:
	# Source storage drops unlocked background missions. Keep local pending work;
	# compare source storage ownership separately from the exact local round trip.
	var result := value.duplicate(true)
	result.exploration.erase("missions")
	result.exploration.erase("surveyProgressBySystem")
	return result

static func _bindings_retained(state: GameState, before: Dictionary) -> bool:
	for pair in [[state.resource_sites, before.sites], [state.planet_viewports, before.viewports], [state.planet_metrics, before.metrics]]:
		for id in pair[1]:
			if pair[0].get(id) != pair[1][id]: return false
	return true

static func _untouched(state: GameState) -> Dictionary:
	var excluded := ["active_planet_id", "planet_inventory", "planet_inventories", "portable_fleet", "explored_system_ids", "colonized_planet_ids", "exploration_missions", "survey_progress_by_system", "resource_sites", "planet_viewports", "planet_metrics", "_source_catalog_cache"]
	var payload := GameStateCodec.to_persistent_dict(state.copy_state())
	for field in excluded: payload.erase(field)
	var raw := {}
	for property in state.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or property.name in excluded: continue
		var value: Variant = state.get(property.name)
		raw[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"raw": raw, "canonical": payload}

func _check(kind: String, ok: bool, assertion: String) -> void:
	var key: String = KEYS[kind]
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
