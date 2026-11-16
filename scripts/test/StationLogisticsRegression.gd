extends Node

var failures := 0

func run() -> int:
	var state := GameState.new()
	state.completed_technologies = ["interstellar_logistics"]
	state.planet_inventory = {"iron_ore": 100.0, "logistics_drone": 2.0}
	var a := _station(state, Vector2.ZERO)
	var b := _station(state, Vector2(300, 0))
	var stations := StationSystem.new(state)
	_expect(stations.configure_slots([a], 0, "iron_ore", "supply", 100, 0.1, 1).ok, "configure supply")
	_expect(stations.configure_slots([b], 0, "iron_ore", "demand", 100, 0.1, 1).ok, "configure demand")
	_expect(stations.transfer_cargo(a, 0, 40, true).ok, "load real cargo")
	_expect(stations.transfer_fleet(a, "logistics_drone", 1, true).ok, "install real vehicle")
	var before := GameStateCodec.to_persistent_dict(state)
	_expect(not stations.configure_slots([a, "missing"], 0, "copper_ore", "supply", 100, 0.1, 1).ok, "batch rejects invalid peer")
	_expect(GameStateCodec.to_persistent_dict(state) == before, "failed configuration is atomic")
	var logistics := LogisticsSystem.new(state)
	logistics.update(1.0 / 60.0)
	_expect(state.logistics_routes.size() == 1, "dispatch owns a unique vehicle")
	_expect(state.buildings[a].station.fleet.logistics_drone == 0, "dispatched vehicle leaves hangar")
	_expect(not state.remove_building(a).ok, "cannot delete route owner")
	var restored := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
	_expect(restored != null, "in-flight save is valid")
	if restored != null:
		_expect(GameStateCodec.to_persistent_dict(restored) == GameStateCodec.to_persistent_dict(state), "save preserves cargo and ownership")
	state.buildings[b].power_efficiency = 0.0
	for i in range(600):
		logistics.update(1.0 / 60.0)
	_expect(state.buildings[b].station.slots[0].amount == 0, "unpowered destination cannot unload")
	_expect(_cargo(state) == 100, "waiting conserves cargo")
	state.buildings[b].power_efficiency = 1.0
	for i in range(1200):
		logistics.update(1.0 / 60.0)
	_expect(state.buildings[b].station.slots[0].amount == 40, "all cargo arrives")
	_expect(state.logistics_routes.is_empty() and state.buildings[a].station.fleet.logistics_drone == 1, "vehicle returns exactly once")
	_expect(_cargo(state) == 100, "whole journey conserves cargo")
	_test_crafting_reachability()
	_test_fixed_ticks()
	_test_failures_and_belts()
	await _test_ui()
	_test_interstellar()
	_test_scale_and_fairness()
	_test_connection_refresh()
	return failures

func _test_connection_refresh() -> void:
	var state := GameState.new()
	var source := _station(state, Vector2.ZERO)
	var target := state.add_building({"type": "smelter", "recipe_id": "iron_ingot_recipe"})
	var slot: Dictionary = state.buildings[source].station.slots[0]
	slot.merge({"item_id": "iron_ore", "mode": "storage", "amount": 10.0}, true)
	var logistics := LogisticsSystem.new(state)
	logistics.update(1.0 / 60.0)
	_expect(slot.amount == 10 and state.buildings[source].output_buffer.is_empty(), "unconnected station retains slot cargo")
	var connection := state.add_connection({"source_id": source, "target_id": target, "item_id": "iron_ore", "flow_rate": 10.0})
	logistics.update(1.0 / 60.0)
	_expect(slot.amount == 0 and state.buildings[source].output_buffer.iron_ore == 10, "next logistics update sees newly added outgoing connection")
	state.buildings[source].output_buffer.clear()
	slot.amount = 10.0
	state.connections[connection].enabled = false
	logistics.update(1.0 / 60.0)
	_expect(slot.amount == 10 and state.buildings[source].output_buffer.is_empty(), "disabled connection cannot withdraw station cargo")
	state.connections[connection].enabled = true
	logistics.update(1.0 / 60.0)
	_expect(slot.amount == 0 and state.buildings[source].output_buffer.iron_ore == 10, "reenabled connection resumes slot withdrawal")
	state.buildings[source].output_buffer.clear()
	slot.amount = 10.0
	state.connections.erase(connection)
	logistics.update(1.0 / 60.0)
	_expect(slot.amount == 10 and state.buildings[source].output_buffer.is_empty(), "removed connection is absent from next logistics update")

func _station(state: GameState, position: Vector2) -> String:
	state.construction_inventory["planetary_logistics_station"] = 1.0
	var result := state.try_place_building("planetary_logistics_station", position)
	if not result.ok:
		_expect(false, "station placement is reachable")
		return ""
	state.buildings[result.id].power_efficiency = 1.0
	return result.id

func _cargo(state: GameState) -> float:
	var total := float(state.planet_inventory.get("iron_ore", 0))
	for building in state.buildings.values():
		for slot in building.get("station", {}).get("slots", []):
			if slot.item_id == "iron_ore":
				total += float(slot.amount)
	for route in state.logistics_routes.values():
		if route.item_id == "iron_ore":
			total += float(route.amount)
	return total

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("STATION: " + message)


func _test_interstellar() -> void:
	var state := GameState.new()
	state.completed_technologies = ["factory_foundations", "fluid_handling", "advanced_materials", "interstellar_logistics"]
	state.planet_inventory = {"space_warper": 2.0, "logistics_vessel": 1.0, "iron_ore": 40.0}
	state.colonized_planet_ids.append("frost")
	state.explored_system_ids.append("borealis")
	state.survey_progress_by_system["borealis"] = 1.0
	state.planet_inventories["frost"] = {}
	state.planet_viewports["frost"] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	var a := _interstellar_station(state)
	state.set_active_planet("frost")
	var b := _interstellar_station(state)
	var stations := StationSystem.new(state)
	_expect(stations.configure_slots([b], 0, "iron_ore", "demand", 100, 0.1, 0).ok, "configure remote demand")
	state.set_active_planet("home")
	stations.configure_slots([a], 0, "iron_ore", "supply", 100, 0.1, 0)
	stations.transfer_fleet(a, "logistics_vessel", 1, true)
	stations.transfer_cargo(a, 0, 40, true)
	var logistics := LogisticsSystem.new(state)
	logistics.update(1.0 / 60)
	_expect(state.logistics_routes.is_empty(), "cross-system flight requires warpers")
	stations.transfer_fleet(a, "space_warper", 2, true)
	state.completed_technologies.erase("interstellar_logistics")
	logistics.update(1.0 / 60)
	_expect(state.logistics_routes.is_empty(), "cross-planet flight requires technology")
	state.completed_technologies.append("interstellar_logistics")
	logistics.update(1.0 / 60)
	_expect(state.logistics_routes.size() == 1 and state.buildings[a].station.fleet.space_warper == 0, "departure consumes exactly two warpers")
	if state.logistics_routes.is_empty():
		return
	var payload := GameStateCodec.to_persistent_dict(state)
	_expect(GameStateValidator.validate_persistent_dict(payload).is_empty(), "cross-system in-flight payload validates")
	var save_system := SaveSystem.new("res://.godot/task13-saves")
	var saved := save_system.save_slot(1, state)
	_expect(saved.ok, "real save verifies in-flight ownership on disk: " + str(saved))
	var loaded := save_system.load_slot(1)
	_expect(loaded.ok, "real save loads in-flight ownership: " + str(loaded.get("error", {})))
	var restored: GameState = loaded.get("state")
	_expect(restored != null, "JSON in-flight round trip")
	if restored == null:
		return
	for building in restored.buildings.values():
		building.power_efficiency = 1.0
	var resumed := LogisticsSystem.new(restored)
	for i in range(10000):
		logistics.update(1.0 / 60)
		resumed.update(1.0 / 60)
	_expect(GameStateCodec.to_persistent_dict(state) == GameStateCodec.to_persistent_dict(restored), "resume matches uninterrupted voyage")
	_expect(state.interplanetary_delivered == 40 and state.logistics_routes.is_empty(), "interplanetary delivery and return complete")
	ProgressionSystem.new(state).evaluate()
	_expect(state.completed_objective_ids.has("first_interplanetary_delivery"), "real delivery completes formal campaign objective")
	var mutations := [
		["amount", -1], ["amount", "20"], ["amount", 101], ["vehicle", "logistics_drone"],
		["remaining", -1], ["remaining", 100000], ["source_slot", 4], ["phase", "returning"], ["target_id", "missing"], ["interplanetary", false]
	]
	var route_id: String = payload.logistics_routes.keys()[0]
	for mutation in mutations:
		var bad := payload.duplicate(true)
		bad.logistics_routes[route_id][mutation[0]] = mutation[1]
		_expect(GameStateCodec.from_persistent_dict(bad) == null, "reject corrupt route " + str(mutation[0]))
	var old := payload.duplicate(true)
	old.schema_version = 6
	old.erase("logistics_routes")
	old.erase("interplanetary_delivered")
	for building in old.buildings.values():
		building.erase("station")
		building.erase("input_buffer")
		building.erase("output_buffer")
	var migrated := GameStateCodec.from_persistent_dict(old)
	_expect(migrated != null and migrated.logistics_routes.is_empty() and migrated.buildings[a].station.fleet.logistics_vessel == 0, "v6 migration adds empty stations without gifts")

func _interstellar_station(state: GameState) -> String:
	state.construction_inventory["interstellar_logistics_station"] = 1.0
	var result := state.try_place_building("interstellar_logistics_station", Vector2.ZERO)
	_expect(result.ok, "build real interstellar station")
	state.buildings[result.id].power_efficiency = 1.0
	return result.id

func _test_scale_and_fairness() -> void:
	for count in [10, 50, 100]:
		var state := GameState.new()
		var ids: Array = []
		for i in range(count):
			var id := _station(state, Vector2(i * 300, 0))
			ids.append(id)
			var slot: Dictionary = state.buildings[id].station.slots[0]
			slot.item_id = "iron_ore"
			slot.mode = "supply" if i < count / 2 else "demand"
			slot.amount = 80.0 if i < count / 2 else 0.0
			state.buildings[id].station.fleet.logistics_drone = 2
		var duplicate := GameStateCodec.from_persistent_dict(GameStateCodec.to_persistent_dict(state))
		_expect(duplicate != null, "scale fixture validates")
		if duplicate == null:
			continue
		for building in duplicate.buildings.values():
			building.power_efficiency = 1.0
		# Reverse insertion order proves dispatch does not depend on dictionary history.
		var reversed := {}
		var reverse_ids := duplicate.buildings.keys()
		reverse_ids.reverse()
		for id in reverse_ids:
			reversed[id] = duplicate.buildings[id]
		duplicate.buildings = reversed
		var first := LogisticsSystem.new(state)
		var second := LogisticsSystem.new(duplicate)
		var start := Time.get_ticks_usec()
		for tick in range(600):
			first.update(1.0 / 60)
			second.update(1.0 / 60)
		_expect(GameStateCodec.to_persistent_dict(state) == GameStateCodec.to_persistent_dict(duplicate), "%d stations deterministic across insertion orders" % count)
		_expect(is_equal_approx(_cargo(state), float(count / 2) * 80), "%d stations conserve cargo" % count)
		print("LOGISTICS SCALE %d stations / 600 ticks x 2: %.1f ms" % [count, (Time.get_ticks_usec() - start) / 1000.0])
	var fair := GameState.new()
	var a := _station(fair, Vector2.ZERO)
	var b := _station(fair, Vector2(300, 0))
	var c := _station(fair, Vector2(600, 0))
	for id in [a, b, c]:
		var slot: Dictionary = fair.buildings[id].station.slots[0]
		slot.item_id = "iron_ore"
		slot.mode = "demand" if id == c else "supply"
		slot.amount = 0.0 if id == c else 80.0
		fair.buildings[id].station.fleet.logistics_drone = 2
	var engine := LogisticsSystem.new(fair)
	engine.update(1.0 / 60)
	engine.update(1.0 / 60)
	_expect(fair.buildings[a].station.slots[0].amount == 60 and fair.buildings[b].station.slots[0].amount == 60, "fair cursor alternates equivalent suppliers")
	fair.buildings[b].station.slots[0].priority = 2
	engine.update(1.0 / 60)
	_expect(fair.buildings[b].station.slots[0].amount == 40 and fair.buildings[a].station.slots[0].amount == 60, "higher priority supply wins before fair rotation")




func _test_failures_and_belts() -> void:
	var state := GameState.new()
	state.planet_inventory = {"iron_ore": 40.0, "logistics_drone": 1.0}
	var a := _station(state, Vector2.ZERO)
	var b := _station(state, Vector2(300, 0))
	var stations := StationSystem.new(state)
	stations.configure_slots([a], 0, "iron_ore", "supply", 100, 0.1, 0)
	stations.configure_slots([b], 0, "iron_ore", "demand", 20, 0.1, 0)
	stations.transfer_cargo(a, 0, 40, true)
	stations.transfer_fleet(a, "logistics_drone", 1, true)
	var before := GameStateCodec.to_persistent_dict(state)
	_expect(not stations.transfer_cargo(a, 0, 100, false).ok, "cannot withdraw missing cargo")
	_expect(not stations.transfer_fleet(a, "logistics_drone", 2, false).ok, "cannot withdraw missing vehicles")
	_expect(not stations.configure_slots([a], 0, "iron_ore", "supply", 100, NAN, 0).ok, "configuration rejects NaN")
	_expect(GameStateCodec.to_persistent_dict(state) == before, "failed transfers preserve full state")
	var logistics := LogisticsSystem.new(state)
	state.buildings[a].power_efficiency = 0
	logistics.update(1.0 / 60)
	_expect(state.logistics_routes.is_empty(), "unpowered supplier cannot dispatch")
	state.buildings[a].power_efficiency = 1
	logistics.update(1.0 / 60)
	state.planet_inventory["iron_ore"] = 1.0
	_expect(not stations.transfer_cargo(b, 0, 1, true).ok, "in-flight reservation blocks overfilling")
	_expect(not stations.configure_slots([b], 0, "copper_ore", "demand", 100, 0.1, 0).ok, "route locks target configuration")
	# A valid capacity change in a future subsystem must leave arrivals waiting, never discard cargo.
	stations.set_enabled([a], false)
	state.buildings[b].station.slots[0].capacity = 10.0
	for tick in range(180):
		logistics.update(1.0 / 60)
	_expect(state.logistics_routes.size() == 1 and state.buildings[b].station.slots[0].amount == 0, "full target retains in-flight cargo")
	state.buildings[b].station.slots[0].capacity = 20.0
	for tick in range(180):
		logistics.update(1.0 / 60)
	_expect(state.buildings[b].station.slots[0].amount == 20 and state.logistics_routes.is_empty(), "stopped station still unloads and returns existing flight")
	var smelter := state.add_building({"type": "smelter", "position": Vector2(600, 0), "recipe_id": "iron_ingot_recipe", "input_buffer": {}, "output_buffer": {}, "power_efficiency": 1.0})
	var connection := state.try_add_connection(b, smelter)
	_expect(connection.ok, "station output connects to production")
	for tick in range(240):
		logistics.update(1.0 / 60)
		BeltSystem.new(state).update(1.0 / 60)
	_expect(float(state.buildings[smelter].input_buffer.get("iron_ore", 0)) > 19.9, "station cargo feeds a real belt")
	var extractor := state.add_building({"type": "miner", "position": Vector2(-300, 0), "output_item": "iron_ore", "input_buffer": {}, "output_buffer": {"iron_ore": 10.0}, "power_efficiency": 1.0})
	_expect(state.try_add_connection(extractor, a).ok, "production output connects to configured station")
	for tick in range(120):
		BeltSystem.new(state).update(1.0 / 60)
		logistics.update(1.0 / 60)
	_expect(float(state.buildings[extractor].output_buffer.get("iron_ore", 0)) < 0.01, "real belt feeds station supply")

func _test_ui() -> void:
	var state := GameState.new()
	state.planet_inventory = {"iron_ore": 30.0, "logistics_drone": 1.0}
	var id := _station(state, Vector2.ZERO)
	GameManager.replace_game_state(state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child(viewport)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	var workspace: Node = main.get_node("FactoryWorkspaceUI")
	main.get_node("InputHandler").set_selected_entities([id])
	workspace.refresh_now()
	var list: Node = workspace.get_node("InspectorPanel/RecipeScroll/RecipeList")
	var configure: Button = null
	for child in list.get_children():
		if child is Button and child.text == "配置物流站":
			configure = child
	_expect(configure != null, "formal inspector exposes station configuration")
	if configure != null:
		configure.pressed.emit()
	var panel: Control = workspace.get_node("StationPanel")
	_expect(panel.visible, "real configure button opens logistics workspace")
	await get_tree().process_frame
	_expect(workspace.is_pointer_over_ui(panel.get_global_rect().get_center()), "logistics workspace consumes canvas pointer input")
	for i in range(panel.item_choice.item_count):
		if panel.item_choice.get_item_metadata(i) == "iron_ore":
			panel.item_choice.select(i)
	panel.mode_choice.select(0)
	panel.call("_apply")
	panel.quantity.value = 20
	panel.call("_cargo", true)
	panel.quantity.value = 1
	panel.call("_fleet", true)
	_expect(state.buildings[id].station.slots[0].amount == 20 and state.buildings[id].station.fleet.logistics_drone == 1, "formal controls transfer real cargo and vehicles")
	state.interplanetary_delivered = 20
	EventBus.logistics_delivered.emit()
	await get_tree().process_frame
	_expect(state.completed_objective_ids.has("first_interplanetary_delivery"), "delivery event advances the formal campaign")
	workspace.show_exclusive_workspace("TechnologyPanel")
	_expect(not panel.visible, "logistics is mutually exclusive with technology workspace")
	GameManager.replace_game_state(GameState.new())
	_expect(not panel.visible, "state replacement closes stale logistics configuration")
	viewport.queue_free()
	await get_tree().process_frame



func _test_fixed_ticks() -> void:
	var state := GameState.new()
	var a := _station(state, Vector2.ZERO)
	var b := _station(state, Vector2(300, 0))
	for id in [a, b]:
		var slot: Dictionary = state.buildings[id].station.slots[0]
		slot.item_id = "iron_ore"
		slot.mode = "supply" if id == a else "demand"
		slot.amount = 40.0 if id == a else 0.0
	state.buildings[a].station.fleet.logistics_drone = 1
	state.add_building({"type": "power_generator", "position": Vector2(600, 0), "input_buffer": {}, "output_buffer": {}, "fuel_item": "coal", "fuel_remaining": 300.0})
	var copy := state.copy_state()
	var fine := SimulationEngine.new(state)
	var coarse := SimulationEngine.new(copy)
	state.paused = true
	var before := GameStateCodec.to_persistent_dict(state)
	fine.update(10)
	_expect(GameStateCodec.to_persistent_dict(state) == before, "paused simulation cannot dispatch or advance logistics")
	state.paused = false
	for tick in range(600):
		fine.update(1.0 / 60)
	for frame in range(100):
		coarse.update(0.1)
	_expect(GameStateCodec.to_persistent_dict(state) == GameStateCodec.to_persistent_dict(copy), "real engine logistics is frame-partition independent")
	_expect(state.buildings[b].station.slots[0].amount == 40, "real powered engine delivers all cargo")



func _test_crafting_reachability() -> void:
	var state := GameState.new()
	state.planet_inventory = {"iron_ingot": 8.0, "processor": 8.0, "gear": 8.0, "titanium_alloy": 10.0, "matrix_science_1": 2.0}
	state.sync_active_planet_inventory()
	var crafting := HandcraftSystem.new(state)
	for recipe in ["handcraft_planetary_station", "handcraft_interstellar_station", "handcraft_space_warper"]:
		_expect(crafting.queue_craft(recipe, 1).ok, "reachable logistics handcraft " + recipe)
	crafting.update(30)
	_expect(state.construction_inventory.get("planetary_logistics_station", 0) == 1 and state.construction_inventory.get("interstellar_logistics_station", 0) == 1 and state.planet_inventory.get("space_warper", 0) == 1, "real queue delivers station kits and warper")
	_expect(not state.try_place_building("interstellar_logistics_station", Vector2.ZERO).ok and state.construction_inventory.interstellar_logistics_station == 1, "locked station placement does not spend its kit")
