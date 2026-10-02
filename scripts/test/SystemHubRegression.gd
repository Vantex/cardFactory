class_name SystemHubRegression
extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("SYSTEM HUB: " + message)

func run() -> int:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-local-hub.json"))
	for row in gold.cases:
		var state := SourceDysonRegression.new().fresh()
		state.emit_canvas_events = false
		state.completed_technologies.append_array(["dsp_quantum_logistics_network", "dsp_orbital_multi_cargo_bus", "dsp_interstellar_logistics"])
		var hub := SystemSpaceStationSystem.empty_station("helios")
		hub.status = "building"
		hub.cost_revision = 1
		for requirement in SystemSpaceStationSystem.requirements(10000):
			if DecimalCount.compare(requirement.required, hub.construction_buffer.get(requirement.item_id, "0")) > 0: hub.construction_buffer[requirement.item_id] = requirement.required
		SystemSpaceStationSystem.apply_buffer(hub)
		hub.inventory.iron_ingot = "5"
		state.system_space_stations.helios = hub
		var ids := []
		for index in range(2):
			var id := state.add_building({"type": SystemHubLogisticsSystem.STATION_TYPE, "position": Vector2(1800 + index * 400, 1000), "station": StationSystem.empty_station(SystemHubLogisticsSystem.STATION_TYPE), "input_buffer": {"iron_ingot": 200.0}, "output_buffer": {}, "power_efficiency": 1.0 if index == 0 else float(row.power)})
			ids.append(id)
			check(QuantumLogisticsSystem.new(state).upgrade_station(id).ok, "real Mk.II upgrade")
		var model := SystemHubLogisticsSystem.new(state)
		state.logistics_routes.test_route = {"source_id": ids[0], "target_id": ids[1]}
		for id in ids: check(model.request_mode(id, "elevator").ok, "queue mode transition")
		model.update()
		check(state.buildings[ids[0]].station.has("mode_transition"), "related route blocks mode transition")
		state.logistics_routes.clear()
		state.elapsed_time = 4.0
		model.update()
		for id in ids:
			check(SystemHubLogisticsSystem.is_elevator(state.buildings[id]), "transition completes after routes settle")
			check(model.set_output(id, 0, "iron_ingot", 2).ok, "five-output command")
			check(not model.set_output(id, 1, "iron_ingot", 2).ok, "duplicate output items rejected")
		var before := GameStateCodec.to_persistent_dict(state)
		check(not model.set_output(ids[0], 0, "copper_ingot", 1).ok and GameStateCodec.to_persistent_dict(state) == before, "one confirmation cannot change ports")
		hub = state.system_space_stations.helios
		state.elapsed_time = 5.0
		model.update()
		check(hub.inventory == row.inventory, "frozen powered shared inventory")
		for index in range(2):
			check(state.buildings[ids[index]].input_buffer == row.stations[index].inputs and state.buildings[ids[index]].output_buffer == row.stations[index].outputs, "frozen proportionate local outputs")
		check(JSON.parse_string(JSON.stringify(hub.routing_cursors)) == row.cursors, "frozen persistent remainder cursor")
		before = GameStateCodec.to_persistent_dict(state)
		model.update()
		check(GameStateCodec.to_persistent_dict(state) == before, "same five-second boundary cannot settle twice")
		var save := SaveSystem.new("res://.godot/task26-system-hub")
		var saved := save.save_slot(0, state)
		check(saved.ok, "elevator disk save: " + str(saved))
		var loaded := save.load_slot(0)
		check(loaded.ok, "elevator disk load")
		if loaded.ok:
			var restored_before := GameStateCodec.to_persistent_dict(loaded.state)
			SystemHubLogisticsSystem.new(loaded.state).update()
			check(GameStateCodec.to_persistent_dict(loaded.state) == restored_before, "disk reload cannot replay settled boundary")
		var consumer := state.add_building({"type": "assembling_machine_mk1", "position": Vector2(3000, 1000), "recipe_id": "gear_recipe", "input_buffer": {}, "output_buffer": {}})
		state.construction_inventory.conveyor_belt_mk1 = 1.0
		var belt := state.try_add_connection(ids[0], consumer, "iron_ingot")
		check(belt.ok, "real elevator output belt")
		if belt.ok:
			state.construction_inventory.conveyor_belt_mk1 = GameState.construction_capacity("conveyor_belt_mk1")
			before = GameStateCodec.to_persistent_dict(state)
			check(not model.set_output(ids[0], 0, "copper_ingot", 2).ok and GameStateCodec.to_persistent_dict(state) == before, "full refund inventory rejects output change atomically")
			state.construction_inventory.conveyor_belt_mk1 -= 1
			var stock: Dictionary = state.buildings[ids[0]].output_buffer.duplicate(true)
			check(model.set_output(ids[0], 0, "copper_ingot", 2).ok and not state.connections.has(belt.id) and state.buildings[ids[0]].output_buffer == stock, "confirmed port change refunds belt without deleting retained output stock")
	check(SystemHubLogisticsSystem.multiply_divide(10000000000000, 99999999, 100000001) == 9999999800000, "allocation multiplication cannot overflow int64 intermediates")
	_test_cross()
	return failures
func _test_cross() -> void:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity/behavior/task26-cross-hub.json"))
	for row in gold.allocations:
		var allocation := SystemHubLogisticsSystem.allocate_decimal(int(row.budget), row.requests)
		for key in row.expected.allocations: check(str(allocation[key]) == row.expected.allocations[key], "frozen 256-digit proportional allocation")
	for row in gold.cases:
		var state := SourceDysonRegression.new().fresh()
		state.emit_canvas_events = false
		state.colonized_planet_ids.append("frost")
		state.planet_inventories["frost"] = {}
		state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
		state.completed_technologies.append_array(["dsp_quantum_logistics_network", "dsp_orbital_multi_cargo_bus", "dsp_unified_system_logistics_protocol", "dsp_interstellar_logistics"])
		var ids := []
		var model := SystemHubLogisticsSystem.new(state)
		for index in range(2):
			var system_id := "helios" if index == 0 else "borealis"
			var planet_id := "home" if index == 0 else "frost"
			var hub := SystemSpaceStationSystem.empty_station(system_id)
			hub.cost_revision = 1
			hub.status = "building"
			for requirement in SystemSpaceStationSystem.requirements(10000):
				if DecimalCount.compare(requirement.required, hub.construction_buffer.get(requirement.item_id, "0")) > 0: hub.construction_buffer[requirement.item_id] = requirement.required
			SystemSpaceStationSystem.apply_buffer(hub)
			state.system_space_stations[system_id] = hub
			state.set_active_planet(planet_id)
			var id := state.add_building({"type": SystemHubLogisticsSystem.STATION_TYPE, "planet_id": planet_id, "position": Vector2(1600, 1200), "station": StationSystem.empty_station(SystemHubLogisticsSystem.STATION_TYPE), "input_buffer": {}, "output_buffer": {}, "power_efficiency": 1.0 if index == 0 else float(row.power)})
			ids.append(id)
			check(QuantumLogisticsSystem.new(state).upgrade_station(id).ok and model.request_mode(id, "elevator").ok, "cross-system real elevator setup")
		state.set_active_planet("home")
		model.update()
		state.portable_fleet.logistics_vessel = 2
		check(StationSystem.new(state).set_fleet_target(ids[0], "logistics_vessel", 2).ok, "cross-system fleet funded from portable ownership")
		state.planet_inventory.space_warper = 4.0
		check(model.load_warpers(4).ok and state.planet_inventory.get("space_warper", 0) == 0, "warp inventory is paid")
		state.system_space_stations.helios.inventory.iron_ingot = "1000"
		check(model.set_policy("helios", "iron_ingot", "100", "0", true).ok and model.set_policy("borealis", "iron_ingot", "0", row.targetAmount, true).ok, "actual cross-system reserve and demand policy")
		if float(row.power) == 1.0:
			var multi := state.copy_state()
			multi.system_space_stations.helios.inventory.copper_ingot = "1000"
			var multi_model := SystemHubLogisticsSystem.new(multi)
			multi_model.set_policy("helios", "copper_ingot", "100", "0", true)
			multi_model.set_policy("borealis", "copper_ingot", "0", "200", true)
			multi.elapsed_time = 5.0
			multi_model.update()
			var received: Dictionary = multi.system_space_stations.borealis.inventory
			check(int(received.get("iron_ingot", "0")) + int(received.get("copper_ingot", "0")) == 200 and multi.galactic_hub_network.fleet_busy == 2 and multi.galactic_hub_network.warpers == "0", "multiple materials share fleet and warper budget without overdraw")
		state.elapsed_time = 5.0
		model.update()
		check(state.system_space_stations.helios.inventory == row.inventories[0] and state.system_space_stations.borealis.inventory == row.inventories[1], "frozen cross-system cargo settlement")
		var network: Dictionary = state.galactic_hub_network
		check(network.fleet_busy == row.network.fleetBusy and network.warpers == row.network.warpers and network.fleet_installed == row.network.fleetInstalled, "frozen vessel and warper economics")
		for index in range(network.fleet_returns.size()):
			check(network.fleet_returns[index].route_key == row.network.fleetReturns[index].routeKey and network.fleet_returns[index].return_at_second == row.network.fleetReturns[index].returnAtSecond, "frozen route-dependent return duration")
		var save := SaveSystem.new("res://.godot/task26-cross-system-hub")
		var saved := save.save_slot(0, state)
		check(saved.ok, "cross-system disk save: " + str(saved))
		var loaded := save.load_slot(0)
		check(loaded.ok, "cross-system disk read")
		if network.fleet_busy > 0:
			var before := GameStateCodec.to_persistent_dict(state)
			check(not state.remove_building(ids[0]).ok and GameStateCodec.to_persistent_dict(state) == before, "busy aggregate fleet blocks demolition")
			StationSystem.new(state).set_fleet_target(ids[0], "logistics_vessel", 0)
			check(int(state.portable_fleet.logistics_vessel) + int(network.fleet_busy) == 2, "cannot unload busy vessels into portable fleet")
			check(model.request_mode(ids[0], "legacy").ok, "queue return to legacy mode")
			var return_at := int(network.fleet_returns[0].return_at_second)
			state.elapsed_time = ceilf(float(return_at) / 5.0) * 5.0
			model.update()
			model.update()
			check(network.fleet_busy == 0 and network.fleet_returns.is_empty() and not SystemHubLogisticsSystem.is_elevator(state.buildings[ids[0]]) and int(state.buildings[ids[0]].station.fleet.logistics_vessel) + int(state.portable_fleet.logistics_vessel) == 2, "return buckets restore exact owner before mode switch")
			var bad := GameStateCodec.to_persistent_dict(loaded.state) if loaded.ok else {}
			if not bad.is_empty():
				bad.galactic_hub_network.fleet_returns[0].vessel_count += 1
				check(GameStateCodec.from_persistent_dict(bad) == null, "tampered aggregate fleet ownership rejected")
