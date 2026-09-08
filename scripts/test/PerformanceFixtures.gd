class_name PerformanceFixtures
extends RefCounted

const SCALES := {"small": 32, "medium": 256, "large": 1024}

static func create_factory(scale: String) -> GameState:
	var state := GameState.new()
	for index in range(int(SCALES[scale])):
		var id := "fixture_%04d" % index
		var kind := "planetary_logistics_station" if index % 16 == 15 else "solar_panel" if index % 4 == 0 else "smelter" if index % 4 == 2 else "storage"
		state.buildings[id] = {"id": id, "type": kind, "planet_id": "home", "position": Vector2((index % 32) * 280 - 560, (index / 32) * 190 - 380), "status": "idle", "recipe_id": "iron_ingot_recipe" if kind == "smelter" else "", "progress": 0.0, "speed": 1.0, "input_buffer": {"iron_ore": 50.0} if kind == "smelter" else {}, "output_buffer": {"iron_ore": 50.0} if kind == "storage" else {}}
		if kind == "planetary_logistics_station":
			var station := StationSystem.empty_station()
			var supply := index % 32 == 15
			station.slots[0].merge({"item_id": "iron_ore", "mode": "supply" if supply else "demand", "amount": 50.0 if supply else 0.0}, true)
			station.fleet.logistics_drone = 1
			state.buildings[id]["station"] = station
			state.buildings[id]["input_buffer"] = {}
			state.buildings[id]["output_buffer"] = {}
		if index % 4 == 2:
			state.add_connection({"source_id": "fixture_%04d" % (index - 1), "target_id": id, "planet_id": "home", "item_id": "iron_ore", "flow_rate": 10.0})
	state._next_id = int(SCALES[scale]) + 1
	return state
