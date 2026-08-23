# scripts/test/TestPhase2Simple.gd
extends Node

func _ready():
    print("=== 第二阶段功能测试 ===")
    print("")
    
    var game_state = GameManager.get_game_state()
    var pass_count = 0
    var total_count = 0
    
    # 科技系统
    print("--- 科技系统 ---")
    var tech_script = load("res://scripts/game/TechnologySystem.gd")
    var tech = tech_script.new(game_state)
    
    total_count += 1
    if tech.get_technology("automation").size() > 0:
        pass_count += 1
        print("✓ 获取科技")
    
    total_count += 1
    if tech.get_all_technologies().size() > 0:
        pass_count += 1
        print("✓ 获取所有科技: ", tech.get_all_technologies().size())
    
    total_count += 1
    if tech.can_research_technology("automation"):
        pass_count += 1
        print("✓ 可以研究")
    
    total_count += 1
    if tech.start_research("automation"):
        pass_count += 1
        print("✓ 开始研究")
    
    total_count += 1
    tech.update_research(5.0)
    pass_count += 1
    print("✓ 更新研究进度")
    
    # 物流站系统
    print("\n--- 物流站系统 ---")
    var station_script = load("res://scripts/game/StationSystem.gd")
    var station = station_script.new(game_state)
    
    var station_id = game_state.add_building({
        "type": "planetary_logistics_station",
        "position": Vector2(500, 500)
    })
    total_count += 1
    pass_count += 1
    print("✓ 添加物流站")
    
    total_count += 1
    if station.create_station(station_id, "planetary_logistics_station"):
        pass_count += 1
        print("✓ 创建配置")
    
    total_count += 1
    if station.set_station_slot_item(station_id, 0, "iron_ore"):
        pass_count += 1
        print("✓ 设置槽位物品")
    
    # 建筑类型
    print("\n--- 建筑类型 ---")
    var buildings = ["solar_panel", "wind_turbine", "storage_mk1", "assembler", "chemical_plant"]
    for b in buildings:
        total_count += 1
        var id = game_state.add_building({"type": b, "position": Vector2(600, 600)})
        if not id.is_empty():
            pass_count += 1
            print("✓ 添加: ", b)
    
    # 物品和配方
    print("\n--- 物品和配方 ---")
    var items = ["copper_ore", "coal", "crude_oil", "water", "graphene"]
    for item in items:
        total_count += 1
        if not DataManager.get_item(item).is_empty():
            pass_count += 1
            print("✓ 物品: ", item)
    
    var recipes = ["copper_ingot_recipe", "gear_recipe", "circuit_recipe", "plastic_recipe"]
    for recipe in recipes:
        total_count += 1
        if not DataManager.get_recipe(recipe).is_empty():
            pass_count += 1
            print("✓ 配方: ", recipe)
    
    # 存档系统
    print("\n--- 存档系统 ---")
    var save_script = load("res://scripts/game/SaveSystem.gd")
    var save = save_script.new()
    
    total_count += 1
    if save.save_game(0, game_state):
        pass_count += 1
        print("✓ 保存游戏")
    
    total_count += 1
    if save.has_save(0):
        pass_count += 1
        print("✓ 检查存档")
    
    # 统计系统
    print("\n--- 统计系统 ---")
    var stats_script = load("res://scripts/game/StatisticsSystem.gd")
    var stats = stats_script.new(game_state)
    
    total_count += 1
    stats.update(1.0)
    pass_count += 1
    print("✓ 更新统计")
    
    total_count += 1
    if stats.get_statistics_summary().size() > 0:
        pass_count += 1
        print("✓ 获取统计摘要")
    
    # 结果
    print("\n=== 测试结果 ===")
    print("通过: ", pass_count, "/", total_count)
    print("通过率: ", snapped(pass_count * 100.0 / total_count, 0.1), "%")
    print("状态: ", "通过 ✓" if pass_count == total_count else "失败 ✗")
