class_name PlanetTraySystem
extends RefCounted
const MIN_LIMIT := 1000.0
const MAX_LIMIT := 100000000.0
const DEFAULT_LIMIT := 1000000.0
var state: GameState
func _init(game_state: GameState) -> void: state = game_state
func limit(planet_id: String = "") -> float:
	var id := state.active_planet_id if planet_id == "" else planet_id
	if state.source_galaxy.is_empty(): return float(state.planet_tray_limits.get(id, InventorySystem.MAX_PLANET_STACK))
	var value: Variant = state.planet_tray_limits.get(id, DEFAULT_LIMIT)
	return clampf(floorf(float(value)), MIN_LIMIT, MAX_LIMIT) if (value is int or value is float) and is_finite(float(value)) else DEFAULT_LIMIT
func free_capacity(planet_id: String, item_id: String) -> float:
	if item_id in ["logistics_drone", "logistics_vessel"]: return INF
	var tray := state.planet_inventory if planet_id == state.active_planet_id else state.get_planet_inventory(planet_id)
	return maxf(0, limit(planet_id) - floorf(float(tray.get(item_id, 0))))
func set_limit(planet_id: String, value: float) -> Dictionary:
	if state.source_galaxy.is_empty() or not is_finite(value) or GalaxySystem.new(state).get_planet(planet_id).is_empty(): return {"ok": false, "message": "请选择源版星图中的有效行星"}
	state.planet_tray_limits[planet_id] = clampf(floorf(value), MIN_LIMIT, MAX_LIMIT)
	return {"ok": true, "message": "托盘容量已设置；已有库存保留，超出容量时停止继续入库"}
func discard(planet_id: String, item: String, amount: float, confirmed: bool) -> Dictionary:
	return discard_batch(planet_id, [{"itemId": item, "amount": amount}], confirmed)

func discard_batch(planet_id: String, requests: Array, confirmed: bool) -> Dictionary:
	if not confirmed: return {"ok": false, "message": "请确认丢弃物料"}
	var valid_planet: bool = state.colonized_planet_ids.has(planet_id) if state.source_galaxy.is_empty() else SourceGalaxySystem.catalog().planets.has(planet_id)
	if not valid_planet: return {"ok": false, "message": "行星不存在"}
	var requested := {}
	for request in requests:
		if not request is Dictionary or not request.get("itemId") is String or not DataManager.all_items.has(request.itemId): continue
		var amount: Variant = request.get("amount")
		if not (amount is int or amount is float) or not is_finite(float(amount)): continue
		var integral := floorf(maxf(0, float(amount)))
		if integral >= 1: requested[request.itemId] = float(requested.get(request.itemId, 0)) + integral
	var source: Dictionary = state.planet_inventory if planet_id == state.active_planet_id else state.planet_inventories.get(planet_id, {})
	var next := source.duplicate(true)
	var removed := {}
	for item in requested:
		var owned: Variant = next.get(item, 0)
		if not (owned is int or owned is float) or not is_finite(float(owned)): continue
		var count := minf(floorf(maxf(0, float(owned))), float(requested[item]))
		if count < 1: continue
		# Local production owns continuous quantities; delete whole units only.
		var remaining := float(owned) - count
		if remaining > 0: next[item] = remaining
		else: next.erase(item)
		removed[item] = count
	if removed.is_empty(): return {"ok": false, "message": "没有可丢弃的整份物料"}
	state.planet_inventories[planet_id] = next
	if planet_id == state.active_planet_id: state.planet_inventory = next
	return {"ok": true, "message": "托盘物料已丢弃", "removed": removed}
static func validate(data: Dictionary) -> Array:
	var raw: Variant = data.get("planet_tray_limits", {})
	if not raw is Dictionary: return ["行星托盘容量配置无效"]
	if not raw.is_empty() and data.get("source_galaxy", {}).is_empty(): return ["旧星图不能携带源托盘容量配置"]
	var rules := GameState.new()
	rules.source_galaxy = data.get("source_galaxy", {}).duplicate(true)
	for id in raw:
		if not id is String or GalaxySystem.new(rules).get_planet(id).is_empty() or not ContentPackValidator.numeric(raw[id], MIN_LIMIT, MAX_LIMIT, true): return ["行星托盘容量或行星 ID 无效"]
	return []
