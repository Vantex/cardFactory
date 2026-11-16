extends Node

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
var errors := []
var saves := 0
var rejected := 0
var partial := 0
var checked := 0
var results := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := "res://tests/fixtures/parity/behavior/task27-resource-collection.json"
	if FileAccess.get_sha256(fixture) != "ec7a3ea53574381f5861ba57bf207153f8f093a0d72a6e4a0e41083f1a2a066a":
		printerr("MANUAL COLLECTION FIXTURE DRIFT")
		get_tree().quit(1)
		return
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var root := "res://.godot/task27-manual-collection-%d/" % OS.get_process_id()
	for row in gold.cases:
		var state := GameState.new()
		state.emit_canvas_events = false
		SourceGalaxySystem.new(state).initialize(240721, false)
		state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
		state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
		for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
		var planets := PlanetSystem.new(state)
		for planet in [row.input.planet, row.input.active_planet]: planets.ensure_colonized_planet_records(planet)
		state.set_active_planet(row.input.active_planet)
		planets.initialize_colonized_resource_sites()
		for planet in state.colonized_planet_ids: state.planet_inventories[planet] = row.initial.planet_trays.get(planet, {}).duplicate(true)
		state.planet_inventory = row.initial.tray.duplicate(true)
		state.sync_active_planet_inventory()
		state.planet_tray_limits[state.active_planet_id] = row.input.tray_limit
		var site: Dictionary = {}
		for candidate in planets.get_planet_resource_sites(row.input.planet):
			if candidate.item_id == row.input.item: site = state.resource_sites[candidate.id]; break
		if site.is_empty(): errors.append(row.id + ": seeded native site missing"); continue
		if row.input.count > 0:
			state.set_active_planet(row.input.planet)
			var type := OUTPUT.extractor_type(row.input.item)
			state.construction_inventory[type] = 1
			var installed := state.try_place_building(type, site.position)
			if not installed.ok or state.construction_inventory[type] != 0: errors.append(row.id + ": actual funded count-one placement failed"); continue
			state.buildings[installed.id].machine_count = row.input.count
			state.buildings[installed.id].output_buffer = {row.input.item: row.input.current}
			state.set_active_planet(row.input.active_planet)
		else: site.output_buffer = {row.input.item: row.input.current}
		var before := OWNER._ownership(state)
		var result := InventorySystem.new(state).try_collect_resource_output(site.id)
		var moved := float(row.expected.tray.get(row.input.item, 0)) - float(row.initial.tray.get(row.input.item, 0))
		if OUTPUT.raw_amount(state, site) != float(row.expected.outputs.get(row.input.item, 0)): errors.append(row.id + ": shared resource output differs")
		if result.ok != (moved > 0): errors.append(row.id + ": collect success differs")
		if moved == 0:
			rejected += 1
			if before != OWNER._ownership(state): errors.append(row.id + ": rejected/no-op collection changes complete raw or canonical state")
		if moved > 0 and moved < row.input.current: partial += 1
		for planet in state.colonized_planet_ids:
			var expected: Dictionary = row.expected.tray if planet == row.input.active_planet else row.initial.planet_trays.get(planet, {})
			if not EXACT._exact(state.get_planet_inventory(planet), expected): errors.append(row.id + ": actual canonical tray differs at " + planet)
		var after := OWNER._ownership(state)
		var original: Dictionary = before.raw.fields.duplicate(true)
		var current: Dictionary = after.raw.fields.duplicate(true)
		for field in ["planet_inventory", "planet_inventories", "resource_sites", "buildings"]:
			original.erase(field)
			current.erase(field)
		if not EXACT._exact(original, current): errors.append(row.id + ": collection changed unrelated persistent facts/cargo/reserve")
		var old_sites: Dictionary = before.canonical.resource_sites.duplicate(true)
		var new_sites: Dictionary = after.canonical.resource_sites.duplicate(true)
		for id in old_sites: old_sites[id].erase("output_buffer"); new_sites[id].erase("output_buffer")
		if not EXACT._exact(old_sites, new_sites): errors.append(row.id + ": collection changed resource identity/reserve/binding")
		var old_buildings: Dictionary = before.canonical.buildings.duplicate(true)
		var new_buildings: Dictionary = after.canonical.buildings.duplicate(true)
		for id in old_buildings: old_buildings[id].erase("output_buffer"); new_buildings[id].erase("output_buffer")
		if not EXACT._exact(old_buildings, new_buildings): errors.append(row.id + ": collection changed building identity/configuration")
		results.append({"id": row.id, "moved": moved, "actual_output": OUTPUT.raw_amount(state, site), "actual_active_tray": state.planet_inventory.duplicate(true), "ok": result.ok})
		checked += 1
		if row.input.count == 1 and row.input.current == 179 and row.input.free == 7:
			var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
			var storage := SaveSystem.new(root + row.id + "/")
			var saved := storage.save_slot(0, state)
			var loaded := storage.load_recovery_source(0, "primary") if saved.ok else {}
			if not saved.ok or not loaded.get("ok", false) or not EXACT._exact(GameStateCodec.to_persistent_dict(loaded.state), canonical): errors.append(row.id + ": actual partial collection primary roundtrip failed")
			else: saves += 1
	print("PARITY RESOURCE COLLECTION TESTS: cases=", checked, "; rejected=", rejected, "; partial=", partial, "; primary=", saves, "; errors=", errors.size(), "; examples=", errors.slice(0, 12))
	var passed := checked == 1536 and saves == 32 and errors.is_empty()
	if passed: print("PARITY RESOURCE COLLECTION TESTS PASSED")
	get_tree().quit(0 if passed else 1)
