# scripts/game/StatisticsSystem.gd
class_name StatisticsSystem
extends RefCounted

var game_state: GameState

# 生产统计
var production_stats: Dictionary = {}
var consumption_stats: Dictionary = {}

# 时间统计
var stats_start_time: float = 0.0
var last_update_time: float = 0.0

func _init(state: GameState):
    game_state = state
    stats_start_time = state.elapsed_time
    last_update_time = state.elapsed_time

func update(delta: float):
    var current_time = game_state.elapsed_time
    
    # 每秒更新一次统计
    if current_time - last_update_time >= 1.0:
        _update_statistics()
        last_update_time = current_time

func _update_statistics():
    # 重置统计
    production_stats.clear()
    consumption_stats.clear()
    
    # 遍历所有建筑
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_type = building.get("type", "")
        var recipe_id = building.get("recipe_id", "")
        
        # 统计生产
        var output_buffer = building.get("output_buffer", {})
        for item_id in output_buffer:
            var amount = output_buffer[item_id]
            if amount > 0:
                if not production_stats.has(item_id):
                    production_stats[item_id] = 0.0
                production_stats[item_id] += amount
        
        # 统计消耗
        var input_buffer = building.get("input_buffer", {})
        for item_id in input_buffer:
            var amount = input_buffer[item_id]
            if amount > 0:
                if not consumption_stats.has(item_id):
                    consumption_stats[item_id] = 0.0
                consumption_stats[item_id] += amount

func get_production_rate(item_id: String) -> float:
    return production_stats.get(item_id, 0.0)

func get_consumption_rate(item_id: String) -> float:
    return consumption_stats.get(item_id, 0.0)

func get_net_production(item_id: String) -> float:
    return get_production_rate(item_id) - get_consumption_rate(item_id)

func get_all_production() -> Dictionary:
    return production_stats

func get_all_consumption() -> Dictionary:
    return consumption_stats

func get_total_buildings() -> int:
    return game_state.buildings.size()

func get_total_connections() -> int:
    return game_state.connections.size()

func get_building_count_by_type(building_type: String) -> int:
    var count = 0
    for building_id in game_state.buildings:
        if game_state.buildings[building_id].get("type", "") == building_type:
            count += 1
    return count

func get_statistics_summary() -> Dictionary:
    return {
        "total_buildings": get_total_buildings(),
        "total_connections": get_total_connections(),
        "elapsed_time": game_state.elapsed_time,
        "production": get_all_production(),
        "consumption": get_all_consumption()
    }

# === 统计系统补完功能 ===

# 1. 获取物流吞吐量
func get_logistics_throughput() -> Dictionary:
    var throughput = {}
    var game_state = GameManager.get_game_state()
    
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        var item_id = connection.get("item_id", "")
        var flow_rate = connection.get("flow_rate", 0.0)
        
        if not throughput.has(item_id):
            throughput[item_id] = 0.0
        throughput[item_id] += flow_rate
    
    return throughput

# 2. 获取物流延迟
func get_logistics_latency() -> Dictionary:
    # 简化实现：返回固定延迟
    return {
        "min_latency": 0.1,
        "max_latency": 1.0,
        "avg_latency": 0.5
    }

# 3. 获取物流效率
func get_logistics_efficiency() -> float:
    var game_state = GameManager.get_game_state()
    var total_connections = game_state.connections.size()
    var active_connections = 0
    
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        if connection.get("active", false):
            active_connections += 1
    
    if total_connections == 0:
        return 0.0
    
    return float(active_connections) / float(total_connections)

# 4. 获取电力统计
func get_power_statistics() -> Dictionary:
    var game_state = GameManager.get_game_state()
    var stats = {
        "total_demand": 0.0,
        "total_generation": 0.0,
        "balance": 0.0,
        "efficiency": 0.0
    }
    
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_type = building.get("type", "")
        var building_def = DataManager.get_building(building_type)
        
        if building_def.has("power_demand"):
            stats.total_demand += building_def.power_demand
        if building_def.has("power_generation"):
            stats.total_generation += building_def.power_generation
    
    stats.balance = stats.total_generation - stats.total_demand
    stats.efficiency = min(1.0, stats.total_generation / max(1.0, stats.total_demand))
    
    return stats

# 5. 获取生产历史
var production_history: Array = []

func record_production_snapshot():
    var snapshot = {
        "timestamp": GameManager.get_game_state().elapsed_time,
        "production": get_all_production().duplicate(),
        "consumption": get_all_consumption().duplicate()
    }
    production_history.append(snapshot)
    
    # 保留最近100条记录
    if production_history.size() > 100:
        production_history.pop_front()

func get_production_history() -> Array:
    return production_history

# 6. 获取生产趋势
func get_production_trend(item_id: String) -> float:
    if production_history.size() < 2:
        return 0.0
    
    var recent = production_history[-1].get("production", {})
    var previous = production_history[-2].get("production", {})
    
    var recent_amount = recent.get(item_id, 0.0)
    var previous_amount = previous.get(item_id, 0.0)
    
    if previous_amount == 0:
        return 0.0
    
    return (recent_amount - previous_amount) / previous_amount

# 7. 获取建筑效率统计
func get_building_efficiency_stats() -> Dictionary:
    var game_state = GameManager.get_game_state()
    var stats = {
        "total_buildings": 0,
        "running_buildings": 0,
        "idle_buildings": 0,
        "blocked_buildings": 0,
        "avg_efficiency": 0.0
    }
    
    var total_efficiency = 0.0
    
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var status = building.get("status", "idle")
        
        stats.total_buildings += 1
        
        match status:
            "running":
                stats.running_buildings += 1
                total_efficiency += building.get("efficiency", 1.0)
            "idle":
                stats.idle_buildings += 1
            "blocked":
                stats.blocked_buildings += 1
    
    if stats.running_buildings > 0:
        stats.avg_efficiency = total_efficiency / stats.running_buildings
    
    return stats

# 8. 获取资源统计
func get_resource_statistics() -> Dictionary:
    var game_state = GameManager.get_game_state()
    var stats = {}
    
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var input_buffer = building.get("input_buffer", {})
        var output_buffer = building.get("output_buffer", {})
        
        for item_id in input_buffer:
            if not stats.has(item_id):
                stats[item_id] = {"stored": 0.0, "produced": 0.0, "consumed": 0.0}
            stats[item_id].stored += input_buffer[item_id]
        
        for item_id in output_buffer:
            if not stats.has(item_id):
                stats[item_id] = {"stored": 0.0, "produced": 0.0, "consumed": 0.0}
            stats[item_id].stored += output_buffer[item_id]
    
    return stats
