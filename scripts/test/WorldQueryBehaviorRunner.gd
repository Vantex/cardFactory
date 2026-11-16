extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-world-queries.json"
const SUITE := "task27-world-queries"
const KEYS := {"colonized": "commands:engine.isPlanetColonized", "requirements": "commands:engine.getColonizationRequirements", "colonize": "commands:engine.canColonizePlanet", "unlocked": "commands:engine.isStarSystemUnlocked", "explore": "commands:engine.canExploreStarSystem", "limit": "commands:engine.getPlanetTrayItemLimit", "capacity": "commands:engine.getPlanetTrayItemFreeCapacity"}
var errors: Array[String] = []
var claims := {}

func run(fixture_override: Dictionary = {}, after_queries: Callable = Callable()) -> Dictionary:
	errors.clear()
	claims.clear()
	var fixture := DSPOnlineParity.read_json(FIXTURE) if fixture_override.is_empty() else fixture_override
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return _reject("world query provenance missing")
	for file in ["src/game/engine.ts", "src/game/content.ts", "src/game/galaxy.ts"]:
		if not fixture.source_files.has(file): return _reject("world query source module missing")
	for file in fixture.source_files:
		if fixture.source_files[file] != source.source.files.get(file): return _reject("world query source drift")
	var catalog := SourceGalaxySystem.catalog()
	var planets: Array = catalog.planets.keys()
	var systems: Array = catalog.systems.keys()
	var items: Array = source.catalog.items.map(func(row): return row.id)
	if not _same_ids(fixture.get("planets"), planets) or not _same_ids(fixture.get("systems"), systems) or not _same_ids(fixture.get("items"), items): return _reject("world query catalog coverage missing or duplicated")
	var wanted := []
	for tag in ["240721-false", "42-false", "240721-true"]:
		for stage in ["fresh", "technology", "unlocked", "colonized"]: wanted.append(stage + "-" + tag)
		for planet in planets:
			var definition: Dictionary = catalog.planets[planet]
			if definition.systemId == "helios" or catalog.systems[definition.systemId].planetIds[0] == planet: continue
			for stage in ["below", "exact", "overshoot", "remote_only", "fleet_missing"]: wanted.append("colony-" + planet + "-" + stage + "-" + tag)
	for system in systems:
		if system == "helios": continue
		for stage in ["locked_technology", "locked_prerequisite", "materials_below", "materials_exact", "materials_epsilon", "mission_running", "already_unlocked"]: wanted.append("system-" + system + "-" + stage)
	for stage in ["minimum", "maximum", "fractional", "too_low", "too_high", "missing", "nonfinite"]: wanted.append("tray-" + stage)
	if not fixture.get("cases") is Array or not _same_ids(fixture.cases.map(func(row): return row.id), wanted): return _reject("world query states missing, duplicated or unknown")
	var statuses := []
	for row in fixture.cases:
		if not _same_ids(row.expected.systems.map(func(value): return value.id), systems + ["unknown_system", ""]): return _reject("world query system rows missing")
		if not _same_ids(row.expected.planets.map(func(value): return value.id), planets): return _reject("world query planet rows missing")
		var capacity_items: Array = items + ["unknown_item"] if row.id == "fresh-240721-false" or row.id.begins_with("tray-") else ["iron_ore", "logistics_drone", "logistics_vessel", "unknown_item"]
		if not row.id.begins_with("tray-") and row.id != "fresh-240721-false":
			for item in row.input.tray:
				if not capacity_items.has(item): capacity_items.append(item)
			for tray in row.input.planetTrays.values():
				for item in tray:
					if not capacity_items.has(item): capacity_items.append(item)
		for planet in row.expected.planets:
			if not _same_ids(planet.freeCapacity.map(func(value): return value.itemId), capacity_items): return _reject("world query capacity rows missing")
			if not statuses.has(planet.requirements.status): statuses.append(planet.requirements.status)
	if not _same_ids(statuses, ["colonized", "technology", "prerequisite-system", "system-locked", "materials", "ready"]): return _reject("world query colonization statuses missing")
	for row in fixture.cases:
		var state := _state(row.input)
		var before := _ownership(state)
		var galaxy := GalaxySystem.new(state)
		var planet := PlanetSystem.new(state, galaxy)
		var tray := PlanetTraySystem.new(state)
		var view := preload("res://scenes/ui/GalaxyMap.gd").new()
		view.game_state = state
		view.galaxy_system = galaxy
		view.planet_system = planet
		for value in row.expected.systems:
			var label: String = row.id + ":" + value.id
			_check("unlocked", galaxy.has_method("is_source_system_unlocked") and galaxy.call("is_source_system_unlocked", value.id) == value.unlocked, label + ": actual unlocked query")
			_check("explore", galaxy.has_method("can_explore_source_system") and galaxy.call("can_explore_source_system", value.id) == value.canExplore, label + ": actual exploration eligibility")
			_check("explore", galaxy.get_exploration_requirements(value.id).get("available", false) == value.canExplore, label + ": existing formal requirements consume actual source eligibility")
		for value in row.expected.planets:
			var label: String = row.id + ":" + value.id
			_check("colonized", planet.has_method("is_source_planet_colonized") and planet.call("is_source_planet_colonized", value.id) == value.colonized, label + ": actual colonization ownership query")
			_check("requirements", planet.has_method("get_source_colonization_requirements") and planet.call("get_source_colonization_requirements", value.id) == value.requirements, label + ": exact source status reason costs and stock")
			_check("colonize", planet.has_method("can_colonize_source_planet") and planet.call("can_colonize_source_planet", value.id) == value.canColonize, label + ": actual colonization eligibility")
			var summary := galaxy.get_planet_summary(value.id)
			_check("colonized", summary.colonization.colonized == value.colonized, label + ": existing formal summary consumes actual source ownership")
			_check("requirements", summary.colonization.get("source_requirements", {}) == value.requirements, label + ": existing formal summary exposes exact source requirements")
			var available: Dictionary = view._colonization_availability(summary)
			_check("colonize", available.ok == value.canColonize and available.message == value.requirements.reason, label + ": existing formal button predicate consumes source eligibility and reason")
			_check("limit", tray.limit(value.id) == value.trayLimit, label + ": actual item capacity limit")
			for capacity in value.freeCapacity:
				var expected: float = INF if capacity.value is String and capacity.value == "Infinity" else float(capacity.value)
				_check("capacity", tray.has_method("free_capacity") and tray.call("free_capacity", value.id, capacity.itemId) == expected, label + ":" + capacity.itemId + ": actual free capacity and portable fleet")
		_check("limit", tray.limit() == row.expected.activeTrayLimit and tray.limit("unknown_planet") == row.expected.unknownTrayLimit, row.id + ": active default and unknown planet limit")
		view.free()
		if after_queries.is_valid(): after_queries.call(row.id, state)
		var conserved := _ownership(state) == before
		for kind in KEYS: _check(kind, conserved, row.id + ": queries preserve complete raw and canonical ownership")
	var keys := []
	var proofs := {}
	for key in claims:
		if claims[key].failures.is_empty():
			keys.append(key)
			proofs[key] = {"suite": SUITE, "fixture": FIXTURE, "fixture_sha256": FileAccess.get_sha256(FIXTURE), "assertions": claims[key].assertions.duplicate()}
	return {"errors": errors.duplicate(), "verified_keys": keys, "proofs": proofs, "claims": claims.duplicate(true)}

static func _state(input: Dictionary) -> GameState:
	var state := GameState.new()
	state.source_galaxy = input.galaxy.duplicate(true)
	state.galaxy_seed = int(input.galaxy.seed)
	state.active_planet_id = input.activePlanetId
	state.planet_inventory = input.tray.duplicate(true)
	state.planet_inventories = input.planetTrays.duplicate(true)
	state.planet_tray_limits = input.planetTrayItemLimits.duplicate(true)
	for planet in state.planet_tray_limits:
		if state.planet_tray_limits[planet] is String and state.planet_tray_limits[planet] == "Infinity": state.planet_tray_limits[planet] = INF
	state.portable_fleet = input.portableFleet.duplicate(true)
	state.completed_technologies = input.research.completedTechIds.map(func(id): return "dsp_" + String(id))
	state.explored_system_ids = input.exploration.unlockedSystemIds.duplicate()
	state.colonized_planet_ids = input.exploration.colonizedPlanetIds.duplicate()
	state.survey_progress_by_system = input.exploration.surveyProgressBySystem.duplicate(true)
	state.exploration_missions = input.exploration.missions.map(func(mission): return {"system_id": mission.systemId, "progress": mission.elapsedSeconds, "duration_seconds": mission.durationSeconds})
	return state

static func _ownership(state: GameState) -> Dictionary:
	var raw := {}
	for field in ["source_galaxy", "active_planet_id", "planet_inventory", "planet_inventories", "planet_tray_limits", "portable_fleet", "completed_technologies", "explored_system_ids", "colonized_planet_ids", "exploration_missions", "survey_progress_by_system"]:
		var value: Variant = state.get(field)
		raw[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"raw": raw, "canonical": GameStateCodec.to_persistent_dict(state.copy_state())}

static func _same_ids(actual: Variant, expected: Array) -> bool:
	if not actual is Array: return false
	var left: Array = actual.duplicate()
	var right := expected.duplicate()
	left.sort()
	right.sort()
	return left == right

func _check(kind: String, ok: bool, assertion: String) -> void:
	var key: String = KEYS[kind]
	if not claims.has(key): claims[key] = {"assertions": [], "failures": []}
	claims[key].assertions.append(assertion)
	if not ok:
		claims[key].failures.append(assertion)
		errors.append(key + ": " + assertion)

static func _reject(message: String) -> Dictionary:
	return {"errors": [message], "verified_keys": [], "proofs": {}, "claims": {}}
