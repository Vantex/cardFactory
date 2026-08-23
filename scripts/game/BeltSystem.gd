# scripts/game/BeltSystem.gd
class_name BeltSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
    game_state = state

func update(delta: float):
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        _update_connection(connection, delta)

func _update_connection(connection: Dictionary, delta: float):
    var source_id = connection.get("source_id", "")
    var target_id = connection.get("target_id", "")
    var item_id = connection.get("item_id", "")
    var flow_rate = connection.get("flow_rate", 10.0)
    
    var source = game_state.get_building(source_id)
    var target = game_state.get_building(target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    # 计算可传输量
    var available = source.get("output_buffer", {}).get(item_id, 0.0)
    var target_buffer = target.get("input_buffer", {}).get(item_id, 0.0)
    var max_transfer = min(available, 60.0 - target_buffer)
    var transfer_amount = min(max_transfer, flow_rate * delta)
    
    if transfer_amount > 0:
        # 执行传输
        if not source.has("output_buffer"):
            source.output_buffer = {}
        if not target.has("input_buffer"):
            target.input_buffer = {}
        
        source.output_buffer[item_id] = source.output_buffer.get(item_id, 0.0) - transfer_amount
        target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
        
        # 更新连接状态
        connection["current_flow"] = transfer_amount / delta
        connection["active"] = true
    else:
        connection["current_flow"] = 0.0
        connection["active"] = false

func create_belt(source_id: String, target_id: String, item_id: String, flow_rate: float = 10.0) -> String:
    var connection_data = {
        "source_id": source_id,
        "target_id": target_id,
        "item_id": item_id,
        "flow_rate": flow_rate,
        "type": "belt",
        "current_flow": 0.0,
        "active": false
    }
    return game_state.add_connection(connection_data)
