class_name OrbitalCollectorSystem
extends RefCounted

const TYPE := "dsp_orbital_collector"
const ITEMS := ["hydrogen", "deuterium", "fire_ice"]
const YIELDS := {"giant": {"hydrogen": 1.0, "deuterium": 0.2, "fire_ice": 0.5}, "boreal_giant": {"hydrogen": 0.8, "deuterium": 0.12, "fire_ice": 1.0}}

var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

static func initialize(building: Dictionary) -> void:
	building["collector_item"] = "hydrogen"
	building["collector_progress"] = 0.0
	for index in range(ITEMS.size()):
		var slot: Dictionary = building.station.slots[index]
		slot.item_id = ITEMS[index]
		slot.local_mode = "storage"
		slot.remote_mode = "supply" if index == 0 else "storage"
		slot.mode = slot.remote_mode

func select_item(id: String, item: String) -> Dictionary:
	var building: Dictionary = state.buildings.get(id, {})
	if building.get("type") != TYPE or building.get("interaction_locked", false) or not SourceGalaxySystem.new(state).orbital_yields(building.get("planet_id", "")).has(item): return {"ok": false, "message": "该采集器不能采集所选物品"}
	if StationSystem.new(state).has_route(id): return {"ok": false, "message": "请先等待关联航线返航"}
	building.collector_item = item
	building.collector_progress = 0.0
	for slot in building.station.slots:
		slot.remote_mode = "supply" if slot.item_id == item else "storage"
		slot.mode = slot.remote_mode
	return {"ok": true, "message": "采集物品已更新；已有物资保留在各自库存"}

func update(delta: float, statistics: StatisticsSystem = null) -> void:
	if not is_finite(delta) or delta <= 0: return
	for building in state.buildings.values():
		if building.get("type") != TYPE or not building.get("station", {}).get("enabled", false): continue
		var item: String = building.get("collector_item", "hydrogen")
		var index := ITEMS.find(item)
		if index < 0: continue
		var slot: Dictionary = building.station.slots[index]
		var free := maxi(0, int(floorf(StationSystem.capacity_for(slot, state, building) - float(slot.amount) - float(building.get("output_buffer", {}).get(item, 0)))))
		if free < 1:
			building.collector_progress = 0.0
			continue
		var galaxy := SourceGalaxySystem.new(state)
		var rate := float(galaxy.orbital_yields(building.planet_id).get(item, 0)) * float(galaxy.profile(building.planet_id).get("orbitalYieldMultiplier", 1.0)) * SourceTechnologyEffects.multiplier(state, "resource_collection") * StationSystem.stack_count(building)
		var progress := float(building.get("collector_progress", 0)) + rate * delta
		var produced := mini(free, int(floorf(progress + SimulationEngine.STEP_EPSILON)))
		slot.amount += float(produced)
		building.collector_progress = 0.0 if produced >= free else snappedf(progress - produced, 0.000001)
		if statistics != null and produced > 0: statistics.record_produced(item, produced, building.id, building.planet_id)

static func validate(data: Dictionary) -> Array:
	var errors := []
	var buildings: Variant = data.get("buildings", {})
	if not buildings is Dictionary: return errors
	for building in buildings.values():
		if not building is Dictionary: continue
		if building.get("type") != TYPE:
			if building.has("collector_item") or building.has("collector_progress"): errors.append("非采集器含轨道采集状态")
			continue
		var available: Dictionary = YIELDS.get(building.get("planet_id"), {})
		var source: Variant = data.get("source_galaxy", {})
		if source is Dictionary and not source.is_empty(): available = source.get("profiles", {}).get(building.get("planet_id"), {}).get("orbitalYields", {})
		if available.is_empty() or not available.has(building.get("collector_item")): errors.append("轨道采集器行星或物品无效")
		var progress: Variant = building.get("collector_progress")
		if not (progress is int or progress is float) or not is_finite(float(progress)) or float(progress) < 0 or float(progress) >= 1.000001: errors.append("轨道采集余数无效")
		var slots: Variant = building.get("station", {}).get("slots") if building.get("station") is Dictionary else null
		if not slots is Array or slots.size() != ITEMS.size():
			errors.append("轨道采集槽位无效")
			continue
		for index in range(ITEMS.size()):
			var slot: Variant = slots[index]
			var mode := "supply" if ITEMS[index] == building.get("collector_item") else "storage"
			if not slot is Dictionary or slot.get("item_id") != ITEMS[index] or slot.get("local_mode") != "storage" or slot.get("remote_mode") != mode or slot.get("mode") != mode or slot.get("capacity") != 2000.0 * StationSystem.stack_count(building): errors.append("轨道采集槽位与所选物品不符")
	return errors
