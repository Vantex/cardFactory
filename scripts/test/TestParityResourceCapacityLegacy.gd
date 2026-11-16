extends Node

var errors := []
var saves := 0
const FIXTURES := preload("res://scripts/test/LegacyMiningCompatibilityRegression.gd").FIXTURES
var rejections := 0
var continued := 0

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _ready() -> void:
	call_deferred("_run")

func _exact(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_finite(float(a)) and is_finite(float(b)) and a == b
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _exact(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _exact(a[i], b[i]): return false
		return true
	return typeof(a) == typeof(b) and a == b

func _run() -> void:
	var root := "res://.godot/task27-capacity-legacy-%d/" % OS.get_process_id()
	for name in ["iron", "oil", "near-full"]:
		var fixture: String = FIXTURES[name][0]
		_check(FileAccess.get_sha256(fixture) == FIXTURES[name][1], name + ": frozen old primary bytes unchanged")
		var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
		var old_sites: Dictionary = envelope.state.resource_sites
		var storage := SaveSystem.new(root + name + "/")
		_check(DirAccess.copy_absolute(fixture, root + name + "/save_0.json") == OK, name + ": actual old primary copy")
		_check(FileAccess.get_sha256(fixture) == FileAccess.get_sha256(root + name + "/save_0.json"), name + ": copied old bytes exact")
		var loaded := storage.load_recovery_source(0, "primary")
		_check(loaded.ok, name + ": actual old primary loads; error=" + JSON.stringify(loaded.get("error", {})))
		if not loaded.ok: continue
		var state: GameState = loaded.state
		var before: Dictionary = GameStateCodec.to_persistent_dict(state)
		var target_id: String = state.buildings.building_1.resource_site_id
		var original: Dictionary = before.resource_sites[target_id]
		var source_capacity: int = GalaxySystem.new(state).build_resource_sites_for_planet(original.planet_id, state.galaxy_seed)[target_id].capacity
		for illegal in [null, true, false, "capacity", 0, -1, 1.25, float(original.capacity) + 1, source_capacity + 1, NAN, INF]:
			var bad := before.duplicate(true)
			bad.resource_sites[target_id].capacity = illegal
			_check(not GameStateValidator.validate_persistent_dict(bad).is_empty(), name + ": illegal capacity rejected: " + str(illegal))
			rejections += 1
		var excessive := before.duplicate(true)
		excessive.resource_sites[target_id].remaining = float(original.capacity) + 1
		_check(not GameStateValidator.validate_persistent_dict(excessive).is_empty(), name + ": reserve cannot exceed preserved capacity")
		rejections += 1
		for id in old_sites:
			_check(JSON.stringify(before.resource_sites[id], "", true, true) == JSON.stringify(old_sites[id], "", true, true), name + ": original capacity/reserve/carry/ID preserved at " + id)
		PlanetSystem.new(state).initialize_colonized_resource_sites()
		var initialized: Dictionary = GameStateCodec.to_persistent_dict(state)
		_check(JSON.stringify(initialized, "", true, true) == JSON.stringify(before, "", true, true), name + ": existing site initialization preserves entire old persistent state")
		_check(storage.save_slot(0, state).ok, name + ": verified new primary")
		loaded = storage.load_recovery_source(0, "primary")
		_check(loaded.ok, name + ": actual primary reopening")
		if not loaded.ok: continue
		_check(JSON.stringify(GameStateCodec.to_persistent_dict(loaded.state), "", true, true) == JSON.stringify(initialized, "", true, true), name + ": complete canonical old compatibility")
		saves += 1
		var target: Dictionary = loaded.state.buildings.building_1
		var site: Dictionary = loaded.state.resource_sites[target.resource_site_id]
		_check(site.capacity == old_sites[site.id].capacity, name + ": source jitter correction does not reset legal old capacity")
		var resumed: GameState = loaded.state
		var engine := SimulationEngine.new(resumed)
		for tick in range(60): engine.update(1.0 / 60.0)
		var old_output: float = before.buildings.building_1.output_buffer[target.output_item]
		var output: float = resumed.buildings.building_1.output_buffer[target.output_item]
		_check(output == old_output + (0.0 if name == "near-full" else 1.0), name + ": actual old fullEngine cycle output")
		_check(resumed.elapsed_time > before.elapsed_time, name + ": continuation advances real time")
		_check(resumed.resource_sites[site.id].remaining == float(original.remaining) - (1.0 if name == "oil" else 0.0), name + ": old raw fractional reserve preserved/depleted exactly")
		_check(resumed.resource_sites[site.id].get("depletion_remainder", 0) == (9 if name == "iron" else 0), name + ": exact old fractional carry")
		var continuing := SaveSystem.new(root + name + "/continued/")
		var expected: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(resumed), "", true, true))
		_check(continuing.save_slot(0, resumed).ok, name + ": fullEngine60tick continuation primary")
		var reopening := continuing.load_recovery_source(0, "primary")
		_check(reopening.ok, name + ": actual continuation primary reload")
		if reopening.ok:
			_check(_exact(GameStateCodec.to_persistent_dict(reopening.state), expected), name + ": full canonical continued old state")
			_check(reopening.state.resource_sites[site.id].capacity == old_sites[site.id].capacity, name + ": production preserves actual old capacity")
			continued += 1
	_check(saves == 3, "three old primary copy/reopen/save sequences")
	_check(rejections == 36 and continued == 3, "complete old capacity rejection and actual continuations")
	print("PARITY RESOURCE CAPACITY LEGACY TESTS: old_primary=3; resaved_primary=", saves, "; continued_primary=", continued, "; rejections=", rejections, "; root: ", root, "; errors=", errors)
	if errors.is_empty(): print("PARITY RESOURCE CAPACITY LEGACY TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
