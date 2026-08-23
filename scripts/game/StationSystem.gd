# scripts/game/StationSystem.gd
class_name StationSystem
extends RefCounted

var game_state: GameState

# 物流站配置
var station_slots: Dictionary = {}

func _init(state: GameState):
    game_state = state

# === 物流站系统功能（30个） ===

# 1. 创建物流站
func create_station(station_id: String, station_type: String) -> bool:
    if not game_state.buildings.has(station_id):
        print("ERROR: Station not found: ", station_id)
        return false
    
    var station_data = {
        "id": station_id,
        "type": station_type,
        "slots": [],
        "drones": 0,
        "vessels": 0,
        "warpers": 0
    }
    
    # 根据类型设置默认值
    if station_type == "planetary_logistics_station":
        station_data["drones"] = 10
        station_data["slot_count"] = 4
    elif station_type == "interstellar_logistics_station":
        station_data["drones"] = 10
        station_data["vessels"] = 10
        station_data["slot_count"] = 4
    
    # 初始化槽位
    for i in range(station_data["slot_count"]):
        station_data["slots"].append({
            "item_id": "",
            "mode": "storage",
            "min_load": 0.1,
            "max_load": 1.0,
            "priority": 0
        })
    
    station_slots[station_id] = station_data
    print("Created station: ", station_id, " type: ", station_type)
    return true

# 2. 设置槽位物品
func set_station_slot_item(station_id: String, slot_index: int, item_id: String) -> bool:
    if not station_slots.has(station_id):
        print("ERROR: Station not found: ", station_id)
        return false
    
    var station = station_slots[station_id]
    if slot_index < 0 or slot_index >= station["slots"].size():
        print("ERROR: Invalid slot index: ", slot_index)
        return false
    
    station["slots"][slot_index]["item_id"] = item_id
    print("Set station ", station_id, " slot ", slot_index, " to ", item_id)
    return true

# 3. 设置槽位模式
func set_station_slot_mode(station_id: String, slot_index: int, mode: String) -> bool:
    if not station_slots.has(station_id):
        print("ERROR: Station not found: ", station_id)
        return false
    
    var station = station_slots[station_id]
    if slot_index < 0 or slot_index >= station["slots"].size():
        print("ERROR: Invalid slot index: ", slot_index)
        return false
    
    var valid_modes = ["supply", "demand", "storage"]
    if mode not in valid_modes:
        print("ERROR: Invalid mode: ", mode)
        return false
    
    station["slots"][slot_index]["mode"] = mode
    print("Set station ", station_id, " slot ", slot_index, " mode to ", mode)
    return true

# 4. 设置最小负载
func set_station_slot_min_load(station_id: String, slot_index: int, min_load: float) -> bool:
    if not station_slots.has(station_id):
        print("ERROR: Station not found: ", station_id)
        return false
    
    var station = station_slots[station_id]
    if slot_index < 0 or slot_index >= station["slots"].size():
        print("ERROR: Invalid slot index: ", slot_index)
        return false
    
    var clamped_load = clamp(min_load, 0.0, 1.0)
    station["slots"][slot_index]["min_load"] = clamped_load
    print("Set station ", station_id, " slot ", slot_index, " min load to ", clamped_load)
    return true

# 5. 设置最大负载
func set_station_slot_max_load(station_id: String, slot_index: int, max_load: float) -> bool:
    if not station_slots.has(station_id):
        print("ERROR: Station not found: ", station_id)
        return false
    
    var station = station_slots[station_id]
    if slot_index < 0 or slot_index >= station["slots"].size():
        print("ERROR: Invalid slot index: ", slot_index)
        return false
    
    var clamped_load = clamp(max_load, 0.0, 1.0)
    station["slots"][slot_index]["max_load"] = clamped_load
    print("Set station ", station_id, " slot ", slot_index, " max load to ", clamped_load)
    return true

# 6. 设置优先级
func set_station_slot_priority(station_id: String, slot_index: int, priority: int) -> bool:
    if not station_slots.has(station_id):
        print("ERROR: Station not found: ", station_id)
        return false
    
    var station = station_slots[station_id]
    if slot_index < 0 or slot_index >= station["slots"].size():
        print("ERROR: Invalid slot index: ", slot_index)
        return false
    
    var clamped_priority = clamp(priority, 0, 2)
    station["slots"][slot_index]["priority"] = clamped_priority
    print("Set station ", station_id, " slot ", slot_index, " priority to ", clamped_priority)
    return true

# 7. 获取物流站信息
func get_station_info(station_id: String) -> Dictionary:
    return station_slots.get(station_id, {})

# 8. 获取物流站槽位
func get_station_slots(station_id: String) -> Array:
    var station = station_slots.get(station_id, {})
    return station.get("slots", [])

# 9. 更新物流站
func update_stations(delta: float):
    for station_id in station_slots:
        _update_station(station_id, delta)

# 10. 更新单个物流站
func _update_station(station_id: String, delta: float):
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return
    
    # 这里可以添加物流站的更新逻辑

# 11. 获取物流站类型
func get_station_type(station_id: String) -> String:
    var station = station_slots.get(station_id, {})
    return station.get("type", "")

# 12. 获取无人机数量
func get_drone_count(station_id: String) -> int:
    var station = station_slots.get(station_id, {})
    return station.get("drones", 0)

# 13. 获取飞船数量
func get_vessel_count(station_id: String) -> int:
    var station = station_slots.get(station_id, {})
    return station.get("vessels", 0)

# 14. 获取翘曲器数量
func get_warper_count(station_id: String) -> int:
    var station = station_slots.get(station_id, {})
    return station.get("warpers", 0)

# 15. 设置无人机数量
func set_drone_count(station_id: String, count: int) -> bool:
    if not station_slots.has(station_id):
        return false
    station_slots[station_id]["drones"] = count
    return true

# 16. 设置飞船数量
func set_vessel_count(station_id: String, count: int) -> bool:
    if not station_slots.has(station_id):
        return false
    station_slots[station_id]["vessels"] = count
    return true

# 17. 设置翘曲器数量
func set_warper_count(station_id: String, count: int) -> bool:
    if not station_slots.has(station_id):
        return false
    station_slots[station_id]["warpers"] = count
    return true

# 18. 获取槽位数量
func get_slot_count(station_id: String) -> int:
    var station = station_slots.get(station_id, {})
    return station.get("slot_count", 0)

# 19. 清空槽位
func clear_station_slot(station_id: String, slot_index: int) -> bool:
    if not station_slots.has(station_id):
        return false
    
    var station = station_slots[station_id]
    if slot_index < 0 or slot_index >= station["slots"].size():
        return false
    
    station["slots"][slot_index] = {
        "item_id": "",
        "mode": "storage",
        "min_load": 0.1,
        "max_load": 1.0,
        "priority": 0
    }
    return true

# 20. 清空所有槽位
func clear_all_slots(station_id: String) -> bool:
    if not station_slots.has(station_id):
        return false
    
    var station = station_slots[station_id]
    for i in range(station["slots"].size()):
        clear_station_slot(station_id, i)
    return true

# 21. 获取供应槽位
func get_supply_slots(station_id: String) -> Array:
    var slots = get_station_slots(station_id)
    var supply_slots = []
    for slot in slots:
        if slot.get("mode") == "supply":
            supply_slots.append(slot)
    return supply_slots

# 22. 获取需求槽位
func get_demand_slots(station_id: String) -> Array:
    var slots = get_station_slots(station_id)
    var demand_slots = []
    for slot in slots:
        if slot.get("mode") == "demand":
            demand_slots.append(slot)
    return demand_slots

# 23. 获取存储槽位
func get_storage_slots(station_id: String) -> Array:
    var slots = get_station_slots(station_id)
    var storage_slots = []
    for slot in slots:
        if slot.get("mode") == "storage":
            storage_slots.append(slot)
    return storage_slots

# 24. 检查槽位是否为空
func is_slot_empty(station_id: String, slot_index: int) -> bool:
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return true
    
    var slots = station.get("slots", [])
    if slot_index < 0 or slot_index >= slots.size():
        return true
    
    return slots[slot_index].get("item_id", "").is_empty()

# 25. 获取槽位物品
func get_slot_item(station_id: String, slot_index: int) -> String:
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return ""
    
    var slots = station.get("slots", [])
    if slot_index < 0 or slot_index >= slots.size():
        return ""
    
    return slots[slot_index].get("item_id", "")

# 26. 获取槽位模式
func get_slot_mode(station_id: String, slot_index: int) -> String:
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return ""
    
    var slots = station.get("slots", [])
    if slot_index < 0 or slot_index >= slots.size():
        return ""
    
    return slots[slot_index].get("mode", "storage")

# 27. 获取槽位最小负载
func get_slot_min_load(station_id: String, slot_index: int) -> float:
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return 0.0
    
    var slots = station.get("slots", [])
    if slot_index < 0 or slot_index >= slots.size():
        return 0.0
    
    return slots[slot_index].get("min_load", 0.1)

# 28. 获取槽位最大负载
func get_slot_max_load(station_id: String, slot_index: int) -> float:
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return 0.0
    
    var slots = station.get("slots", [])
    if slot_index < 0 or slot_index >= slots.size():
        return 0.0
    
    return slots[slot_index].get("max_load", 1.0)

# 29. 获取槽位优先级
func get_slot_priority(station_id: String, slot_index: int) -> int:
    var station = station_slots.get(station_id, {})
    if station.is_empty():
        return 0
    
    var slots = station.get("slots", [])
    if slot_index < 0 or slot_index >= slots.size():
        return 0
    
    return slots[slot_index].get("priority", 0)

# 30. 删除物流站
func remove_station(station_id: String) -> bool:
    if station_slots.has(station_id):
        station_slots.erase(station_id)
        print("Removed station: ", station_id)
        return true
    return false
