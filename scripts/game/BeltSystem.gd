# scripts/game/BeltSystem.gd
class_name BeltSystem
extends RefCounted

const DEFAULT_BUFFER_CAPACITY := 60.0

var game_state: GameState
var statistics_system: StatisticsSystem

func _init(state: GameState, statistics: StatisticsSystem = null):
	game_state = state
	statistics_system = statistics

func clear_flow_state() -> void:
	for conn_id in game_state.connections:
		var connection = game_state.connections[conn_id]
		connection["active"] = false
		connection["current_flow"] = 0.0

func update(delta: float):
	clear_flow_state()
	var connection_ids: Array = game_state.connections.keys()
	connection_ids.sort_custom(_connection_precedes)
	for conn_id in connection_ids:
		var connection = game_state.connections[conn_id]
		_update_connection(connection, delta)

func _connection_precedes(left_id: Variant, right_id: Variant) -> bool:
	var left_key := String(left_id)
	var right_key := String(right_id)
	var left_config := game_state.get_belt_configuration(left_key)
	var right_config := game_state.get_belt_configuration(right_key)
	var left_priority := int(left_config.get("priority", 0))
	var right_priority := int(right_config.get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	return left_key < right_key

func _update_connection(connection: Dictionary, delta: float):
	if not connection.get("enabled", true) or delta <= 0.0:
		return

	var source_id = connection.get("source_id", "")
	var target_id = connection.get("target_id", "")
	var item_id = connection.get("item_id", "")
	var flow_rate := _effective_throughput(connection)

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
	var target_definition := DataManager.get_building(String(target.get("type", "")))
	var target_capacity := maxf(float(target.get("input_buffer_capacity", target_definition.get("input_buffer_capacity", DEFAULT_BUFFER_CAPACITY))), 0.0)
	var max_transfer = min(available, target_capacity - target_buffer)
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
		if connection.get("monitor_enabled", false):
			connection["total_transferred"] = float(connection.get("total_transferred", 0.0)) + transfer_amount
		if statistics_system != null:
			statistics_system.record_transferred(String(item_id), transfer_amount, String(connection.get("id", "")))

func _effective_throughput(connection: Dictionary) -> float:
	var connection_type := String(connection.get("type", "belt"))
	if connection_type == "belt":
		return maxf(float(connection.get("flow_rate", 10.0)), 0.0)
	var configuration := game_state.get_belt_configuration(String(connection.get("id", "")))
	if configuration.is_empty():
		return maxf(float(connection.get("flow_rate", 10.0)), 0.0)
	return maxf(float(configuration.get("effective_throughput", 10.0)), 0.0)

func create_belt(source_id: String, target_id: String, item_id: String, flow_rate: float = 10.0) -> String:
	var result := game_state.try_add_connection(source_id, target_id, item_id)
	return String(result.get("id", "")) if result.get("ok", false) else ""
