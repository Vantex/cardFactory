class_name DysonSphereSystem
extends RefCounted

const AMMO := {"solar_sail_ejector": "solar_sail", "dyson_sphere_launcher": "small_carrier_rocket"}
const BUILDINGS := ["solar_sail_ejector", "dyson_sphere_launcher", "ray_receiver"]
static var _rules_cache: Dictionary = {}
var game_state: GameState
var galaxy: GalaxySystem
var rules: Dictionary
var statistics: StatisticsSystem
var diagnostics: Dictionary = {}

func _init(state: GameState, stats: StatisticsSystem = null) -> void:
	game_state = state
	galaxy = GalaxySystem.new(state)
	rules = get_rules()
	statistics = stats

static func get_rules() -> Dictionary:
	if _rules_cache.is_empty():
		var file := FileAccess.open("res://data/dyson.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_rules_cache = parsed.get("dyson_rules", {})
	return _rules_cache.duplicate(true)

static func empty_system() -> Dictionary:
	return {"orbits": {}, "layers": {}, "sails_launched": 0, "sails_expired": 0, "rockets_launched": 0}

func get_system(id: String) -> Dictionary:
	return game_state.dyson_systems.get(id, {}).duplicate(true)

func _system(id: String) -> Dictionary:
	if not game_state.dyson_systems.has(id):
		game_state.dyson_systems[id] = empty_system()
	return game_state.dyson_systems[id]

func _allowed(system_id: String) -> bool:
	return game_state.completed_technologies.has("dyson_engineering") and game_state.explored_system_ids.has(system_id) and not galaxy.get_star_system(system_id).is_empty()

func _geometry(radius: float, inclination: float, longitude: float) -> bool:
	return is_finite(radius) and radius >= 5000 and radius <= 50000 and is_finite(inclination) and absf(inclination) <= 90 and is_finite(longitude) and longitude >= 0 and longitude < 360

func create_orbit(system_id: String, radius: float = 10000, inclination: float = 0, longitude: float = 0) -> Dictionary:
	if not _allowed(system_id) or not _geometry(radius, inclination, longitude):
		return _result(false, "需要戴森工程科技、已探索星系和合法轨道参数")
	if game_state.dyson_systems.get(system_id, {}).get("orbits", {}).size() >= int(rules.max_orbits):
		return _result(false, "太阳帆轨道数量已达上限")
	var id := game_state.generate_id("orbit")
	_system(system_id).orbits[id] = {"id": id, "radius": radius, "inclination": inclination, "longitude": longitude, "cohorts": []}
	return _result(true, "太阳帆轨道已规划", id)

func create_layer(system_id: String, orbit_id: String, radius: float = 15000, inclination: float = 0, longitude: float = 0) -> Dictionary:
	var system: Dictionary = game_state.dyson_systems.get(system_id, {})
	if not _allowed(system_id) or not system.get("orbits", {}).has(orbit_id) or not _geometry(radius, inclination, longitude):
		return _result(false, "层必须关联本星系合法太阳帆轨道")
	if system.layers.size() >= int(rules.max_layers):
		return _result(false, "戴森层数量已达上限")
	var id := game_state.generate_id("layer")
	system.layers[id] = {"id": id, "orbit_id": orbit_id, "radius": radius, "inclination": inclination, "longitude": longitude, "nodes": {}, "shell": {}, "absorption_ticks": 0}
	return _result(true, "戴森层已规划", id)

func add_node(system_id: String, layer_id: String, angle: float) -> Dictionary:
	var layer: Dictionary = game_state.dyson_systems.get(system_id, {}).get("layers", {}).get(layer_id, {})
	if not _allowed(system_id) or layer.is_empty() or not is_finite(angle) or angle < 0 or angle >= 360:
		return _result(false, "节点参数无效或科技未解锁")
	if not layer.shell.is_empty() or layer.nodes.size() >= int(rules.max_nodes):
		return _result(false, "壳面已规划或节点数量已达上限")
	for node in layer.nodes.values():
		if absf(float(node.angle) - angle) < 1.0 or absf(float(node.angle) - angle) > 359.0:
			return _result(false, "节点角度过近")
	var id := game_state.generate_id("node")
	layer.nodes[id] = {"id": id, "angle": angle, "points": 0}
	return _result(true, "节点已规划，等待火箭提供结构点", id)

func plan_shell(system_id: String, layer_id: String) -> Dictionary:
	var layer: Dictionary = game_state.dyson_systems.get(system_id, {}).get("layers", {}).get(layer_id, {})
	if not _allowed(system_id) or layer.is_empty() or layer.nodes.size() < 3 or not layer.shell.is_empty():
		return _result(false, "壳面需要至少三个节点，且不能重复规划")
	layer.shell = {"sails": 0}
	return _result(true, "壳面已规划；结构完成后从关联轨道吸附太阳帆")

func remove_plan(system_id: String, id: String, kind: String) -> Dictionary:
	var system: Dictionary = game_state.dyson_systems.get(system_id, {})
	if not _allowed(system_id) or kind not in ["orbits", "layers"] or not system.get(kind, {}).has(id):
		return _result(false, "规划不存在")
	for building in game_state.buildings.values():
		if building.get("dyson", {}).get("target_id", "") == id:
			return _result(false, "请先解除发射设备的目标")
	if kind == "orbits":
		if not system.orbits[id].cohorts.is_empty():
			return _result(false, "轨道仍有太阳帆")
		for layer in system.layers.values():
			if layer.orbit_id == id:
				return _result(false, "轨道仍被戴森层引用")
	else:
		for node in system.layers[id].nodes.values():
			if int(node.points) > 0:
				return _result(false, "已投入结构材料的层不能直接删除")
	system[kind].erase(id)
	return _result(true, "空规划已删除")

func configure_launcher(id: String, target_id: String, enabled: bool = true) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(id, {})
	if building.get("type", "") not in AMMO or building.get("planet_id", "") != game_state.active_planet_id or building.get("interaction_locked", false):
		return _result(false, "请选择当前行星未锁定的发射设备")
	var system_id := String(galaxy.get_planet(building.planet_id).get("system_id", ""))
	var kind := "orbits" if building.type == "solar_sail_ejector" else "layers"
	if not _allowed(system_id) or (target_id != "" and not game_state.dyson_systems.get(system_id, {}).get(kind, {}).has(target_id)):
		return _result(false, "发射目标必须属于设备所在恒星系")
	building["dyson"] = {"target_id": target_id, "enabled": enabled, "progress": float(building.get("dyson", {}).get("progress", 0))}
	return _result(true, "发射目标已配置")

func load_ammo(id: String, count: int) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(id, {})
	if building.get("type", "") not in AMMO or building.get("planet_id", "") != game_state.active_planet_id or building.get("interaction_locked", false) or count <= 0:
		return _result(false, "只能向当前行星发射设备装载正整数耗材")
	var item: String = AMMO[building.type]
	var buffer: Dictionary = building.get("input_buffer", {})
	if float(buffer.get(item, 0)) + count > 60:
		return _result(false, "发射设备输入容量不足")
	var paid := InventorySystem.new(game_state).try_remove(item, count)
	if not paid.ok:
		return paid
	buffer[item] = float(buffer.get(item, 0)) + count
	building.input_buffer = buffer
	return _result(true, "发射耗材已装入")

func begin_tick() -> void:
	game_state.dyson_tick += 1
	for system in game_state.dyson_systems.values():
		for orbit in system.orbits.values():
			var remaining: Array = []
			for cohort in orbit.cohorts:
				if int(cohort.expires_tick) <= game_state.dyson_tick:
					system.sails_expired += int(cohort.count)
				else:
					remaining.append(cohort)
			orbit.cohorts = remaining

func update_launches(delta: float) -> void:
	diagnostics.clear()
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = game_state.buildings[id]
		if building.get("type", "") in AMMO:
			diagnostics[id] = _launch(building, delta)
	var system_ids := game_state.dyson_systems.keys()
	system_ids.sort()
	for system_id in system_ids:
		var system: Dictionary = game_state.dyson_systems[system_id]
		var layers: Array = system.layers.keys()
		layers.sort()
		for layer_id in layers:
			_absorb(system, system.layers[layer_id])

func _launch(building: Dictionary, delta: float) -> String:
	var system_id := String(galaxy.get_planet(building.planet_id).get("system_id", ""))
	if not _allowed(system_id):
		return "戴森工程科技未解锁"
	var config: Dictionary = building.get("dyson", {})
	if not config.get("enabled", false):
		return "发射已停止"
	var kind := "orbits" if building.type == "solar_sail_ejector" else "layers"
	var system: Dictionary = game_state.dyson_systems.get(system_id, {})
	var target: Dictionary = system.get(kind, {}).get(config.get("target_id", ""), {})
	if target.is_empty():
		return "没有本星系合法发射目标"
	if float(building.get("power_efficiency", 0)) <= 0:
		return "设备断电"
	var node := {}
	if kind == "layers":
		var nodes: Array = target.nodes.keys()
		nodes.sort()
		for id in nodes:
			if int(target.nodes[id].points) < int(rules.node_structure_points):
				node = target.nodes[id]
				break
		if node.is_empty():
			return "没有待建结构节点"
	var item: String = AMMO[building.type]
	if float(building.input_buffer.get(item, 0)) < 1:
		return "缺少" + DataManager.get_item(item).get("name", item)
	var duration := float(rules.launch_seconds[building.type])
	config.progress = minf(duration, float(config.get("progress", 0)) + delta * clampf(float(building.power_efficiency), 0, 1))
	if float(config.progress) + 0.0000001 < duration:
		return "正在发射"
	building.input_buffer[item] -= 1.0
	config.progress = 0.0
	if kind == "orbits":
		var expires := game_state.dyson_tick + int(float(rules.sail_lifetime_ticks) * game_state.get_technology_effect_multiplier("sail_lifetime"))
		if not target.cohorts.is_empty() and int(target.cohorts.back().expires_tick) == expires:
			target.cohorts.back().count += 1
		else:
			target.cohorts.append({"expires_tick": expires, "count": 1})
		system.sails_launched += 1
	else:
		node.points += 1
		system.rockets_launched += 1
	if statistics != null:
		statistics.record_consumed(item, 1.0, building.id, building.planet_id)
	return "已发射"

func _absorb(system: Dictionary, layer: Dictionary) -> void:
	if layer.shell.is_empty() or int(layer.shell.sails) >= layer.nodes.size() * int(rules.sails_per_node):
		return
	for node in layer.nodes.values():
		if int(node.points) < int(rules.node_structure_points):
			return
	var orbit: Dictionary = system.orbits[layer.orbit_id]
	if orbit.cohorts.is_empty():
		return
	layer.absorption_ticks += 1
	if int(layer.absorption_ticks) < maxi(1, int(ceilf(float(rules.absorption_interval_ticks) / game_state.get_technology_effect_multiplier("sail_absorption")))):
		return
	layer.absorption_ticks = 0
	orbit.cohorts[0].count -= 1
	if int(orbit.cohorts[0].count) == 0:
		orbit.cohorts.pop_front()
	layer.shell.sails += 1

func get_summary(system_id: String) -> Dictionary:
	var system: Dictionary = game_state.dyson_systems.get(system_id, empty_system())
	var live := 0
	var absorbed := 0
	var points := 0
	var required_points := 0
	var required_sails := 0
	var orbit_deficits := {}
	for orbit in system.orbits.values():
		for cohort in orbit.cohorts:
			live += int(cohort.count)
	for layer in system.layers.values():
		for node in layer.nodes.values():
			points += int(node.points)
			required_points += int(rules.node_structure_points)
		if not layer.shell.is_empty():
			absorbed += int(layer.shell.sails)
			required_sails += layer.nodes.size() * int(rules.sails_per_node)
			orbit_deficits[layer.orbit_id] = int(orbit_deficits.get(layer.orbit_id, 0)) + layer.nodes.size() * int(rules.sails_per_node) - int(layer.shell.sails)
	var missing_sails := 0
	for orbit_id in orbit_deficits:
		var available := 0
		for cohort in system.orbits[orbit_id].cohorts:
			available += int(cohort.count)
		missing_sails += maxi(0, int(orbit_deficits[orbit_id]) - available)
	var power := (live * float(rules.sail_power_kw) + points * float(rules.structure_power_kw) + absorbed * float(rules.shell_sail_power_kw)) * game_state.get_technology_effect_multiplier("dyson_power")
	return {"live_sails": live, "absorbed_sails": absorbed, "expired_sails": int(system.sails_expired), "launched_sails": int(system.sails_launched), "structure_points": points, "rockets_launched": int(system.rockets_launched), "missing_rockets": required_points - points, "missing_sails": missing_sails, "power_kw": power, "planned_power_kw": required_points * float(rules.structure_power_kw) + required_sails * float(rules.shell_sail_power_kw)}

func receiver_outputs() -> Dictionary:
	var result := {}
	if not game_state.completed_technologies.has("dyson_engineering"):
		return result
	var grouped := {}
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = game_state.buildings[id]
		if building.get("type", "") != "ray_receiver":
			continue
		var system_id := String(galaxy.get_planet(building.planet_id).get("system_id", ""))
		if not grouped.has(system_id):
			grouped[system_id] = []
		grouped[system_id].append(id)
	for system_id in grouped:
		var capacity := float(DataManager.get_building("ray_receiver").get("power_generation", 0)) * game_state.get_technology_effect_multiplier("ray_capacity")
		var total_capacity := 0.0
		for id in grouped[system_id]:
			total_capacity += capacity * clampf(float(game_state.buildings[id].get("generation_factor", 1)), 0, 1)
		var power := float(get_summary(system_id).power_kw)
		for id in grouped[system_id]:
			var requested := capacity * clampf(float(game_state.buildings[id].get("generation_factor", 1)), 0, 1)
			result[id] = requested * minf(1, power / total_capacity) if total_capacity > 0 else 0.0
	return result

static func _result(ok: bool, message: String, id: String = "") -> Dictionary:
	return {"ok": ok, "message": message, "id": id}
