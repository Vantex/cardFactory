extends RefCounted

const MINIMUM := 1000
const DEFAULT := 1000000
const MAXIMUM := 100000000

static func buffer_limit(state: GameState, entity: Dictionary) -> int:
	var definition := DataManager.get_building(String(entity.get("type", "")))
	var logistics: bool = definition.get("kind", "") in ["storage", "splitter", "station"]
	return _limit(state.source_buffer_limits.get("logistics" if logistics else "production"))

static func input_capacity(state: GameState, entity: Dictionary) -> int:
	return _capacity(state, entity, "source_input_capacity")

static func output_capacity(state: GameState, entity: Dictionary) -> int:
	return _capacity(state, entity, "source_output_capacity")

static func station_slot_capacity(state: GameState, entity: Dictionary, slot: Dictionary) -> float:
	var rated := float(output_capacity(state, entity))
	var maximum: Variant = slot.get("max_stock", 0)
	return minf(rated, float(maximum)) if _number(maximum) and maximum > 0 else rated

static func item_input_capacity(state: GameState, entity: Dictionary, item: String) -> float:
	var definition := DataManager.get_building(String(entity.get("type", "")))
	if definition.get("kind") == "station" and definition.get("source_id") != "orbital_collector":
		var slots: Array = entity.get("station", {}).get("slots", [])
		if slots.is_empty() and not String(entity.get("stored_item", "")).is_empty() and entity.stored_item == item:
			return station_slot_capacity(state, entity, {"max_stock": 0})
		for slot in slots.slice(0, 5):
			if not slot is Dictionary or String(slot.get("item_id", "")).is_empty() or slot.get("item_id") != item or DataManager.get_item(item).is_empty(): continue
			var raw: Variant = slot.get("max_stock", 0)
			var maximum := maxf(0, floorf(float(raw))) if _number(raw) else 0.0
			return station_slot_capacity(state, entity, {"max_stock": maximum})
	var rated := float(input_capacity(state, entity))
	var tier: Variant = entity.get("proliferator_tier")
	if entity.get("spray_coater_installed", false) and _number(tier) and tier == floorf(float(tier)) and tier >= 1 and tier <= 3 and item == "proliferator_mk%d" % int(tier):
		var raw: Variant = state.source_buffer_limits.get("proliferator")
		var maximum := int(clampf(floorf(float(raw)), 1, MAXIMUM)) if _number(raw) else 600
		return minf(rated, maximum)
	return rated

static func _capacity(state: GameState, entity: Dictionary, field: String) -> int:
	var definition := DataManager.get_building(String(entity.get("type", "")))
	var base := maxi(0, int(floorf(float(definition.get(field, 0)))))
	var raw: Variant = entity.get("machine_count", 1)
	if definition.get("kind") == "station": raw = entity.get("station_stack_count", raw)
	var count := maxf(1, floorf(float(raw))) if _number(raw) else 1.0
	var limit := buffer_limit(state, entity)
	if base == 0: return 0
	if float(base) > float(limit) / count: return limit
	return mini(limit, int(float(base) * count))

static func _limit(value: Variant) -> int:
	if not _number(value): return DEFAULT
	return int(clampf(floorf(float(value)), MINIMUM, MAXIMUM))

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func validate(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not payload.has("source_buffer_limits"): return errors
	var limits: Variant = payload.source_buffer_limits
	if not limits is Dictionary: return ["建筑缓冲上限必须是字典"]
	for key in limits:
		if key not in ["production", "logistics", "proliferator"]: errors.append("未知建筑缓冲上限字段")
		var value: Variant = limits[key]
		var minimum := 1 if key == "proliferator" else MINIMUM
		if not _number(value) or float(value) != floorf(float(value)) or value < minimum or value > MAXIMUM: errors.append("喷涂缓冲上限必须是 1 到 100000000 的整数" if key == "proliferator" else "建筑缓冲上限必须是 1000 到 100000000 的整数")
	return errors

static func site_output_capacity(state: GameState, site_id: String) -> int:
	var site: Dictionary = state.resource_sites.get(site_id, {})
	if site.is_empty(): return 0
	var limit := buffer_limit(state, site)
	var total := 0
	for entity in state.buildings.values():
		if entity.get("resource_site_id") != site_id: continue
		var definition := DataManager.get_building(String(entity.get("type", "")))
		if not definition.has("source_id") or definition.get("kind") != "extractor": continue
		total = mini(limit, total + output_capacity(state, entity))
	return total
