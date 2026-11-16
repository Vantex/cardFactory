extends Node

const GUARD := preload("res://scripts/test/ResourceCapacityFixtureGuard.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors := []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _run() -> void:
	var gold := GUARD.load_fixture()
	if gold.is_empty():
		get_tree().quit(1)
		return
	var matched := 0
	var initialized := 0
	var saves := 0
	var root := "res://.godot/task27-initial-capacity-%d/" % OS.get_process_id()
	for scenario in gold.cases:
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(int(scenario.input.seed), scenario.input.preserve_baseline)
		_check(state.galaxy_seed == scenario.source_seed, scenario.id + ": source normalized seed")
		var galaxy := GalaxySystem.new(state)
		var before := OWNER._ownership(state)
		var expected_pairs := {}
		for vein in scenario.veins:
			var pair: String = vein.planet + ":" + vein.item
			_check(not expected_pairs.has(pair), scenario.id + ": unique planet/resource")
			expected_pairs[pair] = vein
			var selected: Dictionary = {}
			for site in galaxy.build_resource_sites_for_planet(vein.planet, state.galaxy_seed).values():
				if site.item_id == vein.item: selected = site; break
			_check(not selected.is_empty(), scenario.id + ": generated resource " + vein.id)
			if selected.is_empty(): continue
			_check(selected.capacity == vein.initial_capacity and selected.remaining == vein.initial_remaining and selected.infinite == vein.snapshot.infinite, scenario.id + ": exact initial reserve " + vein.id)
			_check(EXACT._exact(state.get_resource_reserve_snapshot(selected), vein.snapshot), scenario.id + ": exact initial reserve snapshot " + vein.id)
			matched += 1
		for planet in SourceGalaxySystem.catalog().planets:
			for site in galaxy.build_resource_sites_for_planet(planet, state.galaxy_seed).values():
				_check(expected_pairs.has(planet + ":" + site.item_id), scenario.id + ": no unexpected resource")
		_check(OWNER._ownership(state) == before, scenario.id + ": generator/query preserve complete owner")
		# The generation gate supplies colony prerequisites; earned colonization is a separate gate.
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for system_id in state.explored_system_ids: state.survey_progress_by_system[system_id] = 1.0
		var planets := PlanetSystem.new(state)
		for planet in SourceGalaxySystem.catalog().planets: planets.ensure_colonized_planet_records(planet)
		planets.initialize_colonized_resource_sites()
		var actual_pairs := {}
		for site in state.resource_sites.values():
			var pair: String = site.planet_id + ":" + site.item_id
			_check(expected_pairs.has(pair) and not actual_pairs.has(pair), scenario.id + ": exact initialized resource set")
			actual_pairs[pair] = true
			if not expected_pairs.has(pair): continue
			var vein: Dictionary = expected_pairs[pair]
			_check(site.capacity == vein.initial_capacity and site.remaining == vein.initial_remaining and site.infinite == vein.snapshot.infinite, scenario.id + ": registered initial reserve")
			initialized += 1
		_check(actual_pairs.size() == expected_pairs.size(), scenario.id + ": every source resource initialized")
		var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
		var save_owner := OWNER._ownership(state)
		var storage := SaveSystem.new(root + scenario.id + "/")
		var saved := storage.save_slot(0, state)
		_check(saved.ok and OWNER._ownership(state) == save_owner, scenario.id + ": actual primary save preserves owner")
		if not saved.ok: continue
		var loaded := storage.load_recovery_source(0, "primary")
		_check(loaded.ok, scenario.id + ": actual primary reopening")
		if loaded.ok:
			_check(EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical), scenario.id + ": complete canonical initial primary")
			var reopened_planets := PlanetSystem.new(loaded.state)
			var reinitialized := OWNER._ownership(loaded.state)
			reopened_planets.initialize_colonized_resource_sites()
			_check(OWNER._ownership(loaded.state) == reinitialized, scenario.id + ": reopening initialization is idempotent")
			_check(EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical), scenario.id + ": cold catalog setup and initialization preserve full persistent state")
			saves += 1
	var rejections := GUARD.rejection_errors()
	errors.append_array(rejections.errors)
	_check(gold.cases.size() == 12 and matched == 1268 and initialized == 1268 and saves == 12 and rejections.rejected == 19, "complete initial generation/save/drift corpus")
	print("PARITY RESOURCE INITIAL CAPACITY TESTS: states=", gold.cases.size(), "; matched=", matched, "; initialized=", initialized, "; primary=", saves, "; fixture_rejects=", rejections.rejected, "; root: ", root, "; errors=", errors)
	if errors.is_empty(): print("PARITY RESOURCE INITIAL CAPACITY TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
