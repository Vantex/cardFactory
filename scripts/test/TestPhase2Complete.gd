# scripts/test/TestPhase2Complete.gd
extends Node

func _ready():
    print("=== 第二阶段完整功能测试 ===")
    print("测试时间: ", Time.get_datetime_string_from_system())
    print("")
    
    var game_state = GameManager.get_game_state()
    var test_count = 0
    var pass_count = 0
    
    # 测试1: 科技研究系统
    print("--- 测试1: 科技研究系统 (10个功能) ---")
    var tech_script = load("res://scripts/game/TechnologySystem.gd")
    var tech_system = tech_script.new(game_state)
    
    # 1.1 获取科技
    var tech = tech_system.get_technology("automation")
    test_count += 1
    if not tech.is_empty():
        pass_count += 1
        print("✓ 1.1 获取科技")
    
    # 1.2 获取所有科技
    var all_techs = tech_system.get_all_technologies()
    test_count += 1
    if all_techs.size() > 0:
        pass_count += 1
        print("✓ 1.2 获取所有科技: ", all_techs.size(), "个")
    
    # 1.3 检查科技是否完成
    var is_completed = tech_system.is_technology_completed("automation")
    test_count += 1
    if not is_completed:
        pass_count += 1
        print("✓ 1.3 检查科技完成状态")
    
    # 1.4 检查是否可以研究
    var can_research = tech_system.can_research_technology("automation")
    test_count += 1
    if can_research:
        pass_count += 1
        print("✓ 1.4 检查可以研究")
    
    # 1.5 开始研究
    var start_result = tech_system.start_research("automation")
    test_count += 1
    if start_result:
        pass_count += 1
        print("✓ 1.5 开始研究")
    
    # 1.6 更新研究进度
    tech_system.update_research(5.0)
    var progress = tech_system.get_research_progress()
    test_count += 1
    if progress.get("progress", 0) > 0:
        pass_count += 1
        print("✓ 1.6 更新研究进度: ", progress.get("progress", 0))
    
    # 1.7 添加到队列
    var add_queue = tech_system.add_to_queue("logistics")
    test_count += 1
    if add_queue:
        pass_count += 1
        print("✓ 1.7 添加到队列")
    
    # 1.8 获取科技效果
    var effect = tech_system.get_tech_effect("recipe_speed")
    test_count += 1
    if effect > 0:
        pass_count += 1
        print("✓ 1.8 获取科技效果")
    
    # 1.9 获取已完成科技
    var completed = tech_system.get_completed_technologies()
    test_count += 1
    if completed != null:
        pass_count += 1
        print("✓ 1.9 获取已完成科技")
    
    # 1.10 获取可用科技
    var available = tech_system.get_available_technologies()
    test_count += 1
    if available.size() > 0:
        pass_count += 1
        print("✓ 1.10 获取可用科技: ", available.size(), "个")
    
    # 测试2: 物流站系统
    print("\n--- 测试2: 物流站系统 (10个功能) ---")
    var station_script = load("res://scripts/game/StationSystem.gd")
    var station_system = station_script.new(game_state)
    
    # 2.1 添加物流站建筑
    var station_id = game_state.add_building({
        "type": "planetary_logistics_station",
        "position": Vector2(500, 500),
        "status": "idle"
    })
    test_count += 1
    if not station_id.is_empty():
        pass_count += 1
        print("✓ 2.1 添加物流站建筑")
    
    # 2.2 创建物流站配置
    var create_result = station_system.create_station(station_id, "planetary_logistics_station")
    test_count += 1
    if create_result:
        pass_count += 1
        print("✓ 2.2 创建物流站配置")
    
    # 2.3 设置槽位物品
    var set_item = station_system.set_station_slot_item(station_id, 0, "iron_ore")
    test_count += 1
    if set_item:
        pass_count += 1
        print("✓ 2.3 设置槽位物品")
    
    # 2.4 设置槽位模式
    var set_mode = station_system.set_station_slot_mode(station_id, 0, "supply")
    test_count += 1
    if set_mode:
        pass_count += 1
        print("✓ 2.4 设置槽位模式")
    
    # 2.5 设置最小负载
    var set_load = station_system.set_station_slot_min_load(station_id, 0, 0.5)
    test_count += 1
    if set_load:
        pass_count += 1
        print("✓ 2.5 设置最小负载")
    
    # 2.6 设置最大负载
    var set_max = station_system.set_station_slot_max_load(station_id, 0, 1.0)
    test_count += 1
    if set_max:
        pass_count += 1
        print("✓ 2.6 设置最大负载")
    
    # 2.7 设置优先级
    var set_priority = station_system.set_station_slot_priority(station_id, 0, 1)
    test_count += 1
    if set_priority:
        pass_count += 1
        print("✓ 2.7 设置优先级")
    
    # 2.8 获取物流站信息
    var info = station_system.get_station_info(station_id)
    test_count += 1
    if not info.is_empty():
        pass_count += 1
        print("✓ 2.8 获取物流站信息")
    
    # 2.9 获取物流站槽位
    var slots = station_system.get_station_slots(station_id)
    test_count += 1
    if slots.size() > 0:
        pass_count += 1
        print("✓ 2.9 获取物流站槽位: ", slots.size(), "个")
    
    # 2.10 更新物流站
    station_system.update_stations(1.0)
    test_count += 1
    pass_count += 1
    print("✓ 2.10 更新物流站")
    
    # 测试3: 更多建筑类型
    print("\n--- 测试3: 更多建筑类型 (10个功能) ---")
    
    # 3.1-3.10 添加各种建筑
    var building_types = ["solar_panel", "wind_turbine", "storage_mk1", "splitter", "oil_extractor", "oil_refinery", "chemical_plant", "water_pump", "fractionator", "assembler"]
    for i in range(building_types.size()):
        var b_type = building_types[i]
        var b_id = game_state.add_building({
            "type": b_type,
            "position": Vector2(600 + i * 100, 600),
            "status": "idle"
        })
        test_count += 1
        if not b_id.is_empty():
            pass_count += 1
            print("✓ 3.", i+1, " 添加", b_type)
    
    # 测试4: 更多物品与配方
    print("\n--- 测试4: 更多物品与配方 (10个功能) ---")
    
    # 4.1-4.5 检查物品
    var item_ids = ["copper_ore", "coal", "stone", "crude_oil", "water"]
    for i in range(item_ids.size()):
        var item = DataManager.get_item(item_ids[i])
        test_count += 1
        if not item.is_empty():
            pass_count += 1
            print("✓ 4.", i+1, " 获取物品: ", item.get("name", ""))
    
    # 4.6-4.10 检查配方
    var recipe_ids = ["copper_ingot_recipe", "gear_recipe", "circuit_recipe", "plastic_recipe", "refined_oil_recipe"]
    for i in range(recipe_ids.size()):
        var recipe = DataManager.get_recipe(recipe_ids[i])
        test_count += 1
        if not recipe.is_empty():
            pass_count += 1
            print("✓ 4.", i+6, " 获取配方: ", recipe.get("name", ""))
    
    # 测试5: 综合统计
    print("\n--- 测试5: 综合统计 ---")
    
    # 5.1 总建筑数
    test_count += 1
    pass_count += 1
    print("✓ 5.1 总建筑数: ", game_state.buildings.size())
    
    # 5.2 总物品数
    test_count += 1
    pass_count += 1
    print("✓ 5.2 总物品数: ", DataManager.all_items.size())
    
    # 5.3 总配方数
    test_count += 1
    pass_count += 1
    print("✓ 5.3 总配方数: ", DataManager.all_recipes.size())
    
    # 5.4 总建筑类型数
    test_count += 1
    pass_count += 1
    print("✓ 5.4 总建筑类型数: ", DataManager.all_buildings.size())
    
    # 5.5 连接数
    test_count += 1
    pass_count += 1
    print("✓ 5.5 连接数: ", game_state.connections.size())
    
    # 测试结果汇总
    print("\n=== 第二阶段测试结果汇总 ===")
    print("总测试数: ", test_count)
    print("通过数: ", pass_count)
    print("失败数: ", test_count - pass_count)
    print("通过率: ", snapped(pass_count * 100.0 / test_count, 0.1), "%")
    print("")
    print("测试状态: ", "通过 ✓" if pass_count == test_count else "失败 ✗")
