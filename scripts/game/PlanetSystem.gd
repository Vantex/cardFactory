class_name PlanetSystem
extends RefCounted

const AMOUNT_EPSILON := 0.0000001
const RESOURCE_SITE_RADIUS := 180.0

var game_state: GameState
var galaxy_system: GalaxySystem

func _init(state: GameState, galaxy: GalaxySystem = null) -> void:
	game_state = state
	galaxy_system = galaxy if galaxy != null else GalaxySystem.new(state)

func initialize_colonized_resource_sites() -> void:
	for planet_id_value in game_state.colonized_planet_ids:
		var planet_id := String(planet_id_value)
		var sites := galaxy_system.build_resource_sites_for_planet(planet_id, game_state.galaxy_seed)
		for site_id in sites:
			if not game_state.resource_sites.has(site_id):
				game_state.resource_sites[site_id] = sites[site_id]

func get_planet(planet_id: String) -> Dictionary:
	return galaxy_system.get_planet(planet_id)

func get_all_planets() -> Dictionary:
	var planets: Dictionary = {}
	for planet_id in galaxy_system.get_all_planet_ids():
		planets[planet_id] = galaxy_system.get_planet(planet_id)
	return planets

func get_planet_name(planet_id: String) -> String:
	return String(get_planet(planet_id).get("name", ""))

func get_planet_resources(planet_id: String) -> Array:
	var items: Array = []
	for site_value in get_planet(planet_id).get("resource_sites", []):
		if site_value is Dictionary:
			items.append(String(site_value.get("item_id", "")))
	return items

func get_planets_in_system(system_id: String) -> Array:
	return galaxy_system.get_system_planets(system_id)

func get_planet_statistics() -> Dictionary:
	var terrestrial := 0
	var gas_giant := 0
	for planet_id in galaxy_system.get_all_planet_ids():
		if String(get_planet(planet_id).get("kind", "")) == "gas_giant":
			gas_giant += 1
		else:
			terrestrial += 1
	return {"total_planets": galaxy_system.get_all_planet_ids().size(), "total_systems": galaxy_system.get_all_system_ids().size(), "terrestrial_count": terrestrial, "gas_giant_count": gas_giant}

func get_planet_buildings(planet_id: String) -> Array:
	var buildings: Array = []
	for building_id in game_state.buildings.keys():
		var building: Dictionary = game_state.buildings[building_id]
		if String(building.get("planet_id", "")) == planet_id:
			buildings.append(building.duplicate(true))
	buildings.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	return buildings

func get_planet_connections(planet_id: String) -> Array:
	var connections: Array = []
	for connection_id in game_state.connections.keys():
		var connection: Dictionary = game_state.connections[connection_id]
		if String(connection.get("planet_id", "")) == planet_id:
			connections.append(connection.duplicate(true))
	connections.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	return connections

func get_planet_resource_sites(planet_id: String) -> Array:
	var sites: Array = []
	for site_id in game_state.resource_sites.keys():
		var site: Dictionary = game_state.resource_sites[site_id]
		if String(site.get("planet_id", "")) == planet_id:
			sites.append(site.duplicate(true))
	sites.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	return sites

func get_colonization_requirements(planet_id: String) -> Dictionary:
	var planet := get_planet(planet_id)
	if planet.is_empty():
		return {}
	var materials: Dictionary = {}
	var vehicles: Dictionary = {}
	for cost_value in planet.get("colonization_cost", []):
		if not cost_value is Dictionary:
			continue
		var item_id := String(cost_value.get("item_id", ""))
		var amount := float(cost_value.get("amount", 0.0))
		if item_id.begins_with("logistics_"):
			vehicles[item_id] = amount
		else:
			materials[item_id] = amount
	return {"planet_id": planet_id, "materials": materials, "vehicles": vehicles, "required_technology_id": String(planet.get("required_technology_id", "")), "system_id": String(planet.get("system_id", ""))}

func try_colonize_planet(planet_id: String) -> Dictionary:
	var planet := get_planet(planet_id)
	if planet.is_empty():
		return _failure("unknown_planet", "目标行星不存在")
	if game_state.colonized_planet_ids.has(planet_id):
		return _failure("already_colonized", "目标行星已殖民")
	var system_id := String(planet.get("system_id", ""))
	if not game_state.explored_system_ids.has(system_id):
		return _failure("system_locked", "目标星系尚未探索")
	var required_technology := String(planet.get("required_technology_id", ""))
	if not required_technology.is_empty() and not game_state.completed_technologies.has(required_technology):
		return _failure("technology_locked", "缺少殖民所需科技")
	var requirements := get_colonization_requirements(planet_id)
	var source_inventory: Dictionary = game_state.planet_inventory.duplicate(true)
	var fleet: Dictionary = game_state.portable_fleet.duplicate(true)
	for vehicle_id_value in requirements["vehicles"]:
		var vehicle_id := String(vehicle_id_value)
		if float(fleet.get(vehicle_id, 0.0)) + AMOUNT_EPSILON < float(requirements["vehicles"][vehicle_id]):
			return _failure("missing_vehicle", "全局物流载具不足", {"item_id": vehicle_id, "required": requirements["vehicles"][vehicle_id]})
	for item_id_value in requirements["materials"]:
		var item_id := String(item_id_value)
		if float(source_inventory.get(item_id, 0.0)) + AMOUNT_EPSILON < float(requirements["materials"][item_id]):
			return _failure("missing_materials", "活动行星材料不足", {"item_id": item_id, "required": requirements["materials"][item_id]})
	for vehicle_id_value in requirements["vehicles"]:
		var vehicle_id := String(vehicle_id_value)
		fleet[vehicle_id] = float(fleet.get(vehicle_id, 0.0)) - float(requirements["vehicles"][vehicle_id])
	for item_id_value in requirements["materials"]:
		var item_id := String(item_id_value)
		var remaining := float(source_inventory.get(item_id, 0.0)) - float(requirements["materials"][item_id])
		if remaining <= AMOUNT_EPSILON:
			source_inventory.erase(item_id)
		else:
			source_inventory[item_id] = remaining
	var sites := galaxy_system.build_resource_sites_for_planet(planet_id, game_state.galaxy_seed)
	game_state.planet_inventories[game_state.active_planet_id] = source_inventory
	game_state.planet_inventory = source_inventory
	game_state.portable_fleet = fleet
	game_state.colonized_planet_ids.append(planet_id)
	game_state.planet_inventories[planet_id] = {}
	game_state.planet_viewports[planet_id] = {"position": Vector2.ZERO, "zoom": Vector2.ONE}
	game_state.planet_metrics[planet_id] = {}
	for site_id in sites:
		game_state.resource_sites[site_id] = sites[site_id]
	return _success("行星殖民完成", {"planet_id": planet_id})

func try_transfer_to_portable_fleet(item_id: String, amount: int) -> Dictionary:
	if not game_state.portable_fleet.has(item_id):
		return _failure("invalid_vehicle", "物品不是可携带物流载具")
	if amount <= 0:
		return _failure("invalid_amount", "载具转入数量必须是正整数")
	var source_inventory := game_state.planet_inventory.duplicate(true)
	if float(source_inventory.get(item_id, 0.0)) + AMOUNT_EPSILON < float(amount):
		return _failure("missing_vehicle_item", "活动行星托盘中的载具不足", {"item_id": item_id, "required": amount})
	var next_fleet := game_state.portable_fleet.duplicate(true)
	var remaining := float(source_inventory.get(item_id, 0.0)) - float(amount)
	if remaining <= AMOUNT_EPSILON:
		source_inventory.erase(item_id)
	else:
		source_inventory[item_id] = remaining
	next_fleet[item_id] = int(next_fleet.get(item_id, 0)) + amount
	game_state.planet_inventories[game_state.active_planet_id] = source_inventory
	game_state.planet_inventory = game_state.planet_inventories[game_state.active_planet_id]
	game_state.portable_fleet = next_fleet
	return _success("物流载具已转入随身编队", {"item_id": item_id, "amount": amount})

func try_set_active_planet(planet_id: String) -> Dictionary:
	if get_planet(planet_id).is_empty():
		return _failure("unknown_planet", "目标行星不存在")
	if not game_state.colonized_planet_ids.has(planet_id):
		return _failure("not_colonized", "目标行星尚未殖民")
	if not game_state.explored_system_ids.has(String(get_planet(planet_id).get("system_id", ""))):
		return _failure("system_locked", "目标星系尚未探索")
	if not game_state.set_active_planet(planet_id):
		return _failure("not_colonized", "目标行星没有可用托盘")
	return _success("已切换活动行星", {"planet_id": planet_id})

func try_bind_extractor(building_id: String, resource_site_id: String) -> Dictionary:
	if not game_state.buildings.has(building_id):
		return _failure("unknown_building", "采集建筑不存在")
	var building: Dictionary = game_state.buildings[building_id]
	var definition := DataManager.get_building(String(building.get("type", "")))
	if String(definition.get("kind", "")) != "extractor":
		return _failure("invalid_extractor", "建筑不是采集器")
	var site: Variant = game_state.resource_sites.get(resource_site_id)
	if not site is Dictionary or String(site.get("planet_id", "")) != String(building.get("planet_id", "")):
		return _failure("invalid_resource_site", "资源点不属于建筑所在行星")
	var output_item := String(building.get("output_item", definition.get("extraction", {}).get("item_id", "")))
	if String(site.get("item_id", "")) != output_item:
		return _failure("resource_mismatch", "资源点物品与采集器不匹配")
	if not bool(site.get("infinite", false)) and float(site.get("remaining", 0.0)) <= AMOUNT_EPSILON:
		return _failure("resource_depleted", "资源点已耗尽")
	building["resource_site_id"] = resource_site_id
	game_state.buildings[building_id] = building
	return _success("采集器已绑定资源点", {"building_id": building_id, "resource_site_id": resource_site_id})

func find_nearest_resource_site(planet_id: String, item_id: String, position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for site in get_planet_resource_sites(planet_id):
		if String(site.get("item_id", "")) != item_id or (not bool(site.get("infinite", false)) and float(site.get("remaining", 0.0)) <= AMOUNT_EPSILON):
			continue
		var distance := position.distance_squared_to(site.get("position", Vector2.ZERO))
		if distance > RESOURCE_SITE_RADIUS * RESOURCE_SITE_RADIUS + AMOUNT_EPSILON:
			continue
		if distance < best_distance - AMOUNT_EPSILON or (is_equal_approx(distance, best_distance) and (best.is_empty() or String(site.get("id", "")) < String(best.get("id", "")))):
			best = site
			best_distance = distance
	return best

func get_planet_industrial_summary(planet_id: String) -> Dictionary:
	var buildings := get_planet_buildings(planet_id)
	return {"planet_id": planet_id, "building_count": buildings.size(), "connection_count": get_planet_connections(planet_id).size(), "resource_site_count": get_planet_resource_sites(planet_id).size(), "inventory": game_state.get_planet_inventory(planet_id).duplicate(true)}

func _success(message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": true, "reason": "", "message": message, "details": details}

func _failure(reason: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message, "details": details}
