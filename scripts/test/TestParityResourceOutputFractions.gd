extends Node

const OUTPUT := preload("res://scripts/game/SourceResourceOutputSystem.gd")
var errors := []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		printerr("FAIL: ", label)

func _state() -> GameState:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	state.completed_technologies = DataManager.all_technologies.keys().filter(func(id): return String(id).begins_with("dsp_"))
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	return state

func _miner(state: GameState) -> Dictionary:
	var site: Dictionary = state.resource_sites.home_iron_ore_1
	state.construction_inventory.dsp_mining_machine = 1
	var placed := state.try_place_building("dsp_mining_machine", site.position)
	_check(placed.ok, "paid extractor setup")
	return state.buildings[placed.id] if placed.ok else {}

func _run() -> void:
	for fraction in [0.495, 0.1, 0.3, 0.7, 1.495]:
		var state := _state()
		var miner := _miner(state)
		if miner.is_empty(): continue
		var site: Dictionary = state.resource_sites.home_iron_ore_1
		site.output_buffer = {"iron_ore": 2.0}
		miner.output_buffer.iron_ore = fraction
		var available := OUTPUT.raw_amount(state, site)
		_check(OUTPUT.take(state, site, available) == available, "full fractional debit succeeds: " + str(fraction))
		_check(OUTPUT.raw_amount(state, site) == 0, "full fractional debit empties both owners: " + str(fraction))
		_check(OUTPUT.take(state, site, available) == 0, "empty stock cannot debit twice: " + str(fraction))
	var state := _state()
	var miner := _miner(state)
	var site: Dictionary = state.resource_sites.home_iron_ore_1
	site.output_buffer = {"iron_ore": 2.0}
	miner.output_buffer.iron_ore = 0.495
	miner.power_efficiency = 1.0
	state.construction_inventory.dsp_arc_smelter = 1
	var placed := state.try_place_building("dsp_arc_smelter", site.position + Vector2(500, 0))
	_check(placed.ok and state.set_entity_recipe(placed.id, "dsp_iron_ingot"), "paid smelter setup")
	if placed.ok:
		var target: Dictionary = state.buildings[placed.id]
		target.power_efficiency = 1.0
		var belt := BeltSystem.new(state)
		var connected := belt.try_create_belt(miner.id, target.id, "iron_ore")
		_check(connected.ok, "actual resource belt setup")
		if connected.ok:
			var stock := OUTPUT.raw_amount(state, site)
			belt.update(1.0)
			_check(OUTPUT.raw_amount(state, site) == 0 and float(target.input_buffer.get("iron_ore", 0)) == stock, "fractional full belt transfer conserves all stock")
			belt.update(1.0)
			_check(float(target.input_buffer.get("iron_ore", 0)) == stock and not state.connections[connected.id].active, "second tick cannot duplicate unchanged source")
	for current in [179.00005, 179.5, 179.99999, 180.0]:
		var near := _state()
		var near_miner := _miner(near)
		var near_site: Dictionary = near.resource_sites.home_iron_ore_1
		near_miner.output_buffer.iron_ore = current
		var reserve := float(near_site.remaining)
		var result := SourceProgressionFacts.mine(near, near_site.id)
		_check(not result.ok and OUTPUT.raw_amount(near, near_site) == current and float(near_site.remaining) == reserve, "less than one raw unit of capacity rejects whole mining: " + str(current))
	var old := _state()
	var old_site: Dictionary = old.resource_sites.home_iron_ore_1
	old.construction_inventory.miner = 1
	var legacy_paid := old.try_place_building("miner", old_site.position)
	_check(legacy_paid.ok, "legacy native extractor remains placeable in source galaxy")
	if legacy_paid.ok:
		var legacy_miner: Dictionary = old.buildings[legacy_paid.id]
		legacy_miner.output_buffer.iron_ore = 2.495
		old_site.output_buffer = {"iron_ore": 0.0}
		_check(BeltSystem.new(old)._source_available(legacy_miner, "iron_ore") == 2.495, "legacy native belt reads its own fractional buffer")
		var old_tray := float(old.planet_inventory.get("iron_ore", 0))
		var picked := InventorySystem.new(old).try_collect_output(legacy_miner.id)
		_check(picked.ok and float(old.planet_inventory.get("iron_ore", 0)) == old_tray + 2.495 and legacy_miner.output_buffer.is_empty(), "legacy native Inspector collects its actual buffer")
	print("PARITY RESOURCE OUTPUT FRACTION TESTS: failures=", errors.size())
	if errors.is_empty(): print("PARITY RESOURCE OUTPUT FRACTION TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
