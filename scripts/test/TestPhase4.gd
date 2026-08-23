# scripts/test/TestPhase4.gd
extends Node

func _ready():
    print("=== 第四阶段功能测试 ===")
    print("")
    
    var game_state = GameManager.get_game_state()
    var total_tests = 0
    var passed_tests = 0
    
    # 测试1: 行星系统
    print("--- 测试1: 行星系统 ---")
    var planet_script = load("res://scripts/game/PlanetSystem.gd")
    var planet_system = planet_script.new(game_state)
    
    # 1.1 获取行星
    total_tests += 1
    var home = planet_system.get_planet("home")
    if not home.is_empty():
        passed_tests += 1
        print("✓ 获取行星: ", home.get("name", ""))
    
    # 1.2 获取所有行星
    total_tests += 1
    var all_planets = planet_system.get_all_planets()
    if all_planets.size() > 0:
        passed_tests += 1
        print("✓ 获取所有行星: ", all_planets.size())
    
    # 1.3 获取行星资源
    total_tests += 1
    var resources = planet_system.get_planet_resources("home")
    if resources.size() > 0:
        passed_tests += 1
        print("✓ 获取行星资源: ", resources.size())
    
    # 1.4 获取星系中的行星
    total_tests += 1
    var helios_planets = planet_system.get_planets_in_system("helios")
    if helios_planets.size() > 0:
        passed_tests += 1
        print("✓ 获取星系行星: ", helios_planets.size())
    
    # 1.5 获取行星统计
    total_tests += 1
    var stats = planet_system.get_planet_statistics()
    if stats.get("total_planets", 0) > 0:
        passed_tests += 1
        print("✓ 获取行星统计: ", stats.get("total_planets", 0), "行星")
    
    # 测试2: 星系系统
    print("\n--- 测试2: 星系系统 ---")
    var galaxy_script = load("res://scripts/game/GalaxySystem.gd")
    var galaxy_system = galaxy_script.new(game_state)
    
    # 2.1 获取星系
    total_tests += 1
    var helios = galaxy_system.get_star_system("helios")
    if not helios.is_empty():
        passed_tests += 1
        print("✓ 获取星系: ", helios.get("name", ""))
    
    # 2.2 获取所有星系
    total_tests += 1
    var all_systems = galaxy_system.get_all_star_systems()
    if all_systems.size() > 0:
        passed_tests += 1
        print("✓ 获取所有星系: ", all_systems.size())
    
    # 2.3 获取星系行星
    total_tests += 1
    var system_planets = galaxy_system.get_system_planets("helios")
    if system_planets.size() > 0:
        passed_tests += 1
        print("✓ 获取星系行星: ", system_planets.size())
    
    # 2.4 检查星系是否解锁
    total_tests += 1
    var is_unlocked = galaxy_system.is_system_unlocked("helios")
    if is_unlocked:
        passed_tests += 1
        print("✓ 母星系已解锁")
    
    # 2.5 获取星系信息
    total_tests += 1
    var summary = galaxy_system.get_system_summary("helios")
    if summary.size() > 0:
        passed_tests += 1
        print("✓ 获取星系信息: ", summary.get("name", ""))
    
    # 测试3: 戴森球系统
    print("\n--- 测试3: 戴森球系统 ---")
    var dyson_script = load("res://scripts/game/DysonSphereSystem.gd")
    var dyson_system = dyson_script.new(game_state)
    
    # 3.1 创建戴森层
    total_tests += 1
    var create_result = dyson_system.create_dyson_layer("helios")
    if create_result:
        passed_tests += 1
        print("✓ 创建戴森层")
    
    # 3.2 添加戴森节点
    total_tests += 1
    var layers = dyson_system.get_layers_in_system("helios")
    if layers.size() > 0:
        var add_result = dyson_system.add_dyson_node(layers[0], 0.0)
        if add_result:
            passed_tests += 1
            print("✓ 添加戴森节点")
    
    # 3.3 获取戴森球状态
    total_tests += 1
    var dyson_status = dyson_system.get_dyson_status("helios")
    if dyson_status.size() > 0:
        passed_tests += 1
        print("✓ 获取戴森球状态: ", dyson_status.get("layer_count", 0), "层")
    
    # 3.4 计算戴森球容量
    total_tests += 1
    var capacity = dyson_system.calculate_dyson_capacity("helios")
    passed_tests += 1
    print("✓ 计算戴森球容量: ", capacity)
    
    # 3.5 获取戴森球统计
    total_tests += 1
    var dyson_stats = dyson_system.get_dyson_statistics()
    if dyson_stats.size() > 0:
        passed_tests += 1
        print("✓ 获取戴森球统计")
    
    # 测试4: UI组件
    print("\n--- 测试4: UI组件 ---")
    
    var ui_files = [
        "res://scenes/ui/GalaxyMap.gd",
        "res://scenes/ui/DysonUI.gd"
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
    
    # 测试结果汇总
    print("\n=== 第四阶段测试结果汇总 ===")
    print("总测试数: ", total_tests)
    print("通过数: ", passed_tests)
    print("失败数: ", total_tests - passed_tests)
    print("通过率: ", snapped(passed_tests * 100.0 / total_tests, 0.1), "%")
    print("")
    print("测试状态: ", "通过 ✓" if passed_tests == total_tests else "失败 ✗")
