extends Node

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
var errors := []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		printerr("FAIL: ", label)

func _run() -> void:
	var old_storage := GameManager.get_save_system()
	var storage := SaveSystem.new("res://.godot/task27-resource-journey-%d/" % OS.get_process_id())
	GameManager.configure_save_system(storage)
	GameManager.set_process(false)
	seed(240721)
	var started := GameManager.start_new_game(2)
	_check(started.ok, "clean real new game")
	if not started.ok:
		get_tree().quit(1)
		return
	var state := GameManager.get_game_state()
	var engine := GameManager.get_simulation_engine()
	var site: Dictionary = state.resource_sites.home_iron_ore_1
	var tray_before := float(state.planet_inventory.iron_ore)
	var mined := SourceProgressionFacts.mine(state, site.id, 4)
	_check(mined.ok and mined.amount == 4 and OUTPUT.raw_amount(state, site) == 4 and float(state.planet_inventory.iron_ore) == tray_before, "manual mining produces actual cache without tray injection")
	var collected := InventorySystem.new(state).try_collect_resource_output(site.id)
	_check(collected.ok and OUTPUT.raw_amount(state, site) == 0 and float(state.planet_inventory.iron_ore) == tray_before + 4, "public collection moves earned ore into tray")
	var wind := state.try_place_building("dsp_wind_turbine", site.position + Vector2(0, -350))
	var extra_wind := state.try_place_building("dsp_wind_turbine", site.position + Vector2(-450, -350))
	var third_wind := state.try_place_building("dsp_wind_turbine", site.position + Vector2(0, -700))
	var miner := state.try_place_building("dsp_mining_machine", site.position)
	var lab := state.try_place_building("dsp_matrix_lab", site.position + Vector2(450, -350))
	var smelter := state.try_place_building("dsp_arc_smelter", site.position + Vector2(450, 0))
	_check(wind.ok and extra_wind.ok and third_wind.ok and miner.ok and lab.ok and smelter.ok, "actual starter kits fund sufficient power, extractor, lab and smelter")
	if wind.ok and miner.ok and lab.ok and smelter.ok:
		_check(state.set_entity_recipe(lab.id, "dsp_matrix_research") and state.set_entity_recipe(smelter.id, "dsp_iron_ingot"), "formal entity recipe commands")
		var connected := BeltSystem.new(state).try_create_belt(miner.id, smelter.id, "iron_ore")
		_check(connected.ok, "actual paid starter belt connects cache to smelter")
		var reserve := float(site.remaining)
		for tick in range(1200): engine.update(1.0 / 60)
		_check(float(site.remaining) < reserve and float(state.progression_facts.produced.get("iron_ore", 0)) > 4, "real powered extractor consumes reserve and produces ore")
		_check(float(state.buildings[smelter.id].output_buffer.get("iron_ingot", 0)) >= 1, "actual belt and powered smelter manufacture ingots")
		var manufactured := ConstructionAutomationSystem.new(state).queue("dsp_electromagnetic_matrix", 3)
		_check(manufactured.ok, "manufacturing consumes real starting and earned materials")
		for tick in range(6000):
			engine.update(1.0 / 60)
			if state.production_orders.is_empty(): break
		_check(float(state.planet_inventory.get("electromagnetic_matrix", 0)) == 3, "real manufacturing completes three matrices")
		var technology := TechnologySystem.new(state)
		_check(technology.start_research("dsp_electromagnetic_matrix") and technology.supply_source_lab(lab.id).ok, "actual matrix supply and research command")
		for tick in range(3600):
			engine.update(1.0 / 60)
			if state.completed_technologies.has("dsp_electromagnetic_matrix"): break
		_check(state.completed_technologies.has("dsp_electromagnetic_matrix"), "first research earned through simulation")
		_check(GameManager.save_current_game().ok, "resource and research journey saves")
		var canonical := GameStateCodec.to_persistent_dict(state)
		var reopened := storage.load_recovery_source(2, "primary")
		_check(reopened.ok and _roundtrip_equal(GameStateCodec.to_persistent_dict(reopened.state), canonical), "primary reload preserves complete earned journey within JSON numeric precision")
		if reopened.ok:
			var continued := reopened.state as GameState
			var before := float(continued.progression_facts.produced.get("iron_ore", 0))
			var continued_engine := SimulationEngine.new(continued)
			for tick in range(1200): continued_engine.update(1.0 / 60)
			_check(float(continued.progression_facts.produced.get("iron_ore", 0)) > before, "loaded factory continues actual production")
	GameManager.end_session()
	GameManager.configure_save_system(old_storage)
	GameManager.set_process(true)
	print("RESOURCE JOURNEY: failures=", errors.size(), "; earned-tech=electromagnetic_matrix")
	if errors.is_empty(): print("PARITY RESOURCE JOURNEY TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)

func _roundtrip_equal(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return is_finite(float(left)) and is_finite(float(right)) and absf(float(left) - float(right)) <= 1e-12
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _roundtrip_equal(left[key], right[key]): return false
		return true
	if left is Array:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _roundtrip_equal(left[index], right[index]): return false
		return true
	return left == right
