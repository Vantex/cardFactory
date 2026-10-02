class_name SourceDysonRegression
extends RefCounted

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("SOURCE DYSON: " + message)

func fresh() -> GameState:
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(240721)
	state.completed_technologies.append_array(["dsp_dyson_swarm", "dsp_dyson_sphere_program", "dsp_dyson_shell", "dsp_vertical_launching_silo", "dsp_ray_receiver"])
	state.explored_system_ids = GalaxySystem.new(state).get_all_system_ids()
	for id in state.explored_system_ids: state.survey_progress_by_system[id] = 1.0
	return state

func run() -> int:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-dyson.json"))
	for row in gold.cases:
		var state := fresh()
		var dyson := DysonSphereSystem.new(state)
		var orbit: String = dyson.create_orbit("helios").id
		var source := SourceDysonEngineering.new(state)
		for index in range(int(row.index)): source.add_layer("helios", orbit, 10000, 0, 0)
		var created := source.standard_layer("helios", orbit, int(row.count))
		check(created.ok, "standard layer command")
		var system: Dictionary = state.dyson_systems.helios
		var layer: Dictionary = system.layers[created.id]
		check(layer.radius == row.radius and layer.inclination == row.inclination and layer.longitude == row.longitude, "frozen standard geometry")
		for index in range(layer.node_order.size()): check(is_equal_approx(float(layer.nodes[layer.node_order[index]].angle), float(row.angles[index])), "frozen node angles")
		for index in range(layer.frame_order.size()): check(layer.frames[layer.frame_order[index]].required_points == row.requirements[index], "frozen frame costs")
		for index in range(layer.shell_order.size()): check(layer.shells[layer.shell_order[index]].capacity == row.capacities[index], "frozen shell capacities")
		var totals := SourceDysonEngineering.totals(system)
		check(totals.planned_structure == row.totals.plannedStructure and totals.active_capacity == row.totals.sailCapacity and totals.completed_structure == 0, "frozen plan totals, inactive shells without free material")
		check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "new star plan validates")
	for row in gold.power:
		var state := fresh()
		state.completed_technologies.append_array(["dsp_ray_transmission_1", "dsp_ray_transmission_2"])
		state.progression_facts["infinite_research"] = {"stellar_harnessing": {"level": int(row.level), "invested": "0"}}
		var dyson := DysonSphereSystem.new(state)
		var orbit: String = dyson.create_orbit(row.id).id
		var system: Dictionary = state.dyson_systems[row.id]
		system.source_plan.structure_points = int(row.points)
		system.source_plan.shell_sails = int(row.sails)
		system.rockets_launched = int(row.points)
		system.sails_launched = int(row.sails + row.live)
		system.orbits[orbit].cohorts = [{"count": int(row.live), "expires_tick": 0}]
		check(is_equal_approx(dyson.get_summary(row.id).power_kw, float(row.expected)), "frozen stellar generation: " + row.id)
		check(is_equal_approx(dyson.receiver_capacity("dsp_ray_receiver"), float(row.receiver)), "frozen upgraded receiver capacity")
		check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "expanded galaxy stellar material ledger validates")
	_test_decay(gold)
	_test_reception()
	_test_launch_and_save()
	return failures

func _test_launch_and_save() -> void:
	var state := fresh()
	var dyson := DysonSphereSystem.new(state)
	var source := SourceDysonEngineering.new(state)
	var orbit: String = dyson.create_orbit("helios").id
	var created := source.standard_layer("helios", orbit, 3)
	var layer_id: String = created.id
	var layer := source.layer_for("helios", layer_id)
	var before := GameStateCodec.to_persistent_dict(state)
	check(not source.add_node("helios", layer_id, 3).ok and GameStateCodec.to_persistent_dict(state) == before, "5 degree spacing rejects atomically")
	var rocket := state.add_building({"type": "dsp_vertical_launching_silo", "position": Vector2(1000, 1000), "input_buffer": {}, "output_buffer": {}, "power_efficiency": 1.0})
	var sail := state.add_building({"type": "dsp_em_rail_ejector", "position": Vector2(1300, 1000), "input_buffer": {}, "output_buffer": {}, "power_efficiency": 1.0})
	state.planet_inventory.small_carrier_rocket = 20.0
	state.planet_inventory.solar_sail = 60.0
	check(dyson.configure_launcher(rocket, layer_id).ok and dyson.configure_launcher(sail, orbit).ok and dyson.load_ammo(rocket, 20).ok and dyson.load_ammo(sail, 60).ok, "real configured source launchers consume tray ammo")
	check(source.configure_schedule("sphere", 0.5, true).ok, "source sphere schedule with half throttle")
	for tick in range(720):
		dyson.begin_tick()
		dyson.update_launches(1.0 / 60.0)
	check(state.dyson_systems.helios.rockets_launched == 1 and state.dyson_systems.helios.sails_launched == 0, "6 second rocket at half throttle; sphere mode blocks sails")
	source.configure_schedule("balanced", 1.0, false)
	before = GameStateCodec.to_persistent_dict(state)
	for tick in range(120):
		dyson.begin_tick()
		dyson.update_launches(1.0 / 60.0)
	check(state.dyson_systems.helios.rockets_launched == 1 and state.buildings[rocket].input_buffer.small_carrier_rocket == 19, "disabled global schedule preserves ammunition")
	source.configure_schedule("balanced", 1.0, true)
	for tick in range(3960):
		dyson.begin_tick()
		dyson.update_launches(1.0 / 60.0)
	var summary := dyson.get_summary("helios")
	check(summary.structure_points == 12 and summary.active_capacity == 360 and summary.frames == 3 and summary.absorbed_sails > 0, "rockets build nodes and frames; completed frames activate shells and absorb real sails")
	check(state.buildings[rocket].input_buffer.small_carrier_rocket == 8 and state.buildings[sail].input_buffer.solar_sail == 55, "source launch intervals conserve exactly 12 rockets and 5 sails")
	check(is_equal_approx(float(state.dyson_engineering.launch_energy_spent_mj), 1404.0), "actual launch energy survives schedule changes")
	check(dyson.ammo_capacity(sail) == 180 and dyson.ammo_capacity(rocket) == 180, "source launcher capacities use frozen definitions")
	var template := source.copy_template("helios", layer_id)
	var pasted := source.paste_template("helios", orbit, template)
	check(pasted.ok, "copy/paste layer command")
	var copy_layer := source.layer_for("helios", pasted.id)
	check(copy_layer.structure_floor == 12 and copy_layer.nodes.values().all(func(node): return int(node.points) == 0) and copy_layer.frames.values().all(func(frame): return int(frame.points) == 0), "paste allocation floor cannot duplicate invested structure")
	var bad_template := template.duplicate(true)
	bad_template.frames[0].source = "missing"
	before = GameStateCodec.to_persistent_dict(state)
	check(not source.paste_template("helios", orbit, bad_template).ok and GameStateCodec.to_persistent_dict(state) == before, "malformed paste rejects without IDs or resources")
	bad_template = template.duplicate(true)
	bad_template.shells[0].boundary.append(bad_template.shells[0].boundary[0])
	check(not source.paste_template("helios", orbit, bad_template).ok and GameStateCodec.to_persistent_dict(state) == before, "repeated shell boundary rejects atomically")
	bad_template = template.duplicate(true)
	bad_template.inclination = 1000
	check(not source.paste_template("helios", orbit, bad_template).ok and GameStateCodec.to_persistent_dict(state) == before, "out-of-range template geometry cannot create an unloadable state")
	var save := SaveSystem.new("res://.godot/task26-dyson-source")
	var saved := save.save_slot(0, state)
	check(saved.ok, "source geometry and global schedule disk save: " + str(saved))
	var loaded := save.load_slot(0)
	check(loaded.ok, "source geometry disk read")
	if loaded.ok:
		check(JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(loaded.state))) == JSON.parse_string(JSON.stringify(GameStateCodec.to_persistent_dict(state))), "disk preserves sorted IDs, explicit allocation order, materials and fractional decay")
		check(GameStateCodec.to_persistent_dict(state.copy_state()) == GameStateCodec.to_persistent_dict(state), "isolated transaction copies preserve global launch schedule")
	var bad := GameStateCodec.to_persistent_dict(state)
	bad.dyson_systems.helios.layers[layer_id].frames[layer.frame_order[0]].required_points += 1
	check(GameStateCodec.from_persistent_dict(bad) == null, "tampered frame cost is rejected")
	bad = GameStateCodec.to_persistent_dict(state)
	bad.dyson_systems.helios.source_plan.structure_points += 1
	check(GameStateCodec.from_persistent_dict(bad) == null, "unpaid structure ledger rejected")
	check(source.set_geometry("helios", pasted.id, "layers", 20000, -30, -15).ok and copy_layer.longitude == 345, "source geometry normalizes longitude and recalculates frame costs")
	var materials := int(state.dyson_systems.helios.source_plan.structure_points)
	check(source.remove_node("helios", pasted.id, copy_layer.node_order[0]).ok and state.dyson_systems.helios.source_plan.structure_points == materials, "node removal retains paid material")
	var orbit2: String = dyson.create_orbit("helios", 20000).id
	check(dyson.remove_plan("helios", orbit2, "orbits").ok, "source orbit removal retains the last orbit")
	check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "edited source geometry remains conserved and loadable")

func _test_reception() -> void:
	var state := fresh()
	var dyson := DysonSphereSystem.new(state)
	var orbit: String = dyson.create_orbit("helios").id
	var system: Dictionary = state.dyson_systems.helios
	system.source_plan.structure_points = 10
	system.rockets_launched = 10
	var a := state.add_building({"type": "dsp_ray_receiver", "position": Vector2.ZERO, "recipe_id": "dsp_ray_power", "input_buffer": {}, "output_buffer": {}})
	var b := state.add_building({"type": "dsp_ray_receiver", "position": Vector2(300, 0), "recipe_id": "dsp_critical_photon", "input_buffer": {}, "output_buffer": {}})
	var receipts := dyson.receiver_allocations()
	var total := float(dyson.get_summary("helios").power_kw)
	check(is_equal_approx(float(receipts[a]) + float(receipts[b]), minf(12000, total)), "power and photon receivers share the same finite stellar budget")
	var grid_outputs := dyson.receiver_outputs()
	check(grid_outputs.has(a) and not grid_outputs.has(b), "photon allocation does not also produce grid electricity")
	PowerSystem.new(state).update(0)
	check(is_equal_approx(float(state.buildings[a].power_output), float(receipts[a])) and float(state.buildings[b].power_output) == 0, "real grid receives only electricity mode allocation")
	var production := ProductionSystem.new(state)
	var duration := 10.0 / (float(receipts[b]) / 6000.0 * SourceGalaxySystem.new(state).production_multiplier("home", "dsp_ray_receiver"))
	production.update(duration)
	check(float(state.buildings[b].output_buffer.get("critical_photon", 0)) == 1.0 and float(state.buildings[a].output_buffer.get("critical_photon", 0)) == 0, "real photon conversion consumes its reception allocation")
	system.source_plan.structure_points = 0
	system.rockets_launched = 0
	var previous := GameStateCodec.to_persistent_dict(state)
	production.update(100)
	check(float(state.buildings[b].output_buffer.get("critical_photon", 0)) == 1.0 and GameStateCodec.to_persistent_dict(state) == previous, "no Dyson power means no free photons")
	state.completed_technologies.erase("dsp_ray_receiver")
	check(dyson.receiver_allocations().is_empty(), "receiver technology gate cannot leak stellar output")
func _test_decay(gold: Dictionary) -> void:
	for row in gold.decay:
		var state := fresh()
		if int(row.life) >= 1: state.completed_technologies.append("dsp_solar_sail_life_1")
		if int(row.life) >= 2: state.completed_technologies.append("dsp_solar_sail_life_2")
		var dyson := DysonSphereSystem.new(state)
		var orbit_id: String = dyson.create_orbit("helios").id
		var system: Dictionary = state.dyson_systems.helios
		var orbit: Dictionary = system.orbits[orbit_id]
		orbit.cohorts = [{"count": int(row.live), "expires_tick": 0}]
		orbit.decay_progress = float(row.progress)
		system.sails_launched = int(row.live)
		for step in range(int(row.steps)): SourceDysonEngineering.new(state).decay(system, float(row.seconds))
		check(dyson.get_summary("helios").live_sails == int(row.expected.sailsInOrbit) and system.sails_expired == int(row.expected.totalExpired) and is_equal_approx(float(orbit.decay_progress), float(row.expected.decayProgress)), "frozen solar sail decay with research and fractional boundary")
		check(GameStateValidator.validate_persistent_dict(GameStateCodec.to_persistent_dict(state)).is_empty(), "fractional source decay ledger validates")
