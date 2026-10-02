class_name ContentPackValidator
extends RefCounted

const LIMITS := {"items": 256, "buildings": 128, "recipes": 512, "technologies": 256, "buildingOverrides": 128, "belts": 29}
const OVERRIDES := {"speed": [0.01, 1000], "inputCapacity": [0, 100000000], "outputCapacity": [0, 100000000], "powerDemandKw": [0, 1000000000000], "powerGenerationKw": [0, 1000000000000], "powerChargeKw": [0, 1000000000000], "energyCapacityMj": [0, 1000000000000], "stackLimit": [1, 1000000]}

static func pattern(value: Variant, regex: String) -> bool:
	if not value is String: return false
	var expression := RegEx.new()
	expression.compile(regex)
	return expression.search(value) != null

static func valid_id(value: Variant) -> bool:
	return pattern(value, "^[a-z][a-z0-9_]{1,63}$")

static func name_ok(value: Variant) -> bool:
	return value is String and value.strip_edges().length() in range(1, 121)

static func numeric(value: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and (not integer or float(value) == floorf(float(value)))

static func dependency(value: Variant) -> Dictionary:
	if not value is String: return {}
	var regex := RegEx.new()
	regex.compile("^([a-z][a-z0-9_]{1,63})(?:@((?:\\^|~|>=|<=|>|<|=)?[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?))?$")
	var found := regex.search(value.strip_edges())
	return {"id": found.get_string(1), "range": found.get_string(2)} if found != null else {}

static func version(value: Variant) -> Array:
	if not value is String: return []
	var regex := RegEx.new()
	regex.compile("^([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z.-]+))?$")
	var found := regex.search(value.strip_edges())
	if found == null: return []
	return [int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3)), found.get_string(4)]

static func satisfies(actual: String, spec: String = "") -> bool:
	var left := version(actual)
	if spec.is_empty(): return not left.is_empty()
	var op := "="
	for candidate in [">=", "<=", "^", "~", ">", "<", "="]:
		if spec.begins_with(candidate):
			op = candidate
			spec = spec.trim_prefix(candidate)
			break
	var right := version(spec)
	if left.is_empty() or right.is_empty(): return false
	var comparison := 0
	for index in range(3):
		if left[index] != right[index]:
			comparison = 1 if left[index] > right[index] else -1
			break
	if comparison == 0 and left[3] != right[3]:
		comparison = 1 if left[3] == "" else -1 if right[3] == "" else 1 if left[3] > right[3] else -1
	match op:
		"^": return left[0] == right[0] and comparison >= 0
		"~": return left[0] == right[0] and left[1] == right[1] and comparison >= 0
		">=": return comparison >= 0
		"<=": return comparison <= 0
		">": return comparison > 0
		"<": return comparison < 0
	return comparison == 0

static func amounts(value: Variant, known: Dictionary) -> bool:
	if not value is Array or value.size() > 24: return false
	for entry in value:
		if not entry is Dictionary or not valid_id(entry.get("itemId")) or not known.has(entry.itemId) or not numeric(entry.get("amount"), 0.000000000001, 1000000): return false
	return true

static func validate(value: Variant, core_ids: Dictionary, registry: Dictionary) -> Dictionary:
	var errors: Array = []
	if not value is Dictionary: return {"ok": false, "errors": ["内容包根节点必须是对象"]}
	var manifest: Dictionary = value.duplicate(true)
	if not numeric(manifest.get("formatVersion"), 1, 2, true) or not valid_id(manifest.get("id")) or not name_ok(manifest.get("name")) or version(manifest.get("version")).is_empty(): errors.append("内容包格式、ID、名称或语义版本无效")
	var dependencies: Variant = manifest.get("dependencies", [])
	if not dependencies is Array or dependencies.size() > 32: errors.append("依赖必须为最多 32 项的数组")
	else:
		for spec in dependencies:
			if dependency(spec).is_empty(): errors.append("依赖规格无效：" + str(spec))
	manifest["dependencies"] = dependencies if dependencies is Array else []
	var known := core_ids.duplicate(true)
	for pack in registry.values():
		if pack.manifest.get("id") == manifest.get("id"): continue
		for category in ["items", "buildings", "recipes", "technologies"]:
			for entry in pack.manifest.get(category, []): known[category][entry.id] = true
	var new_ids := {}
	for category in LIMITS:
		var entries: Variant = manifest.get(category, []) if manifest.get("formatVersion") == 2 or category not in ["buildingOverrides", "belts"] else []
		if not entries is Array or entries.size() > LIMITS[category]:
			errors.append(category + " 数量或格式无效")
			entries = []
		manifest[category] = entries
		new_ids[category] = {}
		for entry in entries:
			if not entry is Dictionary or not valid_id(entry.get("id")):
				errors.append(category + " 内容 ID 无效")
				continue
			if new_ids[category].has(entry.id): errors.append("重复 ID：" + entry.id)
			new_ids[category][entry.id] = true
			if category in known:
				if known[category].has(entry.id): errors.append("内容 ID 已占用：" + entry.id)
				known[category][entry.id] = true
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	for category in ["items", "buildings", "recipes", "technologies", "belts"]:
		for entry in manifest[category]:
			if not name_ok(entry.get("name")): errors.append("名称无效：" + entry.id)
	for entry in manifest.items:
		if entry.get("kind", "solid") not in ["solid", "fluid", "matrix"]: errors.append("物品类型无效：" + entry.id)
	for entry in manifest.buildings:
		if entry.get("kind", "machine") not in ["machine", "miner", "power", "storage", "splitter", "station"] or entry.get("accepts", "any") not in ["solid", "fluid", "any"]: errors.append("建筑类型无效：" + entry.id)
		for key in ["speed", "inputCapacity", "outputCapacity", "powerDemandKw", "powerGenerationKw", "outputAmount"]:
			if entry.has(key) and not numeric(entry[key], 0, 1000000): errors.append("建筑数值无效：" + entry.id + "." + key)
		if entry.has("costs") and not amounts(entry.costs, known.items): errors.append("施工成本无效：" + entry.id)
		if entry.has("requiredTechId") and not known.technologies.has(entry.requiredTechId): errors.append("施工科技不存在：" + entry.id)
	for entry in manifest.recipes:
		if not known.buildings.has(entry.get("buildingId", "")) or not numeric(entry.get("duration"), 0.000000000001, 86400) or not amounts(entry.get("inputs"), known.items) or not amounts(entry.get("outputs"), known.items): errors.append("配方设备、周期或物料无效：" + entry.id)
		if entry.has("requiredTechId") and not known.technologies.has(entry.requiredTechId): errors.append("配方科技不存在：" + entry.id)
	for entry in manifest.technologies:
		if not numeric(entry.get("tier", 0), 0, 99) or not amounts(entry.get("costs", []), known.items) or not entry.get("prerequisites", []) is Array: errors.append("科技层级、成本或前置无效：" + entry.id)
		else:
			for prerequisite in entry.get("prerequisites", []):
				if not known.technologies.has(prerequisite): errors.append("科技前置不存在：" + entry.id)
		if not entry.get("unlocks", []) is Array: errors.append("科技解锁说明无效：" + entry.id)
		else:
			for unlock in entry.get("unlocks", []):
				if not name_ok(unlock): errors.append("科技解锁说明必须为文本")
	for entry in manifest.buildingOverrides:
		if not core_ids.buildings.has(entry.id): errors.append("覆盖只能引用核心建筑：" + entry.id)
		var count := 0
		for key in OVERRIDES:
			if entry.has(key):
				count += 1
				if not numeric(entry[key], OVERRIDES[key][0], OVERRIDES[key][1], key in ["inputCapacity", "outputCapacity", "stackLimit"]): errors.append("覆盖字段无效：" + entry.id + "." + key)
		if count == 0: errors.append("覆盖至少需要一个白名单字段")
	var belt_tiers := {}
	for entry in manifest.belts:
		if not numeric(entry.get("tier"), 4, 32, true) or not numeric(entry.get("speed"), 0.000000000001, 1000000) or not amounts(entry.get("costs"), known.items) or not numeric(entry.get("outputAmount", 3), 1, 1000, true): errors.append("传送带等级、速度或成本无效：" + entry.id)
		if belt_tiers.has(entry.get("tier")): errors.append("传送带等级重复")
		belt_tiers[entry.get("tier")] = true
		for category in core_ids:
			if core_ids[category].has(entry.id): errors.append("传送带与核心 ID 冲突：" + entry.id)
		if entry.has("requiredTechId") and not known.technologies.has(entry.requiredTechId): errors.append("传送带科技不存在")
	for existing in registry.values():
		if existing.manifest.id == manifest.get("id"): continue
		for category in LIMITS:
			for entry in existing.manifest.get(category, []):
				if new_ids[category].has(entry.id): errors.append("已注册内容冲突：" + entry.id)
				if category == "belts" and belt_tiers.has(entry.tier): errors.append("已注册传送带等级冲突")
	var technology_graph := {}
	for existing in registry.values():
		if existing.manifest.id != manifest.get("id"):
			for entry in existing.manifest.get("technologies", []): technology_graph[entry.id] = entry.get("prerequisites", [])
	for entry in manifest.technologies: technology_graph[entry.id] = entry.get("prerequisites", [])
	if cyclic(technology_graph): errors.append("科技前置存在循环")
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	manifest.name = manifest.name.strip_edges().substr(0, 120)
	manifest.version = manifest.version.strip_edges().substr(0, 40)
	manifest.dependencies = Array(OrderedSet(manifest.dependencies))
	return {"ok": true, "manifest": manifest, "errors": []}

static func OrderedSet(values: Array) -> Array:
	var result := []
	for value in values:
		if not result.has(value.strip_edges()): result.append(value.strip_edges())
	return result

static func cyclic(graph: Dictionary) -> bool:
	var remaining := graph.duplicate(true)
	while not remaining.is_empty():
		var removable := []
		for id in remaining:
			if not remaining[id].any(func(parent): return remaining.has(parent)): removable.append(id)
		if removable.is_empty(): return true
		for id in removable: remaining.erase(id)
	return false