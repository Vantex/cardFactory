extends Node

var failures := 0
func _ready() -> void:
	check(DataManager.get_validation_errors().is_empty(), "complete catalog validates")
	for error in DataManager.get_validation_errors(): print(error)
	var source := DSPOnlineParity.read_json("res://tests/fixtures/parity/dsponline_source_catalog.json")
	for category in ["items", "buildings", "recipes"]:
		for row in source.catalog[category]:
			var target := String(row.id) if category == "items" else "dsp_" + String(row.id)
			var actual: Dictionary = DataManager.get_item(target) if category == "items" else DataManager.get_building(target) if category == "buildings" else DataManager.get_recipe(target)
			if actual.is_empty():
				failures += 1
				printerr("MISSING CONTENT: " + category + ":" + target)
	_test_special_operations()
	_test_source_research()
	_test_belt_manufacturing()
	_test_source_runtime_boundaries()
	_test_crafting()
	_test_proliferation()
	_test_source_fields(source)
	_test_center_and_refunds()
	if failures == 0: print("CONTENT PARITY TESTS PASSED")
	else: printerr("CONTENT PARITY TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("CONTENT: " + message)

func _test_crafting() -> void:
	var state := GameState.new()
	state.planet_inventory = {"iron_ore": 10.0}
	state.sync_active_planet_inventory()
	var planner := CraftingPlanner.new(state)
	var before := GameStateCodec.to_persistent_dict(state)
	var plan := planner.plan("dsp_gear", 3)
	check(plan.ok and plan.steps.size() == 2 and plan.reserved.get("iron_ore", 0) == 3, "gear recursively reserves raw ore and smelting work")
	check(GameStateCodec.to_persistent_dict(state) == before, "preview does not mutate state")
	var production := ConstructionAutomationSystem.new(state)
	check(production.queue("dsp_gear", 3).ok and state.planet_inventory.iron_ore == 7, "queue reserves all required material atomically")
	production.update(1)
	check(not state.production_orders.is_empty(), "intermediate work remains queued")
	var storage := SaveSystem.new("res://.godot/task22-orders-%d/" % Time.get_ticks_usec())
	var saved := storage.save_slot(0, state)
	if not saved.ok: print(saved)
	check(saved.ok, "in-progress manufacturing writes verified save")
	var restored := storage.load_slot(0)
	check(restored.ok, "in-progress manufacturing restores")
	if restored.ok:
		ConstructionAutomationSystem.new(restored.state).update(20)
		check(restored.state.production_orders.is_empty() and restored.state.planet_inventory.get("gear", 0) == 3, "restored order completes exactly once")
	before = GameStateCodec.to_persistent_dict(state)
	check(not production.queue("dsp_gear", 99).ok and GameStateCodec.to_persistent_dict(state) == before, "missing materials reject the whole order without partial deductions")
	check(not planner.plan("dsp_accumulator", 1).ok, "locked storage technology cannot be bypassed by recursive crafting")

func _test_proliferation() -> void:
	var state := GameState.new()
	var id := state.add_building({"type": "dsp_arc_smelter", "position": Vector2.ZERO, "recipe_id": "dsp_iron_ingot", "speed": 1.0, "progress": 0.0, "input_buffer": {"iron_ore": 8.0, "proliferator_mk1": 1.0}, "output_buffer": {}, "power_efficiency": 1.0, "spray_coater_installed": true, "proliferator_tier": 1.0, "proliferator_mode": "extra"})
	var production := ProductionSystem.new(state)
	production.update(8.0)
	check(state.buildings[id].output_buffer.get("iron_ingot", 0) == 9, "tier one emits exactly one extra item after eight cycles")
	check(state.buildings[id].proliferator_points == 4 and state.buildings[id].input_buffer.proliferator_mk1 == 0, "eight cycles consume eight of twelve spray points")
	var save := SaveSystem.new("res://.godot/task22-spray-%d/" % Time.get_ticks_usec())
	check(save.save_slot(0, state).ok, "spray points and fractional bonus persist")
	var old := GameStateCodec.to_persistent_dict(state)
	check(not ProliferatorSystem.new(state).configure(id, 3, "speed").ok and GameStateCodec.to_persistent_dict(state) == old, "locked spray configuration is atomic")
	state.buildings[id].input_buffer = {"iron_ore": 1.0}
	state.buildings[id].proliferator_points = 0.0
	state.buildings[id].proliferator_mode = "speed"
	production.update(0.5)
	check(is_equal_approx(state.buildings[id].progress, 0.5), "exhausted spray falls back to normal speed")
	state.add_building({"type": "solar_panel"})
	state.buildings[id].input_buffer = {}
	var power := PowerSystem.new(state)
	power.update(1)
	check(state.buildings[id].power_requested == 0, "source machine with missing inputs does not demand rated power")

func _test_source_fields(source: Dictionary) -> void:
	for row in source.catalog.buildings:
		var building := DataManager.get_building("dsp_" + String(row.id))
		var definition: Dictionary = row.definition
		check(building.get("power_demand") == definition.get("powerDemandKw", 0) and building.get("power_generation") == definition.get("powerGenerationKw", 0) and building.get("speed") == definition.speed, "source power and speed: " + String(row.id))
		check(building.source_input_capacity == definition.inputCapacity and building.source_output_capacity == definition.outputCapacity, "source capacities: " + String(row.id))
	for row in source.catalog.recipes:
		var recipe := DataManager.get_recipe("dsp_" + String(row.id))
		check(recipe.duration == row.definition.duration and recipe.required_source_technology == row.definition.get("requiredTechId", ""), "source duration and lock: " + String(row.id))
		check(CraftingPlanner._items(recipe.inputs) == _source_items(row.definition.inputs) and CraftingPlanner._items(recipe.outputs) == _source_items(row.definition.outputs), "source recipe material contract: " + String(row.id))
	for row in source.catalog.construction:
		var construction: Dictionary = DataManager.construction.get("dsp_" + String(row.id), {})
		check(construction.get("costs", {}) == _source_items(row.definition.costs) and construction.get("output_amount") == row.definition.outputAmount, "source construction cost: " + String(row.id))

func _source_items(items: Array) -> Dictionary:
	var result := {}
	for item in items: result[item.itemId] = float(item.amount)
	return result

func _test_center_and_refunds() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_proliferator_1")
	state.construction_inventory["dsp_arc_smelter"] = 1.0
	state.construction_inventory["dsp_spray_coater"] = 1.0
	var original := state.add_building({"type": "dsp_arc_smelter", "position": Vector2.ZERO, "recipe_id": "dsp_iron_ingot", "input_buffer": {}, "output_buffer": {}, "progress": 0.0, "speed": 1.0, "spray_coater_installed": true, "proliferator_tier": 1.0, "proliferator_mode": "extra", "proliferator_points": 4.0})
	var blueprint: Dictionary = BlueprintSystem.new(state).capture_selection([original])
	check(blueprint.ok and not blueprint.blueprint.entities[0].configuration.has("proliferator_points"), "blueprints copy spray configuration but never free spray points")
	var deployed := BlueprintSystem.new(state).deploy(blueprint.blueprint, Vector2(600, 0))
	check(deployed.ok and state.construction_inventory.dsp_spray_coater == 0, "sprayed blueprint charges an additional module kit")
	var before := GameStateCodec.to_persistent_dict(state)
	check(not BlueprintSystem.new(state).deploy(blueprint.blueprint, Vector2(1200, 0)).ok and GameStateCodec.to_persistent_dict(state) == before, "missing blueprint kits leave state unchanged")
	check(ProliferatorSystem.new(state).remove(original).ok and state.planet_inventory.get("proliferator_mk1", 0) == 1 and state.construction_inventory.dsp_spray_coater == 1, "removal refunds a module and rounds remaining spray points up as frozen source specifies")
	state = GameState.new()
	state.planet_inventory = {"iron_ingot": 20.0, "stone_brick": 10.0, "circuit_board": 20.0, "magnetic_coil": 10.0}
	state.sync_active_planet_inventory()
	var center := state.add_building({"type": "dsp_construction_center", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}, "recipe_id": "", "progress": 0.0, "speed": 1.0})
	var automation := ConstructionAutomationSystem.new(state)
	check(automation.configure_center(center, "dsp_arc_smelter", 2).ok, "manufacturing center accepts target inventory")
	automation.update(1)
	check(state.production_orders.size() == 1 and state.production_orders[0].step == 0, "new center order cannot advance before real power is allocated")
	state.buildings[center].power_requested = 12000.0
	state.buildings[center].power_efficiency = 1.0
	automation.update(2)
	automation.update(2)
	check(state.construction_inventory.get("dsp_arc_smelter", 0) == 2, "center replenishes to the exact target count")
	automation.update(2)
	check(state.production_orders.is_empty(), "center stops when target inventory is satisfied")

func _test_special_operations() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_energy_storage")
	state.planet_inventory = {"accumulator": 2.0, "charged_accumulator": 2.0}
	state.sync_active_planet_inventory()
	var before := GameStateCodec.to_persistent_dict(state)
	var automation := ConstructionAutomationSystem.new(state)
	check(not automation.queue("dsp_accumulator_charge", 1).ok, "recursive crafting cannot charge batteries without electricity")
	check(not automation.queue("dsp_accumulator_discharge", 1).ok, "recursive crafting cannot bypass discharge dispatch")
	check(GameStateCodec.to_persistent_dict(state) == before, "rejected energy conversion leaves inventory and queue unchanged")
	var launcher := state.add_building({"type": "dsp_em_rail_ejector", "position": Vector2.ZERO, "recipe_id": "dsp_solar_sail_launch", "input_buffer": {"solar_sail": 10.0}, "output_buffer": {}, "progress": 0.0, "speed": 1.0})
	ProductionSystem.new(state).update(120)
	check(state.buildings[launcher].input_buffer.solar_sail == 10 and state.buildings[launcher].progress == 0, "ordinary production never consumes launch ammunition without a launch system")

	var receiver := state.add_building({"type": "dsp_ray_receiver", "position": Vector2(200, 0), "recipe_id": "dsp_critical_photon", "input_buffer": {}, "output_buffer": {}, "progress": 0.0, "speed": 1.0})
	ProductionSystem.new(state).update(120)
	check(state.buildings[receiver].output_buffer.is_empty(), "ordinary production cannot generate photons without Dyson reception")
	state.planet_inventory = {"iron_ore": 3.0}
	state.sync_active_planet_inventory()
	check(automation.queue("dsp_gear", 1).ok, "validation fixture queues a real job")
	var damaged := state.production_orders.duplicate(true)
	damaged[0].target = "dsp_accumulator_charge"
	check(not ConstructionAutomationSystem.validate(damaged, state.planet_inventories).is_empty(), "save validation rejects mismatched manufacturing target")
	damaged = state.production_orders.duplicate(true)
	damaged[0].quantity = 1.5
	check(not ConstructionAutomationSystem.validate(damaged, state.planet_inventories).is_empty(), "save validation rejects fractional manufacturing batches")

	state = GameState.new()
	state.planet_inventory = {"gear": 998.0, "iron_ingot": 2.0}
	state.sync_active_planet_inventory()
	automation = ConstructionAutomationSystem.new(state)
	check(automation.queue("dsp_gear", 1).ok, "first order reserves the last free output slot")
	before = GameStateCodec.to_persistent_dict(state)
	check(not automation.queue("dsp_gear", 1).ok and GameStateCodec.to_persistent_dict(state) == before, "pending output capacity prevents overbooking without consuming materials")
	check(automation.cancel(state.production_orders[0].id).ok, "cancelled order releases its output reservation")
	check(automation.queue("dsp_gear", 1).ok, "released output slot can be reserved again")

	var definition := DataManager.get_building("dsp_thermal_power_plant")
	var fuel := {"type": "dsp_thermal_power_plant", "fuel_item": "hydrogen", "input_buffer": {}, "output_buffer": {}}
	fuel.fuel_remaining = float(definition.fuel_options.hydrogen) * 0.5
	var refund := {}
	state._collect_building_material_refund(fuel, refund)
	check(is_equal_approx(float(refund.get("hydrogen", 0)), 0.5) and not refund.has("coal"), "demolition refunds selected fuel using its own energy duration")

func _test_source_research() -> void:
	var state := GameState.new()
	check(DataManager.is_recipe_supported_by_building(DataManager.get_recipe("dsp_matrix_research"), "matrix_lab"), "starter laboratory can research the prerequisite for source laboratories")
	var tech := TechnologySystem.new(state)
	check(tech.start_research("dsp_electromagnetic_matrix"), "source research can wait for lab materials without prepaying inventory")
	state.completed_technologies.append("dsp_proliferator_1")
	state.construction_inventory.dsp_spray_coater = 1.0
	var lab := state.add_building({"type": "dsp_matrix_lab", "position": Vector2.ZERO, "recipe_id": "dsp_matrix_research", "input_buffer": {}, "output_buffer": {}, "progress": 0.0, "speed": 1.0})
	check(ProliferatorSystem.new(state).configure(lab, 1, "speed").ok, "source research accepts spray acceleration")
	state.buildings[lab].input_buffer.proliferator_mk1 = 1.0
	state.buildings[lab].power_requested = 480.0
	state.buildings[lab].power_efficiency = 1.0
	tech.update_source_labs(30)
	check(state.buildings[lab].input_buffer.proliferator_mk1 == 1 and state.get_technology_progress("dsp_electromagnetic_matrix") == 0, "research without matrices does not consume spray or progress")
	state.planet_inventory.electromagnetic_matrix = 3.0
	state.sync_active_planet_inventory()
	check(tech.supply_source_lab(lab).ok and state.planet_inventory.get("electromagnetic_matrix", 0) == 0, "research supply moves physical matrices to the lab")
	tech.update_research(100, true)
	check(state.get_technology_progress("dsp_electromagnetic_matrix") == 0, "legacy elapsed-time research cannot complete source technology")
	tech.update_source_labs(2.4)
	check(state.get_technology_progress("dsp_electromagnetic_matrix") == 3 and state.buildings[lab].input_buffer.electromagnetic_matrix == 2 and state.buildings[lab].proliferator_points == 11, "accelerated research consumes one actual matrix and one spray point per cycle")
	var save := SaveSystem.new("res://.godot/task22-research-%d/" % Time.get_ticks_usec())
	var saved := save.save_slot(0, state)
	if not saved.ok: print(saved)
	check(saved.ok, "partial source research saves with consumed-cost validation")
	var loaded := save.load_slot(0)
	check(loaded.ok, "partial source research round-trips from disk")
	tech.pause_research()
	tech.update_source_labs(100)
	check(state.buildings[lab].proliferator_points == 11, "paused research consumes neither materials nor spray")
	tech.resume_research()
	tech.update_source_labs(4.8)
	check(state.completed_technologies.has("dsp_electromagnetic_matrix") and state.buildings[lab].proliferator_points == 9, "source research completes only after consuming its exact matrix costs")

func _test_belt_manufacturing() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_basic_logistics")
	state.planet_inventory = {"iron_ingot": 30.0, "gear": 30.0}
	state.sync_active_planet_inventory()
	state.construction_inventory.conveyor_belt_mk1 = 0.0
	var automation := ConstructionAutomationSystem.new(state)
	check(automation.queue("dsp_conveyor_belt_mk1", 1, true).ok, "source belt construction can be queued")
	automation.update(1)
	check(state.construction_inventory.conveyor_belt_mk1 == 3 and state._has_belt_pieces("conveyor_belt_mk1", 3), "source belt batch delivers three usable line construction kits")
	var center := state.add_building({"type": "dsp_construction_center", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}, "recipe_id": "", "progress": 0.0, "speed": 1.0})
	check(automation.configure_center(center, "dsp_conveyor_belt_mk1", 6).ok, "center accepts source belt target")
	state.buildings[center].power_requested = 12000.0
	state.buildings[center].power_efficiency = 1.0
	automation.update(1)
	automation.update(1)
	if state.construction_inventory.conveyor_belt_mk1 != 6: print({"kits": state.construction_inventory, "orders": state.production_orders, "center": state.buildings[center]})
	check(state.construction_inventory.conveyor_belt_mk1 == 6 and state.production_orders.is_empty(), "center counts batch output pieces rather than recipe batches")

func _test_source_runtime_boundaries() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_proliferator_1")
	var ids: Array = []
	for index in range(2):
		ids.append(state.add_building({"type": "dsp_arc_smelter", "position": Vector2(index * 400, 0), "recipe_id": "dsp_iron_ingot", "input_buffer": {"iron_ore": 1.0}, "output_buffer": {}, "progress": 0.0, "speed": 1.0}))
	state.construction_inventory.dsp_spray_coater = 1.0
	var before := GameStateCodec.to_persistent_dict(state)
	check(not ProliferatorSystem.new(state).configure_batch(ids, 1, "extra").ok and GameStateCodec.to_persistent_dict(state) == before, "batch spray shortage preserves every selected machine and inventory")
	state.construction_inventory.dsp_spray_coater = 2.0
	check(ProliferatorSystem.new(state).configure_batch(ids, 1, "extra").ok and state.construction_inventory.dsp_spray_coater == 0, "batch spray installs exactly one paid module per machine")
	for tier in [1, 2, 3]:
		var lab: Dictionary = state.buildings[ids[0]]
		lab.proliferator_tier = float(tier)
		lab.input_buffer["proliferator_mk%d" % tier] = 1.0
		var effect := ProliferatorSystem.profile(lab, DataManager.get_recipe("dsp_iron_ingot"))
		check(is_equal_approx(float(effect.power), [1.3, 1.7, 2.5][tier - 1]) and is_equal_approx(float(effect.bonus), [0.125, 0.2, 0.25][tier - 1]), "tier %d uses frozen power and extra-product rules" % tier)
		lab.proliferator_mode = "speed"
		effect = ProliferatorSystem.profile(lab, DataManager.get_recipe("dsp_iron_ingot"))
		check(is_equal_approx(float(effect.speed), [1.25, 1.5, 2.0][tier - 1]), "tier %d uses frozen acceleration" % tier)
		lab.proliferator_mode = "extra"
	var machine: Dictionary = state.buildings[ids[0]]
	machine.proliferator_tier = 1.0
	machine.proliferator_bonus = {"iron_ingot": 0.875}
	machine.output_buffer.iron_ingot = float(DataManager.get_building(machine.type).output_buffer_capacity) - 1
	PowerSystem.new(state).update(1)
	check(machine.power_requested == 0, "blocked bonus output does not request electricity")
	state = GameState.new()
	var generator := state.add_building({"type": "dsp_thermal_power_plant", "input_buffer": {"hydrogen": 1.0}, "output_buffer": {}, "fuel_item": "hydrogen", "fuel_remaining": 0.0})
	state.add_building({"type": "dsp_arc_smelter", "recipe_id": "dsp_iron_ingot", "input_buffer": {"iron_ore": 1.0}, "output_buffer": {}, "progress": 0.0, "speed": 1.0})
	PowerSystem.new(state).update(1)
	var definition := DataManager.get_building("dsp_thermal_power_plant")
	var generated := float(state.buildings[generator].power_output)
	check(generated > 0 and is_equal_approx(float(state.buildings[generator].fuel_remaining), float(definition.fuel_options.hydrogen) - generated / float(definition.power_generation)), "selected fuel burns in proportion to real dispatched energy")
	state.completed_technologies.append("dsp_" + String(DataManager.get_building("dsp_geothermal_power_station").required_source_technology))
	state.construction_inventory.dsp_geothermal_power_station = 1.0
	before = GameStateCodec.to_persistent_dict(state)
	check(ConstructionSystem.new(state).try_place_building("dsp_geothermal_power_station", Vector2(2000, 0)).reason == "invalid_planet" and GameStateCodec.to_persistent_dict(state) == before, "invalid geothermal planet rejects placement before spending the kit")
	check(PowerSystem.source_environment_multiplier(state, "dsp_geothermal_power_station", "ashen") == 1 and PowerSystem.source_environment_multiplier(state, "dsp_geothermal_power_station", "home") == 0, "geothermal generation follows the current planets' frozen profiles")
	check(not DataManager.building_pending_reason("dsp_time_warp_device").is_empty() and not DataManager.building_pending_reason("dsp_planetary_logistics_station").is_empty(), "future advanced devices provide an explicit availability reason")
	check(DataManager.get_building("dsp_solar_panel").input_buffer_capacity == 0, "zero source buffers remain zero at runtime")
