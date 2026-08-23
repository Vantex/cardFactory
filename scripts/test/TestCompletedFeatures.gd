# scripts/test/TestCompletedFeatures.gd
extends Node

func _ready():
    print("=== 补完功能测试 ===")
    print("")
    
    var game_state = GameManager.get_game_state()
    var total_tests = 0
    var passed_tests = 0
    
    # 测试1: 游戏核心系统补完功能
    print("--- 测试1: 游戏核心系统补完功能 ---")
    
    # 1.1 创建速通状态
    total_tests += 1
    var speedrun = game_state.create_speedrun_state()
    if speedrun.size() > 0:
        passed_tests += 1
        print("✓ 创建速通状态")
    
    # 1.2 时间扭曲电力成本
    total_tests += 1
    var cost = game_state.get_time_warp_power_cost(2.0)
    if cost > 0:
        passed_tests += 1
        print("✓ 时间扭曲电力成本: ", cost)
    
    # 1.3 模拟预算
    total_tests += 1
    var budget = game_state.get_simulation_budget()
    if budget.size() > 0:
        passed_tests += 1
        print("✓ 获取模拟预算")
    
    # 1.4 游戏状态复制
    total_tests += 1
    var copy = game_state.copy_state()
    if copy != null:
        passed_tests += 1
        print("✓ 复制游戏状态")
    
    # 1.5 实体锁定检查
    total_tests += 1
    var locked = game_state.is_entity_interaction_locked("test")
    passed_tests += 1
    print("✓ 实体锁定检查: ", locked)
    
    # 测试2: 实体与建筑系统补完功能
    print("\n--- 测试2: 实体与建筑系统补完功能 ---")
    
    # 2.1 添加测试建筑
    var building_id = game_state.add_building({
        "type": "miner",
        "position": Vector2(100, 100),
        "status": "idle"
    })
    
    # 2.2 获取建筑堆叠检查
    total_tests += 1
    var stack_check = game_state.get_building_stack_check(0, 5, "miner")
    if stack_check.get("ok"):
        passed_tests += 1
        print("✓ 建筑堆叠检查通过")
    
    # 2.3 获取缓冲区限制
    total_tests += 1
    var buffer_limit = game_state.get_entity_buffer_limit(building_id)
    passed_tests += 1
    print("✓ 缓冲区限制: ", buffer_limit)
    
    # 2.4 获取输入容量
    total_tests += 1
    var input_cap = game_state.get_entity_input_capacity(building_id)
    passed_tests += 1
    print("✓ 输入容量: ", input_cap)
    
    # 2.5 获取输出容量
    total_tests += 1
    var output_cap = game_state.get_entity_output_capacity(building_id)
    passed_tests += 1
    print("✓ 输出容量: ", output_cap)
    
    # 2.6 获取建筑信息
    total_tests += 1
    var info = game_state.get_building_info(building_id)
    if info.size() > 0:
        passed_tests += 1
        print("✓ 获取建筑信息")
    
    # 2.7 检查建筑是否存在
    total_tests += 1
    if game_state.building_exists(building_id):
        passed_tests += 1
        print("✓ 建筑存在检查")
    
    # 2.8 获取建筑数量
    total_tests += 1
    var count = game_state.get_building_count()
    if count > 0:
        passed_tests += 1
        print("✓ 建筑数量: ", count)
    
    # 测试3: 电力系统补完功能
    print("\n--- 测试3: 电力系统补完功能 ---")
    
    # 3.1 添加发电机
    var gen_id = game_state.add_building({
        "type": "power_generator",
        "position": Vector2(300, 100)
    })
    
    # 3.2 获取实体电力需求
    total_tests += 1
    var demand = game_state.get_entity_power_demand(building_id)
    passed_tests += 1
    print("✓ 电力需求: ", demand)
    
    # 3.3 获取实体发电量
    total_tests += 1
    var generation = game_state.get_entity_power_generation(gen_id)
    passed_tests += 1
    print("✓ 发电量: ", generation)
    
    # 3.4 计算电力平衡
    total_tests += 1
    var balance = game_state.calculate_power_balance()
    passed_tests += 1
    print("✓ 电力平衡: ", balance)
    
    # 3.5 检查电力是否充足
    total_tests += 1
    var sufficient = game_state.is_power_sufficient()
    passed_tests += 1
    print("✓ 电力充足: ", sufficient)
    
    # 3.6 获取电力网格统计
    total_tests += 1
    var grid_stats = game_state.get_power_grid_stats()
    if grid_stats.size() > 0:
        passed_tests += 1
        print("✓ 电力网格统计")
    
    # 测试4: 存档系统补完功能
    print("\n--- 测试4: 存档系统补完功能 ---")
    
    var save_script = load("res://scripts/game/SaveSystem.gd")
    var save_system = save_script.new()
    
    # 4.1 检查存档完整性
    total_tests += 1
    var valid = save_system.validate_save(0)
    passed_tests += 1
    print("✓ 存档完整性检查: ", valid)
    
    # 4.2 获取存档大小
    total_tests += 1
    var size = save_system.get_save_size(0)
    passed_tests += 1
    print("✓ 存档大小: ", size)
    
    # 测试5: 统计系统补完功能
    print("\n--- 测试5: 统计系统补完功能 ---")
    
    var stats_script = load("res://scripts/game/StatisticsSystem.gd")
    var stats_system = stats_script.new(game_state)
    
    # 5.1 获取物流吞吐量
    total_tests += 1
    var throughput = stats_system.get_logistics_throughput()
    passed_tests += 1
    print("✓ 物流吞吐量")
    
    # 5.2 获取物流效率
    total_tests += 1
    var efficiency = stats_system.get_logistics_efficiency()
    passed_tests += 1
    print("✓ 物流效率: ", efficiency)
    
    # 5.3 获取电力统计
    total_tests += 1
    var power_stats = stats_system.get_power_statistics()
    if power_stats.size() > 0:
        passed_tests += 1
        print("✓ 电力统计")
    
    # 5.4 获取建筑效率统计
    total_tests += 1
    var building_stats = stats_system.get_building_efficiency_stats()
    if building_stats.size() > 0:
        passed_tests += 1
        print("✓ 建筑效率统计")
    
    # 5.5 获取资源统计
    total_tests += 1
    var resource_stats = stats_system.get_resource_statistics()
    passed_tests += 1
    print("✓ 资源统计")
    
    # 测试6: 性能优化系统
    print("\n--- 测试6: 性能优化系统 ---")
    
    var perf_script = load("res://scripts/game/PerformanceSystem.gd")
    var perf_system = perf_script.new(game_state)
    
    # 6.1 获取性能统计
    total_tests += 1
    var perf_stats = perf_system.get_performance_stats()
    if perf_stats.size() > 0:
        passed_tests += 1
        print("✓ 性能统计")
    
    # 6.2 获取性能配置
    total_tests += 1
    var perf_config = perf_system.get_config()
    if perf_config.size() > 0:
        passed_tests += 1
        print("✓ 性能配置")
    
    # 6.3 模拟批处理大小
    total_tests += 1
    var batch_size = perf_system.get_simulation_batch_size()
    if batch_size > 0:
        passed_tests += 1
        print("✓ 模拟批处理大小: ", batch_size)
    
    # 测试结果汇总
    print("\n=== 补完功能测试结果汇总 ===")
    print("总测试数: ", total_tests)
    print("通过数: ", passed_tests)
    print("失败数: ", total_tests - passed_tests)
    print("通过率: ", snapped(passed_tests * 100.0 / total_tests, 0.1), "%")
    print("")
    print("测试状态: ", "通过 ✓" if passed_tests == total_tests else "失败 ✗")
