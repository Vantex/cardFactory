extends RefCounted

func run(gold: Dictionary) -> Dictionary:
	var errors := []
	var saves := 0
	var panels := 0
	var exact := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var owner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	var root := "res://.godot/task27-mining-paid-%d/" % OS.get_process_id()
	for item in gold.resources:
		var partial: Dictionary = {}
		var final: Dictionary = {}
		for row in gold.cases:
			if row.id == item + "-c1-l1-finite-powered-0.25": partial = row
			if row.id == item + "-c1-l1-finite-powered-1": final = row
		if partial.is_empty() or final.is_empty():
			errors.append(item + ": frozen source case missing")
			continue
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.progression_facts.infinite_research = {"vein_utilization": {"level": 1, "invested": "0"}}
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		planets.ensure_colonized_planet_records(partial.input.planet)
		state.set_active_planet(partial.input.planet)
		planets.initialize_colonized_resource_sites()
		var selected: Dictionary = {}
		for site in planets.get_planet_resource_sites(partial.input.planet):
			if site.item_id == item:
				selected = site
				break
		if selected.is_empty():
			errors.append(item + ": actual resource missing")
			continue
		var position: Vector2 = selected.position
		var type := "dsp_" + String(partial.input.extractor)
		state.construction_inventory[type] = 1
		var installed := state.try_place_building(type, position)
		if not installed.ok or state.construction_inventory[type] != 0:
			errors.append(item + ": actual paid installation failed")
			continue
		state.construction_inventory.dsp_solar_panel = 100
		var power := PowerSystem.new(state)
		var built_panels := 0
		while built_panels < 100:
			var placed := state.try_place_building("dsp_solar_panel", position + Vector2(240 * built_panels, 400))
			if not placed.ok:
				errors.append(item + ": actual solar placement failed: " + JSON.stringify(placed))
				break
			built_panels += 1
			power.update(1.0 / 60)
			if state.buildings[installed.id].power_efficiency == 1.0: break
		panels += built_panels
		if state.buildings[installed.id].power_efficiency != 1.0:
			errors.append(item + ": actual solar power insufficient")
			continue
		var building: Dictionary = state.buildings[installed.id]
		var site: Dictionary = state.resource_sites[building.resource_site_id]
		if not site.infinite: site.remaining = 100.0
		site.depletion_remainder = 0.0
		var engine := SimulationEngine.new(state)
		for tick in range(15): engine.update(1.0 / 60)
		errors.append_array(_differences(state, installed.id, partial.expected, item + " partial"))
		var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
		var before := owner._ownership(state)
		var storage := SaveSystem.new(root + item + "/partial/")
		var saved := storage.save_slot(0, state)
		if not saved.ok or owner._ownership(state) != before:
			errors.append(item + ": actual partial save failed or mutates owner: " + JSON.stringify(saved.get("error", {})))
			continue
		var loaded := storage.load_recovery_source(0, "primary")
		if not loaded.ok or not exact._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical):
			errors.append(item + ": actual partial primary roundtrip failed")
			continue
		saves += 1
		var resumed := SimulationEngine.new(loaded.state)
		for tick in range(45): resumed.update(1.0 / 60)
		errors.append_array(_differences(loaded.state, installed.id, final.expected, item + " resumed"))
		canonical = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(loaded.state), "", true, true))
		before = owner._ownership(loaded.state)
		storage = SaveSystem.new(root + item + "/resumed/")
		saved = storage.save_slot(0, loaded.state)
		if not saved.ok or owner._ownership(loaded.state) != before:
			errors.append(item + ": actual resumed save failed or mutates owner: " + JSON.stringify(saved.get("error", {})))
			continue
		var reopened := storage.load_recovery_source(0, "primary")
		if not reopened.ok or not exact._exact(GameStateCodec.to_persistent_dict(reopened.state), canonical):
			errors.append(item + ": actual resumed primary roundtrip failed: " + (JSON.stringify(reopened.get("error", {})) if not reopened.ok else _first_difference(canonical, GameStateCodec.to_persistent_dict(reopened.state))))
			continue
		saves += 1
	print("MINING PAID SAVE SUMMARY: resources ", gold.resources.size(), "; saves ", saves, "; actual paid solar cards ", panels, "; root: ", root, "; errors: ", JSON.stringify(errors))
	return {"errors": errors, "saves": saves, "panels": panels, "root": root}

func _differences(state: GameState, id: String, expected: Dictionary, label: String) -> Array:
	var building: Dictionary = state.buildings[id]
	var site: Dictionary = state.resource_sites[building.resource_site_id]
	var actual := {"output": building.output_buffer.get(building.output_item, 0), "progress": building.progress, "remainder": site.get("depletion_remainder", 0), "power_factor": building.power_efficiency, "utilization": building.production_utilization, "production_rate": building.last_production_per_minute, "total_produced": state.progression_facts.get("produced", {}).get(building.output_item, 0)}
	if not site.infinite: actual.remaining = site.remaining
	var errors := []
	for field in actual:
		if not preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._number(actual[field]) or absf(float(actual[field]) - float(expected[field])) > 0.00001: errors.append(label + ": " + field + " differs: " + str(actual[field]) + " expected " + str(expected[field]))
	return errors

func _first_difference(left: Variant, right: Variant, at: String = "state") -> String:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return at + ": dictionary size differs"
		for key in left:
			if not right.has(key): return at + ": missing " + str(key)
			var nested := _first_difference(left[key], right[key], at + "." + str(key))
			if nested != "": return nested
		return ""
	if left is Array and right is Array:
		if left.size() != right.size(): return at + ": array size differs"
		for index in range(left.size()):
			var nested := _first_difference(left[index], right[index], at + "[" + str(index) + "]")
			if nested != "": return nested
		return ""
	if not preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")._exact(left, right): return at + ": " + JSON.stringify(left, "", true, true) + " vs " + JSON.stringify(right, "", true, true)
	return ""
