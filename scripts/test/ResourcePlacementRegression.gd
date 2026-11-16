extends RefCounted

const FIXTURE := "res://tests/fixtures/parity/behavior/task27-resource-placement.json"
const INPUTS := {"actual-funded-install-coal":{"item":"coal","planet":"home","entity":"vein_coal","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-copper_ore":{"item":"copper_ore","planet":"home","entity":"vein_copper","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-crude_oil":{"item":"crude_oil","planet":"home","entity":"vein_oil","extractor":"oil_extractor","funded_kits":1,"count":1},"actual-funded-install-fire_ice":{"item":"fire_ice","planet":"frost","entity":"frost_fire_ice","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-fractal_silicon":{"item":"fractal_silicon","planet":"ashen","entity":"ashen_fractal_silicon","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-iron_ore":{"item":"iron_ore","planet":"home","entity":"vein_iron","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-kimberlite_ore":{"item":"kimberlite_ore","planet":"ashen","entity":"ashen_kimberlite","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-optical_grating_crystal":{"item":"optical_grating_crystal","planet":"frost","entity":"vein_optical_grating","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-organic_crystal":{"item":"organic_crystal","planet":"ashen","entity":"ashen_organic_crystal","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-silicon_ore":{"item":"silicon_ore","planet":"ashen","entity":"vein_silicon","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-spiniform_stalagmite_crystal":{"item":"spiniform_stalagmite_crystal","planet":"frost","entity":"ashen_spiniform","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-stone":{"item":"stone","planet":"home","entity":"vein_stone","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-sulfuric_acid":{"item":"sulfuric_acid","planet":"ashen","entity":"ashen_sulfuric","extractor":"water_pump","funded_kits":1,"count":1},"actual-funded-install-titanium_ore":{"item":"titanium_ore","planet":"ashen","entity":"vein_titanium","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-unipolar_magnet":{"item":"unipolar_magnet","planet":"magnetar","entity":"ashen_unipolar","extractor":"mining_machine","funded_kits":1,"count":1},"actual-funded-install-water":{"item":"water","planet":"home","entity":"vein_water","extractor":"water_pump","funded_kits":1,"count":1}}

func run() -> Dictionary:
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	var validation := validation_errors(fixture)
	if not validation.is_empty(): return {"errors": validation, "bindings": 0, "saves": 0, "root": ""}
	var results := []
	var differences := 0
	var errors := []
	var saves := 0
	var save_root := "res://.godot/task27-resource-placement-%d/" % OS.get_process_id()
	var exact := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var owner := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
	for row in fixture.cases:
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		var system_id := String(planets.get_planet(row.input.planet).get("system_id", ""))
		if not state.explored_system_ids.has(system_id): state.explored_system_ids.append(system_id)
		planets.ensure_colonized_planet_records(row.input.planet)
		state.set_active_planet(row.input.planet)
		var type := "dsp_" + String(row.input.extractor)
		state.construction_inventory[type] = row.input.funded_kits
		var selected: Dictionary = {}
		for site in planets.get_planet_resource_sites(row.input.planet):
			if site.item_id == row.input.item:
				selected = site
				break
		if selected.is_empty():
			differences += 1
			results.append({"item": row.input.item, "reason": "actual seeded native resource site missing"})
			continue
		var placed := state.try_place_building(type, selected.position)
		var matches: bool = placed.ok and state.construction_inventory[type] == row.expected.remaining_kits and state.buildings[placed.id].output_item == row.expected.resource and state.buildings[placed.id].resource_site_id == selected.id
		if not matches: differences += 1
		results.append({"item": row.input.item, "site": selected.id, "ok": placed.ok, "reason": placed.get("reason"), "remaining_kits": state.construction_inventory[type], "matches": matches})
		if matches:
			var canonical := GameStateCodec.to_persistent_dict(state)
			var before := owner._ownership(state)
			var storage := SaveSystem.new(save_root + str(saves) + "/")
			var saved := storage.save_slot(0, state)
			if not saved.ok or owner._ownership(state) != before:
				errors.append(row.id + ": actual paid placement save/ownership failed: " + JSON.stringify(saved.get("error", {})))
				continue
			saves += 1
			var loaded := storage.load_recovery_source(0, "primary")
			if not loaded.ok or not exact._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical): errors.append(row.id + ": actual placement primary digest/config/materials reload failed")
	print("RESOURCE PAID PLACEMENT DIFFERENCES: ", differences, "/", fixture.cases.size(), "; results: ", JSON.stringify(results))
	print("RESOURCE PAID PLACEMENT ACTUAL SAVES: ", saves, "; errors: ", JSON.stringify(errors), "; root: ", save_root)
	if differences != 0: errors.append("Actual paid placement mismatches: %d" % differences)
	return {"errors": errors, "bindings": fixture.cases.size() - differences, "saves": saves, "root": save_root}

static func validation_errors(fixture: Dictionary) -> Array[String]:
	var source := DSPOnlineParity.read_json(DSPOnlineParity.ROOT + "dsponline_source_catalog.json")
	var exact := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var controls := preload("res://scripts/test/WorldControlBehaviorRunner.gd")
	if fixture.get("source_commit") != source.source.commit or not fixture.get("source_files") is Dictionary: return ["resource placement provenance missing"]
	if not controls._same_ids(fixture.source_files.keys(), exact.SOURCE_MODULES): return ["resource placement exact source modules changed"]
	for file in exact.SOURCE_MODULES:
		if fixture.source_files[file] != source.source.files.get(file): return ["resource placement source hash drift"]
	if not exact._exact(fixture.get("source_environment"), {"DEV": false, "PROD": true, "MODE": "production"}): return ["resource placement production source environment changed"]
	if not fixture.get("cases") is Array: return ["resource placement cases missing"]
	var ids := []
	for row in fixture.cases:
		if not row is Dictionary: return ["resource placement case malformed"]
		ids.append(row.get("id"))
	if not controls._same_ids(ids, INPUTS.keys()): return ["resource placement cases incomplete or duplicated"]
	for row in fixture.cases:
		var input: Dictionary = INPUTS[row.id]
		if not exact._exact(row.get("input"), input): return ["resource placement source input changed: " + row.id]
		if not exact._exact(row.get("expected"), {"resource": input.item, "miner_count": 1, "extractor": input.extractor, "remaining_kits": 0}): return ["resource placement exact paid source result changed: " + row.id]
	return []

static func rejection_errors() -> Array[String]:
	var errors: Array[String] = []
	var fixture := DSPOnlineParity.read_json(FIXTURE)
	for kind in ["commit", "source", "missing_module", "extra_module", "environment", "missing", "duplicate", "row", "item", "planet", "entity", "extractor", "kit", "count", "count_bool", "count_fraction", "output_shape", "resource", "output_extractor", "miner", "miner_bool", "remaining", "remaining_bool"]:
		var broken := fixture.duplicate(true)
		match kind:
			"commit": broken.source_commit = "wrong"
			"source": broken.source_files["src/game/engine.ts"] = "wrong"
			"missing_module": broken.source_files.erase("src/game/galaxyCatalog.ts")
			"extra_module": broken.source_files["src/game/unknown-miner.ts"] = null
			"environment": broken.source_environment.DEV = true
			"missing": broken.cases.pop_back()
			"duplicate": broken.cases.append(broken.cases[0].duplicate(true))
			"row": broken.cases[0] = []
			"item": broken.cases[0].input.item = "water"
			"planet": broken.cases[0].input.planet = "giant"
			"entity": broken.cases[0].input.entity = "missing"
			"extractor": broken.cases[0].input.extractor = "water_pump"
			"kit": broken.cases[0].input.funded_kits = 2
			"count": broken.cases[0].input.count = 2
			"count_bool": broken.cases[0].input.count = true
			"count_fraction": broken.cases[0].input.count = 1.0 + 5.0e-10
			"output_shape": broken.cases[0].expected.extra = 0
			"resource": broken.cases[0].expected.resource = "water"
			"output_extractor": broken.cases[0].expected.extractor = "water_pump"
			"miner": broken.cases[0].expected.miner_count = 2
			"miner_bool": broken.cases[0].expected.miner_count = true
			"remaining": broken.cases[0].expected.remaining_kits = 1
			"remaining_bool": broken.cases[0].expected.remaining_kits = false
		if validation_errors(broken).is_empty(): errors.append("resource placement accepts " + kind + " fixture drift")
	return errors
