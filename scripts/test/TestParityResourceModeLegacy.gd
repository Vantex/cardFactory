extends Node

const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
const RESERVE := preload("res://scripts/game/SourceResourceReserveSystem.gd")
const FIXTURE := "res://tests/fixtures/task27-legacy-mining-iron-save.json"
var errors := []
var saves := 0

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _ready() -> void:
	call_deferred("_run")

func _save(state: GameState, directory: String) -> GameState:
	var before := OWNER._ownership(state)
	var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
	var storage := SaveSystem.new(directory)
	var written := storage.save_slot(0, state)
	_check(written.ok, directory + ": actual primary write")
	_check(OWNER._ownership(state) == before, directory + ": save keeps owner")
	if not written.ok: return null
	var loaded := storage.load_recovery_source(0, "primary")
	_check(loaded.ok, directory + ": actual primary load")
	if not loaded.ok: return null
	_check(EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical), directory + ": complete canonical primary")
	saves += 1
	return loaded.state

func _run() -> void:
	var root := "res://.godot/task27-mode-legacy-%d/" % OS.get_process_id()
	var storage := SaveSystem.new(root + "old/")
	_check(FileAccess.get_sha256(FIXTURE) == "d0f4027bbd29ccddd361f583e6f34e9e497f0676296c5343567bc9365812d009", "actual old primary fixture unchanged")
	_check(DirAccess.copy_absolute(FIXTURE, (root + "old/").path_join("save_0.json")) == OK, "actual old primary copied")
	var old := storage.load_recovery_source(0, "primary")
	_check(old.ok, "actual old fractional primary accepted")
	if not old.ok:
		print("PARITY RESOURCE MODE LEGACY TESTS errors=", errors)
		get_tree().quit(1)
		return
	saves += 1
	var profiles := [
		{"id": "subunit", "remaining": 0.55, "level": 9, "debt": null, "allowance": 5},
		{"id": "crossunit", "remaining": 1.55, "level": 9, "debt": 9, "allowance": 6},
		{"id": "exhausted", "remaining": 0.55, "level": 9, "debt": 5, "allowance": 0},
		{"id": "level8", "remaining": 0.55, "level": 8, "debt": 0, "allowance": 2},
		{"id": "level1", "remaining": 0.95, "level": 1, "debt": null, "allowance": 1},
	]
	for profile in profiles:
		var state: GameState = old.state.copy_state()
		state.emit_canvas_events = false
		state.progression_facts.infinite_research.vein_utilization.level = profile.level
		var building: Dictionary = state.buildings.building_1
		var site: Dictionary = state.resource_sites[building.resource_site_id]
		site.remaining = profile.remaining
		site.erase("depletion_remainder")
		if profile.debt != null: site.depletion_remainder = profile.debt
		building.output_buffer.iron_ore = 0.0
		building.progress = 0.0
		state = _save(state, root + profile.id + "/before/")
		if state == null: continue
		site = state.resource_sites[building.resource_site_id]
		var before := OWNER._ownership(state)
		var snapshot: Dictionary = state.get_resource_reserve_snapshot(site)
		_check(snapshot.exhausted == (profile.allowance == 0), profile.id + ": query exhaustion follows legal old raw reserve")
		_check(RESERVE.available_output(state, site) == profile.allowance, profile.id + ": manual allowance follows legal old raw reserve")
		_check(OWNER._ownership(state) == before, profile.id + ": query/allowance keeps raw and canonical ownership")
		var projected := site.duplicate(true)
		projected.kind = "vein"
		_check(state.get_resource_reserve_snapshot(projected).exhausted == (profile.allowance == 0), profile.id + ": native copied record with optional kind keeps legacy allowance")
		var automatic: GameState = state.copy_state()
		PowerSystem.new(automatic).update(1.0)
		ProductionSystem.new(automatic).update(30.0)
		_check(automatic.buildings.building_1.output_buffer.iron_ore == profile.allowance, profile.id + ": existing actual production allowance")
		automatic = _save(automatic, root + profile.id + "/automatic/")
		var initial_inventory := float(state.get_planet_inventory("home").get("iron_ore", 0))
		var produced_before := float(state.progression_facts.get("produced", {}).get("iron_ore", 0))
		var manual_before := float(state.progression_facts.get("manual_mined", 0))
		for i in range(profile.allowance):
			_check(SourceProgressionFacts.mine(state, site.id).ok, profile.id + ": actual manual unit " + str(i))
			state = _save(state, root + profile.id + "/manual-" + str(i) + "/")
			if state == null: break
			site = state.resource_sites[building.resource_site_id]
		if state == null: continue
		_check(float(state.get_planet_inventory("home").get("iron_ore", 0)) - initial_inventory == profile.allowance, profile.id + ": native tray exact unit count")
		_check(float(state.progression_facts.get("produced", {}).get("iron_ore", 0)) - produced_before == profile.allowance, profile.id + ": produced fact")
		_check(float(state.progression_facts.get("manual_mined", 0)) - manual_before == profile.allowance, profile.id + ": manual fact")
		var debt := float(site.get("depletion_remainder", 0))
		var initial_debt := float(profile.debt) if profile.debt != null else 0.0
		_check(absf(float(site.remaining) - debt / 10.0 - (profile.remaining - initial_debt / 10.0 - profile.allowance * (10.0 - profile.level) / 10.0)) < 0.00000001, profile.id + ": exact effective reserve conservation")
		_check(automatic != null and site.remaining == automatic.resource_sites[site.id].remaining and debt == automatic.resource_sites[site.id].get("depletion_remainder", 0), profile.id + ": manual/automatic raw reserve and carry agree")
		_check(state.get_resource_reserve_snapshot(site).exhausted, profile.id + ": last finite unit stops")
		var exhausted_owner := OWNER._ownership(state)
		_check(not SourceProgressionFacts.mine(state, site.id).ok and OWNER._ownership(state) == exhausted_owner, profile.id + ": depleted manual rejects without mutation")
		_check(state.set_resource_mode("infinite"), profile.id + ": infinite accepted")
		_check(SourceProgressionFacts.mine(state, site.id).ok, profile.id + ": exhausted old mine resumes in infinite")
		_check(site.remaining == automatic.resource_sites[site.id].remaining and float(site.get("depletion_remainder", 0)) == debt, profile.id + ": infinite preserves old reserve/carry")
		state = _save(state, root + profile.id + "/infinite/")
		if state == null: continue
		site = state.resource_sites[building.resource_site_id]
		_check(state.set_resource_mode("finite") and state.get_resource_reserve_snapshot(site).exhausted, profile.id + ": reopened infinite returns to exhausted finite")
		state = _save(state, root + profile.id + "/finite/")
	_check(saves == 35, "complete legal old primary/continuation count")
	print("PARITY RESOURCE MODE LEGACY TESTS: profiles=", profiles.size(), "; primary=", saves, "; root: ", root, "; errors=", errors)
	if errors.is_empty(): print("PARITY RESOURCE MODE LEGACY TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
