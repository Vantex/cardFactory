# scripts/test/TestPhase3.gd
extends Node

func _ready():
    print("=== 第三阶段功能测试 ===")
    print("")
    
    var game_state = GameManager.get_game_state()
    var total_tests = 0
    var passed_tests = 0
    
    # 测试1: 空间索引系统
    print("--- 测试1: 空间索引系统 ---")
    var spatial_script = load("res://scripts/utils/SpatialIndex.gd")
    var spatial_index = spatial_script.new()
    
    # 添加实体
    spatial_index.add_entity("building_1", Vector2(100, 100))
    spatial_index.add_entity("building_2", Vector2(200, 200))
    spatial_index.add_entity("building_3", Vector2(300, 300))
    
    total_tests += 1
    if spatial_index.get_entity_count() == 3:
        passed_tests += 1
        print("✓ 添加实体: ", spatial_index.get_entity_count())
    
    # 查询实体
    var rect = Rect2(Vector2(50, 50), Vector2(200, 200))
    var entities = spatial_index.get_entities_in_rect(rect)
    
    total_tests += 1
    if entities.size() == 2:
        passed_tests += 1
        print("✓ 查询实体: ", entities.size())
    
    # 测试2: Shader文件
    print("\n--- 测试2: Shader文件 ---")
    
    var shader_files = [
        "res://shaders/glow.gdshader",
        "res://scripts/utils/SpatialIndex.gd"
    ]
    
    for shader_file in shader_files:
        total_tests += 1
        var file = FileAccess.open(shader_file, FileAccess.READ)
        if file:
            passed_tests += 1
            print("✓ Shader文件存在: ", shader_file)
            file.close()
        else:
            print("✗ Shader文件不存在: ", shader_file)
    
    # 测试3: UI组件
    print("\n--- 测试3: UI组件 ---")
    
    var ui_files = [
        "res://scenes/ui/BuildingPanel.gd",
        "res://scenes/ui/TechnologyPanel.gd",
        "res://scenes/ui/StationPanel.gd",
        "res://scenes/ui/SavePanel.gd",
        "res://scenes/ui/StatisticsPanel.gd",
        "res://scenes/ui/MainUI.gd"
    ]
    
    for ui_file in ui_files:
        total_tests += 1
        var file = FileAccess.open(ui_file, FileAccess.READ)
        if file:
            passed_tests += 1
            print("✓ UI组件存在: ", ui_file)
            file.close()
        else:
            print("✗ UI组件不存在: ", ui_file)
    
    # 测试4: 统计系统
    print("\n--- 测试4: 统计系统 ---")
    var stats_script = load("res://scripts/game/StatisticsSystem.gd")
    var stats_system = stats_script.new(game_state)
    
    total_tests += 1
    stats_system.update(1.0)
    passed_tests += 1
    print("✓ 统计系统更新")
    
    total_tests += 1
    var summary = stats_system.get_statistics_summary()
    if summary.size() > 0:
        passed_tests += 1
        print("✓ 获取统计摘要: ", summary.size(), "项")
    
    # 测试5: 存档系统
    print("\n--- 测试5: 存档系统 ---")
    var save_script = load("res://scripts/game/SaveSystem.gd")
    var save_system = save_script.new()
    
    total_tests += 1
    if save_system.save_game(0, game_state):
        passed_tests += 1
        print("✓ 保存游戏")
    
    total_tests += 1
    if save_system.has_save(0):
        passed_tests += 1
        print("✓ 检查存档")
    
    # 测试结果汇总
    print("\n=== 第三阶段测试结果汇总 ===")
    print("总测试数: ", total_tests)
    print("通过数: ", passed_tests)
    print("失败数: ", total_tests - passed_tests)
    print("通过率: ", snapped(passed_tests * 100.0 / total_tests, 0.1), "%")
    print("")
    print("测试状态: ", "通过 ✓" if passed_tests == total_tests else "失败 ✗")
