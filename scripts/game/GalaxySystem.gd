# scripts/game/GalaxySystem.gd
class_name GalaxySystem
extends RefCounted

var game_state: GameState

# 星系定义
var star_systems: Dictionary = {}

func _init(state: GameState):
    game_state = state
    _load_star_systems()

func _load_star_systems():
    # 母恒星系
    star_systems["helios"] = {
        "id": "helios",
        "name": "赫利俄斯",
        "code": "母恒星系",
        "star_type": "G 型主序星",
        "color": "#e1b452",
        "distance_ly": 0.0,
        "description": "工业网络的起点，拥有海洋、熔岩与气态巨星三种基础生态",
        "planet_ids": ["home", "ashen", "giant"],
        "exploration_cost": [],
        "prerequisite_system_id": ""
    }
    
    # 冰晶恒星系
    star_systems["borealis"] = {
        "id": "borealis",
        "name": "北冕座",
        "code": "冰晶恒星系",
        "star_type": "K 型橙矮星",
        "color": "#79aeb9",
        "distance_ly": 4.2,
        "description": "低温行星保存了天然微观结构，是可燃冰与高阶晶体的主要产区",
        "planet_ids": ["frost", "boreal_giant"],
        "exploration_cost": [{"item_id": "space_warper", "amount": 2}],
        "prerequisite_system_id": "helios"
    }
    
    # 中子星系
    star_systems["neutron"] = {
        "id": "neutron",
        "name": "赫卡忒",
        "code": "中子星系",
        "star_type": "中子星",
        "color": "#a88ec5",
        "distance_ly": 11.8,
        "description": "极端磁场重塑了行星矿层，可持续开采极为稀有的单极磁石",
        "planet_ids": ["magnetar"],
        "exploration_cost": [{"item_id": "space_warper", "amount": 5}],
        "prerequisite_system_id": "borealis"
    }
    
    print("Loaded ", star_systems.size(), " star systems")

# === 星系系统功能（25个） ===

# 1. 获取星系定义
func get_star_system(system_id: String) -> Dictionary:
    return star_systems.get(system_id, {})

# 2. 获取所有星系
func get_all_star_systems() -> Dictionary:
    return star_systems

# 3. 获取星系名称
func get_system_name(system_id: String) -> String:
    var system = get_star_system(system_id)
    return system.get("name", "")

# 4. 获取星系代码
func get_system_code(system_id: String) -> String:
    var system = get_star_system(system_id)
    return system.get("code", "")

# 5. 获取恒星类型
func get_star_type(system_id: String) -> String:
    var system = get_star_system(system_id)
    return system.get("star_type", "")

# 6. 获取星系颜色
func get_system_color(system_id: String) -> String:
    var system = get_star_system(system_id)
    return system.get("color", "#ffffff")

# 7. 获取星系距离
func get_system_distance(system_id: String) -> float:
    var system = get_star_system(system_id)
    return system.get("distance_ly", 0.0)

# 8. 获取星系描述
func get_system_description(system_id: String) -> String:
    var system = get_star_system(system_id)
    return system.get("description", "")

# 9. 获取星系中的行星
func get_system_planets(system_id: String) -> Array:
    var system = get_star_system(system_id)
    return system.get("planet_ids", [])

# 10. 获取星系探索成本
func get_exploration_cost(system_id: String) -> Array:
    var system = get_star_system(system_id)
    return system.get("exploration_cost", [])

# 11. 获取前置星系
func get_prerequisite_system(system_id: String) -> String:
    var system = get_star_system(system_id)
    return system.get("prerequisite_system_id", "")

# 12. 检查星系是否已解锁
func is_system_unlocked(system_id: String) -> bool:
    # 母星系默认解锁
    if system_id == "helios":
        return true
    
    # 检查前置星系是否已完成
    var prerequisite = get_prerequisite_system(system_id)
    if prerequisite.is_empty():
        return true
    
    return game_state.completed_systems.has(prerequisite)

# 13. 检查星系是否可以探索
func can_explore_system(system_id: String) -> bool:
    if is_system_unlocked(system_id):
        return false
    
    # 检查探索成本
    var cost = get_exploration_cost(system_id)
    for item_cost in cost:
        var item_id = item_cost.get("item_id", "")
        var amount = item_cost.get("amount", 0)
        # 这里需要检查玩家是否有足够的物品
        # 简化实现：假设总是可以探索
        pass
    
    return true

# 14. 探索星系
func explore_system(system_id: String) -> bool:
    if not can_explore_system(system_id):
        print("Cannot explore system: ", system_id)
        return false
    
    # 标记为已探索
    if not game_state.completed_systems.has(system_id):
        game_state.completed_systems.append(system_id)
    
    print("Explored system: ", system_id)
    return true

# 15. 获取已探索的星系
func get_explored_systems() -> Array:
    return game_state.completed_systems

# 16. 获取可探索的星系
func get_explorable_systems() -> Array:
    var explorable = []
    for system_id in star_systems:
        if can_explore_system(system_id):
            explorable.append(system_id)
    return explorable

# 17. 获取星系数量
func get_system_count() -> int:
    return star_systems.size()

# 18. 获取已探索星系数量
func get_explored_count() -> int:
    return get_explored_systems().size()

# 19. 获取星系信息摘要
func get_system_summary(system_id: String) -> Dictionary:
    var system = get_star_system(system_id)
    return {
        "id": system_id,
        "name": system.get("name", ""),
        "star_type": system.get("star_type", ""),
        "distance_ly": system.get("distance_ly", 0.0),
        "planet_count": system.get("planet_ids", []).size(),
        "explored": is_system_unlocked(system_id)
    }

# 20. 获取所有星系列表
func get_all_system_ids() -> Array:
    return star_systems.keys()

# 21. 检查星系是否存在
func system_exists(system_id: String) -> bool:
    return star_systems.has(system_id)

# 22. 获取星系图标
func get_system_icon(system_id: String) -> String:
    var star_type = get_star_type(system_id)
    if "G 型" in star_type:
        return "☀️"
    elif "K 型" in star_type:
        return "🌟"
    elif "中子星" in star_type:
        return "💫"
    else:
        return "⭐"

# 23. 获取星系信息格式化
func get_system_info_formatted(system_id: String) -> String:
    var system = get_star_system(system_id)
    var info = ""
    info += "名称: %s\n" % system.get("name", "")
    info += "代码: %s\n" % system.get("code", "")
    info += "恒星类型: %s\n" % system.get("star_type", "")
    info += "距离: %.1f 光年\n" % system.get("distance_ly", 0.0)
    info += "行星数: %d\n" % system.get("planet_ids", []).size()
    info += "描述: %s" % system.get("description", "")
    return info

# 24. 获取星系列表格式化
func get_system_list_formatted() -> String:
    var list = ""
    for system_id in star_systems:
        var system = star_systems[system_id]
        var status = "✓" if is_system_unlocked(system_id) else "✗"
        list += "%s %s - %s (%.1f 光年)\n" % [status, system.get("name", ""), system.get("star_type", ""), system.get("distance_ly", 0.0)]
    return list

# 25. 重置星系系统
func reset():
    star_systems.clear()
    _load_star_systems()
    game_state.completed_systems.clear()
    print("Galaxy system reset")
