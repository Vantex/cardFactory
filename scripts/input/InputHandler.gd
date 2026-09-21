extends Node2D

const CardRenderer = preload("res://scripts/rendering/CardRenderer.gd")

enum Mode {
	IDLE,
	PLACING,
	DRAGGING,
	CONNECTING,
	PANNING,
	BOX_SELECTING,
}

signal selection_changed(entity_ids: Array)
signal delete_confirmation_requested(entity_ids: Array)
signal blueprint_capture_requested(entity_ids: Array)
signal blueprint_deployment_requested(position: Vector2)

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
var continuous_connect := false
var _ghost_signature := 0
var _ghost_rects: Array[Rect2] = []
var connection_candidates: Array = []
var connecting_source_id := ""
var selected_entity_ids: Array[String] = []
var selected_building_id := "":
	set(value):
		var accepted_value := value
		if not accepted_value.is_empty() and not _is_active_entity(accepted_value):
			accepted_value = ""
		selected_building_id = accepted_value
		if _syncing_selection:
			return
		if not accepted_value.is_empty() and selected_entity_ids.size() > 1 and selected_entity_ids.has(accepted_value):
			return
		selected_entity_ids.clear()
		if not accepted_value.is_empty():
			selected_entity_ids.append(accepted_value)
		selection_changed.emit(selected_entity_ids.duplicate())
		queue_redraw()
var dragging_building_id := ""
var press_candidate_building_id := ""
var drag_start_screen_position := Vector2.ZERO
var drag_offset := Vector2.ZERO
var drag_start_positions: Dictionary = {}
var selection_box_start := Vector2.ZERO
var selection_box_end := Vector2.ZERO
var selection_box_additive := false
var pan_last_screen_position := Vector2.ZERO
var _ui_hit_test := Callable()
var _syncing_selection := false
var _blueprint_workspace: Control
var canvas_focused := false
var cursor_screen := Vector2.ZERO
var _stick := Vector2.ZERO
var _pan_stick := Vector2.ZERO

func set_ui_hit_test(hit_test: Callable) -> void:
	_ui_hit_test = hit_test

func set_blueprint_workspace(workspace: Control) -> void:
	_blueprint_workspace = workspace

func get_blueprint_workspace() -> Control:
	return _blueprint_workspace

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
		Mode.BOX_SELECTING:
			return "box_selecting"
		_:
			return "idle"

func get_selected_entity_ids() -> Array[String]:
	return selected_entity_ids.duplicate()

func _is_active_entity(entity_id: String) -> bool:
	var state := GameManager.get_game_state()
	var entity: Dictionary = state.buildings.get(entity_id, {})
	if entity.is_empty():
		entity = state.connections.get(entity_id, {})
	return not entity.is_empty() and String(entity.get("planet_id", "")) == state.active_planet_id

func are_active_entities(entity_ids: Array) -> bool:
	if entity_ids.is_empty():
		return false
	for id_value in entity_ids:
		if not _is_active_entity(String(id_value)):
			return false
	return true

func set_selected_entities(entity_ids: Array) -> bool:
	var state := GameManager.get_game_state()
	var normalized: Array[String] = []
	var accepted_all := true
	for id_value in entity_ids:
		var entity_id := String(id_value)
		if entity_id.is_empty() or normalized.has(entity_id):
			continue
		if _is_active_entity(entity_id) and (state.buildings.has(entity_id) or state.connections.has(entity_id)):
			normalized.append(entity_id)
		else:
			accepted_all = false
	selected_entity_ids = normalized
	_sync_primary_building_selection()
	selection_changed.emit(selected_entity_ids.duplicate())
	queue_redraw()
	return accepted_all

func toggle_entity_selection(entity_id: String) -> bool:
	if not _is_active_entity(entity_id):
		return false
	var next_selection := selected_entity_ids.duplicate()
	if next_selection.has(entity_id):
		next_selection.erase(entity_id)
	else:
		next_selection.append(entity_id)
	return set_selected_entities(next_selection)

func select_entities_in_rect(first_corner: Vector2, second_corner: Vector2, additive: bool = false) -> void:
	var selection_rect := Rect2(first_corner, second_corner - first_corner).abs()
	var matches: Array[String] = []
	var state := GameManager.get_game_state()
	var building_ids: Array = state.buildings.keys()
	building_ids.sort()
	for building_id_value in building_ids:
		var building_id := String(building_id_value)
		if not _is_active_entity(building_id):
			continue
		var building: Dictionary = state.buildings[building_id]
		if selection_rect.intersects(Rect2(building.get("position", Vector2.ZERO), CARD_SIZE), true):
			matches.append(building_id)
	var next_selection: Array = selected_entity_ids.duplicate() if additive else []
	for building_id in matches:
		if not next_selection.has(building_id):
			next_selection.append(building_id)
	set_selected_entities(next_selection)

func _sync_primary_building_selection() -> void:
	var primary := ""
	for entity_id in selected_entity_ids:
		if GameManager.get_game_state().buildings.has(entity_id):
			primary = entity_id
			break
	_syncing_selection = true
	selected_building_id = primary
	_syncing_selection = false

func start_placing_card(building_type: String) -> void:
	placing_building_type = building_type
	connecting_source_id = ""
	set_selected_entities([])
	dragging_building_id = ""
	press_candidate_building_id = ""
	current_mode = Mode.PLACING
	queue_redraw()

func start_connection(source_id: String) -> bool:
	continuous_connect = false
	connection_candidates.clear()
	var state := GameManager.get_game_state()
	if source_id.is_empty() or not state.buildings.has(source_id) or not _is_active_entity(source_id):
		return false
	placing_building_type = ""
	connecting_source_id = source_id
	dragging_building_id = ""
	press_candidate_building_id = ""
	current_mode = Mode.CONNECTING
	queue_redraw()
	return true

func complete_connection(target_id: String) -> bool:
	if current_mode != Mode.CONNECTING or connecting_source_id.is_empty():
		return false
	if not _is_active_entity(connecting_source_id) or not _is_active_entity(target_id):
		_publish_command_result({"ok": false, "message": "只能连接活动行星建筑"})
		cancel_operation()
		return false
	var state := GameManager.get_game_state()
	if continuous_connect: return append_connection_candidate(target_id)
	var engine := GameManager.get_simulation_engine()
	var belts := engine.belt_system if engine != null and engine.game_state == state else BeltSystem.new(state)
	var result: Dictionary = belts.try_create_belt(connecting_source_id, target_id)
	_publish_command_result(result)
	cancel_operation()
	return result.get("ok", false)

func cancel_operation() -> void:
	GameManager.get_game_state().command_history.end_group(GameManager.get_game_state())
	continuous_connect = false
	connection_candidates.clear()
	current_mode = Mode.IDLE
	placing_building_type = ""
	connecting_source_id = ""
	dragging_building_id = ""
	press_candidate_building_id = ""
	drag_start_screen_position = Vector2.ZERO
	drag_offset = Vector2.ZERO
	drag_start_positions.clear()
	selection_box_start = Vector2.ZERO
	selection_box_end = Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	if _accessible_input(event):
		get_viewport().set_input_as_handled()
		return
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
		return current_mode == Mode.CONNECTING or current_mode == Mode.DRAGGING or current_mode == Mode.BOX_SELECTING or not press_candidate_building_id.is_empty()
	if button_index == MOUSE_BUTTON_RIGHT or button_index == MOUSE_BUTTON_MIDDLE:
		return current_mode == Mode.PANNING
	return false

func _handle_key_press(event: InputEventKey) -> void:
	if event.ctrl_pressed and event.keycode == KEY_Z:
		var state := GameManager.get_game_state()
		_publish_command_result(state.command_history.redo(state) if event.shift_pressed else state.command_history.undo(state))
		get_viewport().set_input_as_handled()
		return
	if continuous_connect and event.keycode == KEY_ENTER:
		confirm_connection_candidates()
		return
	if continuous_connect and event.keycode == KEY_BACKSPACE:
		if not connection_candidates.is_empty(): connection_candidates.pop_back()
		queue_redraw()
		return
	if event.ctrl_pressed and event.keycode == KEY_C:
		request_blueprint_capture()
		return
	if event.ctrl_pressed and event.keycode == KEY_V:
		request_blueprint_deployment_at_camera()
		return
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
		KEY_T:
			start_placing_card("matrix_lab")

func request_blueprint_capture() -> void:
	var selection := get_selected_entity_ids()
	if not selection.is_empty() and are_active_entities(selection):
		blueprint_capture_requested.emit(selection)

func request_delete(entity_id: String) -> bool:
	return request_delete_entities([entity_id])

func request_delete_entities(entity_ids: Array) -> bool:
	if not are_active_entities(entity_ids):
		return false
	for id_value in entity_ids:
		if not GameManager.get_game_state().buildings.has(String(id_value)):
			return false
	delete_confirmation_requested.emit(entity_ids.duplicate())
	return true

func request_move_entities(positions: Array) -> bool:
	if positions.is_empty():
		return false
	for value in positions:
		if not value is Dictionary or not _is_active_entity(String(value.get("id", ""))):
			return false
	var result := GameManager.get_game_state().try_move_entities(positions)
	if not result.get("ok", false):
		_publish_command_result(result)
	return result.get("ok", false)

func request_blueprint_deployment_at_camera() -> void:
	var camera := _get_camera()
	if camera != null:
		request_blueprint_deployment(camera.global_position)

func request_blueprint_deployment(position: Vector2) -> void:
	blueprint_deployment_requested.emit(position)

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
			_handle_left_press(screen_position, event.ctrl_pressed)
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
	elif current_mode == Mode.BOX_SELECTING:
		selection_box_end = _screen_to_world(screen_position)
		queue_redraw()

func _handle_left_press(screen_position: Vector2, additive: bool = false) -> void:
	if current_mode == Mode.BOX_SELECTING:
		current_mode = Mode.IDLE
		selection_box_start = Vector2.ZERO
		selection_box_end = Vector2.ZERO
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
				var connection_id := _get_connection_at_position(world_position)
				if not connection_id.is_empty():
					if additive:
						toggle_entity_selection(connection_id)
					else:
						set_selected_entities([connection_id])
					EventBus.card_selected.emit("")
					return
				selection_box_start = world_position
				selection_box_end = world_position
				selection_box_additive = additive
				if not additive:
					set_selected_entities([])
					EventBus.card_selected.emit("")
				current_mode = Mode.BOX_SELECTING
				return
			var clicked_id := String(building.get("id", ""))
			if additive:
				toggle_entity_selection(clicked_id)
				if not selected_entity_ids.has(clicked_id):
					EventBus.card_selected.emit(selected_building_id)
					return
			elif not selected_entity_ids.has(clicked_id):
				set_selected_entities([clicked_id])
			_syncing_selection = true
			selected_building_id = clicked_id
			_syncing_selection = false
			press_candidate_building_id = selected_building_id
			drag_start_screen_position = screen_position
			drag_offset = world_position - building.get("position", Vector2.ZERO)
			drag_start_positions.clear()
			for selected_id in selected_entity_ids:
				if GameManager.get_game_state().buildings.has(selected_id):
					drag_start_positions[selected_id] = GameManager.get_game_state().buildings[selected_id].get("position", Vector2.ZERO)
			EventBus.card_selected.emit(selected_building_id)

func _place_card(world_position: Vector2) -> void:
	var result: Dictionary = GameManager.get_game_state().try_place_building(placing_building_type, world_position)
	if result.get("ok", false):
		set_selected_entities([result.get("id", "")])
	_publish_command_result(result)
	cancel_operation()

func _update_drag(world_position: Vector2) -> void:
	if dragging_building_id.is_empty():
		return
	GameManager.get_game_state().command_history.begin_group(GameManager.get_game_state(), "拖动建筑")
	var primary_start: Vector2 = drag_start_positions.get(dragging_building_id, GameManager.get_game_state().get_building(dragging_building_id).get("position", Vector2.ZERO))
	var delta := world_position - drag_offset - primary_start
	var positions: Array = []
	for entity_id in drag_start_positions:
		positions.append({"id": entity_id, "position": Vector2(drag_start_positions[entity_id]) + delta})
	request_move_entities(positions)
	queue_redraw()

func _finish_drag() -> void:
	GameManager.get_game_state().command_history.end_group(GameManager.get_game_state())
	current_mode = Mode.IDLE
	dragging_building_id = ""
	press_candidate_building_id = ""
	drag_start_positions.clear()
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
		return
	if current_mode == Mode.BOX_SELECTING:
		selection_box_end = _screen_to_world(screen_position)
		select_entities_in_rect(selection_box_start, selection_box_end, selection_box_additive)
		current_mode = Mode.IDLE
		selection_box_start = Vector2.ZERO
		selection_box_end = Vector2.ZERO
		EventBus.card_selected.emit(selected_building_id)
		queue_redraw()

func _is_left_button_held(event: InputEventMouseMotion) -> bool:
	return event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _publish_command_result(result: Dictionary) -> void:
	var message: String = result.get("message", "")
	if message.is_empty():
		return
	EventBus.notice_requested.emit(message, "success" if result.get("ok", false) else "error")

func _delete_selected() -> void:
	var building_ids: Array[String] = []
	for entity_id in selected_entity_ids:
		if _is_active_entity(entity_id) and GameManager.get_game_state().buildings.has(entity_id):
			building_ids.append(entity_id)
	if not selected_entity_ids.is_empty() and building_ids.size() != selected_entity_ids.size():
		EventBus.notice_requested.emit("混合选择没有共同的删除命令", "warning")
		return
	if building_ids.is_empty() and not selected_building_id.is_empty():
		if _is_active_entity(selected_building_id):
			building_ids.append(selected_building_id)
	if building_ids.is_empty():
		return
	if request_delete_entities(building_ids):
		EventBus.notice_requested.emit("请在检查器中确认删除 %d 个建筑" % building_ids.size(), "warning")

func _hit_candidates(world_position: Vector2) -> Array:
	var state := GameManager.get_game_state()
	var ids := state.get_spatial_index().get_entities_in_rect(Rect2(world_position - CARD_SIZE - Vector2.ONE, CARD_SIZE + Vector2.ONE * 2))
	# Preserve insertion-order hit precedence for overlapping cards.
	var order := {}
	var rank := 0
	for id in state.buildings:
		order[id] = rank
		rank += 1
	ids.sort_custom(func(a: String, b: String): return int(order[a]) < int(order[b]))
	var result: Array = []
	for id in ids: result.append(state.buildings[id])
	return result
func _get_building_at_position(world_position: Vector2) -> Dictionary:
	for building in _hit_candidates(world_position):
		if not _is_active_entity(String(building.get("id", ""))):
			continue
		if Rect2(building.get("position", Vector2.ZERO), CARD_SIZE).has_point(world_position):
			return building
	return {}

func _get_input_port_at_position(world_position: Vector2) -> String:
	for building in _hit_candidates(world_position):
		if not _is_active_entity(String(building.get("id", ""))):
			continue
		if _get_input_port_rect(building.get("position", Vector2.ZERO)).has_point(world_position):
			return building.get("id", "")
	return ""

func _get_output_port_at_position(world_position: Vector2) -> String:
	for building in _hit_candidates(world_position):
		if not _is_active_entity(String(building.get("id", ""))):
			continue
		if _get_output_port_rect(building.get("position", Vector2.ZERO)).has_point(world_position):
			return building.get("id", "")
	return ""

func _get_connection_at_position(world_position: Vector2) -> String:
	var renderer := get_node_or_null("../ConnectionRenderer")
	if renderer != null and renderer.has_method("get_connection_at_position"):
		return String(renderer.call("get_connection_at_position", world_position))
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
	var workspace := get_parent().get_node_or_null("FactoryWorkspaceUI")
	if workspace != null and workspace.has_method("get_canvas_rect"):
		return workspace.get_canvas_rect().has_point(screen_position)
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

func _ready() -> void:
	EventBus.simulation_updated.connect(queue_redraw)

func _update_ghosts() -> void:
	var live := GameManager.get_game_state()
	var signature := hash([live.active_planet_id, live.construction_queue])
	if signature == _ghost_signature: return
	_ghost_signature = signature
	_ghost_rects.clear()
	for order in live.construction_queue:
		if order.planet_id != live.active_planet_id or not order.placed.is_empty(): continue
		var decoded := BlueprintCodec.new().decode(order.text)
		if not decoded.ok: continue
		for entity in decoded.blueprint.entities:
			var position: Vector2 = entity.position
			for _turn in range(int(order.rotation)): position = Vector2(-position.y, position.x)
			if order.mirrored: position.x = -position.x
			position += Vector2(order.position[0], order.position[1])
			_ghost_rects.append(Rect2(position, CARD_SIZE))

func _draw() -> void:
	_update_ghosts()
	for rect in _ghost_rects:
		draw_rect(rect, Color(0.6, 0.65, 0.7, 0.18), true)
		draw_rect(rect, Color(0.6, 0.65, 0.7, 0.7), false, 2)
	for candidate in connection_candidates:
		var state := GameManager.get_game_state()
		if state.buildings.has(candidate.source_id) and state.buildings.has(candidate.target_id):
			draw_line(state.buildings[candidate.source_id].position + CARD_SIZE / 2, state.buildings[candidate.target_id].position + CARD_SIZE / 2, Color("e1b452"), 3)
	if canvas_focused:
		var point := _screen_to_world(cursor_screen)
		draw_circle(point, 12, Color.BLACK, false, 5)
		draw_circle(point, 12, Color.WHITE, false, 2)
		draw_line(point - Vector2(20, 0), point + Vector2(20, 0), Color.WHITE, 2)
		draw_line(point - Vector2(0, 20), point + Vector2(0, 20), Color.WHITE, 2)
	for entity_id in selected_entity_ids:
		if not _is_active_entity(entity_id):
			continue
		var selected := GameManager.get_game_state().get_building(entity_id)
		if not selected.is_empty():
			draw_rect(Rect2(selected.get("position", Vector2.ZERO), CARD_SIZE), Color(1.0, 0.85, 0.2, 0.25))
	if current_mode == Mode.BOX_SELECTING:
		draw_rect(Rect2(selection_box_start, selection_box_end - selection_box_start).abs(), Color(0.38, 0.71, 0.68, 0.18), true)
		draw_rect(Rect2(selection_box_start, selection_box_end - selection_box_start).abs(), Color("62b5ae"), false, 1.5, true)

func focus_canvas() -> void:
	_stick = Vector2.ZERO
	_pan_stick = Vector2.ZERO
	var workspace := get_parent().get_node_or_null("FactoryWorkspaceUI")
	if workspace != null:
		while workspace.close_active_workspace(): pass
		cursor_screen = workspace.get_canvas_rect().get_center()
	else: cursor_screen = get_viewport().get_visible_rect().size * 0.5
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null: owner.release_focus()
	canvas_focused = true
	queue_redraw()

func focus_interface() -> void:
	canvas_focused = false
	_stick = Vector2.ZERO
	_pan_stick = Vector2.ZERO
	cancel_operation()
	var shell := get_parent().get_node_or_null("AppShell")
	if shell != null: shell._focus_first(get_parent().get_node("FactoryWorkspaceUI"))
	queue_redraw()

func _process(delta: float) -> void:
	if not canvas_focused or not is_processing_input(): return
	_move_cursor(_stick * delta * 360 * float(LocalSettings.values.cursor_speed))
	var camera := _get_camera()
	if camera != null and _pan_stick.length() > 0:
		camera.position += _pan_stick * delta * 400 / camera.zoom
		camera.force_update_scroll()
	queue_redraw()

func _move_cursor(offset: Vector2) -> void:
	var workspace := get_parent().get_node_or_null("FactoryWorkspaceUI")
	var rect: Rect2 = workspace.get_canvas_rect() if workspace != null else get_viewport().get_visible_rect()
	cursor_screen = (cursor_screen + offset).clamp(rect.position + Vector2.ONE, rect.end - Vector2.ONE)
	if current_mode == Mode.DRAGGING: _update_drag(_screen_to_world(cursor_screen))

func _activate_cursor() -> void:
	if current_mode == Mode.DRAGGING:
		_finish_drag()
	elif current_mode == Mode.CONNECTING:
		var target := _get_building_at_position(_screen_to_world(cursor_screen))
		if not target.is_empty(): complete_connection(String(target.id))
	else:
		_handle_left_press(cursor_screen)
		_handle_left_release(cursor_screen)

func _accessible_input(event: InputEvent) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	if event is InputEventKey and event.ctrl_pressed and event.keycode == KEY_K: return false
	for dialog in get_parent().find_children("*", "Window", true, false):
		if dialog.visible: return false
	if event is InputEventMouseButton and event.pressed:
		canvas_focused = false
		if LocalSettings.values.invert_zoom and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _is_pointer_over_ui(event.position) and _is_inside_world_canvas(event.position):
			_zoom_at_pointer(event.position, 1.0 / ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP)
			return true
	var toggle: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)
	if toggle:
		if canvas_focused: focus_interface()
		else: focus_canvas()
		return true
	if not canvas_focused: return false
	if event is InputEventJoypadMotion:
		var value: float = event.axis_value if absf(event.axis_value) > 0.2 else 0.0
		match event.axis:
			JOY_AXIS_LEFT_X: _stick.x = value
			JOY_AXIS_LEFT_Y: _stick.y = value
			JOY_AXIS_RIGHT_X: _pan_stick.x = value
			JOY_AXIS_RIGHT_Y: _pan_stick.y = value
		return true
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: _activate_cursor()
			JOY_BUTTON_B:
				if current_mode != Mode.IDLE: cancel_operation()
				else: focus_interface()
			JOY_BUTTON_X: _delete_selected()
			JOY_BUTTON_LEFT_STICK: _begin_cursor_move()
			JOY_BUTTON_RIGHT_STICK: start_connection(selected_building_id)
			JOY_BUTTON_LEFT_SHOULDER: _zoom_at_pointer(cursor_screen, 1.0 / ZOOM_STEP)
			JOY_BUTTON_RIGHT_SHOULDER: _zoom_at_pointer(cursor_screen, ZOOM_STEP)
			JOY_BUTTON_DPAD_LEFT: _move_cursor(Vector2(-24, 0))
			JOY_BUTTON_DPAD_RIGHT: _move_cursor(Vector2(24, 0))
			JOY_BUTTON_DPAD_UP: _move_cursor(Vector2(0, -24))
			JOY_BUTTON_DPAD_DOWN: _move_cursor(Vector2(0, 24))
		return true
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _move_cursor(Vector2(-24, 0))
			KEY_RIGHT: _move_cursor(Vector2(24, 0))
			KEY_UP: _move_cursor(Vector2(0, -24))
			KEY_DOWN: _move_cursor(Vector2(0, 24))
			KEY_ENTER:
				if continuous_connect: confirm_connection_candidates()
				else: _activate_cursor()
			KEY_ESCAPE:
				if current_mode != Mode.IDLE: cancel_operation()
				else: focus_interface()
			KEY_C: start_connection(selected_building_id)
			KEY_M: _begin_cursor_move()
			KEY_MINUS: _zoom_at_pointer(cursor_screen, 1.0 / ZOOM_STEP)
			KEY_EQUAL: _zoom_at_pointer(cursor_screen, ZOOM_STEP)
			_: _handle_key_press(event)
		return true
	return false

func _begin_cursor_move() -> void:
	var building := GameManager.get_game_state().get_building(selected_building_id)
	if building.is_empty(): return
	dragging_building_id = selected_building_id
	drag_offset = _screen_to_world(cursor_screen) - Vector2(building.position)
	drag_start_positions.clear()
	for entity_id in selected_entity_ids:
		if GameManager.get_game_state().buildings.has(entity_id):
			drag_start_positions[entity_id] = GameManager.get_game_state().buildings[entity_id].position
	current_mode = Mode.DRAGGING

func reset_device_input() -> void:
	canvas_focused = false
	_stick = Vector2.ZERO
	_pan_stick = Vector2.ZERO
	cancel_operation()

func start_continuous_connection(source_id: String) -> bool:
	if not start_connection(source_id): return false
	continuous_connect = true
	connection_candidates.clear()
	_publish_command_result({"ok": true, "message": "点击目标输入端口加入候选；Enter 确认，Backspace 回退，Escape 取消"})
	return true

func append_connection_candidate(target_id: String) -> bool:
	var next := connection_candidates.duplicate(true)
	next.append({"source_id": connecting_source_id, "target_id": target_id})
	var result := GameManager.get_game_state().preview_connections(next)
	if result.ok: connection_candidates = next
	_publish_command_result(result)
	queue_redraw()
	return result.ok

func confirm_connection_candidates() -> bool:
	var result := GameManager.get_game_state().try_add_connections(connection_candidates)
	_publish_command_result(result)
	if result.ok: cancel_operation()
	return result.ok
