extends Node

var failures := 0

func _ready() -> void:
	failures += PureIdleRegression.new().run()
	failures += SourceDysonRegression.new().run()
	failures += SystemSpaceStationRegression.new().run()
	failures += SystemHubRegression.new().run()
	_test_mode_isolation()
	_test_local_colony_research()
	_test_difficulty_catalog()
	_test_time_warp_power()
	_test_orbital_station_conservation()
	_test_galactic_exports()
	_test_station_warper_refill()
	_test_source_dyson_unlock()
	_test_station_contracts()
	_test_station_presentation()
	_test_pure_idle_model()
	_test_black_hole_disposal()
	_test_source_station_and_quantum()
	_test_orbital_collector()
	_test_source_dispatch_edges()
	_test_source_galaxy_gold()
	_test_interstellar_routes()
	_test_contract_offer_gold()
	_test_orbital_cargo_terminal()
	if failures == 0: print("SINGLE PLAYER MODES TESTS PASSED")
	else: printerr("SINGLE PLAYER MODES TESTS FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("SINGLE PLAYER MODES: " + message)

func _test_mode_isolation() -> void:
	var normal := GameState.new()
	check(not GameStateCodec.to_persistent_dict(normal).has("save_mode"), "legacy normal saves retain their canonical digest")
	var speedrun := GameState.new()
	var service := GameModeSystem.new(speedrun)
	check(not service.configure_new_game("pure_idle", "standard"), "pure idle is a settlement operation, not a save mode")
	check(service.configure_new_game("speedrun", "hard"), "new speedrun owns an isolated save mode and difficulty")
	check(speedrun.save_mode == "speedrun" and speedrun.difficulty == "hard" and speedrun.speedrun_state.ruleset == "speedrun-v1", "speedrun fields initialize atomically")
	service.update_active_time(3.5)
	check(is_equal_approx(float(speedrun.speedrun_state.elapsed_active_seconds), 3.5), "active speedrun time follows wall delta")
	speedrun.paused = true
	service.update_active_time(10)
	check(is_equal_approx(float(speedrun.speedrun_state.elapsed_active_seconds), 3.5), "pause does not advance speedrun clock")
	speedrun.paused = false
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(speedrun))
	check(restored != null and restored.save_mode == "speedrun" and restored.difficulty == "hard" and is_equal_approx(float(restored.speedrun_state.elapsed_active_seconds), 3.5), "mode and active clock survive save round trip")
	check(GameStateCodec.to_persistent_dict(speedrun.copy_state()) == GameStateCodec.to_persistent_dict(speedrun), "isolated replay copies preserve save mode, difficulty, and active clock")
	var invalid := GameStateCodec.to_persistent_dict(speedrun)
	invalid.save_mode = "normal"
	check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "speedrun state cannot be loaded as normal mode")
	invalid = GameStateCodec.to_persistent_dict(speedrun)
	invalid.speedrun_state.elapsed_active_seconds = -1
	check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "negative speedrun clock is rejected")
	var normal_after := GameState.new()
	check(normal_after.save_mode == "normal" and normal_after.speedrun_state.is_empty(), "new ordinary factory does not inherit speedrun state")

func _test_local_colony_research() -> void:
	var state := SourceDysonRegression.new().fresh()
	check(state.colonized_planet_ids == ["home"], "source seeded ecology starts on home only")
	state.completed_technologies.append_array(["dsp_energy_matrix", "dsp_high_speed_logistics"])
	var technology := TechnologySystem.new(state)
	check(technology.start_research("dsp_interstellar_logistics"), "real source interstellar research begins")
	var id := state.add_building({"type": "dsp_matrix_lab", "position": Vector2.ZERO, "recipe_id": "dsp_matrix_research", "input_buffer": {}, "output_buffer": {}, "speed": 1.0})
	state.buildings[id].power_requested = 480.0
	state.buildings[id].power_efficiency = 1.0
	state.planet_inventory.electromagnetic_matrix = 20.0
	state.planet_inventory.energy_matrix = 20.0
	check(technology.supply_source_lab(id).ok, "local colonies require forty physical research matrices")
	technology.update_source_labs(1000)
	check(state.completed_technologies.has("dsp_interstellar_logistics") and state.colonized_planet_ids == ["home", "ashen", "giant"] and state.buildings[id].input_buffer.electromagnetic_matrix == 0 and state.buildings[id].input_buffer.energy_matrix == 0, "completed interstellar research opens two source colonies after actual matrix consumption")
	var digest := GameStateCodec.state_digest_payload(state)
	technology.update_source_labs(1000)
	check(digest == GameStateCodec.state_digest_payload(state), "completed colony grant is idempotent")
	check(GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state)) != null, "research-granted colony inventories and resource sites persist")

func _test_difficulty_catalog() -> void:
	var source := DSPOnlineParity.read_json("res://tests/fixtures/parity/dsponline_source_catalog.json")
	var state := GameState.new()
	var mode := GameModeSystem.new(state)
	for row in source.catalog.difficulties:
		check(mode.configure_new_game("normal", row.id), "frozen difficulty is selectable: " + row.id)
		for field in [["production", "productionMultiplier"], ["mining", "miningMultiplier"], ["logistics", "logisticsMultiplier"], ["power_demand", "powerDemandMultiplier"]]:
			check(is_equal_approx(mode.multiplier(field[0]), float(row.definition[field[1]])), "frozen difficulty coefficient: %s %s" % [row.id, field[0]])
	check(not mode.configure_new_game("normal", "unsupported"), "unknown difficulty is rejected")

func _test_time_warp_power() -> void:
	check(TimeWarpSystem.required_power_kw(5) == 1000000.0 and TimeWarpSystem.maximum_stable(72000000.0, 8) == 6, "frozen exponential power curve and stable downgrade")
	var state := GameState.new()
	var controller := state.add_building({"type": "dsp_time_warp_device", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}})
	var star := state.add_building({"type": "dsp_artificial_star", "position": Vector2(80, 0), "input_buffer": {}, "output_buffer": {}, "fuel_item": "antimatter_fuel_rod", "fuel_remaining": 100.0})
	for index in range(19): state.add_building({"type": "dsp_artificial_star", "position": Vector2(160 + index * 80, 0), "input_buffer": {}, "output_buffer": {}, "fuel_item": "antimatter_fuel_rod", "fuel_remaining": 100.0})
	var warp := TimeWarpSystem.new(state)
	check(warp.select_controller(controller) and warp.set_requested(8) and warp.set_enabled(true), "time warp requires a real selected controller")
	var power := PowerSystem.new(state)
	power.update(SimulationEngine.FIXED_DELTA)
	check(warp.effective_multiplier() == 5 and state.time_warp.required_kw == 1000000.0 and state.time_warp.allocated_kw == 1000000.0, "controller uses available generation and downgrades to stable 5x")
	check(float(state.buildings[star].fuel_remaining) < 100.0, "time warp demand burns real generator fuel")
	var payload := GameStateCodec.to_persistent_dict(state)
	check(GameStateCodec.to_persistent_dict(state.copy_state()) == payload, "isolated settlement and construction copies preserve quantum authority")
	check(payload.time_warp.get("effective", "") == "" and payload.time_warp.get("requested") == 8, "runtime power snapshot is omitted from save")
	var restored := GameStateCodec.from_persistent_dict(payload)
	check(restored != null and restored.time_warp.enabled and TimeWarpSystem.new(restored).effective_multiplier() == restored.speed, "loaded warp waits for fresh power allocation")
	power.allow_time_warp = false
	power.update(SimulationEngine.FIXED_DELTA)
	check(warp.effective_multiplier() == state.speed and state.buildings[controller].power_requested == 0, "offline settlement cannot consume warp power or accelerate")
	check(not warp.set_requested(4), "time warp target must be at least 5x")
	state.try_remove_entities([controller])
	check(not state.time_warp.get("enabled", false) and warp.effective_multiplier() == state.speed, "removing the controller disables time warp")

func _test_orbital_station_conservation() -> void:
	var state := GameState.new()
	var station := LocalSpaceStationSystem.new(state)
	check(station.snapshot().stage == "locked" and not station.start().ok, "orbital construction is locked before white matrix production")
	SourceProgressionFacts.record_produced(state, "universe_matrix", 1)
	check(station.snapshot().stage == "eligible" and station.start().ok, "one produced white matrix unlocks the local station")
	state.planet_inventory["titanium_alloy"] = 10.0
	check(station.deliver("titanium_alloy", 7).ok and float(state.planet_inventory.titanium_alloy) == 3.0 and int(state.orbital_station.delivered.core.titanium_alloy) == 7, "construction delivery moves exactly the accepted material")
	check(not station.deliver("titanium_alloy", 7).ok and int(state.orbital_station.delivered.core.titanium_alloy) == 7, "failed delivery cannot partially invest material")
	check(station.snapshot().remaining.titanium_alloy == 199993, "construction reports the authoritative outstanding cost")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and int(restored.orbital_station.delivered.core.titanium_alloy) == 7, "construction progress survives save round trip")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.orbital_station.delivered.core.titanium_alloy = 200001
	check(not GameStateValidator.validate_persistent_dict(corrupt).is_empty(), "overpaid construction state is rejected")
	var speedrun := GameState.new()
	GameModeSystem.new(speedrun).configure_new_game("speedrun", "standard")
	SourceProgressionFacts.record_produced(speedrun, "universe_matrix", 1)
	check(LocalSpaceStationSystem.new(speedrun).snapshot().stage == "locked", "speedrun cannot unlock the normal-mode station")

func _test_galactic_exports() -> void:
	var state := GameState.new()
	var exports := GalacticExportSystem.new(state)
	check(not exports.dispatch("universe_archive", 1).ok, "galactic export requires the source universe matrix technology")
	state.completed_technologies.append("dsp_universe_matrix")
	state.planet_inventory["universe_matrix"] = 130.0
	check(exports.dispatch("universe_archive", 100).ok and float(state.planet_inventory.universe_matrix) == 120.0, "manual export preserves source reserve and consumes exactly 10")
	check(int(state.galactic_exports.total_exported) == 10 and int(state.galactic_exports.credits) == 120, "export credits and totals are derived from consumed goods")
	check(SourceProgressionFacts.value(state, {"kind": "exported"}) == 10 and SourceProgressionFacts.value(state, {"kind": "galactic-score"}) == 120, "campaign export objectives read the authoritative galaxy ledger")
	var project: Dictionary = state.galactic_exports.projects.universe_archive
	project.delivered = 999
	state.planet_inventory.universe_matrix = 121.0
	check(exports.dispatch("universe_archive", 1).ok and int(project.level) == 1 and int(project.delivered) == 0 and int(state.galactic_exports.credits) == 12132, "meeting a project target awards the source level reward")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and int(restored.galactic_exports.projects.universe_archive.level) == 1, "galactic project progress survives save round trip")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.galactic_exports.projects.universe_archive.delivered = -1
	check(not GameStateValidator.validate_persistent_dict(corrupt).is_empty(), "negative galactic delivery is rejected")
	state.planet_inventory.universe_matrix = 130.0
	check(exports.configure("universe_archive", true, 3).ok, "galactic project accepts automation priority")
	exports.update(0.5)
	check(float(state.planet_inventory.universe_matrix) == 129.0, "automatic dispatch follows the requested rate and level-scaled reserve")
	state.progression_facts.infinite_research = {"galactic_logistics": {"level": 10, "invested": "0"}}
	state.planet_inventory.universe_matrix = 140.0
	exports.update(0.5)
	check(state.planet_inventory.universe_matrix == 138.0, "galactic export rate integrates ten-percent infinite logistics per level")

func _test_station_warper_refill() -> void:
	var state := GameState.new()
	var station_id := state.add_building({"type": "interstellar_logistics_station", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}, "station": StationSystem.empty_station()})
	var station := StationSystem.new(state)
	check(not station.set_warper_refill(station_id, true, 5).ok, "warper refill requires space warp technology")
	state.completed_technologies.append("dsp_space_warp")
	check(station.set_warper_refill(station_id, true, 5).ok and station.set_warp_enabled(station_id, false).ok, "interstellar station stores warp and refill controls")
	state.planet_inventory["space_warper"] = 10.0
	LogisticsSystem.new(state).update(SimulationEngine.FIXED_DELTA)
	check(int(state.buildings[station_id].station.fleet.space_warper) == 5 and float(state.planet_inventory.space_warper) == 5.0, "automatic refill moves warpers from the owning planet without creating stock")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and restored.buildings[station_id].station.warper_auto_refill and not restored.buildings[station_id].station.warp_enabled, "warper controls survive save round trip")

func _test_source_dyson_unlock() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_dyson_sphere_program")
	check(DysonSphereSystem.new(state).create_orbit("helios").ok, "frozen Dyson sphere technology unlocks local planning")
	var swarm := GameState.new()
	swarm.completed_technologies.append("dsp_dyson_swarm")
	swarm.construction_inventory["dsp_em_rail_ejector"] = 1.0
	check(DysonSphereSystem.new(swarm).create_orbit("helios").ok, "source Dyson swarm research permits orbital planning before sphere program")
	var placed := ConstructionSystem.new(swarm).try_place_building("dsp_em_rail_ejector", Vector2(800, 0))
	check(placed.ok, "source electromagnetic ejector is buildable through the real construction command")

func _test_station_contracts() -> void:
	var state := GameState.new()
	state.orbital_station = {"version": 1, "stage": "showcase", "delivered": {"core": LocalSpaceStationSystem.COSTS.core.duplicate(true), "dock": LocalSpaceStationSystem.COSTS.dock.duplicate(true), "showcase": {}}}
	var service := StationContractSystem.new(state)
	var now := StationContractSystem._wall_ms()
	var offers: Array = service.snapshot(now).board.offers
	check(offers.size() == 4 and offers[3].difficulty == "P3" and state.station_contracts.is_empty(), "local contract board offers four deterministic tasks without read side effects")
	var contract: Dictionary = offers[0]
	check(service.accept(contract.id, now).ok and state.station_contracts.accepted.size() == 1, "contract acceptance is recorded once")
	var requirement: Dictionary = state.station_contracts.accepted[0].requirements[0]
	state.planet_inventory[requirement.item] = 100.0
	check(service.deliver(contract.id, requirement.item, 50).ok and float(state.planet_inventory[requirement.item]) == 50.0 and int(requirement.delivered) == 50, "contract delivery consumes exactly accepted tray stock")
	check(not service.claim(contract.id).ok, "partial contract cannot claim completion reward")
	check(service.abandon(contract.id).ok and state.station_contracts.history.size() == 1 and state.station_contracts.accepted.is_empty(), "abandonment settles proportional rewards once and archives the contract")
	var marks := int(state.station_contracts.marks)
	check(not service.abandon(contract.id).ok and int(state.station_contracts.marks) == marks, "contract settlement cannot be replayed")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and restored.station_contracts.history.size() == 1 and int(restored.station_contracts.marks) == marks, "contract economy and history survive save round trip")
	var save := SaveSystem.new("res://.godot/task26-saves")
	check(save.save_slot(9, state).ok and save.load_slot(9).ok, "mode, station, galaxy, and contract fields pass the verified disk save path")

	check(not service.set_featured(contract.id).ok, "abandoned contract cannot be featured")
	var next: Dictionary = service.snapshot().board.offers[0]
	check(service.accept(next.id).ok, "next contract accepted for precise economy regression")
	var accepted: Dictionary = state.station_contracts.accepted[0]
	for entry in accepted.requirements: entry.delivered = entry.amount
	accepted.status = "claimable"
	state.station_contracts.marks = "9".repeat(256)
	state.station_contracts.reputation = "1" + "0".repeat(90)
	var expected := HubInteger.add(state.station_contracts.reputation, str(int(accepted.reward[1]) + int(accepted.reward[3])))
	check(service.claim(next.id).ok and state.station_contracts.marks == "9".repeat(256) and state.station_contracts.reputation == expected, "contract rewards retain 256 digit precision and source saturation")
	check(service.set_featured(next.id).ok, "completed history can be featured")
	check(save.save_slot(9, state).ok, "precise contract economy and featured history save")
	var precise := save.load_slot(9)
	check(precise.ok and precise.state.station_contracts.reputation == expected and precise.state.station_contracts.featured_id == next.id, "precise contract economy and featured history restore")
	check(service.set_featured("").ok and state.station_contracts.featured_id == "", "featured contract can be cleared")

func _test_black_hole_disposal() -> void:
	var state := GameState.new()
	state.completed_technologies.append("dsp_micro_black_hole_containment")
	state.construction_inventory[BlackHoleSystem.TYPE] = 1.0
	var placement := ConstructionSystem.new(state).try_place_building(BlackHoleSystem.TYPE, Vector2(800, 0))
	check(placement.ok, "researched micro black hole is placeable with a real construction item")
	if not placement.ok: return
	var hole_id: String = placement.id
	var hole: Dictionary = state.buildings[hole_id]
	check(hole.black_hole_paused and not hole.black_hole_activation_confirmed and hole.black_hole_ports == BlackHoleSystem.empty_ports(), "new black hole begins paused with three empty ports")
	state.construction_inventory["conveyor_belt_mk1"] = 4.0
	var ids := []
	for index in range(4):
		ids.append(state.add_building({"type": "smelter", "position": Vector2(index * 160, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {"iron_ingot": 10.0}, "power_efficiency": 1.0}))
	var connections := []
	for index in range(3):
		var linked := state.try_add_connection(ids[index], hole_id, "iron_ingot")
		check(linked.ok, "black hole accepts a distinct source on port %d" % index)
		if linked.ok: connections.append(linked.id)
	check(not state.try_add_connection(ids[3], hole_id, "iron_ingot").ok and state.construction_inventory.conveyor_belt_mk1 == 1.0, "fourth input is rejected without spending a belt")
	BeltSystem.new(state).update(1.0)
	check(float(state.buildings[ids[0]].output_buffer.iron_ingot) == 10.0 and hole.black_hole_ports == BlackHoleSystem.empty_ports(), "paused black hole cannot destroy stock")
	var controller := BlackHoleSystem.new(state)
	check(not controller.set_paused(hole_id, false).ok and hole.black_hole_paused, "first activation requires explicit confirmation")
	check(controller.set_paused(hole_id, false, true).ok, "confirmed activation starts the black hole")
	BeltSystem.new(state).update(1.0)
	check(float(state.buildings[ids[0]].output_buffer.iron_ingot) < 10.0 and int(hole.black_hole_ports[0].total_destroyed) > 0 and hole.black_hole_ports[0].item_id == "iron_ingot", "running black hole consumes whole items and records its first port")
	var consumed := 0.0
	for port in hole.black_hole_ports: consumed += float(port.total_destroyed)
	var remaining := 0.0
	for source_id in ids.slice(0, 3): remaining += float(state.buildings[source_id].output_buffer.iron_ingot)
	check(is_equal_approx(consumed + remaining, 30.0), "three-port destruction ledger conserves the transferred amount")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	check(restored != null and restored.buildings[hole_id].black_hole_activation_confirmed and restored.buildings[hole_id].black_hole_ports[0].total_destroyed == hole.black_hole_ports[0].total_destroyed, "black hole confirmation and destruction totals survive save round trip")
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.buildings[hole_id].black_hole_ports[0].total_destroyed = "-1"
	check(not GameStateValidator.validate_persistent_dict(corrupt).is_empty(), "negative destruction totals are rejected")
	var huge := BlackHoleSystem.empty_ports()
	huge[0].total_destroyed = "9007199254740993"
	var large_hole := {"type": BlackHoleSystem.TYPE, "black_hole_paused": false, "black_hole_activation_confirmed": true, "black_hole_ports": huge}
	check(BlackHoleSystem.record_transfer(large_hole, 0, "iron_ingot", 6) and huge[0].total_destroyed == "9007199254740999", "decimal port ledger remains exact beyond floating point safe integers")
	var saves := SaveSystem.new("res://.godot/task26-black-hole-saves")
	var saved := saves.save_slot(6, state)
	var loaded := saves.load_slot(6)
	check(saved.ok and loaded.ok, "black hole port indices and decimal ledger survive verified disk persistence: " + str(saved.get("error", {})) + str(loaded.get("error", {})))

func _test_source_station_and_quantum() -> void:
	var state := GameState.new()
	state.completed_technologies.append_array(["dsp_interstellar_logistics", "dsp_quantum_logistics_network"])
	state.construction_inventory["dsp_interstellar_logistics_station"] = 2.0
	var first := ConstructionSystem.new(state).try_place_building("dsp_interstellar_logistics_station", Vector2(800, 0))
	var second := ConstructionSystem.new(state).try_place_building("dsp_interstellar_logistics_station", Vector2(1600, 0))
	check(first.ok and second.ok, "source interstellar stations are available through formal construction")
	if not first.ok or not second.ok: return
	var a: String = first.id
	var b: String = second.id
	var station := StationSystem.new(state)
	check(state.buildings[a].station.slots.size() == 5, "source logistics station exposes all five slots")
	check(station.configure_slots([a], 4, "iron_ingot", "supply", 1000, 0.1, 1, "local").ok and station.configure_slots([b], 4, "iron_ingot", "demand", 1000, 0.1, 1, "local").ok, "fifth slot has an independent local scope")
	check(station.configure_slots([a], 4, "iron_ingot", "supply", 1000, 0.1, 1, "remote").ok and station.configure_slots([b], 4, "iron_ingot", "demand", 1000, 0.1, 1, "remote").ok, "source slots configure their remote scope independently")
	state.portable_fleet.logistics_vessel = 2
	check(station.set_fleet_target(b, "logistics_vessel", 1).ok and state.portable_fleet.logistics_vessel == 1 and state.buildings[b].station.fleet.logistics_vessel == 1, "source station fleet targets conserve the global portable fleet")
	state.colonized_planet_ids.append("ashen")
	state.planet_inventories["ashen"] = {}
	state.planet_viewports["ashen"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["ashen"] = {}
	state.buildings[b].planet_id = "ashen"
	var a_slot: Dictionary = state.buildings[a].station.slots[4]
	var b_slot: Dictionary = state.buildings[b].station.slots[4]
	a_slot.amount = 50.0
	state.buildings[a].power_efficiency = 1.0
	state.buildings[b].power_efficiency = 1.0
	var logistics := LogisticsSystem.new(state)
	logistics.update(SimulationEngine.FIXED_DELTA)
	check(state.logistics_routes.size() == 1 and state.logistics_routes.values()[0].get("owner_id") == b and state.buildings[b].station.fleet.logistics_vessel == 0, "source demand station owns the dispatched vessel")
	var quantum := QuantumLogisticsSystem.new(state)
	check(not quantum.attach(b).ok and quantum.upgrade_station(b).ok and quantum.attach(b).ok, "Mk.II upgrade and quantum attachment are separate technology-gated actions")
	state.elapsed_time = 5.0
	quantum.update()
	check(state.buildings[b].station.quantum_mode == "transitioning", "quantum attachment waits for all in-flight cargo and vehicles")
	var pending_saves := SaveSystem.new("res://.godot/task26-quantum-pending-saves")
	var pending_saved := pending_saves.save_slot(5, state)
	var pending_loaded := pending_saves.load_slot(5)
	check(pending_saved.ok and pending_loaded.ok and pending_loaded.state.buildings[b].station.quantum_mode == "transitioning" and pending_loaded.state.logistics_routes.values()[0].owner_id == b, "pending quantum transition and in-flight ownership survive verified disk persistence")
	state.set_active_planet("ashen")
	var busy_target := station.set_fleet_target(b, "logistics_vessel", 0)
	check(busy_target.ok and busy_target.final == 1 and busy_target.busy == 1, "fleet target cannot unload a busy vessel")
	state.set_active_planet("home")
	logistics.update(30.0)
	logistics.update(30.0)
	state.elapsed_time = 10.0
	quantum.update()
	check(state.logistics_routes.is_empty() and state.buildings[b].station.fleet.logistics_vessel == 1 and state.buildings[b].station.quantum_mode == "quantum", "finished legacy route returns its vessel before the quantum handoff")
	check(quantum.upgrade_station(a).ok and quantum.attach(a).ok, "second tower can join the same save-wide network")
	state.elapsed_time = 15.0
	quantum.update()
	a_slot.amount = 1000.0
	b_slot.amount = 0.0
	state.buildings[a].power_efficiency = 0.0
	state.buildings[b].power_efficiency = 0.0
	state.elapsed_time = 20.0
	quantum.update()
	check(a_slot.amount == 0.0 and b_slot.amount == 833.0 and state.quantum_network.inventory.iron_ingot == "167", "quantum supply buffers enter shared inventory directly while two towers share the frozen 833-item five-second download budget independently of local power")
	quantum.update()
	check(a_slot.amount == 0.0 and b_slot.amount == 833.0, "a repeated quantum boundary cannot settle twice")
	check(quantum.set_item_capacity("iron_ingot", "10000").ok and not quantum.set_item_capacity("iron_ingot", "1e5").ok, "quantum capacities accept bounded decimal integers and reject exponent notation")
	state.quantum_network.inventory.iron_ingot = "50000"
	check(quantum.set_item_capacity("iron_ingot", "10000").ok and state.quantum_network.inventory.iron_ingot == "50000", "lowering quantum capacity does not delete existing stock")
	var payload := GameStateCodec.to_persistent_dict(state)
	var restored := GameStateCodec.from_persistent_dict(payload)
	check(restored != null and restored.quantum_network.inventory.iron_ingot == "50000" and restored.buildings[a].station.slots.size() == 5, "quantum inventory, modes, and five-slot station state survive save round trip")
	var saves := SaveSystem.new("res://.godot/task26-quantum-saves")
	var saved := saves.save_slot(8, state)
	check(saved.ok and saves.load_slot(8).ok, "source stations and quantum quantities pass verified disk persistence: " + str(saved.get("error", {})))
	payload.quantum_network.inventory.iron_ingot = "NaN"
	check(not GameStateValidator.validate_persistent_dict(payload).is_empty(), "invalid decimal quantum inventory is rejected")

func _test_orbital_collector() -> void:
	var state := GameState.new()
	state.completed_technologies.append_array(["dsp_orbital_collection", "dsp_interstellar_logistics", "dsp_quantum_logistics_network"])
	state.construction_inventory[OrbitalCollectorSystem.TYPE] = 1.0
	var before := GameStateCodec.to_persistent_dict(state)
	check(not ConstructionSystem.new(state).try_place_building(OrbitalCollectorSystem.TYPE, Vector2(800, 0)).ok and GameStateCodec.to_persistent_dict(state) == before, "collector rejects terrestrial deployment before spending its kit")
	state.colonized_planet_ids.append("giant")
	state.planet_inventories["giant"] = {}
	state.planet_viewports["giant"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	state.planet_metrics["giant"] = {}
	state.set_active_planet("giant")
	var placed := ConstructionSystem.new(state).try_place_building(OrbitalCollectorSystem.TYPE, Vector2(800, 0))
	check(placed.ok, "collector deploys through formal gas giant construction")
	if not placed.ok: return
	var id: String = placed.id
	var building: Dictionary = state.buildings[id]
	var captured: Dictionary = BlueprintSystem.new(state).capture_selection([id])
	state.set_active_planet("home")
	var before_blueprint := GameStateCodec.to_persistent_dict(state)
	check(captured.ok and not BlueprintSystem.new(state).deploy(captured.blueprint, Vector2(1600, 0)).ok and GameStateCodec.to_persistent_dict(state) == before_blueprint, "blueprint deployment cannot bypass gas giant restrictions or spend construction materials")
	state.set_active_planet("giant")
	var collector := OrbitalCollectorSystem.new(state)
	var statistics := StatisticsSystem.new(state)
	PowerSystem.new(state).update(1.0)
	collector.update(2.0, statistics)
	check(building.power_efficiency == 1.0 and building.station.slots[0].amount == 2.0 and SourceProgressionFacts.value(state, {"kind": "produced", "itemId": "hydrogen"}) == 2.0, "self-powered collector produces whole hydrogen and authoritative production facts")
	check(collector.select_item(id, "deuterium").ok, "collector can select a gas giant's deuterium yield")
	collector.update(5.0, statistics)
	check(building.station.slots[1].amount == 1.0 and building.station.slots[0].amount == 2.0, "changing collection product preserves previous inventory and fractional yield accounting")
	check(not collector.select_item(id, "iron_ore").ok, "collector rejects resources outside its orbital yield profile")
	collector.select_item(id, "hydrogen")
	building.station.slots[0].amount = 120.0
	state.set_active_planet("home")
	state.construction_inventory["dsp_interstellar_logistics_station"] = 1.0
	var tower := ConstructionSystem.new(state).try_place_building("dsp_interstellar_logistics_station", Vector2(800, 0))
	check(tower.ok, "collector cargo has a real interstellar demand endpoint")
	if not tower.ok: return
	var tower_id: String = tower.id
	var stations := StationSystem.new(state)
	stations.configure_slots([tower_id], 0, "hydrogen", "demand", 1000, 0.1, 1, "remote")
	state.portable_fleet.logistics_vessel = 1
	stations.set_fleet_target(tower_id, "logistics_vessel", 1)
	state.buildings[tower_id].power_efficiency = 1.0
	var logistics := LogisticsSystem.new(state)
	logistics.update(SimulationEngine.FIXED_DELTA)
	check(state.logistics_routes.size() == 1 and state.logistics_routes.values()[0].owner_id == tower_id and building.station.slots[0].amount == 20.0, "collector supplies a demand tower's vessel without creating its own fleet")
	var quantum := QuantumLogisticsSystem.new(state)
	quantum.upgrade_station(tower_id)
	check(quantum.attach(tower_id).ok and quantum.set_collector_mode(id, true).ok, "tower and collector independently request quantum handoff")
	state.elapsed_time = 5.0
	quantum.update()
	check(building.station.quantum_mode == "transitioning", "collector waits for the vessel route stored on its demand peer")
	logistics.update(30.0)
	logistics.update(30.0)
	state.elapsed_time = 10.0
	quantum.update()
	check(building.station.quantum_mode == "quantum" and state.buildings[tower_id].station.fleet.logistics_vessel == 1, "collector handoff completes only after peer cargo and vessel return")
	state.elapsed_time = 15.0
	quantum.update()
	check(quantum.snapshot().active_towers == 1 and state.quantum_network.inventory.hydrogen == "20" and building.station.slots[0].amount == 0.0, "quantum collector uploads within tower bandwidth without adding bandwidth")
	state.elapsed_time = 20.0
	quantum.update()
	check(state.quantum_network.inventory.hydrogen == "0" and state.buildings[tower_id].station.slots[0].amount == 120.0, "next boundary downloads the exact collector cargo to its demand tower")
	check(quantum.set_collector_mode(id, false).ok, "collector can return to traditional logistics")
	check(quantum.cancel(id).ok and building.station.quantum_mode == "quantum", "cancelling collector exit restores its previous quantum mode")
	quantum.set_collector_mode(id, false)
	state.elapsed_time = 25.0
	quantum.update()
	check(building.station.quantum_mode == "legacy", "collector mode reversal completes at a persistent boundary")
	var save := SaveSystem.new("res://.godot/task26-collector-saves")
	var saved := save.save_slot(7, state)
	check(saved.ok and save.load_slot(7).ok, "collector production and mode state survive verified disk persistence: " + str(saved.get("error", {})))
	var corrupt := GameStateCodec.to_persistent_dict(state)
	corrupt.buildings[id].station.slots[0].remote_mode = "demand"
	check(not GameStateValidator.validate_persistent_dict(corrupt).is_empty(), "collector saves cannot replace fixed supply slots with demand slots")

func _test_source_dispatch_edges() -> void:
	var state := GameState.new()
	state.completed_technologies.append_array(["dsp_interstellar_logistics", "dsp_quantum_logistics_network"])
	state.construction_inventory.dsp_interstellar_logistics_station = 2.0
	var a: String = ConstructionSystem.new(state).try_place_building("dsp_interstellar_logistics_station", Vector2(800, 0)).id
	var b: String = ConstructionSystem.new(state).try_place_building("dsp_interstellar_logistics_station", Vector2(1600, 0)).id
	var stations := StationSystem.new(state)
	stations.configure_slots([a], 0, "iron_ingot", "supply", 1000, 1.0, 1, "local")
	stations.configure_slots([b], 0, "iron_ingot", "demand", 1000, 0.1, 1, "local")
	stations.configure_slots([b], 0, "iron_ingot", "supply", 1000, 0.1, 1, "remote")
	state.portable_fleet.logistics_drone = 5
	stations.set_fleet_target(a, "logistics_drone", 3)
	state.buildings[a].power_efficiency = 1.0
	state.buildings[b].power_efficiency = 0.0
	state.buildings[a].station.slots[0].amount = 75.0
	var logistics := LogisticsSystem.new(state)
	logistics.update(SimulationEngine.FIXED_DELTA)
	check(state.logistics_routes.size() == 3 and state.buildings[a].station.fleet.logistics_drone == 0 and state.buildings[a].station.slots[0].amount == 0.0, "source supply fleet fills three local cargoes in one dispatch while demand fleet is empty")
	var captured: Dictionary = BlueprintSystem.new(state).capture_selection([a])
	check(captured.ok and captured.fleet_targets.values()[0].logistics_drone == 3, "blueprint fleet targets include source-owned in-flight drones")
	var quantum := QuantumLogisticsSystem.new(state)
	quantum.upgrade_station(b)
	quantum.attach(b)
	state.elapsed_time = 5.0
	quantum.update()
	check(state.buildings[b].station.quantum_mode == "quantum" and state.logistics_routes.size() == 3, "quantum attachment preserves active local routes")
	logistics.update(8.0)
	check(state.logistics_routes.is_empty() and state.buildings[a].station.fleet.logistics_drone == 3 and state.quantum_network.inventory.iron_ingot == "75" and state.buildings[b].station.slots[0].amount == 0.0, "local drones deliver directly to quantum supply inventory using only their owner's power and release vehicles at trip completion")
	state.quantum_network.inventory.iron_ingot = "9999"
	quantum.set_item_capacity("iron_ingot", "10000")
	state.planet_inventory.iron_ingot = PlanetTraySystem.new(state).limit()
	check(quantum.deposit("iron_ingot", 25) == 1 and state.quantum_network.inventory.iron_ingot == "10000", "direct quantum deposits respect shared remaining capacity")
	check(not quantum.withdraw("iron_ingot", 1).ok and state.quantum_network.inventory.iron_ingot == "10000", "full tray rejection leaves quantum stock intact")
	check(state.remove_building(a).ok and state.portable_fleet.logistics_drone == 5 and state.planet_inventory.get("logistics_drone", 0) == 0, "source station demolition returns parked fleet to portable ownership")

func _test_source_galaxy_gold() -> void:
	var file := FileAccess.open("res://tests/fixtures/parity/behavior/task26-galaxy.json", FileAccess.READ)
	var gold: Dictionary = JSON.parse_string(file.get_as_text())
	for row in gold.cases:
		var state := GameState.new()
		var service := SourceGalaxySystem.new(state)
		service.initialize(int(row.seed), row.baseline)
		check(_gold_equal(state.source_galaxy, row.state), "galaxy profiles match frozen source seed %s baseline %s" % [row.seed, row.baseline])
		for planet in row.state.profiles:
			for item in row.state.profiles[planet].resourceIds:
				var id: String = "%s_%s_1" % [planet, item]
				check(service.reserve(planet, item, id) == int(row.reserves[id]), "vein reserve matches frozen source %s seed %s" % [id, row.seed])
		var galaxy := GalaxySystem.new(state)
		check(galaxy.get_all_planet_ids().size() == 22 and galaxy.get_all_system_ids().size() == 8 and galaxy.get_catalog_errors().is_empty(), "source world exposes the complete validated 22-planet and 8-system catalog")
		PlanetSystem.new(state, galaxy).initialize_colonized_resource_sites()
		var first_id: String = state.resource_sites.keys()[0]
		state.resource_sites[first_id].remaining -= 1
		var remaining := float(state.resource_sites[first_id].remaining)
		PlanetSystem.new(state, galaxy).initialize_colonized_resource_sites()
		check(state.resource_sites[first_id].remaining == remaining, "reinitializing resource bindings never resets depleted reserves")
		check(service.set_role("home", "research").ok and service.set_metadata("home", "本地母星", "科学基地", ["矩阵"]).ok and service.set_metadata("helios", "本地星系", "", [], true).ok, "source world stores local role, names, notes, and tags")
		check(galaxy.get_planet("home").name == "本地母星" and galaxy.get_system_name("helios") == "本地星系" and galaxy.search("科学基地").planet_ids.has("home"), "formal galaxy queries immediately project local metadata and search notes")
		var before_metadata := state.source_galaxy.duplicate(true)
		check(not service.set_metadata("home", "x".repeat(33)).ok and state.source_galaxy == before_metadata, "overlong local names reject atomically")
		check(GameStateCodec.to_persistent_dict(state.copy_state()) == GameStateCodec.to_persistent_dict(state), "source world authority survives isolated state copies")
		var saves := SaveSystem.new("res://.godot/task26-galaxy-saves")
		var saved := saves.save_slot(4, state)
		var loaded := saves.load_slot(4)
		check(saved.ok and loaded.ok and _gold_equal(loaded.state.source_galaxy, state.source_galaxy), "source world profiles and finite reserves survive verified disk persistence: " + str(saved.get("error", {})) + str(loaded.get("error", {})))
	var legacy := GameState.new()
	check(GalaxySystem.new(legacy).get_all_planet_ids().size() == 6 and not GameStateCodec.to_persistent_dict(legacy).has("source_galaxy"), "legacy saves keep their original world catalog and digest")
	var invalid := GameStateCodec.to_persistent_dict(legacy)
	invalid.source_galaxy = {"seed": "bad"}
	check(not GameStateValidator.validate_persistent_dict(invalid).is_empty(), "malformed source galaxy is rejected before catalog construction")

func _gold_equal(actual: Variant, expected: Variant) -> bool:
	if (actual is float or actual is int) and (expected is float or expected is int): return absf(float(actual) - float(expected)) < 0.000000001
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _gold_equal(actual[key], expected[key]):
				printerr("GALAXY GOLD FIELD: " + str(key) + " actual=" + str(actual.get(key)) + " expected=" + str(expected[key]))
				return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index in range(actual.size()):
			if not _gold_equal(actual[index], expected[index]): return false
		return true
	return actual == expected

func _test_interstellar_routes() -> void:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-routes.json"))
	var fields := {"distanceLy": "distance_ly", "orbitSpan": "orbit_span", "requiresWarp": "requires_warp", "durationSeconds": "duration", "cargoPerTrip": "cargo_per_trip", "throughputPerMinute": "throughput_per_minute", "warpersPerTrip": "warpers_per_trip", "powerKw": "power_kw", "energyMjPerTrip": "energy_mj_per_trip", "routeAvailable": "available", "routeKind": "kind", "waypointStationIds": "waypoint_ids", "hopCount": "hop_count", "maxLegDistanceLy": "max_leg_distance_ly", "warpersPerVessel": "warpers_per_vessel"}
	for row in gold.cases:
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(int(gold.seed))
		state.difficulty = row.difficulty
		state.progression_facts["infinite_research"] = {"galactic_logistics": {"level": int(row.level), "invested": "0"}}
		state.explored_system_ids = GalaxySystem.new(state).get_all_system_ids()
		for entity in [row.source, row.target] + row.hubs:
			state.buildings[entity.id] = {"id": entity.id, "type": "dsp_interstellar_logistics_station", "planet_id": entity.planetId, "station": {"hub_enabled": entity.get("stationHubEnabled", false), "hub_priority": int(entity.get("stationHubPriority", 1))}}
		var actual := InterstellarRouteSystem.new(state).economics(state.buildings.source, state.buildings.target, int(row.count), {"route_policy": row.policy, "warper_budget": int(row.budget)})
		for field in fields: check(_gold_equal(actual[fields[field]], row.expected[field]), "frozen source route economics %s %s: %s vs %s" % [row.policy, field, actual[fields[field]], row.expected[field]])
	var state := GameState.new()
	SourceGalaxySystem.new(state).initialize(int(gold.seed))
	var galaxy := GalaxySystem.new(state)
	state.explored_system_ids = galaxy.get_all_system_ids()
	for system_id in state.explored_system_ids: state.survey_progress_by_system[system_id] = 1.0
	state.colonized_planet_ids = galaxy.get_all_planet_ids()
	for planet in state.colonized_planet_ids:
		if not state.planet_inventories.has(planet): state.planet_inventories[planet] = {}
		state.planet_viewports[planet] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	PlanetSystem.new(state, galaxy).initialize_colonized_resource_sites()
	state.completed_technologies.append_array(["dsp_interstellar_logistics", "dsp_space_warp", "dsp_quantum_logistics_network"])
	var ids := {}
	var row: Dictionary = gold.cases[4]
	for entity in [row.source, row.target] + row.hubs:
		var id := state.add_building({"type": "dsp_interstellar_logistics_station", "planet_id": entity.planetId, "position": Vector2(ids.size() * 200, 0), "input_buffer": {}, "output_buffer": {}, "power_efficiency": 1.0, "station": StationSystem.empty_station("dsp_interstellar_logistics_station")})
		ids[entity.id] = id
		state.buildings[id].station.merge({"hub_enabled": entity.get("stationHubEnabled", false), "hub_priority": int(entity.get("stationHubPriority", 1))}, true)
	var source: Dictionary = state.buildings[ids.source]
	var target: Dictionary = state.buildings[ids.target]
	source.station.slots[0].merge({"item_id": "iron_ingot", "remote_mode": "supply", "amount": 100.0}, true)
	target.station.slots[0].merge({"item_id": "iron_ingot", "remote_mode": "demand", "route_policy": "relay-required", "warper_budget": 1}, true)
	source.station.fleet.logistics_vessel = 1
	source.station.fleet.space_warper = 4
	var logistics := LogisticsSystem.new(state)
	logistics.update(0.1)
	check(state.logistics_routes.is_empty() and source.station.slots[0].amount == 100.0 and source.station.fleet.space_warper == 4, "relay-required cannot silently fall back to a direct route or spend stock with one-hop budget")
	target.station.slots[0].warper_budget = 4
	logistics.update(0.1)
	check(state.logistics_routes.size() == 1, "relay policy dispatches a legal multi-hop route")
	if state.logistics_routes.is_empty(): return
	var route: Dictionary = state.logistics_routes.values()[0]
	check(route.waypoint_ids.size() > 0 and source.station.fleet.space_warper == 4 - int(route.warpers_per_vessel) and source.station.fleet.logistics_vessel == 0, "dispatch consumes one warper per leg and preserves vehicle ownership")
	var hub_id: String = route.waypoint_ids[0]
	state.buildings[hub_id].power_efficiency = 0.0
	var remaining := float(route.remaining)
	logistics.update(10)
	check(route.remaining == remaining and not state.remove_building(hub_id).ok, "an unpowered relay pauses cargo and an active waypoint cannot be dismantled")
	var saves := SaveSystem.new("res://.godot/task26-route-saves")
	var saved := saves.save_slot(3, state)
	var loaded := saves.load_slot(3)
	check(saved.ok and loaded.ok and loaded.state.logistics_routes.values()[0].waypoint_ids == route.waypoint_ids, "in-flight relay plan survives verified disk persistence: " + str(saved.get("error", {})) + str(loaded.get("error", {})))
	state.set_active_planet(state.buildings[hub_id].planet_id)
	var quantum := QuantumLogisticsSystem.new(state)
	check(quantum.upgrade_station(hub_id).ok and quantum.attach(hub_id).ok, "relay can request a quantum transition")
	state.elapsed_time = 5
	quantum.update()
	check(state.buildings[hub_id].station.quantum_mode == "transitioning", "quantum transition waits for routes using the station as a relay")
	state.buildings[hub_id].power_efficiency = 1.0
	logistics.update(float(route.duration) + 1)
	quantum.update()
	check(state.logistics_routes.is_empty() and source.station.fleet.logistics_vessel == 1 and target.station.slots[0].amount == 100.0 and state.buildings[hub_id].station.quantum_mode == "quantum", "completed relay releases its vehicle, delivers once, and then completes the quantum transition")

func _test_contract_offer_gold() -> void:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-contracts.json"))
	for row in gold.cases:
		var state := GameState.new()
		SourceGalaxySystem.new(state).initialize(int(gold.seed))
		state.colonized_planet_ids = row.planets.duplicate()
		state.progression_facts["produced"] = row.produced.duplicate()
		state.quantum_network = {"enabled": row.enabled}
		var service := StationContractSystem.new(state)
		for expected in row.offers:
			var offer := service._create_offer(int(row.day), int(expected.slot))
			check(offer.id == expected.id and offer.template == expected.templateId and offer.difficulty == expected.difficulty, "frozen deterministic contract identity and difficulty: " + expected.id)
			check(offer.requirements.size() == expected.requirements.size(), "frozen contract requirement count: " + expected.id)
			for index in range(mini(offer.requirements.size(), expected.requirements.size())):
				var actual: Dictionary = offer.requirements[index]
				var requirement: Dictionary = expected.requirements[index]
				check(actual.item == requirement.itemId and int(actual.amount) == int(requirement.amount) and actual.channel == requirement.channel and actual.source_planet_ids == requirement.get("sourcePlanetIds", []) and actual.weight == requirement.weight, "frozen contract item, channel, amount, origin and weight: " + expected.id)
			var rewards: Dictionary = expected.rewards
			check(offer.reward == [int(rewards.baseMarks), int(rewards.baseReputation), int(rewards.completionMarks), int(rewards.completionReputation)], "frozen contract rewards: " + expected.id)

func _test_orbital_cargo_terminal() -> void:
	var state := GameState.new()
	state.progression_facts["produced"] = {"universe_matrix": 1.0}
	var definition := DataManager.get_building(OrbitalCargoTerminalSystem.TYPE)
	state.completed_technologies.append("dsp_" + String(definition.required_source_technology))
	state.construction_inventory[OrbitalCargoTerminalSystem.TYPE] = 1.0
	var placed := ConstructionSystem.new(state).try_place_building(OrbitalCargoTerminalSystem.TYPE, Vector2(10000, 0))
	check(placed.ok, "orbital cargo terminal is buildable through the real construction command")
	if not placed.ok: return
	var id: String = placed.id
	var service := OrbitalCargoTerminalSystem.new(state)
	check(service.bind_target(id, {"kind": "construction"}).ok, "cargo terminal binds the eligible station construction stage")
	state.construction_inventory.conveyor_belt_mk1 = 5.0
	var items := LocalSpaceStationSystem.COSTS.core.keys()
	for index in range(items.size()):
		var item: String = items[index]
		var recipe := {}
		for candidate in DataManager.get_all_recipes().values():
			if candidate.get("outputs", []).any(func(output): return output.item_id == item):
				recipe = candidate
				break
		var source := state.add_building({"type": recipe.building_id, "position": Vector2(index * 200, 0), "recipe_id": recipe.id, "input_buffer": {}, "output_buffer": {item: 100.0}, "power_efficiency": 1.0})
		var connected := state.try_add_connection(source, id, item)
		check(connected.ok and state.buildings[id].orbital_cargo_ports[index] == item, "real belt construction configures orbital cargo port %d: %s" % [index, connected])
		state.buildings[id].input_buffer[item] = 200.0
	state.buildings[id].power_efficiency = 1.0
	service.update(1.0)
	check(state.buildings[id].orbital_cargo_total == "333" and state.buildings[id].orbital_cargo_cursor == 1, "four cargo ports share the 20000-per-minute budget and rotate integer remainder")
	for index in range(items.size()):
		var delivered := 84 if index == 0 else 83
		check(int(state.orbital_station.delivered.core[items[index]]) == delivered and float(state.buildings[id].input_buffer[items[index]]) == 200 - delivered, "terminal debit equals station credit for port %d" % index)
	state.buildings[id].power_efficiency = 0.0
	var before := state.orbital_station.duplicate(true)
	service.update(10)
	check(state.orbital_station == before and state.buildings[id].orbital_cargo_total == "333", "unpowered cargo terminal cannot upload")
	var saves := SaveSystem.new("res://.godot/task26-terminal-saves")
	var saved := saves.save_slot(2, state)
	var loaded := saves.load_slot(2)
	check(saved.ok and loaded.ok and loaded.state.buildings[id].orbital_cargo_total == "333" and loaded.state.buildings[id].orbital_cargo_cursor == 1, "cargo ports, buffers, binding and exact ledger survive verified disk persistence: " + str(saved.get("error", {})) + str(loaded.get("error", {})))
	check(not service.clear_port(id, 0).ok, "occupied port requires confirmation before clearing")
	state.planet_inventory[items[0]] = PlanetTraySystem.new(state).limit()
	var before_clear := GameStateCodec.to_persistent_dict(state)
	check(not service.clear_port(id, 0, true).ok and GameStateCodec.to_persistent_dict(state) == before_clear, "full tray blocks port clearing without losing buffered items or installed belts")
	state.planet_inventory[items[0]] = 0.0
	check(service.clear_port(id, 0, true).ok and state.buildings[id].orbital_cargo_ports[0] == "" and state.planet_inventory[items[0]] == 116.0 and state.construction_inventory.conveyor_belt_mk1 == 2.0 and state.connections.size() == 3, "confirmed port clearing atomically returns buffered stock and the installed belt")
	state.quantum_network = QuantumLogisticsSystem._initial()
	state.quantum_network.enabled = true
	state.quantum_network.inventory[items[0]] = "75"
	check(LocalSpaceStationSystem.new(state).deliver_quantum(items[0], 100).ok and state.quantum_network.inventory[items[0]] == "0" and int(state.orbital_station.delivered.core[items[0]]) == 159, "player-confirmed quantum construction consumes only accepted shared stock")
	state.orbital_station = {"version": 1, "stage": "showcase", "delivered": {"core": LocalSpaceStationSystem.COSTS.core.duplicate(true), "dock": LocalSpaceStationSystem.COSTS.dock.duplicate(true), "showcase": {}}}
	state.colonized_planet_ids.append("ashen")
	var contracts := StationContractSystem.new(state)
	var now := StationContractSystem._wall_ms()
	var day := StationContractSystem.day_index(now)
	state.station_contracts = StationContractSystem._initial(now)
	var origin_contract := {}
	for slot in range(4):
		var offer := contracts._create_offer(day, slot)
		if offer.template in ["origin", "multi-origin"]: origin_contract = offer
	if origin_contract.is_empty():
		origin_contract = contracts._create_offer(day, 0)
		origin_contract.requirements[0].channel = "terminal"
		origin_contract.requirements[0].source_planet_ids = ["ashen"]
	origin_contract.status = "accepted"
	state.station_contracts.accepted = [origin_contract]
	var entry: Dictionary = origin_contract.requirements[0]
	entry.source_planet_ids = ["ashen"]
	for required_entry in origin_contract.requirements:
		if required_entry.item == entry.item: required_entry.source_planet_ids = ["ashen"]
	state.planet_inventory[entry.item] = 100.0
	check(not contracts.deliver(origin_contract.id, entry.item, 20).ok and state.planet_inventory[entry.item] == 100.0, "ordinary contract delivery respects the required source planet")
	state.quantum_network.inventory[entry.item] = "50"
	check(contracts.deliver_quantum(origin_contract.id, entry.item, 20).ok and state.quantum_network.inventory[entry.item] == "30" and int(entry.delivered) == 20, "confirmed quantum delivery is a fallback for an origin-restricted contract")
	service.bind_target(id, {"kind": "contract", "contract_id": origin_contract.id})
	state.buildings[id].orbital_cargo_ports = [entry.item, "", "", ""]
	state.buildings[id].input_buffer = {entry.item: 50.0}
	state.buildings[id].power_efficiency = 1.0
	service.update(1)
	check(state.buildings[id].input_buffer[entry.item] == 50.0 and int(entry.delivered) == 20, "automatic terminal delivery cannot bypass source restrictions")
	contracts.abandon(origin_contract.id)
	service.update(1)
	check(state.buildings[id].orbital_cargo_binding.is_empty() and state.buildings[id].input_buffer[entry.item] == 50.0, "settled target clears the terminal binding while retaining owned cargo")

func _test_station_presentation() -> void:
	var state := SourceDysonRegression.new().fresh()
	state.orbital_station = {"version": 1, "stage": "operational", "delivered": LocalSpaceStationSystem.COSTS.duplicate(true)}
	state.station_contracts = StationContractSystem._initial(StationContractSystem._wall_ms())
	var model := StationPresentationSystem.new(state)
	var before := GameStateCodec.to_persistent_dict(state)
	model.snapshot()
	model.level()
	check(GameStateCodec.to_persistent_dict(state) == before, "decoration queries never materialize state or currency")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-decorations.json"))
	for row in gold.checks:
		state.station_contracts.reputation = row.reputation
		state.orbital_station.presentation = StationPresentationSystem.initial()
		state.orbital_station.presentation.unlocked = [row.decoration]
		var result := model.placement_check(row.decoration, row.position)
		check(result.ok == row.expected.ok and result.code == row.expected.code, "frozen decoration placement and level: " + row.decoration + " " + row.reputation)
	state.orbital_station.presentation = StationPresentationSystem.initial()
	state.station_contracts.marks = "10000"
	state.station_contracts.reputation = "5000"
	check(model.purchase("cargo_crate").ok and state.station_contracts.marks == "9970" and state.station_contracts.reputation == "5000", "permanent license consumes marks without spending reputation")
	check(not model.purchase("cargo_crate").ok and state.station_contracts.marks == "9970", "duplicate purchase cannot debit marks")
	var position := {"x": -750.0, "y": 400.0, "rotation": 0, "layer": 1, "variant": 0}
	check(model.place("cargo_crate", position).ok, "licensed decoration placed outside functional anchors")
	var id: String = model.snapshot().placements[0].id
	before = GameStateCodec.to_persistent_dict(state)
	check(not model.update_placement(id, {"x": -270.0, "y": -80.0}).ok and GameStateCodec.to_persistent_dict(state) == before, "anchor collision rejects layout move atomically")
	check(model.update_placement(id, {"rotation": 90, "layer": 2, "variant": 1}).ok, "valid layout move and rotation")
	check(model.remove(id).ok and model.snapshot().unlocked.has("cargo_crate") and model.place("cargo_crate", position).ok, "removal preserves license and allows reuse without payment")
	check(model.purchase("nebula_violet", true).ok and model.set_theme("nebula_violet").ok and state.station_contracts.marks == "9710", "theme license paid once and persists")
	check(model.set_profile("<轨道港>", "测试\u0001名片", ["dyson-power", "bad", "dyson-power"]).ok and model.snapshot().profile.title == "轨道港" and model.snapshot().profile.featured_metrics == ["dyson-power"], "profile filters markup and unknown or duplicate metrics")
	state.completed_achievement_ids = ["first_building"]
	check(model.set_featured_achievements(["first_building", "locked", "first_building"]).ok and model.snapshot().featured_achievements == ["first_building"], "featured achievements limited to unlocked distinct awards")
	check(model.set_viewport(30000, -30000, 5).ok and model.snapshot().viewport == {"x": 20000.0, "y": -20000.0, "zoom": 2.5}, "source viewport clamps pan and zoom")
	check(model.purchase("contract_trophy").ok and model.place("contract_trophy", position).ok and not model.place("contract_trophy", position).ok, "unique trophy cannot be duplicated")
	var save := SaveSystem.new("res://.godot/task26-station-presentation")
	var written := save.save_slot(0, state)
	check(written.ok, "station presentation disk save: " + str(written))
	var loaded := save.load_slot(0)
	check(loaded.ok and JSON.parse_string(JSON.stringify(loaded.state.orbital_station.presentation)) == JSON.parse_string(JSON.stringify(state.orbital_station.presentation)), "station layout profile and licenses disk round trip")
	var bad := GameStateCodec.to_persistent_dict(state)
	bad.orbital_station.presentation.placements[0].x = -270.0
	bad.orbital_station.presentation.placements[0].y = -80.0
	check(GameStateCodec.from_persistent_dict(bad) == null, "stored decoration cannot overlap functional anchor")
	model.remove(model.snapshot().placements[1].id)
	for index in range(255): check(model.place("cargo_crate", position).ok, "source level six allows repeated placements")
	check(model.snapshot().placements.size() == 256 and not model.place("cargo_crate", position).ok, "source level six placement cap enforced")

func _test_pure_idle_model() -> void:
	var state := SourceDysonRegression.new().fresh()
	var controller := state.add_building({"type": "dsp_time_warp_device", "position": Vector2.ZERO, "input_buffer": {}, "output_buffer": {}})
	for index in range(20): state.add_building({"type": "dsp_artificial_star", "position": Vector2(500 + 300 * index, 0), "input_buffer": {}, "output_buffer": {}, "fuel_item": "antimatter_fuel_rod", "fuel_remaining": 1000.0})
	var machine := state.add_building({"type": "smelter", "position": Vector2(500, 500), "recipe_id": "iron_ingot_recipe", "input_buffer": {"iron_ore": 1000.0}, "output_buffer": {}, "input_buffer_capacity": 2000.0, "output_buffer_capacity": 2000.0})
	var warp := TimeWarpSystem.new(state)
	warp.select_controller(controller)
	warp.set_requested(5)
	warp.set_enabled(true)
	PowerSystem.new(state).update(0)
	var original := GameStateCodec.to_persistent_dict(state)
	var job := PureIdleSimulationJob.new()
	var begun := job.begin(state, 30)
	check(begun.ok, "pure idle starts only from verified funded normal warp state: " + str(begun))
	if not begun.ok: return
	for step in range(200):
		job.advance(1000000, 600)
		if job.phase == "ready": break
	check(job.phase == "ready" and not job.partial and job.macro_seconds > 0, "three exact calibration windows produce a guarded affine factory bucket: " + str(job.summary()))
	check(GameStateCodec.to_persistent_dict(state) == original, "pure idle candidate never mutates the live source before commit")
	var exact := state.copy_state()
	var engine := SimulationEngine.new(exact)
	engine.offline_replay = true
	var blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	for tick in range(int(round(job.settled_simulation * 60))): engine.update(SimulationEngine.FIXED_DELTA)
	EventBus.set_block_signals(blocked)
	check(absf(float(exact.buildings[machine].output_buffer.get("iron_ingot", 0)) - float(job.candidate.buildings[machine].output_buffer.get("iron_ingot", 0))) < 0.00001 and absf(float(exact.buildings[machine].input_buffer.get("iron_ore", 0)) - float(job.candidate.buildings[machine].input_buffer.get("iron_ore", 0))) < 0.00001, "affine bucket matches exact production and consumed input ownership")
	for id in exact.buildings:
		if exact.buildings[id].has("fuel_remaining"): check(absf(exact.buildings[id].fuel_remaining - job.candidate.buildings[id].fuel_remaining) < 0.00001, "macro warp and generator fuel paid at exact observed rate")
	var blocked_state := state.copy_state()
	blocked_state.buildings[machine].output_buffer_capacity = 35.0
	var bounded := PureIdleSimulationJob.new()
	check(bounded.begin(blocked_state, 30).ok, "bounded factory pure idle accepted")
	for step in range(200):
		bounded.advance(1000000, 600)
		if bounded.phase == "ready": break
	check(bounded.phase == "ready" and bounded.boundary_corrections > 0 and float(bounded.candidate.buildings[machine].output_buffer.get("iron_ingot", 0)) <= 35.000001, "capacity boundary falls back to exact without speculative excess output")
	var original_duration: float = DataManager.all_recipes.iron_ingot_recipe.duration
	DataManager.all_recipes.iron_ingot_recipe.duration = 11.0
	check(not PureIdleSimulationJob.supports_macro(exact), "noncommensurate recipe phase cannot reuse a ten-second macro rate")
	DataManager.all_recipes.iron_ingot_recipe.duration = 45.0
	var long_cycle := PureIdleSimulationJob.new()
	check(long_cycle.begin(state, 12).ok, "long-cycle factory begins conservative settlement")
	for step in range(300):
		long_cycle.advance(100000, 600)
		if long_cycle.phase == "ready": break
	var long_exact := state.copy_state()
	var long_engine := SimulationEngine.new(long_exact)
	long_engine.offline_replay = true
	EventBus.set_block_signals(true)
	for tick in range(int(round(long_cycle.settled_simulation * 60))): long_engine.update(SimulationEngine.FIXED_DELTA)
	EventBus.set_block_signals(blocked)
	check(long_cycle.phase == "ready" and long_cycle.macro_seconds == 0 and long_exact.buildings[machine].output_buffer == long_cycle.candidate.buildings[machine].output_buffer and long_exact.buildings[machine].input_buffer == long_cycle.candidate.buildings[machine].input_buffer and absf(long_exact.buildings[machine].progress - long_cycle.candidate.buildings[machine].progress) < 0.00001, "long recipe crosses its first production boundary exactly instead of extrapolating zero output")
	DataManager.all_recipes.iron_ingot_recipe.duration = original_duration
	blocked_state.paused = true
	check(not PureIdleSimulationJob.new().begin(blocked_state, 30).ok, "paused factory cannot start pure idle")
	blocked_state.paused = false
	blocked_state.save_mode = "speedrun"
	check(not PureIdleSimulationJob.new().begin(blocked_state, 30).ok, "speedrun excludes pure idle approximation")
