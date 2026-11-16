extends Node

const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
var errors := []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _run() -> void:
	var gold := preload("res://scripts/test/ResourceModeFixtureGuard.gd").load_fixture("query")
	if gold.is_empty():
		get_tree().quit(1)
		return
	var rejects := preload("res://scripts/test/ResourceModeFixtureGuard.gd").rejection_errors()
	errors.append_array(rejects.errors)
	_check(rejects.rejected == 36, "complete 36 frozen-fixture drift rejections")
	var baseline := GameState.new()
	SourceGalaxySystem.new(baseline).initialize(240721, false)
	var queried := 0
	for row in gold.cases:
		var state := GameState.new()
		state.source_galaxy = baseline.source_galaxy.duplicate(true)
		state.progression_facts = {"infinite_research": {"vein_utilization": {"level": row.input.level, "invested": "0"}}}
		_check(state.set_resource_mode(row.input.mode), row.id + ": actual state mode command")
		var site := {"id": "reserve-probe", "kind": row.input.kind, "item_id": row.input.resource, "planet_id": row.input.planet}
		for pair in [["remaining", "remaining"], ["capacity", "capacity"], ["depletion_remainder", "remainder"]]:
			if row.input[pair[1]] != null: site[pair[0]] = row.input[pair[1]]
		state.resource_sites["reserve-probe"] = site
		state.command_history.undo_entries.append({"label": "reserve query sentinel", "changes": []})
		state._spatial_index.add_entity("reserve-sentinel", Vector2(10, 20))
		var before := OWNER._ownership(state)
		var actual: Variant = state.get_resource_reserve_snapshot(site)
		var repeated: Variant = state.get_resource_reserve_snapshot(site)
		_check(EXACT._exact(actual, row.expected), row.id + ": public snapshot exact source result")
		_check(EXACT._exact(actual, repeated), row.id + ": repeated result exact")
		_check(OWNER._ownership(state) == before, row.id + ": complete raw/canonical ownership retained")
		queried += 1
	_check(queried == 4328, "complete original corpus executed")
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721, false)
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	state.command_history.undo_entries.append({"label": "mode command sentinel", "changes": []})
	state._spatial_index.add_entity("mode-sentinel", Vector2(10, 20))
	var before := OWNER._ownership(state)
	for illegal in [true, false, null, 0, 1.0, "", "FINITE", "unknown"]:
		_check(not state.set_resource_mode(illegal), "illegal command rejected: " + str(illegal))
		_check(OWNER._ownership(state) == before, "illegal mode command retains full ownership")
	var old := GameStateCodec.to_persistent_dict(state)
	_check(not old.has("resource_mode"), "finite default preserves old payload shape")
	var missing := GameStateCodec.from_persistent_dict(old)
	_check(missing != null and missing.resource_mode == "finite", "missing old schema-v9 field defaults to finite")
	for illegal in [true, false, null, 0, 1.0, "", "FINITE", "unknown"]:
		var bad := old.duplicate(true)
		bad.resource_mode = illegal
		_check(not GameStateValidator.validate_persistent_dict(bad).is_empty(), "illegal persistent mode rejected")
		_check(GameStateCodec.from_persistent_dict(bad) == null, "illegal persistent mode cannot decode")
	_check(state.set_resource_mode("infinite"), "valid mode change accepted")
	_check(state.copy_state().resource_mode == "infinite", "copy preserves mode")
	var copied := GameState.new()
	copied.copy_from(state)
	_check(copied.resource_mode == "infinite", "install/copy_from preserves mode")
	var payload := GameStateCodec.to_persistent_dict(state)
	_check(payload.get("resource_mode") == "infinite", "infinite mode is persistent")
	var storage := SaveSystem.new("res://.godot/task27-mode-save-%d/" % OS.get_process_id())
	var ownership := OWNER._ownership(state)
	var saved := storage.save_slot(0, state)
	_check(saved.ok, "actual infinite mode primary save")
	_check(OWNER._ownership(state) == ownership, "saving does not mutate owner")
	if saved.ok:
		var loaded := storage.load_recovery_source(0, "primary")
		_check(loaded.ok and loaded.state.resource_mode == "infinite", "actual primary load retains mode")
		if loaded.ok:
			var canonical: Dictionary = JSON.parse_string(JSON.stringify(payload, "", true, true))
			_check(EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical), "actual primary keeps complete canonical state")
	_check(state.set_resource_mode("finite"), "switch back to finite accepted")
	print("PARITY RESOURCE MODE QUERY TESTS: ", queried, "; fixture rejects=36; illegal command=8; illegal persistent=8; primary=", int(saved.ok), "; root: res://.godot/task27-mode-save-%d/; errors: " % OS.get_process_id(), errors.slice(0, 12))
	if errors.is_empty(): print("PARITY RESOURCE MODE QUERY TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
