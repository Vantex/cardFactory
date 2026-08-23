# scripts/game/SimulationEngine.gd
class_name SimulationEngine
extends Node

var game_state: GameState
var production_system: ProductionSystem
var belt_system: RefCounted
var power_system: RefCounted
var statistics_system: RefCounted

func _init(state: GameState):
    game_state = state
    production_system = ProductionSystem.new(state)
    
    # 动态加载BeltSystem
    var belt_script = load("res://scripts/game/BeltSystem.gd")
    if belt_script:
        belt_system = belt_script.new(state)
    else:
        print("ERROR: Failed to load BeltSystem script")
    
    # 动态加载PowerSystem
    var power_script = load("res://scripts/game/PowerSystem.gd")
    if power_script:
        power_system = power_script.new(state)
    else:
        print("ERROR: Failed to load PowerSystem script")
    
    # 动态加载StatisticsSystem
    var stats_script = load("res://scripts/game/StatisticsSystem.gd")
    if stats_script:
        statistics_system = stats_script.new(state)
    else:
        print("ERROR: Failed to load StatisticsSystem script")

func update(delta: float):
    if game_state.paused:
        return
    
    var game_delta = delta * game_state.speed
    game_state.elapsed_time += game_delta
    
    # 更新顺序：电力 → 传送带 → 生产 → 统计
    if power_system:
        power_system.update(game_delta)
    if belt_system:
        belt_system.update(game_delta)
    production_system.update(game_delta)
    if statistics_system:
        statistics_system.update(game_delta)
    
    EventBus.simulation_updated.emit()

func toggle_pause():
    game_state.paused = !game_state.paused

func set_speed(new_speed: float):
    game_state.speed = clamp(new_speed, 0.5, 4.0)

func get_power_info() -> Dictionary:
    if power_system:
        return power_system.get_power_info()
    return {"generation": 0, "consumption": 0, "balance": 0}

func get_statistics() -> Dictionary:
    if statistics_system:
        return statistics_system.get_statistics_summary()
    return {}
