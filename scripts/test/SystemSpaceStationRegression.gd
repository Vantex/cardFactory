class_name SystemSpaceStationRegression
extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("SYSTEM SPACE STATION: " + message)

func run() -> int:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-system-station.json"))
	for row in gold.modules:
		check(SystemSpaceStationSystem.module_cost("backbone", int(row.existing), int(row.amount)) == row.cost, "frozen escalating module cost including 256-digit saturation")
	check(HubInteger.half("9007199254740993") == "4503599627370496", "exact refund above floating point precision")
	for row in gold.cases:
		var state := SourceDysonRegression.new().fresh()
		state.emit_canvas_events = false
		state.completed_technologies.append("dsp_system_space_station_engineering")
		for id in row.technologies: state.completed_technologies.append("dsp_" + id)
		state.construction_inventory[SystemSpaceStationSystem.TYPE] = 2.0
		var construction := ConstructionSystem.new(state)
		var placed := construction.try_place_building(SystemSpaceStationSystem.TYPE, Vector2(1800, 1000))
		check(placed.ok, "real construction command available")
		if not placed.ok: continue
		var before := GameStateCodec.to_persistent_dict(state)
		check(not construction.try_place_building(SystemSpaceStationSystem.TYPE, Vector2(2200, 1000)).ok and GameStateCodec.to_persistent_dict(state) == before, "unique platform rejects before spending kit")
		var blueprint := BlueprintSystem.new(state).capture_selection([placed.id])
		check(blueprint.ok, "construction platform blueprint capture")
		if blueprint.ok:
			check(not BlueprintSystem.new(state).deploy(blueprint.blueprint, Vector2(3000, 1000)).ok and GameStateCodec.to_persistent_dict(state) == before, "blueprint cannot bypass single-platform limit")
		var model := SystemSpaceStationSystem.new(state)
		check(model.start("helios").ok, "source start guards and discount snapshot")
		var station: Dictionary = state.system_space_stations.helios
		check(station.cost_multiplier_basis_points == row.initial.costMultiplierBasisPoints, "frozen research discount")
		state.buildings[placed.id].input_buffer = {"titanium_alloy": 4000.0, "frame_material": 2000.0}
		state.buildings[placed.id].power_efficiency = 0.5
		model.update()
		check(station.delivered == row.station.delivered and station.construction_buffer == row.station.constructionBuffer and state.buildings[placed.id].input_buffer == row.inputs, "frozen power-scaled real input settlement")
		if not state.completed_technologies.has("dsp_autonomous_station_construction"): state.completed_technologies.append("dsp_autonomous_station_construction")
		check(station.cost_multiplier_basis_points == row.initial.costMultiplierBasisPoints, "later research cannot retroactively change construction costs")
		state.planet_inventory.titanium_alloy = 10.5
		var old_delivered := int(station.delivered.titanium_alloy)
		check(model.deliver("helios", "titanium_alloy", 999).ok and state.planet_inventory.titanium_alloy == 0.5 and int(station.delivered.titanium_alloy) == old_delivered + 10, "manual delivery preserves fractional native inventory")
		for requirement in SystemSpaceStationSystem.requirements(int(station.cost_multiplier_basis_points)):
			var item: String = requirement.item_id
			var remaining := HubInteger.subtract(requirement.required, station.delivered.get(item, "0"))
			if DecimalCount.compare(remaining, station.construction_buffer.get(item, "0")) > 0: station.construction_buffer[item] = remaining
		SystemSpaceStationSystem.apply_buffer(station)
		check(station.status == "operational" and station.phase_index == 16, "four stages consume shared material ledger exactly once")
		check(station.delivered.frame_material == str(2000000 * int(station.cost_multiplier_basis_points) / 10000), "repeated materials use source cumulative requirements")
		var costs := SystemSpaceStationSystem.module_cost("backbone", 0, 11)
		station.inventory = costs.duplicate(true)
		check(model.set_module_count("helios", "backbone", 11).ok and station.inventory.values().all(func(amount): return amount == "0"), "modules debit only hub inventory")
		check(model.set_module_count("helios", "backbone", 9).ok and station.inventory.frame_material == "150000", "cross-tier demolition returns exact half")
		var producer := state.add_building({"type": "smelter", "position": Vector2(2500, 2000), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {"iron_ingot": 20.0}, "power_efficiency": 1.0})
		state.buildings[placed.id].power_efficiency = 1.0
		state.construction_inventory.conveyor_belt_mk1 = 1.0
		var belt := state.try_add_connection(producer, placed.id, "iron_ingot")
		check(belt.ok, "real belt connects to platform without a recipe")
		if belt.ok:
			for tick in range(60): BeltSystem.new(state).update(1.0 / 60.0)
			var stock := float(state.buildings[placed.id].input_buffer.get("iron_ingot", 0))
			check(stock >= 5 and stock == floorf(stock) and is_equal_approx(stock + float(state.buildings[producer].output_buffer.iron_ingot), 20), "fractional belt credit delivers conserved whole construction inputs")
		var save := SaveSystem.new("res://.godot/task26-system-station")
		var saved := save.save_slot(0, state)
		check(saved.ok, "station disk save: " + str(saved))
		var loaded := save.load_slot(0)
		check(loaded.ok, "station disk read")
		if loaded.ok: check(JSON.parse_string(JSON.stringify(loaded.state.system_space_stations)) == JSON.parse_string(JSON.stringify(state.system_space_stations)), "disk preserves decimal ledgers and stage")
		check(state.copy_state().system_space_stations == state.system_space_stations, "isolated transaction copy retains station authority")
		var bad := GameStateCodec.to_persistent_dict(state)
		bad.system_space_stations.helios.inventory.processor = "1e30"
		check(GameStateCodec.from_persistent_dict(bad) == null, "noncanonical inventory rejected")
		bad = GameStateCodec.to_persistent_dict(state)
		bad.system_space_stations.helios.inventory[12] = "10"
		check(not SystemSpaceStationSystem.validate(bad).is_empty(), "non-string hub item rejected without typed call crash")
		bad = GameStateCodec.to_persistent_dict(state)
		bad.buildings[placed.id].input_buffer.processor = {}
		check(not SystemSpaceStationSystem.validate(bad).is_empty(), "malformed construction amount rejected before conversion")
	return failures
