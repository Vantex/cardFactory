extends Node2D

const CardRenderer = preload("res://scripts/rendering/CardRenderer.gd")

enum Mode {
	IDLE,
	PLACING,
	DRAGGING,
	CONNECTING,
	PANNING,
}

const CARD_SIZE := CardRenderer.CARD_SIZE
const PORT_SIZE := CardRenderer.PORT_SIZE
const DRAG_THRESHOLD := 5.0
const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.8
const ZOOM_STEP := 1.1
const CANVAS_MARGIN_LEFT := 216.0
const CANVAS_MARGIN_TOP := 52.0
const CANVAS_MARGIN_RIGHT := 286.0
const CANVAS_MARGIN_BOTTOM := 92.0

var current_mode: Mode = Mode.IDLE
var placing_building_type := ""
var connecting_source_id := ""
var selected_building_id := ""
var dragging_building_id := ""
var press_candidate_building_id := ""
var drag_start_screen_position := Vector2.ZERO
var drag_offset := Vector2.ZERO
var pan_last_screen_position := Vector2.ZERO
var _ui_hit_test := Callable()

func set_ui_hit_test(hit_test: Callable) -> void:
	_ui_hit_test = hit_test

func get_mode_name() -> String:
	match current_mode:
		Mode.PLACING:
			return "placing"
		Mode.DRAGGING:
			return "dragging"
		Mode.CONNECTING:
			return "connecting"
		Mode.PANNING:
			return "panning"
		_:
			return "idle"

func start_placing_card(building_type: String) -> void:
	placing_building_type = building_type
	connecting_source_id = ""
	selected_building_id = ""
	dragging_building_id = ""
	press_candidate_building_id = ""
	current_mode = Mode.PLACING
	queue_redraw()

func start_connection(source_id: String) -> void:
	if source_id.is_empty() or GameManager.get_game_state().get_building(source_id).is_empty():
		return
	placing_building_type = ""
	connecting_source_id = source_id
	dragging_building_id = ""
	press_candidate_building_id = ""
	current_mode = Mode.CONNECTING
	queue_redraw()

func complete_connection(target_id: String) -> bool:
	if current_mode != Mode.CONNECTING or connecting_source_id.is_empty():
		return false
	var result: Dictionary = GameManager.get_game_state().try_add_connection(connecting_source_id, target_id)
	_publish_command_result(result)
	cancel_operation()
	return result.get("ok", false)

func cancel_operation() -> void:
	current_mode = Mode.IDLE
	placing_building_type = ""
	connecting_source_id = ""
	dragging_building_id = ""
	press_candidate_building_id = ""
	drag_start_screen_position = Vector2.ZERO
	drag_offset = Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.pressed or not _has_pending_pointer_release(event.button_index):
		return
	_handle_mouse_button(event, _get_event_screen_position(event))
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var consumes_escape: bool = event.keycode == KEY_ESCAPE and current_mode != Mode.IDLE
		_handle_key_press(event)
		if consumes_escape:
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var screen_position := _get_event_screen_position(event)
	if event is InputEventMouseButton and not event.pressed:
		_handle_mouse_button(event, screen_position)
		return
	if _is_pointer_over_ui(screen_position):
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event, screen_position)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event, screen_position)

func _has_pending_pointer_release(button_index: MouseButton) -> bool:
	if button_index == MOUSE_BUTTON_LEFT:
		return current_mode == Mode.CONNECTING or current_mode == Mode.DRAGGING or not press_candidate_building_id.is_empty()
	if button_index == MOUSE_BUTTON_RIGHT or button_index == MOUSE_BUTTON_MIDDLE:
		return current_mode == Mode.PANNING
	return false

func _handle_key_press(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			cancel_operation()
		KEY_DELETE:
			_delete_selected()
		KEY_SPACE:
			GameManager.get_game_state().paused = not GameManager.get_game_state().paused
			EventBus.simulation_updated.emit()
		KEY_1:
			GameManager.get_game_state().speed = 1.0
			EventBus.simulation_updated.emit()
		KEY_2:
			GameManager.get_game_state().speed = 2.0
			EventBus.simulation_updated.emit()
		KEY_3:
			GameManager.get_game_state().speed = 3.0
			EventBus.simulation_updated.emit()
		KEY_Q:
			start_placing_card("miner")
		KEY_W:
			start_placing_card("smelter")
		KEY_E:
			start_placing_card("assembling_machine_mk1")
		KEY_R:
			start_placing_card("power_generator")

func _handle_mouse_button(event: InputEventMouseButton, screen_position: Vector2) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if event.pressed and _is_inside_world_canvas(screen_position):
			_zoom_at_pointer(screen_position, ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		return
	if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed and _is_inside_world_canvas(screen_position):
			current_mode = Mode.PANNING
			pan_last_screen_position = screen_position
		elif not event.pressed and current_mode == Mode.PANNING:
			cancel_operation()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _is_inside_world_canvas(screen_position):
			_handle_left_press(screen_position)
	else:
		_handle_left_release(screen_position)

func _handle_mouse_motion(event: InputEventMouseMotion, screen_position: Vector2) -> void:
	if current_mode == Mode.PANNING:
		_pan_camera(screen_position)
		return
	if not _is_inside_world_canvas(screen_position) or not _is_left_button_held(event):
		return
	if current_mode == Mode.IDLE and not press_candidate_building_id.is_empty() and screen_position.distance_to(drag_start_screen_position) >= DRAG_THRESHOLD:
		dragging_building_id = press_candidate_building_id
		press_candidate_building_id = ""
		current_mode = Mode.DRAGGING
	if current_mode == Mode.DRAGGING:
		_update_drag(_screen_to_world(screen_position))

func _handle_left_press(screen_position: Vector2) -> void:
	press_candidate_building_id = ""
	var world_position := _screen_to_world(screen_position)
	match current_mode:
		Mode.PLACING:
			_place_card(world_position)
		Mode.CONNECTING:
			pass
		Mode.IDLE:
			var source_id := _get_output_port_at_position(world_position)
			if not source_id.is_empty():
				start_connection(source_id)
				return
			var building := _get_building_at_position(world_position)
			if building.is_empty():
				selected_building_id = ""
				EventBus.card_selected.emit("")
				return
			selected_building_id = building.get("id", "")
			press_candidate_building_id = selected_building_id
			drag_start_screen_position = screen_position
			drag_offset = world_position - building.get("position", Vector2.ZERO)
			EventBus.card_selected.emit(selected_building_id)

func _place_card(world_position: Vector2) -> void:
	var result: Dictionary = GameManager.get_game_state().try_place_building(placing_building_type, world_position)
	if result.get("ok", false):
		selected_building_id = result.get("id", "")
	_publish_command_result(result)
	cancel_operation()

func _update_drag(world_position: Vector2) -> void:
	if dragging_building_id.is_empty():
		return
	GameManager.get_game_state().move_entity(dragging_building_id, world_position - drag_offset)
	queue_redraw()

func _finish_drag() -> void:
	current_mode = Mode.IDLE
	dragging_building_id = ""
	press_candidate_building_id = ""
	queue_redraw()

func _handle_left_release(screen_position: Vector2) -> void:
	press_candidate_building_id = ""
	if current_mode == Mode.CONNECTING:
		if _is_pointer_over_ui(screen_position) or not _is_inside_world_canvas(screen_position):
			_publish_command_result({"ok": false, "message": "连接已取消：请在输入端口释放"})
			cancel_operation()
			return
		var target_id := _get_input_port_at_position(_screen_to_world(screen_position))
		if target_id.is_empty():
			_publish_command_result({"ok": false, "message": "连接已取消：请在输入端口释放"})
			cancel_operation()
			return
		complete_connection(target_id)
		return
	if current_mode == Mode.DRAGGING:
		_finish_drag()

func _is_left_button_held(event: InputEventMouseMotion) -> bool:
	return event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _publish_command_result(result: Dictionary) -> void:
	var message: String = result.get("message", "")
	if message.is_empty():
		return
	EventBus.notice_requested.emit(message, "success" if result.get("ok", false) else "error")

func _delete_selected() -> void:
	if selected_building_id.is_empty():
		return
	GameManager.get_game_state().remove_building(selected_building_id)
	selected_building_id = ""
	cancel_operation()

func _get_building_at_position(world_position: Vector2) -> Dictionary:
	for building in GameManager.get_game_state().buildings.values():
		if Rect2(building.get("position", Vector2.ZERO), CARD_SIZE).has_point(world_position):
			return building
	return {}

func _get_input_port_at_position(world_position: Vector2) -> String:
	for building in GameManager.get_game_state().buildings.values():
		if _get_input_port_rect(building.get("position", Vector2.ZERO)).has_point(world_position):
			return building.get("id", "")
	return ""

func _get_output_port_at_position(world_position: Vector2) -> String:
	for building in GameManager.get_game_state().buildings.values():
		if _get_output_port_rect(building.get("position", Vector2.ZERO)).has_point(world_position):
			return building.get("id", "")
	return ""

func _get_input_port_rect(card_position: Vector2) -> Rect2:
	return CardRenderer.get_input_port_rect(card_position)

func _get_output_port_rect(card_position: Vector2) -> Rect2:
	return CardRenderer.get_output_port_rect(card_position)

func _get_event_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	return Vector2.ZERO

func _is_pointer_over_ui(screen_position: Vector2) -> bool:
	return _ui_hit_test.is_valid() and _ui_hit_test.call(screen_position)

func _is_inside_world_canvas(screen_position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var canvas_size := viewport_size - Vector2(CANVAS_MARGIN_LEFT + CANVAS_MARGIN_RIGHT, CANVAS_MARGIN_TOP + CANVAS_MARGIN_BOTTOM)
	return Rect2(Vector2(CANVAS_MARGIN_LEFT, CANVAS_MARGIN_TOP), canvas_size.max(Vector2.ZERO)).has_point(screen_position)

func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()

func _screen_to_world(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position

func _pan_camera(screen_position: Vector2) -> void:
	var camera := _get_camera()
	if camera == null:
		return
	camera.global_position -= (screen_position - pan_last_screen_position) / camera.zoom
	pan_last_screen_position = screen_position
	camera.force_update_scroll()

func _zoom_at_pointer(screen_position: Vector2, factor: float) -> void:
	var camera := _get_camera()
	if camera == null:
		return
	var world_before_zoom := _screen_to_world(screen_position)
	var next_zoom := clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(next_zoom, next_zoom)
	camera.force_update_scroll()
	camera.global_position += world_before_zoom - _screen_to_world(screen_position)
	camera.force_update_scroll()

func _draw() -> void:
	if selected_building_id.is_empty():
		return
	var selected := GameManager.get_game_state().get_building(selected_building_id)
	if not selected.is_empty():
		draw_rect(Rect2(selected.get("position", Vector2.ZERO), CARD_SIZE), Color(1.0, 0.85, 0.2, 0.25))
