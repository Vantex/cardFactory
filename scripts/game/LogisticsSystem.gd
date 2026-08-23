# scripts/game/LogisticsSystem.gd
class_name LogisticsSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
    game_state = state

func update(delta: float):
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        _update_connection(connection, delta)

func _update_connection(connection: Dictionary, delta: float):
    var source_id = connection.source_id
    var target_id = connection.target_id
    var item_id = connection.item_id
    var flow_rate = connection.get("flow_rate", 10.0) / 60.0  # 转换为每秒
    
    var source = game_state.get_building(source_id)
    var target = game_state.get_building(target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    # 计算可传输量
    var available = source.get("output_buffer", {}).get(item_id, 0.0)
    var target_buffer = target.get("input_buffer", {}).get(item_id, 0.0)
    var max_transfer = min(available, 60 - target_buffer)  # 目标最大60
    var transfer_amount = min(max_transfer, flow_rate * delta)
    
    if transfer_amount > 0:
        # 执行传输
        if not source.has("output_buffer"):
            source.output_buffer = {}
        if not target.has("input_buffer"):
            target.input_buffer = {}
        
        source.output_buffer[item_id] = source.output_buffer.get(item_id, 0.0) - transfer_amount
        target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
