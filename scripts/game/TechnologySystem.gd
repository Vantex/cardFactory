# scripts/game/TechnologySystem.gd
class_name TechnologySystem
extends RefCounted

var game_state: GameState

# 科技定义
var technologies: Dictionary = {}

# 当前研究
var current_research: String = ""
var research_progress: float = 0.0
var research_queue: Array = []

# 科技效果缓存
var tech_effects: Dictionary = {}

func _init(state: GameState):
    game_state = state
    _load_technologies()

func _load_technologies():
    # 基础科技
    technologies["automation"] = {
        "id": "automation",
        "name": "自动化",
        "description": "解锁基础自动化设备",
        "cost": {"matrix_science_1": 10},
        "duration": 10.0,
        "prerequisites": [],
        "unlocks": ["assembling_machine_mk1"],
        "effects": {"recipe_speed": 1.0}
    }
    
    technologies["logistics"] = {
        "id": "logistics",
        "name": "物流",
        "description": "解锁基础物流设备",
        "cost": {"matrix_science_1": 20},
        "duration": 20.0,
        "prerequisites": ["automation"],
        "unlocks": ["conveyor_belt_mk1", "sorter_mk1"],
        "effects": {"logistics_speed": 1.0}
    }
    
    technologies["electromagnetism"] = {
        "id": "electromagnetism",
        "name": "电磁学",
        "description": "解锁电磁设备",
        "cost": {"matrix_science_1": 30, "matrix_science_2": 10},
        "duration": 30.0,
        "prerequisites": ["logistics"],
        "unlocks": ["electric_motor", "magnetic_coil"],
        "effects": {"power_efficiency": 1.0}
    }
    
    # 进阶科技
    technologies["steel_smelting"] = {
        "id": "steel_smelting",
        "name": "钢材冶炼",
        "description": "解锁钢材冶炼配方",
        "cost": {"matrix_science_1": 40, "matrix_science_2": 20},
        "duration": 40.0,
        "prerequisites": ["electromagnetism"],
        "unlocks": ["steel"],
        "effects": {"smelting_speed": 1.0}
    }
    
    technologies["advanced_mining"] = {
        "id": "advanced_mining",
        "name": "高级采矿",
        "description": "解锁高级采矿设备",
        "cost": {"matrix_science_1": 50, "matrix_science_2": 30},
        "duration": 50.0,
        "prerequisites": ["steel_smelting"],
        "unlocks": ["mining_machine_mk2"],
        "effects": {"mining_speed": 1.0}
    }
    
    # 化工科技
    technologies["chemical_processing"] = {
        "id": "chemical_processing",
        "name": "化工处理",
        "description": "解锁化工设备和配方",
        "cost": {"matrix_science_1": 60, "matrix_science_2": 40},
        "duration": 60.0,
        "prerequisites": ["steel_smelting"],
        "unlocks": ["chemical_plant"],
        "effects": {"chemical_speed": 1.0}
    }
    
    # 电子科技
    technologies["electronics"] = {
        "id": "electronics",
        "name": "电子学",
        "description": "解锁电子元件和电路",
        "cost": {"matrix_science_1": 70, "matrix_science_2": 50, "matrix_science_3": 10},
        "duration": 70.0,
        "prerequisites": ["chemical_processing"],
        "unlocks": ["circuit", "chip"],
        "effects": {"electronics_speed": 1.0}
    }
    
    # 电力科技
    technologies["power_systems"] = {
        "id": "power_systems",
        "name": "电力系统",
        "description": "解锁高级发电设备",
        "cost": {"matrix_science_1": 80, "matrix_science_2": 60},
        "duration": 80.0,
        "prerequisites": ["electromagnetism"],
        "unlocks": ["solar_panel", "wind_turbine"],
        "effects": {"power_generation": 1.0}
    }
    
    # 物流科技
    technologies["advanced_logistics"] = {
        "id": "advanced_logistics",
        "name": "高级物流",
        "description": "解锁物流站和分拣器",
        "cost": {"matrix_science_1": 90, "matrix_science_2": 70},
        "duration": 90.0,
        "prerequisites": ["logistics"],
        "unlocks": ["planetary_logistics_station"],
        "effects": {"logistics_capacity": 1.0}
    }
    
    # 星际科技
    technologies["interstellar_logistics"] = {
        "id": "interstellar_logistics",
        "name": "星际物流",
        "description": "解锁星际物流站",
        "cost": {"matrix_science_1": 100, "matrix_science_2": 80, "matrix_science_3": 20},
        "duration": 100.0,
        "prerequisites": ["advanced_logistics"],
        "unlocks": ["interstellar_logistics_station"],
        "effects": {"interstellar_speed": 1.0}
    }
    
    print("Loaded ", technologies.size(), " technologies")

# === 科技研究系统功能（30个） ===

# 1. 获取科技定义
func get_technology(tech_id: String) -> Dictionary:
    return technologies.get(tech_id, {})

# 2. 获取所有科技
func get_all_technologies() -> Dictionary:
    return technologies

# 3. 检查科技是否完成
func is_technology_completed(tech_id: String) -> bool:
    return game_state.completed_technologies.has(tech_id)

# 4. 检查是否可以研究
func can_research_technology(tech_id: String) -> bool:
    if is_technology_completed(tech_id):
        return false
    
    var tech = get_technology(tech_id)
    if tech.is_empty():
        return false
    
    # 检查前置科技
    for prereq in tech.get("prerequisites", []):
        if not is_technology_completed(prereq):
            return false
    
    return true

# 5. 开始研究
func start_research(tech_id: String) -> bool:
    if not can_research_technology(tech_id):
        print("Cannot research: ", tech_id)
        return false
    
    current_research = tech_id
    research_progress = 0.0
    EventBus.technology_research_started.emit(tech_id)
    print("Started research: ", tech_id)
    return true

# 6. 更新研究进度
func update_research(delta: float):
    if current_research.is_empty():
        return
    
    var tech = get_technology(current_research)
    if tech.is_empty():
        return
    
    research_progress += delta
    
    # 检查是否完成
    if research_progress >= tech.get("duration", 0.0):
        _complete_research()

# 7. 完成研究
func _complete_research():
    if current_research.is_empty():
        return
    
    var tech = get_technology(current_research)
    if tech.is_empty():
        return
    
    # 标记为已完成
    game_state.completed_technologies.append(current_research)
    EventBus.technology_research_completed.emit(current_research)
    print("Completed research: ", current_research)
    
    # 触发解锁
    var unlocks = tech.get("unlocks", [])
    for unlock_id in unlocks:
        print("Unlocked: ", unlock_id)
        EventBus.technology_unlocked.emit(unlock_id)
    
    # 应用科技效果
    _apply_tech_effects(current_research)
    
    # 处理队列
    current_research = ""
    research_progress = 0.0
    
    if research_queue.size() > 0:
        var next_tech = research_queue.pop_front()
        start_research(next_tech)

# 8. 应用科技效果
func _apply_tech_effects(tech_id: String):
    var tech = get_technology(tech_id)
    if tech.is_empty():
        return
    
    var effects = tech.get("effects", {})
    for effect_key in effects:
        tech_effects[effect_key] = effects[effect_key]
        print("Applied effect: ", effect_key, " = ", effects[effect_key])

# 9. 添加到队列
func add_to_queue(tech_id: String) -> bool:
    if not can_research_technology(tech_id):
        return false
    
    if tech_id not in research_queue:
        research_queue.append(tech_id)
        print("Added to queue: ", tech_id)
    
    return true

# 10. 从队列移除
func remove_from_queue(tech_id: String):
    research_queue.erase(tech_id)
    print("Removed from queue: ", tech_id)

# 11. 获取研究进度
func get_research_progress() -> Dictionary:
    if current_research.is_empty():
        return {"tech_id": "", "progress": 0.0, "duration": 0.0}
    
    var tech = get_technology(current_research)
    return {
        "tech_id": current_research,
        "progress": research_progress,
        "duration": tech.get("duration", 0.0)
    }

# 12. 获取科技效果
func get_tech_effect(effect_key: String) -> float:
    return tech_effects.get(effect_key, 1.0)

# 13. 获取已完成科技
func get_completed_technologies() -> Array:
    return game_state.completed_technologies

# 14. 获取可用科技
func get_available_technologies() -> Array:
    var available = []
    for tech_id in technologies:
        if can_research_technology(tech_id):
            available.append(tech_id)
    return available

# 15. 获取科技成本
func get_technology_cost(tech_id: String) -> Dictionary:
    var tech = get_technology(tech_id)
    return tech.get("cost", {})

# 16. 获取科技持续时间
func get_technology_duration(tech_id: String) -> float:
    var tech = get_technology(tech_id)
    return tech.get("duration", 0.0)

# 17. 获取科技解锁内容
func get_technology_unlocks(tech_id: String) -> Array:
    var tech = get_technology(tech_id)
    return tech.get("unlocks", [])

# 18. 获取科技前置条件
func get_technology_prerequisites(tech_id: String) -> Array:
    var tech = get_technology(tech_id)
    return tech.get("prerequisites", [])

# 19. 检查科技是否有前置条件
func has_prerequisites(tech_id: String) -> bool:
    var prereqs = get_technology_prerequisites(tech_id)
    return prereqs.size() > 0

# 20. 获取科技描述
func get_technology_description(tech_id: String) -> String:
    var tech = get_technology(tech_id)
    return tech.get("description", "")

# 21. 获取科技名称
func get_technology_name(tech_id: String) -> String:
    var tech = get_technology(tech_id)
    return tech.get("name", "")

# 22. 检查科技是否在队列中
func is_in_queue(tech_id: String) -> bool:
    return tech_id in research_queue

# 23. 获取队列长度
func get_queue_length() -> int:
    return research_queue.size()

# 24. 清空队列
func clear_queue():
    research_queue.clear()
    print("Research queue cleared")

# 25. 获取当前研究
func get_current_research() -> String:
    return current_research

# 26. 检查是否正在研究
func is_researching() -> bool:
    return not current_research.is_empty()

# 27. 取消当前研究
func cancel_research() -> bool:
    if current_research.is_empty():
        return false
    
    print("Cancelled research: ", current_research)
    current_research = ""
    research_progress = 0.0
    return true

# 28. 获取研究进度百分比
func get_research_progress_percent() -> float:
    if current_research.is_empty():
        return 0.0
    
    var tech = get_technology(current_research)
    var duration = tech.get("duration", 0.0)
    if duration <= 0:
        return 0.0
    
    return research_progress / duration

# 29. 获取科技树结构
func get_tech_tree() -> Dictionary:
    var tree = {}
    for tech_id in technologies:
        var tech = technologies[tech_id]
        tree[tech_id] = {
            "prerequisites": tech.get("prerequisites", []),
            "unlocks": tech.get("unlocks", [])
        }
    return tree

# 30. 重置科技系统
func reset():
    current_research = ""
    research_progress = 0.0
    research_queue.clear()
    tech_effects.clear()
    game_state.completed_technologies.clear()
    print("Technology system reset")
