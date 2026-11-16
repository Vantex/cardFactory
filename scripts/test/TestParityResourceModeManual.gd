extends Node

var errors := []
func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var gold := preload("res://scripts/test/ResourceModeFixtureGuard.gd").load_fixture("manual")
	if gold.is_empty():
		get_tree().quit(1)
		return
	var checked := 0
	var saved := 0
	for row in gold.cases:
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.progression_facts.infinite_research = {"vein_utilization": {"level": row.input.level, "invested": "0"}}
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		planets.initialize_colonized_resource_sites()
		var site: Dictionary = {}
		for candidate in planets.get_planet_resource_sites(row.input.planet):
			if candidate.item_id == row.input.item: site = candidate; break
		if site.is_empty():
			errors.append(row.id + ": actual resource missing")
			continue
		site = state.resource_sites[site.id]
		site.remaining = row.input.remaining
		site.depletion_remainder = row.input.remainder
		state.set_resource_mode(row.input.mode)
		var inventory_before := float(state.get_planet_inventory(state.active_planet_id).get(row.input.item, 0))
		var result := SourceProgressionFacts.mine(state, site.id)
		var produced := preload("res://scripts/game/SourceResourceOutputSystem.gd").raw_amount(state, site)
		_check(produced == row.expected.produced, row.id + ": source-produced quantity belongs to resource output")
		_check(float(state.get_planet_inventory(state.active_planet_id).get(row.input.item, 0)) == inventory_before, row.id + ": manual output leaves tray stock unchanged")
		_check(site.remaining == row.expected.remaining and site.depletion_remainder == row.expected.remainder, row.id + ": exact finite reserve/carry or infinite reserve retention")
		_check(float(state.progression_facts.get("produced", {}).get(row.input.item, 0)) == float(row.expected.total_produced), row.id + ": actual produced fact")
		_check(float(state.progression_facts.get("manual_mined", 0)) == float(row.expected.manual_mined), row.id + ": actual manual fact")
		_check(result.ok == (row.expected.produced == 1), row.id + ": local action success reflects mined amount")
		if row.input.item == "iron_ore" and row.input.level == 1:
			var storage := SaveSystem.new("res://.godot/task27-mode-manual-%d/%s/" % [OS.get_process_id(), row.id])
			var write := storage.save_slot(0, state)
			_check(write.ok, row.id + ": actual manual mode primary save")
			if write.ok:
				var loaded := storage.load_recovery_source(0, "primary")
				_check(loaded.ok and loaded.state.resource_mode == row.input.mode, row.id + ": actual manual mode primary reload")
				if loaded.ok: saved += 1
		checked += 1
	_check(checked == 312 and saved == 6, "complete source manual-domain and save counts")
	print("PARITY RESOURCE MODE MANUAL TESTS: ", checked, "; primary=", saved, "; root: res://.godot/task27-mode-manual-%d/; errors=" % OS.get_process_id(), errors.slice(0, 12))
	if errors.is_empty(): print("PARITY RESOURCE MODE MANUAL TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
