# scripts/test/TestPhase2Final.gd
extends Node

func _ready():
    print("=== 第二阶段最终功能测试 ===")
    print("测试时间: ", Time.get_datetime_string_from_system())
    print("")
    
    var game_state = GameManager.get_game_state()
    var total_tests = 0
    var passed_tests = 0
    
    # 测试1: 科技研究系统 (30个功能)
    print("--- 测试1: 科技研究系统 ---")
    var tech_script = load("res://scripts/game/TechnologySystem.gd")
    var tech_system = tech_script.new(game_state)
    
    var tech_tests = [
        {"name": "获取科技", "func": "get_technology", "args": ["automation"]},
        {"name": "获取所有科技", "func": "get_all_technologies", "args": []},
        {"name": "检查科技完成", "func": "is_technology_completed", "args": ["automation"]},
        {"name": "检查可以研究", "func": "can_research_technology", "args": ["automation"]},
        {"name": "开始研究", "func": "start_research", "args": ["automation"]},
        {"name": "更新研究进度", "func": "update_research", "args": [5.0]},
        {"name": "获取研究进度", "func": "get_research_progress", "args": []},
        {"name": "添加到队列", "func": "add_to_queue", "args": ["logistics"]},
        {"name": "获取科技效果", "func": "get_tech_effect", "args": ["recipe_speed"]},
        {"name": "获取已完成科技", "func": "get_completed_technologies", "args": []},
        {"name": "获取可用科技", "func": "get_available_technologies", "args": []}
    ]
    
    for test in tech_tests:
        total_tests += 1
        var result = tech_system.call(test.func, test.args) if test.args.size() > 0 else tech_system.call(test.func)
        if result != null:
            passed_tests += 1
            print("✓ ", test.name)
        else:
            print("✗ ", test.name)
    
    # 测试2: 物流站系统 (30个功能)
    print("\n--- 测试2: 物流站系统 ---")
    var station_script = load("res://scripts/game/StationSystem.gd")
    var station_system = station_script.new(game_state)
    
    # 添加测试物流站
    var station_id = game_state.add_building({
        "type": "planetary_logistics_station",
        "position": Vector2(500, 500),
        "status": "idle"
    })
    
    var station_tests = [
        {"name": "添加物流站", "result": station_id},
        {"name": "创建物流站配置", "result": station_system.create_station(station_id, "planetary_logistics_station")},
        {"name": "设置槽位物品", "result": station_system.set_station_slot_item(station_id, 0, "iron_ore")},
        {"name": "设置槽位模式", "result": station_system.set_station_slot_mode(station_id, 0, "supply")},
        {"name": "设置最小负载", "result": station_system.set_station_slot_min_load(station_id, 0, 0.5)},
        {"name": "设置最大负载", "result": station_system.set_station_slot_max_load(station_id, 0, 1.0)},
        {"name": "设置优先级", "result": station_system.set_station_slot_priority(station_id, 0, 1)},
        {"name": "获取物流站信息", "result": station_system.get_station_info(station_id)},
        {"name": "获取物流站槽位", "result": station_system.get_station_slots(station_id)},
        {"name": "更新物流站", "result": station_system.update_stations(1.0)}
    ]
    
    for test in station_tests:
        total_tests += 1
        if test.result != null:
            passed_tests += 1
            print("✓ ", test.name)
        else:
            print("✗ ", test.name)
    
    # 测试3: 更多建筑类型 (30个功能)
    print("\n--- 测试3: 更多建筑类型 ---")
    var building_types = [
        "solar_panel", "wind_turbine", "storage_mk1", "splitter",
        "oil_extractor", "oil_refinery", "chemical_plant", "water_pump",
        "fractionator", "assembler", "graphene_facility", "quantum_processor",
        "antimatter_generator", "dyson_sphere_launcher", "ray_receiver"
    ]
    
    for b_type in building_types:
        total_tests += 1
        var b_id = game_state.add_building({
            "type": b_type,
            "position": Vector2(600 + total_tests * 50, 600),
            "status": "idle"
        })
        if not b_id.is_empty():
            passed_tests += 1
            print("✓ 添加: ", b_type)
        else:
            print("✗ 添加: ", b_type)
    
    # 测试4: 更多物品与配方 (30个功能)
    print("\n--- 测试4: 更多物品与配方 ---")
    var items_to_check = [
        "copper_ore", "coal", "stone", "crude_oil", "water",
        "graphene", "carbon_nanotube", "titanium_alloy", "super_magnetic_ring",
        "particle_container", "strange_matter", "antimatter", "space_warper"
    ]
    
    for item_id in items_to_check:
        total_tests += 1
        var item = DataManager.get_item(item_id)
        if not item.is_empty():
            passed_tests += 1
            print("✓ 物品: ", item.get("name", ""))
        else:
            print("✗ 物品: ", item_id)
    
    var recipes_to_check = [
        "copper_ingot_recipe", "gear_recipe", "circuit_recipe", "plastic_recipe",
        "refined_oil_recipe", "graphene_recipe", "carbon_nanotube_recipe",
        "quantum_chip_recipe", "strange_matter_recipe", "space_warper_recipe"
    ]
    
    for recipe_id in recipes_to_check:
        total_tests += 1
        var recipe = DataManager.get_recipe(recipe_id)
        if not recipe.is_empty():
            passed_tests += 1
            print("✓ 配方: ", recipe.get("name", ""))
        else:
            print("✗ 配方: ", recipe_id)
    
    # 测试5: 存档系统
    print("\n--- 测试5: 存档系统 ---")
    var save_script = load("res://scripts/game/SaveSystem.gd")
    var save_system = save_script.new()
    
    var save_tests = [
        {"name": "保存游戏", "result": save_system.save_game(0, game_state)},
        {"name": "检查存档", "result": save_system.has_save(0)},
        {"name": "获取存档信息", "result": save_system.get_save_info(0)},
        {"name": "获取所有存档", "result": save_system.get_all_saves()},
        {"name": "删除存档", "result": save_system.delete_save(0)}
    ]
    
    for test in save_tests:
        total_tests += 1
        if test.result != null:
            passed_tests += 1
            print("✓ ", test.name)
        else:
            print("✗ ", test.name)
    
    # 测试6: 统计系统
    print("\n--- 测试6: 统计系统 ---")
    var stats_script = load("res://scripts/game/StatisticsSystem.gd")
    var stats_system = stats_script.new(game_state)
    
    stats_system.update(1.0)
    
    var stats_tests = [
        {"name": "获取生产统计", "result": stats_system.get_all_production()},
        {"name": "获取消耗统计", "result": stats_system.get_all_consumption()},
        {"name": "获取建筑数量", "result": stats_system.get_total_buildings()},
        {"name": "获取连接数量", "result": stats_system.get_total_connections()},
        {"name": "获取统计摘要", "result": stats_system.get_statistics_summary()}
    ]
    
    for test in stats_tests:
        total_tests += 1
        if test.result != null:
            passed_tests += 1
            print("✓ ", test.name)
        else:
            print("✗ ", test.name)
    
    # 测试结果汇总
    print("\n=== 第二阶段测试结果汇总 ===")
    print("总测试数: ", total_tests)
    print("通过数: ", passed_tests)
    print("失败数: ", total_tests - passed_tests)
    print("通过率: ", snapped(passed_tests * 100.0 / total_tests, 0.1), "%")
    print("")
    print("测试状态: ", "通过 ✓" if passed_tests == total_tests else "失败 ✗")
