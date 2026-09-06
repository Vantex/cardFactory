class_name DysonStateValidator
extends RefCounted

static func validate(data: Dictionary) -> Array:
	var rules := DysonSphereSystem.get_rules()
	if not _int(data.get("dyson_tick"), 0, 9000000000000) or not data.get("dyson_systems") is Dictionary or rules.is_empty():
		return _error("戴森根状态无效")
	var systems: Dictionary = data.dyson_systems
	var galaxy := GalaxySystem.new(GameState.new())
	var seen := {}
	for system_id in systems:
		if not system_id is String or galaxy.get_star_system(system_id).is_empty() or not data.get("explored_system_ids", []).has(system_id):
			return _error("戴森工程所属恒星系无效")
		var system: Variant = systems[system_id]
		if not system is Dictionary or not system.get("orbits") is Dictionary or not system.get("layers") is Dictionary:
			return _error("戴森星系结构无效")
		if system.orbits.size() > int(rules.max_orbits) or system.layers.size() > int(rules.max_layers):
			return _error("戴森规划超出上限")
		for field in ["sails_launched", "sails_expired", "rockets_launched"]:
			if not _int(system.get(field), 0, 9000000000000):
				return _error("戴森累计数量无效")
		var live := 0
		var absorbed := 0
		var built := 0
		for id in system.orbits:
			var orbit: Variant = system.orbits[id]
			if not orbit is Dictionary or not _id(id, orbit, "orbit", data, seen) or not _geometry(orbit) or not orbit.get("cohorts") is Array:
				return _error("太阳帆轨道无效")
			if orbit.cohorts.size() > int(rules.sail_lifetime_ticks):
				return _error("太阳帆批次数量无界")
			var previous := int(data.dyson_tick)
			for cohort in orbit.cohorts:
				if not cohort is Dictionary or not _int(cohort.get("count"), 1, 1000000) or not _int(cohort.get("expires_tick"), previous + 1, int(data.dyson_tick) + int(rules.sail_lifetime_ticks)):
					return _error("太阳帆批次到期时间或数量无效")
				previous = int(cohort.expires_tick)
				live += int(cohort.count)
		for id in system.layers:
			var layer: Variant = system.layers[id]
			if not layer is Dictionary or not _id(id, layer, "layer", data, seen) or not _geometry(layer) or not layer.get("nodes") is Dictionary or not layer.get("shell") is Dictionary:
				return _error("戴森层结构无效")
			if not layer.get("orbit_id") is String or not system.orbits.has(layer.orbit_id) or layer.nodes.size() > int(rules.max_nodes) or not _int(layer.get("absorption_ticks"), 0, int(rules.absorption_interval_ticks) - 1):
				return _error("戴森层轨道、节点数或吸附进度无效")
			var angles: Array = []
			var complete := true
			for node_id in layer.nodes:
				var node: Variant = layer.nodes[node_id]
				if not node is Dictionary or not _id(node_id, node, "node", data, seen) or not _number(node.get("angle"), 0, 359.999999) or not _int(node.get("points"), 0, int(rules.node_structure_points)):
					return _error("戴森节点无效")
				for angle in angles:
					var distance := absf(float(node.angle) - float(angle))
					if distance < 1 or distance > 359:
						return _error("戴森节点重复或过近")
				angles.append(node.angle)
				built += int(node.points)
				complete = complete and int(node.points) == int(rules.node_structure_points)
			if not layer.shell.is_empty():
				if layer.nodes.size() < 3 or layer.shell.size() != 1 or not _int(layer.shell.get("sails"), 0, layer.nodes.size() * int(rules.sails_per_node)):
					return _error("戴森壳面容量无效")
				if int(layer.shell.sails) > 0 and not complete:
					return _error("未完成结构不能吸附壳面")
				absorbed += int(layer.shell.sails)
			elif int(layer.absorption_ticks) != 0:
				return _error("未规划壳面不能有吸附进度")
		if int(system.sails_launched) != live + absorbed + int(system.sails_expired) or int(system.rockets_launched) != built:
			return _error("戴森发射材料不守恒")
	for building in data.get("buildings", {}).values():
		if not building is Dictionary or not building.has("dyson"):
			continue
		if building.get("type", "") not in DysonSphereSystem.AMMO or not building.dyson is Dictionary:
			return _error("非发射设备包含发射配置")
		var config: Dictionary = building.dyson
		if not config.get("enabled") is bool or not config.get("target_id") is String or not _number(config.get("progress"), 0, float(rules.launch_seconds[building.type])):
			return _error("发射设备配置无效")
		var system_id := String(galaxy.get_planet(String(building.get("planet_id", ""))).get("system_id", ""))
		var kind := "orbits" if building.type == "solar_sail_ejector" else "layers"
		if config.target_id != "" and not systems.get(system_id, {}).get(kind, {}).has(config.target_id):
			return _error("设备发射目标跨星系或不存在")
	return []

static func _id(id: Variant, value: Dictionary, prefix: String, data: Dictionary, seen: Dictionary) -> bool:
	if not id is String or value.get("id") != id or seen.has(id) or not id.begins_with(prefix + "_"):
		return false
	var suffix: String = id.trim_prefix(prefix + "_")
	if not suffix.is_valid_int() or int(suffix) < 1 or int(suffix) >= int(data.get("next_id", 0)):
		return false
	seen[id] = true
	return true

static func _geometry(value: Dictionary) -> bool:
	return _number(value.get("radius"), 5000, 50000) and _number(value.get("inclination"), -90, 90) and _number(value.get("longitude"), 0, 359.999999)

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _int(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))

static func _error(message: String) -> Array:
	return [{"code": "invalid_dyson_state", "entity_type": "dyson", "entity_id": "", "message": message}]

static func normalize_integer_fields(data: Dictionary) -> void:
	if _int(data.get("dyson_tick"), 0, 9000000000000):
		data.dyson_tick = int(data.dyson_tick)
	_normalize(data.get("dyson_systems", {}))

static func _normalize(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			if key in ["sails_launched", "sails_expired", "rockets_launched", "expires_tick", "count", "points", "sails", "absorption_ticks"] and _int(value[key], 0, 9000000000000):
				value[key] = int(value[key])
			else:
				_normalize(value[key])
	elif value is Array:
		for item in value:
			_normalize(item)
