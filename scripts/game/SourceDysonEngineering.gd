class_name SourceDysonEngineering
extends RefCounted

const SHELL_CAPACITY := 40
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

static func frame_requirement(radius: float, a: float, b: float) -> int:
	var direct := fmod(absf(a - b), 360.0)
	return maxi(1, int(ceilf(radius / 10000.0 * minf(direct, 360.0 - direct) / 45.0)))

static func normalize_angle(value: float) -> float:
	return fposmod(floorf(value * 10.0 + 0.5) / 10.0, 360.0)

func ensure(system_id: String) -> Dictionary:
	if not state.dyson_systems.has(system_id): state.dyson_systems[system_id] = DysonSphereSystem.empty_system()
	var system: Dictionary = state.dyson_systems[system_id]
	if not system.has("source_plan"):
		system.source_plan = {"structure_points": 0, "shell_sails": 0, "absorption_progress": 0.0, "layer_order": [], "active_layer": "", "active_orbit": ""}
	if state.dyson_engineering.is_empty(): state.dyson_engineering = {"version": 1, "launch_mode": "balanced", "throttle": 1.0, "enabled": true, "launch_energy_spent_mj": 0.0}
	return system

func allowed(system_id: String) -> bool:
	return not state.source_galaxy.is_empty() and state.explored_system_ids.has(system_id) and SourceTechnologyEffects.completed(state, "dyson_sphere_program") and not GalaxySystem.new(state).get_star_system(system_id).is_empty()

func add_layer(system_id: String, orbit_id: String, radius: float, inclination: float, longitude: float, allocation_floor: bool = false) -> Dictionary:
	if not allowed(system_id): return result(false, "需要已探索星系和戴森球计划科技")
	var system := ensure(system_id)
	if system.layers.size() >= 8 or not system.orbits.has(orbit_id): return result(false, "层数已满或关联轨道无效")
	var id := state.generate_id("layer")
	system.layers[id] = {"id": id, "orbit_id": orbit_id, "name": "壳层 %d" % (system.layers.size() + 1), "radius": radius, "inclination": inclination, "longitude": longitude, "nodes": {}, "shell": {}, "absorption_ticks": 0, "frames": {}, "shells": {}, "node_order": [], "frame_order": [], "shell_order": [], "structure_floor": int(system.source_plan.structure_points) if allocation_floor else 0, "shell_floor": int(system.source_plan.shell_sails) if allocation_floor else 0}
	system.source_plan.layer_order.append(id)
	system.source_plan.active_layer = id
	return result(true, "戴森层已规划", id)

func layer_for(system_id: String, layer_id: String) -> Dictionary:
	return state.dyson_systems.get(system_id, {}).get("layers", {}).get(layer_id, {})

func add_node(system_id: String, layer_id: String, angle: float) -> Dictionary:
	var layer := layer_for(system_id, layer_id)
	if not allowed(system_id) or layer.is_empty() or not is_finite(angle) or layer.nodes.size() >= 24: return result(false, "节点无效、已满或科技未解锁")
	angle = normalize_angle(angle)
	for node in layer.nodes.values():
		var direct := absf(float(node.angle) - angle)
		if minf(direct, 360.0 - direct) < 5: return result(false, "节点角度间距至少 5°")
	var id := state.generate_id("node")
	layer.nodes[id] = {"id": id, "angle": angle, "required_points": 1, "points": 0}
	layer.node_order.append(id)
	reconcile(ensure(system_id))
	return result(true, "节点已规划", id)

func connect_nodes(system_id: String, layer_id: String, source_id: String, target_id: String) -> Dictionary:
	var layer := layer_for(system_id, layer_id)
	if not allowed(system_id) or layer.is_empty() or source_id == target_id or not layer.nodes.has(source_id) or not layer.nodes.has(target_id): return result(false, "框架节点无效")
	for frame in layer.frames.values():
		if [source_id, target_id].has(frame.source_id) and [source_id, target_id].has(frame.target_id): return result(false, "框架已存在")
	var id := state.generate_id("frame")
	layer.frames[id] = {"id": id, "source_id": source_id, "target_id": target_id, "required_points": frame_requirement(float(layer.radius), float(layer.nodes[source_id].angle), float(layer.nodes[target_id].angle)), "points": 0}
	layer.frame_order.append(id)
	reconcile(ensure(system_id))
	return result(true, "框架已连接", id)

func auto_connect(system_id: String, layer_id: String) -> Dictionary:
	var layer := layer_for(system_id, layer_id)
	if not allowed(system_id) or layer.is_empty() or layer.nodes.size() < 3: return result(false, "至少需要三个节点")
	var nodes: Array = layer.nodes.values()
	nodes.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.angle) < float(b.angle))
	for index in range(nodes.size()): connect_nodes(system_id, layer_id, nodes[index].id, nodes[(index + 1) % nodes.size()].id)
	return result(true, "相邻节点已连接成环")

func plan_shell(system_id: String, layer_id: String) -> Dictionary:
	if not SourceTechnologyEffects.completed(state, "dyson_shell"): return result(false, "需要戴森球壳科技")
	var connected := auto_connect(system_id, layer_id)
	if not connected.ok: return connected
	var layer := layer_for(system_id, layer_id)
	var added := 0
	var nodes: Array = layer.nodes.values()
	nodes.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.angle) < float(b.angle))
	for index in range(nodes.size()):
		var a: String = nodes[index].id
		var b: String = nodes[(index + 1) % nodes.size()].id
		for frame in layer.frames.values():
			if not ([a, b].has(frame.source_id) and [a, b].has(frame.target_id)): continue
			var exists := false
			for shell in layer.shells.values():
				if [a, b].has(shell.source_id) and [a, b].has(shell.target_id): exists = true
			if exists: continue
			var id := state.generate_id("shell")
			layer.shells[id] = {"id": id, "source_id": a, "target_id": b, "boundary_frames": [frame.id], "capacity": int(frame.required_points) * SHELL_CAPACITY, "sails": 0}
			layer.shell_order.append(id)
			added += 1
	reconcile(ensure(system_id))
	return result(added > 0, "壳面已规划" if added > 0 else "壳面已全部规划")

func standard_layer(system_id: String, orbit_id: String, count: int = 8) -> Dictionary:
	if not allowed(system_id): return result(false, "戴森球计划未解锁")
	var system := ensure(system_id)
	var index: int = system.layers.size()
	var created := add_layer(system_id, orbit_id, 10000.0 + index * 4000, 0.0 if index % 2 == 0 else 18.0, float(index * 24 % 360))
	if not created.ok: return created
	count = clampi(count, 3, 16)
	for n in range(count):
		var node := add_node(system_id, created.id, float(n) * 360.0 / count)
		system.layers[created.id].nodes[node.id].angle = float(n) * 360.0 / count
	auto_connect(system_id, created.id)
	if SourceTechnologyEffects.completed(state, "dyson_shell"): plan_shell(system_id, created.id)
	return created

static func reconcile(system: Dictionary) -> void:
	var plan: Dictionary = system.source_plan
	var structure_cursor := 0
	for id in plan.layer_order:
		var layer: Dictionary = system.layers[id]
		structure_cursor = maxi(structure_cursor, int(layer.structure_floor))
		var budget := maxi(0, int(plan.structure_points) - structure_cursor)
		for field in ["nodes", "frames"]:
			for key in layer.node_order if field == "nodes" else layer.frame_order:
				var part: Dictionary = layer[field][key]
				part.points = mini(int(part.required_points), budget)
				budget -= int(part.points)
				structure_cursor += int(part.required_points)
	var sail_cursor := 0
	for id in plan.layer_order:
		var layer: Dictionary = system.layers[id]
		sail_cursor = maxi(sail_cursor, int(layer.shell_floor))
		for key in layer.shell_order:
			var shell: Dictionary = layer.shells[key]
			if not shell_active(layer, shell):
				shell.sails = 0
				continue
			shell.sails = mini(int(shell.capacity), maxi(0, int(plan.shell_sails) - sail_cursor))
			sail_cursor += int(shell.capacity)

static func shell_active(layer: Dictionary, shell: Dictionary) -> bool:
	if shell.boundary_frames.is_empty(): return false
	for id in shell.boundary_frames:
		if not layer.frames.has(id) or int(layer.frames[id].points) < int(layer.frames[id].required_points): return false
	return true

static func totals(system: Dictionary) -> Dictionary:
	var result_data := {"nodes": 0, "frames": 0, "shells": 0, "planned_structure": 0, "completed_structure": 0, "active_capacity": 0, "planned_capacity": 0}
	for layer in system.get("layers", {}).values():
		result_data.nodes += layer.nodes.size()
		result_data.frames += layer.frames.size()
		result_data.shells += layer.shells.size()
		for part in layer.nodes.values() + layer.frames.values():
			result_data.planned_structure += int(part.required_points)
			result_data.completed_structure += int(part.points)
		for shell in layer.shells.values():
			result_data.planned_capacity += int(shell.capacity)
			if shell_active(layer, shell): result_data.active_capacity += int(shell.capacity)
	if system.get("layers", {}).is_empty(): result_data.active_capacity = int(system.get("source_plan", {}).get("structure_points", 0)) * SHELL_CAPACITY
	return result_data

func absorb(system: Dictionary, delta: float) -> void:
	if not SourceTechnologyEffects.completed(state, "dyson_shell"): return
	var plan: Dictionary = system.source_plan
	var free := maxi(0, int(totals(system).active_capacity) - int(plan.shell_sails))
	var live := 0
	for orbit in system.orbits.values():
		for cohort in orbit.cohorts: live += int(cohort.count)
	if free < 1: plan.absorption_progress = 0.0
	if int(plan.structure_points) < 1 or free < 1 or live < 1: return
	var accumulated := float(plan.absorption_progress) + int(plan.structure_points) * 0.1 * SourceTechnologyEffects.multiplier(state, "sail_absorption") * delta
	var requested := mini(free, mini(live, int(floorf(accumulated + 0.0001))))
	var remaining := requested
	for orbit in system.orbits.values():
		while remaining > 0 and not orbit.cohorts.is_empty():
			var take := mini(remaining, int(orbit.cohorts[0].count))
			orbit.cohorts[0].count -= take
			remaining -= take
			if int(orbit.cohorts[0].count) == 0: orbit.cohorts.pop_front()
	plan.shell_sails += requested
	plan.absorption_progress = floorf(clampf(accumulated - requested, 0.0, 0.999999) * 1000000.0 + 0.5) / 1000000.0
	reconcile(system)

func configure_schedule(mode: String, throttle: float, enabled: bool) -> Dictionary:
	if mode not in ["balanced", "swarm", "sphere"] or throttle not in [0.25, 0.5, 0.75, 1.0] or state.source_galaxy.is_empty(): return result(false, "发射模式或节流无效")
	state.dyson_engineering = {"version": 1, "launch_mode": mode, "throttle": throttle, "enabled": enabled, "launch_energy_spent_mj": float(state.dyson_engineering.get("launch_energy_spent_mj", 0))}
	return result(true, "所有恒星系发射计划已更新")

func launch_factor(sail: bool) -> float:
	var schedule: Dictionary = state.dyson_engineering
	if not schedule.get("enabled", true) or (sail and schedule.get("launch_mode", "balanced") == "sphere") or (not sail and schedule.get("launch_mode", "balanced") == "swarm"): return 0.0
	return float(schedule.get("throttle", 1.0))

func set_geometry(system_id: String, id: String, kind: String, radius: float, inclination: float, longitude: float) -> Dictionary:
	var system: Dictionary = state.dyson_systems.get(system_id, {})
	if not allowed(system_id) or kind not in ["layers", "orbits"] or not system.get(kind, {}).has(id) or not is_finite(radius) or not is_finite(inclination) or not is_finite(longitude): return result(false, "几何参数或目标无效")
	var target: Dictionary = system[kind][id]
	target.radius = clampf(floorf(radius + 0.5), 5000, 50000)
	target.inclination = clampf(floorf(inclination + 0.5), -90, 90)
	target.longitude = normalize_angle(longitude)
	if kind == "layers":
		for frame in target.frames.values(): frame.required_points = frame_requirement(target.radius, target.nodes[frame.source_id].angle, target.nodes[frame.target_id].angle)
		for shell in target.shells.values():
			shell.capacity = 0
			for frame_id in shell.boundary_frames: shell.capacity += int(target.frames[frame_id].required_points) * SHELL_CAPACITY
		reconcile(system)
	return result(true, "轨道几何已更新；材料投入保持不变")

func remove_node(system_id: String, layer_id: String, node_id: String) -> Dictionary:
	var layer := layer_for(system_id, layer_id)
	if not allowed(system_id) or layer.is_empty() or not layer.nodes.has(node_id): return result(false, "节点不存在")
	layer.nodes.erase(node_id)
	layer.node_order.erase(node_id)
	var removed := []
	for id in layer.frame_order:
		if node_id in [layer.frames[id].source_id, layer.frames[id].target_id]: removed.append(id)
	for id in removed:
		layer.frames.erase(id)
		layer.frame_order.erase(id)
	for id in layer.shell_order.duplicate():
		var shell: Dictionary = layer.shells[id]
		if node_id in [shell.source_id, shell.target_id] or shell.boundary_frames.any(func(frame): return removed.has(frame)):
			layer.shells.erase(id)
			layer.shell_order.erase(id)
	reconcile(ensure(system_id))
	return result(true, "节点及相连框架已删除；已投入材料保留在恒星系")

func clear_shells(system_id: String, layer_id: String) -> Dictionary:
	var layer := layer_for(system_id, layer_id)
	if not allowed(system_id) or layer.is_empty(): return result(false, "层不存在")
	layer.shells.clear()
	layer.shell_order.clear()
	reconcile(ensure(system_id))
	return result(true, "壳面规划已清空；已吸附材料保留")

func copy_template(system_id: String, layer_id: String) -> Dictionary:
	var layer := layer_for(system_id, layer_id)
	if layer.is_empty(): return {}
	var template := {"name": layer.name, "radius": layer.radius, "inclination": layer.inclination, "longitude": layer.longitude, "nodes": [], "frames": [], "shells": []}
	for id in layer.node_order: template.nodes.append({"key": id, "angle": layer.nodes[id].angle})
	for id in layer.frame_order:
		var frame: Dictionary = layer.frames[id]
		template.frames.append({"key": id, "source": frame.source_id, "target": frame.target_id})
	for id in layer.shell_order:
		var shell: Dictionary = layer.shells[id]
		template.shells.append({"source": shell.source_id, "target": shell.target_id, "boundary": shell.boundary_frames.duplicate()})
	return template

func paste_template(system_id: String, orbit_id: String, template: Dictionary) -> Dictionary:
	if not allowed(system_id) or state.dyson_systems.get(system_id, {}).get("layers", {}).size() >= 8: return result(false, "目标星系未解锁或已满八层")
	var errors := validate_template(template)
	if not errors.is_empty(): return result(false, errors[0])
	if not template.shells.is_empty() and not SourceTechnologyEffects.completed(state, "dyson_shell"): return result(false, "需要戴森球壳科技")
	var candidate := state.copy_state()
	var model := SourceDysonEngineering.new(candidate)
	var added := model.add_layer(system_id, orbit_id, float(template.radius), float(template.inclination), float(template.longitude), true)
	if not added.ok: return added
	var layer := model.layer_for(system_id, added.id)
	layer.name = String(template.name) + " 副本"
	var node_map := {}
	for node in template.nodes: node_map[node.key] = model.add_node(system_id, added.id, float(node.angle)).id
	var frame_map := {}
	for frame in template.frames: frame_map[frame.key] = model.connect_nodes(system_id, added.id, node_map[frame.source], node_map[frame.target]).id
	for shell in template.shells:
		var id := candidate.generate_id("shell")
		var boundary := []
		var capacity := 0
		for key in shell.boundary:
			boundary.append(frame_map[key])
			capacity += int(layer.frames[frame_map[key]].required_points) * SHELL_CAPACITY
		layer.shells[id] = {"id": id, "source_id": node_map[shell.source], "target_id": node_map[shell.target], "boundary_frames": boundary, "capacity": capacity, "sails": 0}
		layer.shell_order.append(id)
	reconcile(candidate.dyson_systems[system_id])
	state.install_state(candidate)
	return result(true, "壳层模板已粘贴；副本等待新的材料投入", added.id)

static func validate_template(template: Dictionary) -> Array:
	for key in ["radius", "inclination", "longitude"]:
		if not number(template.get(key), -1000000, 1000000): return ["壳层轨道参数无效"]
	if float(template.radius) < 5000 or float(template.radius) > 50000 or absf(float(template.inclination)) > 90 or float(template.longitude) < 0 or float(template.longitude) >= 360 or not template.get("name") is String or template.name.length() > 120: return ["壳层名称或半径无效"]
	for key in ["nodes", "frames", "shells"]:
		if not template.get(key) is Array or template[key].size() > (24 if key == "nodes" else 276): return ["模板数组无效或超出上限"]
	var nodes := {}
	for node in template.nodes:
		if not node is Dictionary or not node.get("key") is String or node.key.is_empty() or nodes.has(node.key) or not number(node.get("angle"), -1000000, 1000000): return ["节点模板无效"]
		var angle := normalize_angle(float(node.angle))
		for other in nodes.values():
			var direct := absf(angle - float(other))
			if minf(direct, 360.0 - direct) < 5: return ["节点间距不足 5°"]
		nodes[node.key] = angle
	var frames := {}
	var edges := {}
	for frame in template.frames:
		if not frame is Dictionary or not frame.get("key") is String or frame.key.is_empty() or frames.has(frame.key) or not nodes.has(frame.get("source")) or not nodes.has(frame.get("target")) or frame.source == frame.target: return ["框架模板引用无效"]
		var endpoints: Array = [frame.source, frame.target]
		endpoints.sort()
		var edge := JSON.stringify(endpoints)
		if edges.has(edge): return ["框架重复"]
		edges[edge] = true
		frames[frame.key] = true
	for shell in template.shells:
		if not shell is Dictionary or not nodes.has(shell.get("source")) or not nodes.has(shell.get("target")) or shell.source == shell.target or not shell.get("boundary") is Array or shell.boundary.is_empty() or shell.boundary.size() > frames.size(): return ["壳面边界无效"]
		var seen_boundary := {}
		for key in shell.boundary:
			if not frames.has(key) or seen_boundary.has(key): return ["壳面引用不存在或重复的框架"]
			seen_boundary[key] = true
	return []

static func number(value: Variant, low: float, high: float, integral: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integral or float(value) == floorf(float(value)))

static func result(ok: bool, message: String, id: String = "") -> Dictionary:
	return {"ok": ok, "message": message, "id": id}
static func validate_system(system: Dictionary, data: Dictionary, seen: Dictionary) -> String:
	var plan: Variant = system.get("source_plan")
	if not plan is Dictionary or data.get("source_galaxy", {}).is_empty(): return "源戴森规划根状态无效"
	for field in ["structure_points", "shell_sails"]:
		if not number(plan.get(field), 0, 9000000000000, true): return "戴森工程材料总账无效"
	if not number(plan.get("absorption_progress"), 0, 0.999999) or not ordered_keys(plan.get("layer_order"), system.layers): return "戴森工程分配顺序或吸附进度无效"
	if not plan.get("active_layer") is String or (plan.active_layer != "" and not system.layers.has(plan.active_layer)) or not plan.get("active_orbit") is String or (plan.active_orbit != "" and not system.orbits.has(plan.active_orbit)): return "戴森活动规划无效"
	for id in plan.layer_order:
		var layer: Variant = system.layers[id]
		if not layer is Dictionary or not DysonStateValidator._id(id, layer, "layer", data, seen) or not DysonStateValidator._geometry(layer): return "戴森层几何或 ID 无效"
		if not layer.get("orbit_id") is String or not system.orbits.has(layer.orbit_id) or not layer.get("name") is String or layer.name.length() > 125 or not layer.get("shell") is Dictionary or not layer.shell.is_empty() or not number(layer.get("absorption_ticks"), 0, 0, true): return "源戴森层关联或兼容字段无效"
		for field in ["nodes", "frames", "shells"]:
			if not layer.get(field) is Dictionary or layer[field].size() > (24 if field == "nodes" else 276): return "戴森部件集合无效"
		for field in ["structure_floor", "shell_floor"]:
			if not number(layer.get(field), 0, 9000000000000, true): return "戴森复制层分配起点无效"
		if not ordered_keys(layer.get("node_order"), layer.nodes) or not ordered_keys(layer.get("frame_order"), layer.frames) or not ordered_keys(layer.get("shell_order"), layer.shells): return "戴森部件分配顺序无效"
		var angles := []
		for node_id in layer.node_order:
			var node: Variant = layer.nodes[node_id]
			if not node is Dictionary or not DysonStateValidator._id(node_id, node, "node", data, seen) or not number(node.get("angle"), 0, 359.999999) or not number(node.get("required_points"), 1, 1, true) or not number(node.get("points"), 0, 1, true): return "源戴森节点无效"
			for angle in angles:
				var direct := absf(float(node.angle) - float(angle))
				if minf(direct, 360.0 - direct) < 5: return "戴森节点间距不足"
			angles.append(node.angle)
		var edges := {}
		for frame_id in layer.frame_order:
			var frame: Variant = layer.frames[frame_id]
			if not frame is Dictionary or not DysonStateValidator._id(frame_id, frame, "frame", data, seen) or not layer.nodes.has(frame.get("source_id")) or not layer.nodes.has(frame.get("target_id")) or frame.source_id == frame.target_id: return "戴森框架端点无效"
			var expected := frame_requirement(float(layer.radius), float(layer.nodes[frame.source_id].angle), float(layer.nodes[frame.target_id].angle))
			if not number(frame.get("required_points"), expected, expected, true) or not number(frame.get("points"), 0, expected, true): return "戴森框架结构成本或投入无效"
			var pair: Array = [frame.source_id, frame.target_id]
			pair.sort()
			var edge := JSON.stringify(pair)
			if edges.has(edge): return "戴森框架重复"
			edges[edge] = true
		for shell_id in layer.shell_order:
			var shell: Variant = layer.shells[shell_id]
			if not shell is Dictionary or not DysonStateValidator._id(shell_id, shell, "shell", data, seen) or not layer.nodes.has(shell.get("source_id")) or not layer.nodes.has(shell.get("target_id")) or shell.source_id == shell.target_id or not shell.get("boundary_frames") is Array or shell.boundary_frames.is_empty() or shell.boundary_frames.size() > layer.frames.size(): return "戴森壳面引用无效"
			var capacity := 0
			var used := {}
			for frame_id in shell.boundary_frames:
				if not layer.frames.has(frame_id) or used.has(frame_id): return "壳面框架不存在或重复"
				used[frame_id] = true
				capacity += int(layer.frames[frame_id].required_points) * SHELL_CAPACITY
			if not number(shell.get("capacity"), capacity, capacity, true) or not number(shell.get("sails"), 0, capacity, true): return "戴森壳面容量或投入无效"
	var expected := system.duplicate(true)
	reconcile(expected)
	if expected.layers != system.layers: return "戴森结构分配与材料总账不一致"
	var live := 0
	for orbit in system.orbits.values():
		for cohort in orbit.cohorts: live += int(cohort.count)
	if int(system.rockets_launched) != int(plan.structure_points) or int(system.sails_launched) != live + int(plan.shell_sails) + int(system.sails_expired): return "源戴森材料不守恒"
	return ""

static func ordered_keys(order: Variant, values: Dictionary) -> bool:
	if not order is Array or order.size() != values.size(): return false
	var seen := {}
	for key in order:
		if not key is String or not values.has(key) or seen.has(key): return false
		seen[key] = true
	return true
func decay(system: Dictionary, delta: float) -> void:
	var lifetime := 1200.0 * SourceTechnologyEffects.multiplier(state, "sail_lifetime")
	for orbit in system.orbits.values():
		if orbit.cohorts.is_empty(): continue
		var count := int(orbit.cohorts[0].count)
		var accumulated := fposmod(float(orbit.get("decay_progress", 0.0)), 1.0) + count * delta / lifetime
		var expired := mini(count, int(floorf(accumulated + 0.0001)))
		orbit.cohorts[0].count -= expired
		system.sails_expired += expired
		orbit.decay_progress = floorf(maxf(0.0, accumulated - expired) * 1000000.0 + 0.5) / 1000000.0
		if int(orbit.cohorts[0].count) == 0: orbit.cohorts.clear()
