extends RefCounted

const FIXTURES := {
	"iron": ["res://tests/fixtures/task27-legacy-mining-iron-save.json", "d0f4027bbd29ccddd361f583e6f34e9e497f0676296c5343567bc9365812d009"],
	"oil": ["res://tests/fixtures/task27-legacy-mining-oil-save.json", "54ecb39af6148367d60daff3f6e939d9b0efa32e94ef61682eb0f004095f2d04"],
	"near-full": ["res://tests/fixtures/task27-legacy-mining-near-full-save.json", "93e427196f21571ee81286dfd55213a6bbbac88a7cd57f2f11660c439a7a014c"],
}

func run() -> Dictionary:
	var errors := []
	var saves := 0
	var rejects := 0
	var boundaries := 0
	var root := "res://.godot/task27-legacy-mining-%d/" % OS.get_process_id()
	for label in FIXTURES:
		var fixture: Array = FIXTURES[label]
		if FileAccess.get_sha256(fixture[0]) != fixture[1]:
			errors.append(label + ": actual old primary fixture changed")
			continue
		var directory: String = root + String(label) + "/before/"
		var storage := SaveSystem.new(directory)
		if DirAccess.copy_absolute(fixture[0], directory.path_join("save_0.json")) != OK:
			errors.append(label + ": actual old primary copy failed")
			continue
		var first := storage.load_recovery_source(0, "primary")
		if not first.ok:
			errors.append(label + ": actual old legal primary rejected")
			continue
		saves += 1
		var state: GameState = first.state
		state.emit_canvas_events = false
		PowerSystem.new(state).update(1.0 / 60)
		var building: Dictionary = state.buildings.building_1
		var item := String(building.output_item)
		var site: Dictionary = state.resource_sites[building.resource_site_id]
		var initial_output := float(building.output_buffer[item])
		var initial_reserve := float(site.remaining)
		if initial_output == floorf(initial_output) or initial_reserve == floorf(initial_reserve) or site.has("depletion_remainder"): errors.append(label + ": old actual fractional fixture shape changed")
		var production := ProductionSystem.new(state, StatisticsSystem.new(state))
		production.update(1.0 / 60)
		if building.output_buffer[item] != initial_output or site.remaining != initial_reserve or site.has("depletion_remainder"): errors.append(label + ": zero completed cycles changed old cargo/reserve")
		for tick in range(59): production.update(1.0 / 60)
		var produced := float(building.output_buffer[item]) - initial_output
		var remainder := float(site.get("depletion_remainder", 0))
		var consumption := 0.9 if item == "iron_ore" else 1.0
		if absf(produced - roundf(produced)) > 0.00000001 or absf(float(site.remaining) - remainder / 10 - (initial_reserve - produced * consumption)) > 0.00000001: errors.append(label + ": integer cycles violate legacy cargo/reserve conservation")
		if label == "near-full":
			if produced != 0 or float(building.output_buffer[item]) > preload("res://scripts/game/SourceEntityCapacitySystem.gd").output_capacity(state, building): errors.append("near-full: fractional remaining space rounded up beyond capacity")
			else: boundaries += 1
		elif produced != 1: errors.append(label + ": actual old continuation did not complete exactly one cycle")
		var payload := GameStateCodec.to_persistent_dict(state)
		for invalid in [true, false, "1", null, -1, 10, 0.5, NAN, INF]:
			var broken := payload.duplicate(true)
			broken.resource_sites[building.resource_site_id].depletion_remainder = invalid
			if GameStateValidator.validate_persistent_dict(broken).is_empty(): errors.append(label + ": accepts invalid new debt " + str(invalid))
			else: rejects += 1
		var missing := payload.duplicate(true)
		missing.resource_sites[building.resource_site_id].erase("depletion_remainder")
		if not GameStateValidator.validate_persistent_dict(missing).is_empty(): errors.append(label + ": old missing debt rejected")
		var last := _save(state, root + label + "/after/")
		if not last.ok: errors.append(label + ": legacy continuation primary failed")
		else: saves += 1
		if label == "iron":
			var near := GameState.new()
			near.copy_from(state)
			near.emit_canvas_events = false
			var subject: Dictionary = near.buildings.building_1
			var reserve: Dictionary = near.resource_sites[subject.resource_site_id]
			var capacity := float(preload("res://scripts/game/SourceEntityCapacitySystem.gd").output_capacity(near, subject))
			subject.output_buffer[item] = capacity - 1.0
			subject.progress = 0.0
			PowerSystem.new(near).update(1.0)
			ProductionSystem.new(near).update(1.0)
			if subject.output_buffer[item] != capacity: errors.append("exact free unit fails to accept exactly one output")
			else: boundaries += 1
			near.progression_facts.infinite_research.vein_utilization.level = 9
			subject.output_buffer[item] = initial_output
			subject.progress = 0.0
			reserve.remaining = 0.55
			reserve.depletion_remainder = 0.0
			ProductionSystem.new(near).update(3.0)
			if absf(float(subject.output_buffer[item]) - initial_output - 5.0) > 0.00000001 or reserve.remaining != 0.55 or reserve.depletion_remainder != 5.0: errors.append("sub-unit legacy reserve failed integer allowance or conservation")
			else: boundaries += 1
	print("LEGACY MINING COMPAT SUMMARY: saves ", saves, "; debt rejections ", rejects, "; boundaries ", boundaries, "; root: ", root, "; errors: ", JSON.stringify(errors))
	return {"errors": errors, "saves": saves, "rejections": rejects, "boundaries": boundaries, "root": root}

func _save(state: GameState, root: String) -> Dictionary:
	var exact := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var owner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
	var before := owner._ownership(state)
	var storage := SaveSystem.new(root)
	var saved := storage.save_slot(0, state)
	if not saved.ok or owner._ownership(state) != before: return {"ok": false}
	var loaded := storage.load_recovery_source(0, "primary")
	if not loaded.ok or not exact._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical): return {"ok": false}
	return loaded
