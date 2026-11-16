extends RefCounted

static func consumption_tenths(state: GameState, item: String) -> int:
	if DataManager.get_item(item).get("kind") != "solid": return 10
	return maxi(0, 10 - mini(InfiniteResearchSystem.new(state).level("vein_utilization"), 10))

static func is_infinite(state: GameState, site: Dictionary) -> bool:
	var item := String(site.get("item_id", ""))
	if item.is_empty(): return false
	if state.resource_mode == "infinite" or bool(site.get("infinite", false)) or consumption_tenths(state, item) == 0: return true
	var ocean := String(state.source_galaxy.get("profiles", {}).get(String(site.get("planet_id", "")), {}).get("oceanType", ""))
	return (item == "water" and ocean == "water") or (item == "sulfuric_acid" and ocean == "sulfuric-acid")

static func snapshot(state: GameState, site: Variant) -> Variant:
	if not site is Dictionary or site.get("kind", "vein") != "vein" or String(site.get("item_id", "")).is_empty(): return null
	if is_infinite(state, site):
		return {"infinite": true, "exhausted": false, "remaining": null, "capacity": null, "remainingRatio": 1, "remainingPercent": 100}
	var remaining := maxf(0, floorf(float(site.get("remaining", 0))))
	var capacity := maxf(remaining, floorf(float(site.get("capacity", remaining))))
	var ratio := clampf(remaining / capacity, 0, 1) if capacity > 0 else 0.0
	var allowance := _finite_output_allowance(state, site, _is_registered_native_site(state, site))
	return {"infinite": false, "exhausted": allowance < 1, "remaining": remaining, "capacity": capacity, "remainingRatio": ratio, "remainingPercent": preload("res://scripts/game/ProductionSystem.gd")._source_round(ratio * 100, 0)}

static func _is_registered_native_site(state: GameState, site: Dictionary) -> bool:
	var registered: Variant = state.resource_sites.get(String(site.get("id", "")))
	if not registered is Dictionary or not site.get("position") is Vector2 or not site.get("infinite") is bool: return false
	for field in ["id", "planet_id", "item_id", "position", "capacity", "infinite"]:
		if not site.has(field) or site[field] != registered.get(field): return false
	return true

static func available_output(state: GameState, site: Dictionary) -> float:
	if is_infinite(state, site): return INF
	return _finite_output_allowance(state, site, true)

static func _finite_output_allowance(state: GameState, site: Dictionary, preserve_fractional: bool) -> float:
	# Native schema-v9 saves retain fractional reserve; source vein projections floor it.
	var raw := float(site.get("remaining", 0))
	var reserve := maxf(0, raw if preserve_fractional else floorf(raw))
	var remainder := clampf(floorf(float(site.get("depletion_remainder", 0))), 0, 9)
	return floorf(maxf(0, reserve * 10 - remainder) / consumption_tenths(state, String(site.get("item_id", ""))))

static func consume_output(state: GameState, site: Dictionary, amount: int) -> void:
	if amount < 1 or is_infinite(state, site): return
	var reserve := maxf(0, floorf(float(site.get("remaining", 0))))
	var accrued := clampf(floorf(float(site.get("depletion_remainder", 0))), 0, 9) + amount * consumption_tenths(state, String(site.get("item_id", "")))
	var depleted := minf(reserve, floorf(accrued / 10))
	site.remaining = float(site.get("remaining", 0)) - depleted
	site.depletion_remainder = accrued - depleted * 10
