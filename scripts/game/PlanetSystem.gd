# scripts/game/PlanetSystem.gd
class_name PlanetSystem
extends RefCounted

var game_state: GameState

# 行星定义
var planets: Dictionary = {}

func _init(state: GameState):
    game_state = state
    _load_planets()

func _load_planets():
    # 母星系
    planets["home"] = {
        "id": "home",
        "name": "澄海 I",
        "code": "母星",
        "color": "#61b2aa",
        "environment": "海洋型行星",
        "resources": ["iron", "copper", "stone", "coal", "crude_oil", "water"],
        "kind": "terrestrial",
        "system_id": "helios",
        "orbit_index": 1,
        "solar_multiplier": 1.0,
        "description": "工业网络的起点"
    }
    
    planets["ashen"] = {
        "id": "ashen",
        "name": "烬原 II",
        "code": "熔岩星",
        "color": "#d8794d",
        "environment": "熔岩型行星",
        "resources": ["titanium", "silicon", "iron", "copper", "stone", "coal"],
        "kind": "terrestrial",
        "system_id": "helios",
        "orbit_index": 2,
        "solar_multiplier": 1.5,
        "description": "高温熔岩行星"
    }
    
    planets["giant"] = {
        "id": "giant",
        "name": "苍岚 III",
        "code": "气态巨星",
        "color": "#75a9bd",
        "environment": "冰气态巨星",
        "resources": ["hydrogen", "deuterium", "fire_ice"],
        "kind": "gas_giant",
        "system_id": "helios",
        "orbit_index": 3,
        "solar_multiplier": 0.0,
        "description": "气态巨星，可采集氢和氘"
    }
    
    # 冰原星系
    planets["frost"] = {
        "id": "frost",
        "name": "霜原 I",
        "code": "冰原星",
        "color": "#91b8c4",
        "environment": "永冻冰原行星",
        "resources": ["iron", "copper", "titanium", "silicon", "fire_ice"],
        "kind": "terrestrial",
        "system_id": "borealis",
        "orbit_index": 1,
        "solar_multiplier": 0.8,
        "description": "永冻冰原行星"
    }
    
    # 中子星系
    planets["magnetar"] = {
        "id": "magnetar",
        "name": "极夜 I",
        "code": "磁暴星",
        "color": "#a48ac2",
        "environment": "中子星潮汐锁定行星",
        "resources": ["iron", "copper", "titanium", "silicon", "unipolar_mag"],
        "kind": "terrestrial",
        "system_id": "neutron",
        "orbit_index": 1,
        "solar_multiplier": 0.45,
        "description": "极端磁场环境"
    }
    
    print("Loaded ", planets.size(), " planets")

# === 行星系统功能（40个） ===

# 1. 获取行星定义
func get_planet(planet_id: String) -> Dictionary:
    return planets.get(planet_id, {})

# 2. 获取所有行星
func get_all_planets() -> Dictionary:
    return planets

# 3. 获取行星名称
func get_planet_name(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("name", "")

# 4. 获取行星代码
func get_planet_code(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("code", "")

# 5. 获取行星颜色
func get_planet_color(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("color", "#ffffff")

# 6. 获取行星环境
func get_planet_environment(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("environment", "")

# 7. 获取行星资源
func get_planet_resources(planet_id: String) -> Array:
    var planet = get_planet(planet_id)
    return planet.get("resources", [])

# 8. 获取行星类型
func get_planet_kind(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("kind", "")

# 9. 获取行星所属星系
func get_planet_system(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("system_id", "")

# 10. 获取行星轨道位置
func get_planet_orbit_index(planet_id: String) -> int:
    var planet = get_planet(planet_id)
    return planet.get("orbit_index", 0)

# 11. 获取行星光照倍率
func get_planet_solar_multiplier(planet_id: String) -> float:
    var planet = get_planet(planet_id)
    return planet.get("solar_multiplier", 1.0)

# 12. 获取行星描述
func get_planet_description(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    return planet.get("description", "")

# 13. 检查行星是否有某种资源
func planet_has_resource(planet_id: String, resource_id: String) -> bool:
    var resources = get_planet_resources(planet_id)
    return resource_id in resources

# 14. 获取行星资源列表
func get_planet_resource_list(planet_id: String) -> String:
    var resources = get_planet_resources(planet_id)
    return ", ".join(resources)

# 15. 获取星系中的行星
func get_planets_in_system(system_id: String) -> Array:
    var result = []
    for planet_id in planets:
        if planets[planet_id].get("system_id") == system_id:
            result.append(planet_id)
    return result

# 16. 获取所有星系ID
func get_all_system_ids() -> Array:
    var system_ids = []
    for planet_id in planets:
        var system_id = planets[planet_id].get("system_id")
        if system_id not in system_ids:
            system_ids.append(system_id)
    return system_ids

# 17. 检查行星是否为气态巨星
func is_gas_giant(planet_id: String) -> bool:
    return get_planet_kind(planet_id) == "gas_giant"

# 18. 检查行星是否为陆地行星
func is_terrestrial(planet_id: String) -> bool:
    return get_planet_kind(planet_id) == "terrestrial"

# 19. 获取行星信息摘要
func get_planet_summary(planet_id: String) -> Dictionary:
    var planet = get_planet(planet_id)
    return {
        "id": planet_id,
        "name": planet.get("name", ""),
        "kind": planet.get("kind", ""),
        "environment": planet.get("environment", ""),
        "resources": planet.get("resources", []),
        "solar_multiplier": planet.get("solar_multiplier", 1.0)
    }

# 20. 获取所有行星列表
func get_all_planet_ids() -> Array:
    return planets.keys()

# 21. 获取行星数量
func get_planet_count() -> int:
    return planets.size()

# 22. 获取星系数量
func get_system_count() -> int:
    return get_all_system_ids().size()

# 23. 检查行星是否存在
func planet_exists(planet_id: String) -> bool:
    return planets.has(planet_id)

# 24. 获取母星
func get_home_planet() -> String:
    return "home"

# 25. 获取行星资源数量
func get_planet_resource_count(planet_id: String) -> int:
    return get_planet_resources(planet_id).size()

# 26. 获取行星工业能力
func get_planet_industrial_capacity(planet_id: String) -> float:
    var resources = get_planet_resources(planet_id)
    var capacity = 0.0
    for resource in resources:
        if resource in ["iron", "copper", "titanium", "silicon"]:
            capacity += 1.0
    return capacity

# 27. 获取行星能源能力
func get_planet_energy_capacity(planet_id: String) -> float:
    var solar = get_planet_solar_multiplier(planet_id)
    var resources = get_planet_resources(planet_id)
    var capacity = solar
    if "coal" in resources:
        capacity += 0.5
    if "crude_oil" in resources:
        capacity += 0.3
    return capacity

# 28. 获取行星宜居性
func get_planet_habitability(planet_id: String) -> float:
    var environment = get_planet_environment(planet_id)
    if "海洋" in environment or "草原" in environment:
        return 1.0
    elif "冰" in environment or "沙漠" in environment:
        return 0.7
    elif "熔岩" in environment or "火山" in environment:
        return 0.3
    else:
        return 0.5

# 29. 获取行星探索成本
func get_planet_exploration_cost(planet_id: String) -> Dictionary:
    var orbit = get_planet_orbit_index(planet_id)
    return {"space_warper": orbit}

# 30. 获取行星殖民成本
func get_planet_colonization_cost(planet_id: String) -> Dictionary:
    return {"building": 10, "resource": 100}

# 31. 获取行星列表按星系
func get_planets_grouped_by_system() -> Dictionary:
    var grouped = {}
    for planet_id in planets:
        var system_id = planets[planet_id].get("system_id", "")
        if not grouped.has(system_id):
            grouped[system_id] = []
        grouped[system_id].append(planet_id)
    return grouped

# 32. 获取行星颜色值
func get_planet_color_value(planet_id: String) -> Color:
    var color_hex = get_planet_color(planet_id)
    return Color.html(color_hex)

# 33. 获取行星图标
func get_planet_icon(planet_id: String) -> String:
    var kind = get_planet_kind(planet_id)
    if kind == "gas_giant":
        return "🪐"
    else:
        return "🌍"

# 34. 获取行星资源图标
func get_resource_icon(resource_id: String) -> String:
    var icons = {
        "iron": "⛏️",
        "copper": "⛏️",
        "coal": "�ite",
        "stone": "🪨",
        "crude_oil": "⛽",
        "water": "💧",
        "titanium": "⛏️",
        "silicon": "⛏️",
        "hydrogen": "💨",
        "deuterium": "💨",
        "fire_ice": "🔥",
        "unipolar_mag": "🧲"
    }
    return icons.get(resource_id, "❓")

# 35. 获取行星信息格式化
func get_planet_info_formatted(planet_id: String) -> String:
    var planet = get_planet(planet_id)
    var info = ""
    info += "名称: %s\n" % planet.get("name", "")
    info += "类型: %s\n" % planet.get("kind", "")
    info += "环境: %s\n" % planet.get("environment", "")
    info += "资源: %s\n" % get_planet_resource_list(planet_id)
    info += "光照: %.1fx\n" % planet.get("solar_multiplier", 1.0)
    info += "描述: %s" % planet.get("description", "")
    return info

# 36. 获取行星列表格式化
func get_planet_list_formatted() -> String:
    var list = ""
    for planet_id in planets:
        var planet = planets[planet_id]
        list += "%s - %s (%s)\n" % [planet.get("name", ""), planet.get("code", ""), planet.get("system_id", "")]
    return list

# 37. 获取星系列表格式化
func get_system_list_formatted() -> String:
    var systems = get_planets_grouped_by_system()
    var list = ""
    for system_id in systems:
        var planets_in_system = systems[system_id]
        list += "星系 %s: %d个行星\n" % [system_id, planets_in_system.size()]
    return list

# 38. 获取行星统计
func get_planet_statistics() -> Dictionary:
    var stats = {
        "total_planets": get_planet_count(),
        "total_systems": get_system_count(),
        "terrestrial_count": 0,
        "gas_giant_count": 0,
        "resource_distribution": {}
    }
    
    for planet_id in planets:
        var planet = planets[planet_id]
        if planet.get("kind") == "terrestrial":
            stats.terrestrial_count += 1
        elif planet.get("kind") == "gas_giant":
            stats.gas_giant_count += 1
        
        for resource in planet.get("resources", []):
            if not stats.resource_distribution.has(resource):
                stats.resource_distribution[resource] = 0
            stats.resource_distribution[resource] += 1
    
    return stats

# 39. 获取推荐开发行星
func get_recommended_planets() -> Array:
    var recommended = []
    for planet_id in planets:
        var planet = planets[planet_id]
        var resources = planet.get("resources", [])
        if "iron" in resources and "copper" in resources:
            recommended.append(planet_id)
    return recommended

# 40. 重置行星系统
func reset():
    planets.clear()
    _load_planets()
    print("Planet system reset")
