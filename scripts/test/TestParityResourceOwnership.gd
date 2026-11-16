extends Node

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
const EXACT := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
var errors := []
var stages := 0
var saves := 0
var sessions := 0
var kits := 0
var panels := 0
var results := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := "res://tests/fixtures/parity/behavior/task27-resource-ownership.json"
	if FileAccess.get_sha256(fixture) != "2fbd0c28174f982f5d33d9a5e9ea3614e6efdf31209b18de56c05d5a2881b6c5":
		printerr("MANUAL OWNERSHIP FIXTURE DRIFT")
		get_tree().quit(1)
		return
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var root := "res://.godot/task27-manual-ownership-%d/" % OS.get_process_id()
	for row in gold.cases:
		var state := _setup(row)
		if state == null: continue
		var site_id := ""
		for candidate in state.resource_sites.values():
			if candidate.planet_id == row.input.planet and candidate.item_id == row.input.item: site_id = candidate.id; break
		var row_results := []
		for index in range(row.stages.size()):
			var stage: Dictionary = row.stages[index]
			var site: Dictionary = state.resource_sites[site_id]
			var before := OWNER._ownership(state)
			OUTPUT.amount(state, site)
			OUTPUT.manual_capacity(state, site)
			if before != OWNER._ownership(state): errors.append(row.id + ": pure cache queries changed owner")
			match stage.label:
				"manual-one": SourceProgressionFacts.mine(state, site_id, 1)
				"manual-64": SourceProgressionFacts.mine(state, site_id, 64)
				"output-to-tray": InventorySystem.new(state).try_collect_resource_output(site_id)
				_:
					var engine := SimulationEngine.new(state)
					for tick in range(60): engine.update(1.0 / 60)
					sessions += 1
			var actual := _snapshot(state, site_id)
			_compare(row, stage, actual)
			row_results.append({"label": stage.label, "actual": actual})
			stages += 1
			var canonical: Dictionary = JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state), "", true, true))
			var storage := SaveSystem.new(root + row.id + "/" + str(index) + "/")
			before = OWNER._ownership(state)
			var saved := storage.save_slot(0, state)
			if not saved.ok or before != OWNER._ownership(state):
				errors.append(row.id + "/" + stage.label + ": primary failed or changes owners: " + JSON.stringify(saved.get("error", {})))
				continue
			var reopened := storage.load_recovery_source(0, "primary")
			if not reopened.ok:
				errors.append(row.id + "/" + stage.label + ": primary reopen failed: " + JSON.stringify(reopened.get("error", {})))
				continue
			if not EXACT._exact(GameStateCodec.to_persistent_dict(reopened.state), canonical):
				errors.append(row.id + "/" + stage.label + ": complete primary canonical mismatch")
				continue
			saves += 1
			state = reopened.state
		results.append({"id": row.id, "stages": row_results})
		if results.size() % 16 == 0: print("MANUAL OWNERSHIP PROGRESS: ", results.size(), "/176; errors=", errors.size())
	print("PARITY RESOURCE OWNERSHIP TESTS: cases=", results.size(), "; stages=", stages, "; primary=", saves, "; sessions=", sessions, "; kits=", kits, "; panels=", panels, "; errors=", errors.size(), "; examples=", errors.slice(0, 16))
	var passed := results.size() == 176 and stages == 880 and saves == 880 and sessions == 352 and errors.is_empty()
	if passed: print("PARITY RESOURCE OWNERSHIP TESTS PASSED")
	get_tree().quit(0 if passed else 1)

func _setup(row: Dictionary) -> GameState:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
	# Unrelated native teaching rewards must not inject stock into this controlled flow.
	for objective in ObjectiveSystem.load_catalog().objectives:
		state.completed_objective_ids.append(objective.id)
		state.claimed_progression_reward_ids.append("objective:" + String(objective.id))
	for achievement in ObjectiveSystem.load_catalog().achievements:
		state.completed_achievement_ids.append(achievement.id)
		state.claimed_progression_reward_ids.append("achievement:" + String(achievement.id))
	state.progression_facts.infinite_research = {"vein_utilization": {"level": row.input.level, "invested": "0"}}
	state.explored_system_ids = SourceGalaxySystem.catalog().systems.keys()
	for explored in state.explored_system_ids: state.survey_progress_by_system[explored] = 1.0
	var planets := PlanetSystem.new(state)
	planets.ensure_colonized_planet_records(row.input.planet)
	state.set_active_planet(row.input.planet)
	planets.initialize_colonized_resource_sites()
	state.set_resource_mode(row.input.mode)
	for planet in state.colonized_planet_ids:
		state.planet_inventories[planet] = row.initial.planet_trays.get(planet, {}).duplicate(true)
	state.planet_inventory = row.initial.tray.duplicate(true)
	state.sync_active_planet_inventory()
	var site: Dictionary = {}
	for candidate in planets.get_planet_resource_sites(row.input.planet):
		if candidate.item_id == row.input.item: site = state.resource_sites[candidate.id]; break
	if site.is_empty(): errors.append(row.id + ": missing actual source site"); return null
	if row.input.count > 0:
		var type := OUTPUT.extractor_type(row.input.item)
		state.construction_inventory[type] = 1
		var installed := state.try_place_building(type, site.position)
		if not installed.ok or state.construction_inventory[type] != 0:
			errors.append(row.id + ": paid count-one placement failed"); return null
		kits += 1
		var building: Dictionary = state.buildings[installed.id]
		building.machine_count = row.input.count
		building.output_buffer = {row.input.item: row.input.current}
		state.construction_inventory.dsp_solar_panel = 100
		var power := PowerSystem.new(state)
		var count := 0
		while count < 100:
			var placed := state.try_place_building("dsp_solar_panel", site.position + Vector2(240 * count, 400))
			if not placed.ok: errors.append(row.id + ": paid solar placement failed"); return null
			count += 1
			power.update(1.0 / 60)
			if building.power_efficiency == 1.0: break
		if building.power_efficiency != 1.0 or state.construction_inventory.dsp_solar_panel != 100 - count:
			errors.append(row.id + ": paid solar power/payment failed"); return null
		panels += count
	else:
		site.output_buffer = {row.input.item: row.input.current}
	site.remaining = 0.0 if site.infinite else row.input.remaining
	site.depletion_remainder = row.input.remainder
	return state

func _snapshot(state: GameState, site_id: String) -> Dictionary:
	var site: Dictionary = state.resource_sites[site_id]
	var item := String(site.item_id)
	var progress := 0.0
	var power := 0.0
	var owners := {"site": site.get("output_buffer", {}).duplicate(true), "buildings": {}}
	for building in OUTPUT.extractors(state, site_id):
		progress += float(building.progress)
		power = float(building.get("power_efficiency", 0))
		owners.buildings[building.id] = building.output_buffer.duplicate(true)
	var trays := {}
	for planet in state.colonized_planet_ids: trays[planet] = state.get_planet_inventory(planet).duplicate(true)
	trays[state.active_planet_id] = state.planet_inventory.duplicate(true)
	return {"output": OUTPUT.raw_amount(state, site), "owners": owners, "remaining": site.remaining, "remainder": site.get("depletion_remainder", 0), "progress": progress, "power": power, "produced": state.progression_facts.get("produced", {}).get(item, 0), "mined": state.progression_facts.get("manual_mined", 0), "trays": trays, "cursor": state.cursor_payload.duplicate(true), "network_stock": SourceProgressionFacts.network_stock(state, item)}

func _compare(row: Dictionary, stage: Dictionary, actual: Dictionary) -> void:
	var expected: Dictionary = stage.expected
	var item := String(row.input.item)
	var values := {"output": expected.outputs.get(item, 0), "remaining": expected.remaining, "remainder": expected.remainder, "progress": expected.progress, "produced": expected.total_produced.get(item, 0), "mined": expected.manual_mined}
	# Native intrinsic oceans persist zero reserve; source's controlled raw value is hidden by its infinite query.
	if item in ["water", "sulfuric_acid"]: values.remaining = 0.0
	if stage.label.begins_with("automatic") and row.input.count > 0: values.power = expected.power_factor
	for field in values:
		if not OWNER._number(actual[field]) or not OWNER._number(values[field]) or float(actual[field]) != float(values[field]):
			errors.append(row.id + "/" + stage.label + ": " + field + " differs " + str(actual[field]) + " vs " + str(values[field]))
	var stock := float(values.output)
	for planet in actual.trays:
		var tray: Dictionary = expected.tray if planet == row.input.planet else expected.planet_trays.get(planet, {})
		if not EXACT._exact(actual.trays[planet], tray): errors.append(row.id + "/" + stage.label + ": canonical tray differs at " + planet)
		stock += float(tray.get(item, 0))
	if actual.network_stock != floorf(stock): errors.append(row.id + "/" + stage.label + ": network stock misses or duplicates cache")
	if actual.cursor != {"item_id": "", "amount": 0.0}: errors.append(row.id + "/" + stage.label + ": unexpected cursor ownership")
