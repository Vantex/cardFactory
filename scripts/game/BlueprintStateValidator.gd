class_name BlueprintStateValidator
extends RefCounted

static func validate(data: Dictionary) -> Array:
	var library: Variant = data.get("blueprint_library", {})
	var queue: Variant = data.get("construction_queue", [])
	var regions: Variant = data.get("canvas_regions", [])
	var bookmarks: Variant = data.get("canvas_bookmarks", [])
	if not library is Dictionary or not queue is Array or not regions is Array or not bookmarks is Array: return [_error("蓝图/施工/导航根状态无效")]
	if queue.size() > 100 or regions.size() > 48 or bookmarks.size() > 24: return [_error("施工或导航数量超限")]
	var ids := {}
	for key in library:
		var entry: Variant = library[key]
		if not entry is Dictionary or entry.get("id") != key or not _id(entry, "blueprint", data, ids) or not _definition(entry): return [_error("蓝图库定义无效")]
	for order in queue:
		if not order is Dictionary or not _id(order, "construction", data, ids) or not _definition(order) or not data.get("colonized_planet_ids", []).has(order.get("planet_id")) or not _point(order.get("position")) or not order.get("allow_overlap") is bool: return [_error("施工订单定义无效")]
		if not order.get("placed") is Dictionary or not order.get("reserved") is Dictionary or not order.get("fleet_reserved") is Dictionary: return [_error("施工订单所有权无效")]
		var bp: Dictionary = BlueprintCodec.new().decode(order.text).blueprint
		var costs := {}
		var refs := {}
		for entity in bp.entities:
			refs[entity.ref] = entity
			costs[entity.type] = float(costs.get(entity.type, 0)) + 1
			if entity.configuration.get("spray_coater_installed", false): costs.dsp_spray_coater = float(costs.get("dsp_spray_coater", 0)) + 1
		for link in bp.connections: costs[link.type] = float(costs.get(link.type, 0)) + float(link.configuration.get("parallel_count", 1))
		if not _amounts(order.reserved, costs): return [_error("施工预留超过需求")]
		if not order.placed.is_empty():
			if not order.reserved.is_empty() or order.placed.size() != refs.size(): return [_error("已建订单仍持有施工件或实体引用缺失")]
			for ref in order.placed:
				if not refs.has(ref) or not order.placed[ref] is String: return [_error("已建实体引用无效")]
		var fleet := {}
		for target in order.get("fleet_targets", {}).values():
			for item in target: fleet[item] = float(fleet.get(item, 0)) + float(target[item])
		if not _amounts(order.fleet_reserved, fleet): return [_error("载具预留超过需求")]
	for bookmark in bookmarks:
		if not bookmark is Dictionary or not _id(bookmark, "bookmark", data, ids) or not _name(bookmark.get("name"), 28) or not data.get("colonized_planet_ids", []).has(bookmark.get("planet_id")) or not _point(bookmark.get("position")) or not _number(bookmark.get("zoom"), 0.1, 2.5): return [_error("书签无效")]
	for region in regions:
		if not region is Dictionary or not _id(region, "region", data, ids) or not _name(region.get("name"), 28) or not data.get("colonized_planet_ids", []).has(region.get("planet_id")): return [_error("区域引用无效")]
		var rect: Variant = region.get("rect")
		if not rect is Array or rect.size() != 4 or not _point(rect.slice(0, 2)) or not _number(rect[2], 0.001, 200000) or not _number(rect[3], 0.001, 200000) or not region.get("color") is String or not Color.html_is_valid(region.color): return [_error("区域矩形或颜色无效")]
		if not _point([rect[0] + rect[2], rect[1] + rect[3]]): return [_error("区域终点超出画布范围")]
	return []

static func _definition(entry: Dictionary) -> bool:
	if not _name(entry.get("name"), 32) or not entry.get("text") is String or not _number(entry.get("rotation"), 0, 3) or float(entry.rotation) != floorf(entry.rotation) or not entry.get("mirrored") is bool or not entry.get("overrides", {}) is Dictionary: return false
	var result := BlueprintLibrary.resolve(entry)
	if not result.ok: return false
	var targets: Variant = entry.get("fleet_targets", {})
	if not targets is Dictionary: return false
	var refs := {}
	for entity in result.blueprint.entities: refs[entity.ref] = entity.type
	for ref in targets:
		if not refs.has(ref) or refs[ref] not in StationSystem.TYPES or not targets[ref] is Dictionary: return false
		for item in targets[ref]:
			if item not in StationSystem.FLEET_ITEMS or (refs[ref] == StationSystem.TYPES[0] and item != "logistics_drone") or not _number(targets[ref][item], 0, 999) or float(targets[ref][item]) != floorf(targets[ref][item]): return false
	return true

static func _id(entry: Dictionary, prefix: String, data: Dictionary, ids: Dictionary) -> bool:
	var id: Variant = entry.get("id")
	if not id is String or not id.begins_with(prefix + "_") or not id.trim_prefix(prefix + "_").is_valid_int() or ids.has(id): return false
	var number := int(id.trim_prefix(prefix + "_"))
	if number < 1 or number >= float(data.get("next_id", 0)): return false
	ids[id] = true
	return true

static func _amounts(amounts: Dictionary, limits: Dictionary) -> bool:
	for item in amounts:
		if not limits.has(item) or not _number(amounts[item], 0, float(limits[item])) or float(amounts[item]) != floorf(amounts[item]): return false
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -100000, 100000) and _number(value[1], -100000, 100000)
static func _name(value: Variant, limit: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= limit
static func _error(message: String) -> Dictionary:
	return {"code": "invalid_blueprint_state", "source": "state", "id": "", "message": message}
