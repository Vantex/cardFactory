class_name PlanetTraySystem
extends RefCounted
const MIN_LIMIT := 1000.0
const MAX_LIMIT := 100000000.0
const DEFAULT_LIMIT := 1000000.0
var state: GameState
func _init(game_state: GameState) -> void: state = game_state
func limit(planet_id: String = "") -> float:
	var id := state.active_planet_id if planet_id == "" else planet_id
	return float(state.planet_tray_limits.get(id, DEFAULT_LIMIT if not state.source_galaxy.is_empty() else InventorySystem.MAX_PLANET_STACK))
func set_limit(planet_id: String, value: float) -> Dictionary:
	if state.source_galaxy.is_empty() or not is_finite(value) or GalaxySystem.new(state).get_planet(planet_id).is_empty(): return {"ok": false, "message": "请选择源版星图中的有效行星"}
	state.planet_tray_limits[planet_id] = clampf(floorf(value), MIN_LIMIT, MAX_LIMIT)
	return {"ok": true, "message": "托盘容量已设置；已有库存保留，超出容量时停止继续入库"}
func discard(planet_id: String, item: String, amount: float, confirmed: bool) -> Dictionary:
	if not confirmed or not is_finite(amount) or amount < 1 or not state.colonized_planet_ids.has(planet_id): return {"ok": false, "message": "请选择物品、数量并确认丢弃"}
	return InventorySystem.new(state).try_remove(item, minf(floorf(amount), floorf(state.get_planet_inventory(planet_id).get(item, 0))), planet_id)
static func validate(data: Dictionary) -> Array:
	var raw: Variant = data.get("planet_tray_limits", {})
	if not raw is Dictionary: return ["行星托盘容量配置无效"]
	if not raw.is_empty() and data.get("source_galaxy", {}).is_empty(): return ["旧星图不能携带源托盘容量配置"]
	var rules := GameState.new()
	rules.source_galaxy = data.get("source_galaxy", {}).duplicate(true)
	for id in raw:
		if not id is String or GalaxySystem.new(rules).get_planet(id).is_empty() or not ContentPackValidator.numeric(raw[id], MIN_LIMIT, MAX_LIMIT, true): return ["行星托盘容量或行星 ID 无效"]
	return []