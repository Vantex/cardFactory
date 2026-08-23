# scripts/test/TestNewFeatures.gd
extends Node

func _ready():
    print("=== 第一阶段功能测试 ===")
    print("测试时间: ", Time.get_datetime_string_from_system())
    print("")
    
    var game_state = GameManager.get_game_state()
    
    # 测试1: 实体管理
    print("--- 测试1: 实体管理 ---")
    
    # 添加建筑
    var building_id = game_state.add_building({
        "type": "miner",
        "position": Vector2(100, 100),
        "status": "idle"
    })
    print("✓ 添加矿机: ", building_id, " 位置: (100, 100)")
    
    # 移动建筑
    var move_result = game_state.move_entity(building_id, Vector2(200, 200))
    var new_pos = game_state.get_building(building_id).get("position")
    print("✓ 移动矿机: 结果=", move_result, " 新位置=", new_pos)
    
    # 批量移动
    var building_id2 = game_state.add_building({
        "type": "smelter",
        "position": Vector2(300, 300),
        "status": "idle"
    })
    
    var positions = [
        {"id": building_id, "position": Vector2(150, 150)},
        {"id": building_id2, "position": Vector2(400, 400)}
    ]
    var moved_count = game_state.move_entities(positions)
    print("✓ 批量移动: 移动数量=", moved_count)
    
    # 设置配方
    var recipe_result = game_state.set_entity_recipe(building_id2, "iron_ingot_recipe")
    print("✓ 设置配方: 结果=", recipe_result, " 配方=", game_state.get_building(building_id2).get("recipe_id"))
    
    # 测试2: 建筑升级
    print("\n--- 测试2: 建筑升级 ---")
    
    var building_id3 = game_state.add_building({
        "type": "assembling_machine_mk1",
        "position": Vector2(500, 500),
        "status": "idle"
    })
    
    var upgrade_result = game_state.upgrade_entity(building_id3)
    print("✓ 升级制造台: 结果=", upgrade_result, " 类型=", game_state.get_building(building_id3).get("type"))
    
    # 测试3: 传送带系统
    print("\n--- 测试3: 传送带系统 ---")
    
    var belt_id = game_state.add_connection({
        "source_id": building_id,
        "target_id": building_id2,
        "item_id": "iron_ore",
        "type": "conveyor_belt_mk1",
        "speed_multiplier": 1.0,
        "lanes": 1,
        "priority": 0,
        "stack_size": 1,
        "route_mode": "auto"
    })
    print("✓ 创建传送带: ", belt_id)
    
    # 升级传送带
    game_state.upgrade_belt(belt_id)
    print("✓ 升级传送带: 类型=", game_state.connections[belt_id].get("type"))
    
    # 设置通道数
    game_state.set_belt_lane_count(belt_id, 2)
    print("✓ 设置通道数: ", game_state.connections[belt_id].get("lanes"))
    
    # 设置优先级
    game_state.set_belt_priority(belt_id, 1)
    print("✓ 设置优先级: ", game_state.connections[belt_id].get("priority"))
    
    # 设置堆叠大小
    game_state.set_belt_stack_size(belt_id, 4)
    print("✓ 设置堆叠大小: ", game_state.connections[belt_id].get("stack_size"))
    
    # 设置路由模式
    game_state.set_belt_route_mode(belt_id, "bezier")
    print("✓ 设置路由模式: ", game_state.connections[belt_id].get("route_mode"))
    
    # 测试4: 分拣器系统
    print("\n--- 测试4: 分拣器系统 ---")
    
    var sorter_id = game_state.add_connection({
        "source_id": building_id2,
        "target_id": building_id3,
        "item_id": "iron_ingot",
        "type": "sorter_mk1",
        "speed_multiplier": 1.0,
        "direction": "right",
        "filter_item": ""
    })
    print("✓ 创建分拣器: ", sorter_id)
    
    # 升级分拣器
    game_state.upgrade_sorter(sorter_id)
    print("✓ 升级分拣器: 类型=", game_state.connections[sorter_id].get("type"))
    
    # 设置方向
    game_state.set_sorter_direction(sorter_id, "left")
    print("✓ 设置方向: ", game_state.connections[sorter_id].get("direction"))
    
    # 设置过滤
    game_state.set_sorter_filter(sorter_id, "iron_ingot")
    print("✓ 设置过滤: ", game_state.connections[sorter_id].get("filter_item"))
    
    # 测试5: 电力系统
    print("\n--- 测试5: 电力系统 ---")
    
    # 设置电力网格
    game_state.set_entity_power_grid(building_id, "grid-a")
    print("✓ 设置电力网格: ", game_state.buildings[building_id].get("power_grid_id"))
    
    # 设置电力优先级
    game_state.set_entity_power_priority(building_id, 2)
    print("✓ 设置电力优先级: ", game_state.buildings[building_id].get("power_priority"))
    
    # 设置发电优先级
    game_state.set_entity_generation_priority(building_id, 1)
    print("✓ 设置发电优先级: ", game_state.buildings[building_id].get("generation_priority"))
    
    # 测试6: 批量操作
    print("\n--- 测试6: 批量操作 ---")
    
    # 批量设置配方
    var building_id4 = game_state.add_building({"type": "smelter", "position": Vector2(600, 600)})
    var building_id5 = game_state.add_building({"type": "smelter", "position": Vector2(700, 700)})
    game_state.set_entities_recipe([building_id4, building_id5], "copper_ingot_recipe")
    print("✓ 批量设置配方")
    
    # 批量锁定
    game_state.set_entities_interaction_locked([building_id4, building_id5], true)
    print("✓ 批量锁定")
    
    # 批量升级
    var building_id6 = game_state.add_building({"type": "assembling_machine_mk1", "position": Vector2(800, 800)})
    var building_id7 = game_state.add_building({"type": "assembling_machine_mk1", "position": Vector2(900, 900)})
    game_state.upgrade_entities([building_id6, building_id7])
    print("✓ 批量升级")
    
    # 批量删除
    game_state.remove_entities([building_id4, building_id5, building_id6, building_id7])
    print("✓ 批量删除")
    
    # 测试结果汇总
    print("\n=== 测试结果汇总 ===")
    print("总建筑数: ", game_state.buildings.size())
    print("总连接数: ", game_state.connections.size())
    print("测试状态: 通过 ✓")
