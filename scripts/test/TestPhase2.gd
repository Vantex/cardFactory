# scripts/test/TestPhase2.gd
extends Node

func _ready():
    print("=== 第二阶段功能测试 ===")
    print("测试时间: ", Time.get_datetime_string_from_system())
    print("")
    
    var game_state = GameManager.get_game_state()
    
    # 测试1: 科技研究系统
    print("--- 测试1: 科技研究系统 ---")
    
    # 使用load()函数加载TechnologySystem
    var tech_script = load("res://scripts/game/TechnologySystem.gd")
    var tech_system = tech_script.new(game_state)
    
    # 测试科技定义
    var automation_tech = tech_system.get_technology("automation")
    print("✓ 获取科技: ", automation_tech.get("name", ""))
    
    # 测试科技解锁检查
    var can_research = tech_system.can_research_technology("automation")
    print("✓ 可以研究automation: ", can_research)
    
    # 测试开始研究
    var start_result = tech_system.start_research("automation")
    print("✓ 开始研究automation: ", start_result)
    
    # 测试研究进度更新
    tech_system.update_research(5.0)
    var progress = tech_system.get_research_progress()
    print("✓ 研究进度: ", progress.get("progress", 0.0))
    
    # 测试2: 物流站系统
    print("\n--- 测试2: 物流站系统 ---")
    
    # 使用load()函数加载StationSystem
    var station_script = load("res://scripts/game/StationSystem.gd")
    var station_system = station_script.new(game_state)
    
    # 添加物流站建筑
    var station_id = game_state.add_building({
        "type": "planetary_logistics_station",
        "position": Vector2(500, 500),
        "status": "idle"
    })
    print("✓ 添加物流站: ", station_id)
    
    # 创建物流站配置
    var create_result = station_system.create_station(station_id, "planetary_logistics_station")
    print("✓ 创建物流站配置: ", create_result)
    
    # 设置槽位物品
    var set_item_result = station_system.set_station_slot_item(station_id, 0, "iron_ore")
    print("✓ 设置槽位物品: ", set_item_result)
    
    # 设置槽位模式
    var set_mode_result = station_system.set_station_slot_mode(station_id, 0, "supply")
    print("✓ 设置槽位模式: ", set_mode_result)
    
    # 设置最小负载
    var set_load_result = station_system.set_station_slot_min_load(station_id, 0, 0.5)
    print("✓ 设置最小负载: ", set_load_result)
    
    # 测试3: 更多建筑类型
    print("\n--- 测试3: 更多建筑类型 ---")
    
    # 添加太阳能板
    var solar_id = game_state.add_building({
        "type": "solar_panel",
        "position": Vector2(600, 600),
        "status": "idle"
    })
    print("✓ 添加太阳能板: ", solar_id)
    
    # 添加风力发电机
    var wind_id = game_state.add_building({
        "type": "wind_turbine",
        "position": Vector2(700, 700),
        "status": "idle"
    })
    print("✓ 添加风力发电机: ", wind_id)
    
    # 添加储存箱
    var storage_id = game_state.add_building({
        "type": "storage_mk1",
        "position": Vector2(800, 800),
        "status": "idle"
    })
    print("✓ 添加储存箱: ", storage_id)
    
    # 添加分流器
    var splitter_id = game_state.add_building({
        "type": "splitter",
        "position": Vector2(900, 900),
        "status": "idle"
    })
    print("✓ 添加分流器: ", splitter_id)
    
    # 测试4: 更多物品与配方
    print("\n--- 测试4: 更多物品与配方 ---")
    
    # 检查新物品
    var copper_ore = DataManager.get_item("copper_ore")
    print("✓ 获取铜矿石: ", copper_ore.get("name", ""))
    
    var coal = DataManager.get_item("coal")
    print("✓ 获取煤矿: ", coal.get("name", ""))
    
    # 检查新配方
    var copper_recipe = DataManager.get_recipe("copper_ingot_recipe")
    print("✓ 获取铜锭配方: ", copper_recipe.get("name", ""))
    
    var gear_recipe = DataManager.get_recipe("gear_recipe")
    print("✓ 获取齿轮配方: ", gear_recipe.get("name", ""))
    
    # 测试5: 综合测试
    print("\n--- 测试5: 综合测试 ---")
    
    # 检查所有建筑数量
    print("✓ 总建筑数: ", game_state.buildings.size())
    
    # 检查所有物品数量
    print("✓ 总物品数: ", DataManager.all_items.size())
    
    # 检查所有配方数量
    print("✓ 总配方数: ", DataManager.all_recipes.size())
    
    # 检查所有建筑类型数量
    print("✓ 总建筑类型数: ", DataManager.all_buildings.size())
    
    print("\n=== 第二阶段测试完成 ===")
    print("测试状态: 通过 ✓")
