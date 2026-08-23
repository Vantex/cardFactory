# scripts/game/PowerSystem.gd
class_name PowerSystem
extends RefCounted

var game_state: GameState

# 电力数据
var total_generation: float = 0.0
var total_consumption: float = 0.0
var power_balance: float = 0.0

func _init(state: GameState):
    game_state = state

func update(_delta: float):
    _calculate_power()
    _apply_power_effects()

func _calculate_power():
    total_generation = 0.0
    total_consumption = 0.0
    
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_type = building.get("type", "")
        var building_def = DataManager.get_building(building_type)
        
        if building_def.is_empty():
            continue
        
        # 发电建筑
        if building_def.has("power_generation"):
            var efficiency = building.get("efficiency", 1.0)
            total_generation += building_def.power_generation * efficiency
        
        # 耗电建筑
        if building_def.has("power_demand"):
            total_consumption += building_def.power_demand
    
    power_balance = total_generation - total_consumption

func _apply_power_effects():
    # 如果电力不足，降低建筑效率
    if power_balance < 0 and total_consumption > 0:
        var efficiency_multiplier = max(0.0, 1.0 + power_balance / total_consumption)
        for building_id in game_state.buildings:
            var building = game_state.buildings[building_id]
            building["power_efficiency"] = efficiency_multiplier
    else:
        for building_id in game_state.buildings:
            var building = game_state.buildings[building_id]
            building["power_efficiency"] = 1.0

func get_power_info() -> Dictionary:
    return {
        "generation": total_generation,
        "consumption": total_consumption,
        "balance": power_balance
    }

func is_power_sufficient() -> bool:
    return power_balance >= 0
