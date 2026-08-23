extends Node2D

const CardRenderer = preload("res://scripts/rendering/CardRenderer.gd")
const CURVE_STEPS := 20

var _game_state: GameState

func set_game_state(game_state: GameState) -> void:
	_game_state = game_state
	queue_redraw()

func _draw() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	for connection in game_state.connections.values():
		_draw_connection(connection, game_state)
	_draw_connection_draft(game_state)

func _draw_connection(connection: Dictionary, game_state: GameState) -> void:
	var source: Dictionary = game_state.get_building(connection.get("source_id", ""))
	var target: Dictionary = game_state.get_building(connection.get("target_id", ""))
	if source.is_empty() or target.is_empty():
		return
	var start := CardRenderer.get_output_port_rect(source.get("position", Vector2.ZERO)).get_center()
	var end := CardRenderer.get_input_port_rect(target.get("position", Vector2.ZERO)).get_center()
	var active: bool = connection.get("active", false)
	var color := Color("38e6c2") if active else Color("6e90ad")
	var control := _curve_control(start, end)
	draw_polyline(_curve_points(start, end), color, 3.0 if active else 2.0, true)
	_draw_arrow(_quadratic_point(start, control, end, 0.92), _quadratic_tangent(start, control, end, 0.92), color)
	_draw_connection_label(connection.get("item_id", ""), _quadratic_point(start, control, end, 0.5), color)
	if active:
		_draw_flow_particles(start, end)

func _draw_connection_draft(game_state: GameState) -> void:
	var input_handler := get_node_or_null("../InputHandler")
	if input_handler == null or not input_handler.has_method("get_mode_name") or input_handler.call("get_mode_name") != "connecting":
		return
	var source_id: String = input_handler.get("connecting_source_id")
	var source: Dictionary = game_state.get_building(source_id)
	if source.is_empty():
		return
	var start := CardRenderer.get_output_port_rect(source.get("position", Vector2.ZERO)).get_center()
	draw_polyline(_curve_points(start, get_global_mouse_position()), Color(0.6, 0.84, 1.0, 0.7), 2.0, true)

func _curve_points(start: Vector2, end: Vector2) -> PackedVector2Array:
	var control := _curve_control(start, end)
	var points := PackedVector2Array()
	for step in range(CURVE_STEPS + 1):
		points.append(_quadratic_point(start, control, end, float(step) / float(CURVE_STEPS)))
	return points

func _curve_control(start: Vector2, end: Vector2) -> Vector2:
	var bend := clampf(absf(end.x - start.x) * 0.18, 28.0, 96.0)
	return start.lerp(end, 0.5) + Vector2(0, bend)

func _quadratic_point(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inverse_t := 1.0 - t
	return inverse_t * inverse_t * start + 2.0 * inverse_t * t * control + t * t * end

func _quadratic_tangent(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	return (2.0 * (1.0 - t) * (control - start) + 2.0 * t * (end - control)).normalized()

func _draw_arrow(position: Vector2, direction: Vector2, color: Color) -> void:
	if direction == Vector2.ZERO:
		return
	var tail := position - direction * 8.0
	draw_line(tail, tail + direction.rotated(0.55) * 9.0, color, 2.0, true)
	draw_line(tail, tail + direction.rotated(-0.55) * 9.0, color, 2.0, true)

func _draw_connection_label(item_id: String, position: Vector2, color: Color) -> void:
	if item_id.is_empty():
		return
	var label_size := ThemeDB.fallback_font.get_string_size(item_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var label_rect := Rect2(position - label_size * 0.5 - Vector2(4, 10), label_size + Vector2(8, 7))
	draw_rect(label_rect, Color(0.05, 0.09, 0.14, 0.88), true)
	draw_string(ThemeDB.fallback_font, label_rect.position + Vector2(4, 10), item_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

func _draw_flow_particles(start: Vector2, end: Vector2) -> void:
	var control := _curve_control(start, end)
	var time := Time.get_ticks_msec() / 1000.0
	for index in range(3):
		var progress := fmod(time * 0.65 + float(index) / 3.0, 1.0)
		draw_circle(_quadratic_point(start, control, end, progress), 3.0, Color("ffe16a"))

func _get_game_state() -> GameState:
	return _game_state if _game_state != null else GameManager.get_game_state()

func _process(_delta: float) -> void:
	queue_redraw()
