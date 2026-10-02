class_name SystemSpaceStationSystem
extends RefCounted

const TYPE := "dsp_space_station_construction_launcher"
const PHASES := [
	["轨道基座", "titanium_alloy", 1000000], ["轨道基座", "frame_material", 500000], ["轨道基座", "small_carrier_rocket", 100000], ["轨道基座", "universe_matrix", 100000],
	["主体框架", "frame_material", 2000000], ["主体框架", "dyson_sphere_component", 1000000], ["主体框架", "titanium_glass", 1000000], ["主体框架", "quantum_chip", 500000],
	["能源核心", "antimatter_fuel_rod", 250000], ["能源核心", "annihilation_constraint_sphere", 500000], ["能源核心", "strange_matter", 1000000], ["能源核心", "plane_filter", 1000000],
	["调度核心", "processor", 5000000], ["调度核心", "particle_broadband", 2000000], ["调度核心", "quantum_chip", 2000000], ["调度核心", "universe_matrix", 1000000]
]
const MODULE_COSTS := {
	"backbone": {"frame_material": "100000", "quantum_chip": "50000", "processor": "100000", "universe_matrix": "10000"},
	"energy": {"antimatter_fuel_rod": "50000", "annihilation_constraint_sphere": "50000", "strange_matter": "100000", "quantum_chip": "50000"},
	"interstellar": {"titanium_alloy": "100000", "frame_material": "50000", "particle_container": "100000", "space_warper": "10000"}
}
var state: GameState
func _init(value: GameState) -> void: state = value

static func empty_station(system_id: String) -> Dictionary:
	return {"system_id": system_id, "status": "not-started", "cost_revision": 0, "cost_multiplier_basis_points": 10000, "phase_index": 0, "delivered": {}, "construction_buffer": {}, "inventory": {}, "item_policies": {}, "modules": {"backbone": 0, "energy": 0, "interstellar": 0}, "routing_cursors": {}, "viewport": {"x": 0.0, "y": 0.0, "zoom": 0.85}, "decorations": []}

func snapshot(system_id: String) -> Dictionary:
	return state.system_space_stations.get(system_id, empty_station(system_id)).duplicate(true)

func cost_multiplier() -> int:
	if SourceTechnologyEffects.completed(state, "autonomous_station_construction"): return 8000
	return 9000 if SourceTechnologyEffects.completed(state, "orbital_modular_assembly") else 10000

static func requirements(basis_points: int) -> Array:
	var rows := []
	for index in range(PHASES.size()):
		var phase: Array = PHASES[index]
		rows.append({"phase_index": index, "name": phase[0], "item_id": phase[1], "required": str(int(ceilf(float(phase[2]) * basis_points / 10000.0)))})
	return rows

func planet_system(planet_id: String) -> String:
	return String(GalaxySystem.new(state).get_planet(planet_id).get("system_id", ""))

func has_platform(planet_id: String) -> bool:
	return state.buildings.values().any(func(building): return building.get("type") == TYPE and building.get("planet_id") == planet_id)

func start(system_id: String) -> Dictionary:
	if not state.explored_system_ids.has(system_id) or GalaxySystem.new(state).get_star_system(system_id).is_empty() or not SourceTechnologyEffects.completed(state, "system_space_station_engineering"): return result(false, "需要已探索恒星系和空间站工程科技")
	if snapshot(system_id).status != "not-started": return result(false, "该恒星系空间站已开工")
	if not state.buildings.values().any(func(building): return building.get("type") == TYPE and planet_system(building.planet_id) == system_id): return result(false, "本恒星系需要至少一座施工发射平台")
	var station := empty_station(system_id)
	station.status = "building"
	station.cost_revision = 1
	station.cost_multiplier_basis_points = cost_multiplier()
	state.system_space_stations[system_id] = station
	return result(true, "空间站已开工，建设折扣已锁定")

func deliver(system_id: String, item: String, requested: int) -> Dictionary:
	var station: Dictionary = state.system_space_stations.get(system_id, {})
	if station.get("status") != "building" or requested < 1 or requested > 999 or planet_system(state.active_planet_id) != system_id: return result(false, "只能从本恒星系当前行星托盘向在建空间站交付")
	var remaining := 0
	for row in requirements(int(station.cost_multiplier_basis_points)):
		if row.item_id == item and int(row.phase_index) >= int(station.phase_index):
			remaining = int(HubInteger.subtract(row.required, station.delivered.get(item, "0")))
			break
	var amount := mini(requested, mini(remaining, int(floorf(float(state.planet_inventory.get(item, 0))))))
	if amount <= 0: return result(false, "没有可交付的材料或所选材料不再需要")
	var paid := InventorySystem.new(state).try_remove(item, amount)
	if not paid.ok: return paid
	station.construction_buffer[item] = HubInteger.add(station.construction_buffer.get(item, "0"), str(amount))
	apply_buffer(station)
	return result(true, "已交付 %d 件材料" % amount)

static func apply_buffer(station: Dictionary) -> void:
	var rows := requirements(int(station.cost_multiplier_basis_points))
	while int(station.phase_index) < rows.size():
		var complete := true
		for index in range(int(station.phase_index), int(station.phase_index) + 4):
			var row: Dictionary = rows[index]
			var owned: String = station.delivered.get(row.item_id, "0")
			var remaining := HubInteger.subtract(row.required, owned)
			var available: String = station.construction_buffer.get(row.item_id, "0")
			var take := available if DecimalCount.compare(available, remaining) < 0 else remaining
			if take != "0":
				station.delivered[row.item_id] = HubInteger.add(owned, take)
				station.construction_buffer[row.item_id] = HubInteger.subtract(available, take)
			if DecimalCount.compare(station.delivered.get(row.item_id, "0"), row.required) < 0: complete = false
		if not complete: break
		station.phase_index += 4
	station.status = "operational" if int(station.phase_index) == rows.size() else "building"

func update() -> void:
	for building in state.buildings.values():
		if building.get("type") != TYPE: continue
		var station: Dictionary = state.system_space_stations.get(planet_system(building.planet_id), {})
		if station.get("status") != "building": continue
		var power := clampf(float(building.get("power_efficiency", 0)), 0, 1)
		var changed := false
		for item in building.input_buffer:
			var raw := float(building.input_buffer[item])
			if raw != floorf(raw): continue
			var accepted := int(floorf(raw * power))
			if accepted < 1: continue
			station.construction_buffer[item] = HubInteger.add(station.construction_buffer.get(item, "0"), str(accepted))
			building.input_buffer[item] = raw - accepted
			changed = true
		if changed: apply_buffer(station)

static func module_cost(module: String, existing: int, amount: int) -> Dictionary:
	var costs := {}
	for item in MODULE_COSTS.get(module, {}): costs[item] = HubInteger.module_cost(MODULE_COSTS[module][item], existing, amount)
	return costs

func set_module_count(system_id: String, module: String, count: int) -> Dictionary:
	var station: Dictionary = state.system_space_stations.get(system_id, {})
	if station.get("status") != "operational" or not MODULE_COSTS.has(module) or count < 0 or count > 1000000: return result(false, "模块参数无效或空间站尚未运行")
	var current := int(station.modules[module])
	if count == current: return result(false, "模块数量未变化")
	var costs := module_cost(module, mini(current, count), absi(count - current))
	if count > current:
		for item in costs:
			if DecimalCount.compare(station.inventory.get(item, "0"), costs[item]) < 0: return result(false, "空间站库存不足，无法升级模块")
	for item in costs:
		station.inventory[item] = HubInteger.subtract(station.inventory.get(item, "0"), costs[item]) if count > current else HubInteger.add(station.inventory.get(item, "0"), HubInteger.half(costs[item]))
	station.modules[module] = count
	return result(true, "模块数量已更新" if count > current else "模块已拆回，返还一半建设材料")

func accepts_input(id: String, item: String) -> bool:
	if DataManager.get_item(item).is_empty(): return false
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != TYPE: return false
	var occupied := {}
	for key in building.get("input_buffer", {}):
		if float(building.input_buffer[key]) > 0: occupied[key] = true
	for connection in state.connections.values():
		if connection.target_id == id: occupied[connection.item_id] = true
	return occupied.has(item) or occupied.size() < 4

static func result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

static func validate(data: Dictionary) -> Array:
	var root: Variant = data.get("system_space_stations", {})
	if not root is Dictionary or root.size() > 8: return ["恒星系空间站集合无效"]
	if not data.get("explored_system_ids", []) is Array: return ["空间站已探索恒星系集合无效"]
	var world := GameState.new()
	world.source_galaxy = data.get("source_galaxy", {}).duplicate(true)
	world.galaxy_seed = int(data.get("galaxy_seed", 240721))
	var galaxy := GalaxySystem.new(world)
	for id in root:
		if not id is String: return ["空间站恒星系 ID 无效"]
		var station: Variant = root[id]
		if not station is Dictionary or galaxy.get_star_system(id).is_empty() or not data.get("explored_system_ids", []).has(id) or station.get("system_id") != id: return ["空间站所属恒星系无效"]
		if station.get("status") not in ["not-started", "building", "operational"] or not SourceDysonEngineering.number(station.get("cost_revision"), 0, 1, true) or not SourceDysonEngineering.number(station.get("cost_multiplier_basis_points"), 8000, 10000, true) or int(station.cost_multiplier_basis_points) not in [8000, 9000, 10000] or not SourceDysonEngineering.number(station.get("phase_index"), 0, 16, true) or int(station.phase_index) % 4 != 0: return ["空间站阶段或折扣无效"]
		if (station.status == "not-started" and (station.cost_revision != 0 or station.phase_index != 0)) or (station.status != "not-started" and station.cost_revision != 1) or (station.status == "operational") != (station.phase_index == 16): return ["空间站建设状态不一致"]
		for field in ["delivered", "construction_buffer", "inventory"]:
			if not station.get(field) is Dictionary: return ["空间站库存结构无效"]
			for item in station[field]:
				if not item is String or DataManager.get_item(item).is_empty() or not HubInteger.valid(station[field][item]): return ["空间站库存必须是 256 位以内精确整数"]
		var maximum := {}
		for row in requirements(int(station.cost_multiplier_basis_points)):
			maximum[row.item_id] = maxi(int(maximum.get(row.item_id, 0)), int(row.required))
			if int(row.phase_index) < int(station.phase_index) and DecimalCount.compare(station.delivered.get(row.item_id, "0"), row.required) < 0: return ["空间站已完成阶段缺少材料"]
		for item in station.delivered:
			if not maximum.has(item) or DecimalCount.compare(station.delivered[item], str(maximum[item])) > 0: return ["空间站已交付材料超出工程要求"]
		if not station.get("modules") is Dictionary: return ["空间站模块无效"]
		for module in MODULE_COSTS:
			if not SourceDysonEngineering.number(station.modules.get(module), 0, 1000000, true): return ["空间站模块数量无效"]
		if not station.get("item_policies") is Dictionary or not station.get("routing_cursors") is Dictionary or not station.get("viewport") is Dictionary or not station.get("decorations") is Array: return ["空间站配置无效"]
		for axis in ["x", "y"]:
			if not SourceDysonEngineering.number(station.viewport.get(axis), -1000000000, 1000000000): return ["空间站视图坐标无效"]
		if not SourceDysonEngineering.number(station.viewport.get("zoom"), 0.1, 10): return ["空间站视图缩放无效"]
		for item in station.item_policies:
			var policy: Variant = station.item_policies[item]
			if not item is String or DataManager.get_item(item).is_empty() or not policy is Dictionary or not HubInteger.valid(policy.get("reserve")) or not HubInteger.valid(policy.get("target")) or not policy.get("interstellar_enabled") is bool: return ["空间站跨系物料策略无效"]
		for item in station.routing_cursors:
			if not item is String or DataManager.get_item(item).is_empty() or not SourceDysonEngineering.number(station.routing_cursors[item], 0, 9007199254740991, true): return ["空间站分配游标无效"]
		if not station.decorations.is_empty(): return ["空间站装饰尚未实现，不能载入未知装饰"]
	if not data.get("buildings", {}) is Dictionary: return ["施工平台建筑集合无效"]
	var planets := {}
	for building in data.get("buildings", {}).values():
		if not building is Dictionary or building.get("type") != TYPE: continue
		if not building.get("planet_id", "") is String: return ["施工平台行星无效"]
		var planet: String = building.get("planet_id", "")
		if planets.has(planet): return ["每颗行星最多一座施工发射平台"]
		planets[planet] = true
		if not building.get("input_buffer", {}) is Dictionary: return ["施工平台缓存无效"]
		var occupied := {}
		for item in building.get("input_buffer", {}):
			if not item is String or not SourceDysonEngineering.number(building.input_buffer[item], 0, 4000): return ["施工平台缓存数量无效"]
			if float(building.input_buffer[item]) > 0: occupied[item] = true
		var connections: Variant = data.get("connections", {})
		if not connections is Dictionary: return ["施工平台线路集合无效"]
		for connection in connections.values():
			if not connection is Dictionary: continue
			if connection.get("target_id") == building.get("id"):
				occupied[connection.get("item_id", "")] = true
				if not SourceDysonEngineering.number(connection.get("construction_credit", 0), 0, 1): return ["施工线路累计传输量无效"]
		if occupied.size() > 4: return ["施工平台输入物料超过四种"]
	return []
