class_name DysonSphereSystem
extends RefCounted

const AMMO := {"solar_sail_ejector": "solar_sail", "dyson_sphere_launcher": "small_carrier_rocket", "dsp_em_rail_ejector": "solar_sail", "dsp_vertical_launching_silo": "small_carrier_rocket"}
const BUILDINGS := ["solar_sail_ejector", "dyson_sphere_launcher", "ray_receiver", "dsp_em_rail_ejector", "dsp_vertical_launching_silo", "dsp_ray_receiver"]
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

func _allowed(system_id: String, swarm_only: bool = false) -> bool:
	var unlocked := game_state.completed_technologies.has("dyson_engineering") or game_state.completed_technologies.has("dsp_dyson_sphere_program") or (swarm_only and game_state.completed_technologies.has("dsp_dyson_swarm"))
	return unlocked and game_state.explored_system_ids.has(system_id) and not galaxy.get_star_system(system_id).is_empty()

func _geometry(radius: float, inclination: float, longitude: float) -> bool:
	return is_finite(radius) and radius >= 5000 and radius <= 50000 and is_finite(inclination) and absf(inclination) <= 90 and is_finite(longitude) and longitude >= 0 and longitude < 360

func create_orbit(system_id: String, radius: float = 10000, inclination: float = 0, longitude: float = 0) -> Dictionary:
	if not _allowed(system_id, true) or not _geometry(radius, inclination, longitude):
		return _result(false, "需要戴森工程科技、已探索星系和合法轨道参数")
	if game_state.dyson_systems.get(system_id, {}).get("orbits", {}).size() >= int(rules.max_orbits):
		return _result(false, "太阳帆轨道数量已达上限")
	var id := game_state.generate_id("orbit")
	if not game_state.source_galaxy.is_empty(): SourceDysonEngineering.new(game_state).ensure(system_id)
	_system(system_id).orbits[id] = {"id": id, "radius": radius, "inclination": inclination, "longitude": longitude, "cohorts": []}
	if not game_state.source_galaxy.is_empty():
		_system(system_id).source_plan.active_orbit = id
		_system(system_id).orbits[id].decay_progress = 0.0
	return _result(true, "太阳帆轨道已规划", id)

func create_layer(system_id: String, orbit_id: String, radius: float = 15000, inclination: float = 0, longitude: float = 0) -> Dictionary:
	if not game_state.source_galaxy.is_empty():
		if not _geometry(radius, inclination, longitude): return _result(false, "层几何参数无效")
		return SourceDysonEngineering.new(game_state).add_layer(system_id, orbit_id, radius, inclination, longitude)
	var system: Dictionary = game_state.dyson_systems.get(system_id, {})
	if not _allowed(system_id) or not system.get("orbits", {}).has(orbit_id) or not _geometry(radius, inclination, longitude):
		return _result(false, "层必须关联本星系合法太阳帆轨道")
	if system.layers.size() >= int(rules.max_layers):
		return _result(false, "戴森层数量已达上限")
	var id := game_state.generate_id("layer")
	system.layers[id] = {"id": id, "orbit_id": orbit_id, "radius": radius, "inclination": inclination, "longitude": longitude, "nodes": {}, "shell": {}, "absorption_ticks": 0}
	return _result(true, "戴森层已规划", id)

func add_node(system_id: String, layer_id: String, angle: float) -> Dictionary:
	if not game_state.source_galaxy.is_empty(): return SourceDysonEngineering.new(game_state).add_node(system_id, layer_id, angle)
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
	if not game_state.source_galaxy.is_empty(): return SourceDysonEngineering.new(game_state).plan_shell(system_id, layer_id)
	var layer: Dictionary = game_state.dyson_systems.get(system_id, {}).get("layers", {}).get(layer_id, {})
	if not _allowed(system_id) or layer.is_empty() or layer.nodes.size() < 3 or not layer.shell.is_empty():
		return _result(false, "壳面需要至少三个节点，且不能重复规划")
	layer.shell = {"sails": 0}
	return _result(true, "壳面已规划；结构完成后从关联轨道吸附太阳帆")

func remove_plan(system_id: String, id: String, kind: String) -> Dictionary:
	var system: Dictionary = game_state.dyson_systems.get(system_id, {})
	if kind not in ["orbits", "layers"] or not _allowed(system_id, kind == "orbits") or not system.get(kind, {}).has(id):
		return _result(false, "规划不存在")
	for building in game_state.buildings.values():
		if building.get("dyson", {}).get("target_id", "") == id:
			return _result(false, "请先解除发射设备的目标")
	if system.has("source_plan"):
		if kind == "layers":
			system.layers.erase(id)
			system.source_plan.layer_order.erase(id)
			if system.source_plan.active_layer == id: system.source_plan.active_layer = String(system.source_plan.layer_order[0]) if not system.source_plan.layer_order.is_empty() else ""
			SourceDysonEngineering.reconcile(system)
		else:
			if system.orbits.size() <= 1: return _result(false, "至少保留一条太阳帆轨道")
			var fallback: String = system.orbits.keys().filter(func(key): return key != id)[0]
			system.orbits[fallback].cohorts.append_array(system.orbits[id].cohorts)
			var live := 0
			for cohort in system.orbits[fallback].cohorts: live += int(cohort.count)
			system.orbits[fallback].cohorts = [{"expires_tick": 0, "count": live}] if live > 0 else []
			for layer in system.layers.values():
				if layer.orbit_id == id: layer.orbit_id = fallback
			system.orbits.erase(id)
			if system.source_plan.active_orbit == id: system.source_plan.active_orbit = fallback
		return _result(true, "规划已删除；材料保留在本恒星系")
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
	var kind := "orbits" if building.type in ["solar_sail_ejector", "dsp_em_rail_ejector"] else "layers"
	if not _allowed(system_id, kind == "orbits") or (target_id != "" and not game_state.dyson_systems.get(system_id, {}).get(kind, {}).has(target_id)):
		return _result(false, "发射目标必须属于设备所在恒星系")
	building["dyson"] = {"target_id": target_id, "enabled": enabled, "progress": float(building.get("dyson", {}).get("progress", 0))}
	return _result(true, "发射目标已配置")

func load_ammo(id: String, count: int) -> Dictionary:
	var building: Dictionary = game_state.buildings.get(id, {})
	if building.get("type", "") not in AMMO or building.get("planet_id", "") != game_state.active_planet_id or building.get("interaction_locked", false) or count <= 0:
		return _result(false, "只能向当前行星发射设备装载正整数耗材")
	var item: String = AMMO[building.type]
	var buffer: Dictionary = building.get("input_buffer", {})
	if float(buffer.get(item, 0)) + count > ammo_capacity(id):
		return _result(false, "发射设备输入容量不足")
	var paid := InventorySystem.new(game_state).try_remove(item, count)
	if not paid.ok:
		return paid
	buffer[item] = float(buffer.get(item, 0)) + count
	building.input_buffer = buffer
	return _result(true, "发射耗材已装入")

func ammo_capacity(id: String) -> int:
	var building: Dictionary = game_state.buildings.get(id, {})
	return int(DataManager.get_building(building.get("type", "")).get("input_buffer_capacity", 60)) if not game_state.source_galaxy.is_empty() else 60

func begin_tick() -> void:
	game_state.dyson_tick += 1
	for system in game_state.dyson_systems.values():
		if system.has("source_plan"):
			var engineering := SourceDysonEngineering.new(game_state)
			engineering.absorb(system, 1.0 / 60.0)
			engineering.decay(system, 1.0 / 60.0)
			continue
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
		if not system.has("source_plan"):
			for layer_id in layers:
				_absorb(system, system.layers[layer_id])

func _launch(building: Dictionary, delta: float) -> String:
	var system_id := String(galaxy.get_planet(building.planet_id).get("system_id", ""))
	var config: Dictionary = building.get("dyson", {})
	if not config.get("enabled", false):
		return "发射已停止"
	var kind := "orbits" if building.type in ["solar_sail_ejector", "dsp_em_rail_ejector"] else "layers"
	if not _allowed(system_id, kind == "orbits"):
		return "戴森工程科技未解锁"
	var recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
	if DataManager.get_building(String(building.type)).has("source_id") and not DataManager.source_technology_unlocked(game_state, String(recipe.get("required_source_technology", ""))):
		return "发射配方科技未解锁"
	var system: Dictionary = game_state.dyson_systems.get(system_id, {})
	var target: Dictionary = system.get(kind, {}).get(config.get("target_id", ""), {})
	if target.is_empty():
		return "没有本星系合法发射目标"
	if float(building.get("power_efficiency", 0)) <= 0:
		return "设备断电"
	var source_rules := system.has("source_plan")
	var factor := SourceDysonEngineering.new(game_state).launch_factor(kind == "orbits") if source_rules else 1.0
	if factor <= 0: return "全局发射计划已停止或模式不符"
	var node := {}
	if kind == "layers" and not source_rules:
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
	var duration_key := "solar_sail_ejector" if kind == "orbits" else "dyson_sphere_launcher"
	var duration := (12.0 if kind == "orbits" else 6.0) if source_rules else float(rules.launch_seconds[duration_key])
	var efficiency := clampf(float(building.power_efficiency), 0, 1)
	var speed := efficiency * factor * (GameModeSystem.new(game_state).multiplier("production") * SourceTechnologyEffects.multiplier(game_state, "production_speed") if source_rules else 1.0)
	config.progress = minf(duration, float(config.get("progress", 0)) + delta * speed)
	if source_rules:
		building.production_utilization = efficiency * factor
		building.last_production_per_minute = 60.0 / duration * speed
	if float(config.progress) + 0.0000001 < duration:
		return "正在发射"
	building.input_buffer[item] -= 1.0
	config.progress = 0.0
	if source_rules:
		game_state.dyson_engineering.launch_energy_spent_mj = floorf((float(game_state.dyson_engineering.get("launch_energy_spent_mj", 0)) + (21.6 if kind == "orbits" else 108.0)) * 1000.0 + 0.5) / 1000.0
	if kind == "orbits":
		var expires := 0 if source_rules else game_state.dyson_tick + int(float(rules.sail_lifetime_ticks) * game_state.get_technology_effect_multiplier("sail_lifetime"))
		if not target.cohorts.is_empty() and int(target.cohorts.back().expires_tick) == expires:
			target.cohorts.back().count += 1
		else:
			target.cohorts.append({"expires_tick": expires, "count": 1})
		system.sails_launched += 1
	else:
		if source_rules:
			system.source_plan.structure_points += 1
			SourceDysonEngineering.reconcile(system)
		else: node.points += 1
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
	if system.has("source_plan"): return _source_summary(system_id, system)
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

func receiver_allocations() -> Dictionary:
	var result := {}
	if not (game_state.completed_technologies.has("dyson_engineering") or game_state.completed_technologies.has("dsp_ray_receiver") or game_state.completed_technologies.has("dsp_dyson_sphere_program")):
		return result
	var grouped := {}
	var ids := game_state.buildings.keys()
	ids.sort()
	for id in ids:
		var building: Dictionary = game_state.buildings[id]
		if building.get("type", "") not in ["ray_receiver", "dsp_ray_receiver"]:
			continue
		if building.type == "dsp_ray_receiver" and (building.get("recipe_id", "") not in ["dsp_ray_power", "dsp_critical_photon"] or not SourceTechnologyEffects.completed(game_state, "ray_receiver")): continue
		if building.type == "dsp_ray_receiver" and building.get("recipe_id", "") == "dsp_critical_photon" and not source_photon_has_space(building): continue
		var system_id := String(galaxy.get_planet(building.planet_id).get("system_id", ""))
		if not grouped.has(system_id):
			grouped[system_id] = []
		grouped[system_id].append(id)
	for system_id in grouped:
		var total_capacity := 0.0
		for id in grouped[system_id]:
			var capacity := receiver_capacity(String(game_state.buildings[id].type))
			total_capacity += capacity * clampf(float(game_state.buildings[id].get("generation_factor", 1)), 0, 1)
		var summary := get_summary(system_id)
		var power := float(summary.power_kw)
		if game_state.dyson_systems.get(system_id, {}).has("source_plan"):
			# Source reception uses the unrounded generation; the summary floors it.
			power = (float(summary.live_sails) * 88.0 + float(summary.structure_points) * 960.0 + float(summary.absorbed_sails) * 88.0) * SourceTechnologyEffects.multiplier(game_state, "dyson_power") * float(galaxy.get_star_system(system_id).get("luminosity", 1.0))
		for id in grouped[system_id]:
			var capacity := receiver_capacity(String(game_state.buildings[id].type))
			var requested := capacity * clampf(float(game_state.buildings[id].get("generation_factor", 1)), 0, 1)
			result[id] = requested * minf(1, power / total_capacity) if total_capacity > 0 else 0.0
	return result

static func source_photon_has_space(building: Dictionary) -> bool:
	var capacity := float(building.get("output_buffer_capacity", DataManager.get_building(String(building.type)).get("output_buffer_capacity", 120)))
	return floori(capacity - float(building.get("output_buffer", {}).get("critical_photon", 0)) + 0.0001) >= 1

func refresh_source_receiver_presentation() -> void:
	var allocations := receiver_allocations()
	for id in game_state.buildings:
		var building: Dictionary = game_state.buildings[id]
		if building.get("type", "") != "dsp_ray_receiver": continue
		var received := float(allocations.get(id, 0))
		building.power_output = floorf(received * 100.0 + 0.5) / 100.0
		if building.get("recipe_id", "") == "dsp_ray_power":
			building.progress = 0.0
			building.last_production_per_minute = 0.0
			var capacity := receiver_capacity(building.type)
			building.production_utilization = floorf((received / capacity if capacity > 0 else 0.0) * 10000.0 + 0.5) / 10000.0

static func _result(ok: bool, message: String, id: String = "") -> Dictionary:
	return {"ok": ok, "message": message, "id": id}

func receiver_outputs() -> Dictionary:
	var allocations := receiver_allocations()
	for id in allocations.keys():
		if game_state.buildings[id].type == "dsp_ray_receiver" and game_state.buildings[id].get("recipe_id", "") != "dsp_ray_power": allocations.erase(id)
	return allocations

func receiver_capacity(type: String) -> float:
	return (6000.0 * SourceTechnologyEffects.multiplier(game_state, "ray_capacity")) if type == "dsp_ray_receiver" else float(DataManager.get_building(type).get("power_generation", 0)) * game_state.get_technology_effect_multiplier("ray_capacity")

func _source_summary(system_id: String, system: Dictionary) -> Dictionary:
	var totals := SourceDysonEngineering.totals(system)
	var live := 0
	for orbit in system.orbits.values():
		for cohort in orbit.cohorts: live += int(cohort.count)
	var plan: Dictionary = system.source_plan
	var points := int(plan.structure_points)
	var absorbed := int(plan.shell_sails)
	var multiplier := SourceTechnologyEffects.multiplier(game_state, "dyson_power") * float(galaxy.get_star_system(system_id).get("luminosity", 1.0))
	var power := live * 88.0 * multiplier + floorf((points * 960.0 + absorbed * 88.0) * multiplier)
	return {"live_sails": live, "absorbed_sails": absorbed, "expired_sails": int(system.sails_expired), "launched_sails": int(system.sails_launched), "structure_points": points, "rockets_launched": int(system.rockets_launched), "missing_rockets": maxi(0, int(totals.planned_structure) - int(totals.completed_structure)), "missing_sails": maxi(0, int(totals.planned_capacity) - absorbed - live), "power_kw": power, "planned_power_kw": floorf((int(totals.planned_structure) * 960.0 + int(totals.planned_capacity) * 88.0) * multiplier), "frames": totals.frames, "shells": totals.shells, "active_capacity": totals.active_capacity, "planned_capacity": totals.planned_capacity}
