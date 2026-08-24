# scripts/game/BeltSystem.gd
class_name BeltSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
	game_state = state

func clear_flow_state() -> void:
	for conn_id in game_state.connections:
		var connection = game_state.connections[conn_id]
		connection["active"] = false
		connection["current_flow"] = 0.0

func update(delta: float):
	clear_flow_state()
	var connection_ids: Array = game_state.connections.keys()
	connection_ids.sort()
	for conn_id in connection_ids:
		var connection = game_state.connections[conn_id]
		_update_connection(connection, delta)

func _update_connection(connection: Dictionary, delta: float):
	if not connection.get("enabled", true) or delta <= 0.0:
		return

	var source_id = connection.get("source_id", "")
	var target_id = connection.get("target_id", "")
	var item_id = connection.get("item_id", "")
	var flow_rate = connection.get("flow_rate", 10.0)

	var source = game_state.get_building(source_id)
	var target = game_state.get_building(target_id)

	if source.is_empty() or target.is_empty():
		return
	var source_power := clampf(float(source.get("power_efficiency", 1.0)), 0.0, 1.0)
	var target_power := clampf(float(target.get("power_efficiency", 1.0)), 0.0, 1.0)
	var power_efficiency := minf(source_power, target_power)
	if power_efficiency <= 0.0:
		return

	var available = source.get("output_buffer", {}).get(item_id, 0.0)
	var target_buffer = target.get("input_buffer", {}).get(item_id, 0.0)
	var max_transfer = min(available, 60.0 - target_buffer)
	var transfer_amount = min(max_transfer, flow_rate * delta * power_efficiency)

	if transfer_amount > 0:
		if not source.has("output_buffer"):
			source.output_buffer = {}
		if not target.has("input_buffer"):
			target.input_buffer = {}

		source.output_buffer[item_id] = source.output_buffer.get(item_id, 0.0) - transfer_amount
		target.input_buffer[item_id] = target.input_buffer.get(item_id, 0.0) + transfer_amount
		connection["current_flow"] = transfer_amount / delta
		connection["active"] = true

func create_belt(source_id: String, target_id: String, item_id: String, flow_rate: float = 10.0) -> String:
	var connection_data = {
		"source_id": source_id,
		"target_id": target_id,
		"item_id": item_id,
		"flow_rate": flow_rate,
		"type": "belt",
		"current_flow": 0.0,
		"enabled": true,
		"active": false
	}
	return game_state.add_connection(connection_data)
