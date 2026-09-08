class_name BlueprintWorkspace
extends Control

const BlueprintCodecScript = preload("res://scripts/game/BlueprintCodec.gd")

signal deployment_intent(position: Vector2, rotation_quarters: int, mirrored: bool)
signal capture_intent(entity_ids: Array)

var _input_handler: Node
var _draft: Dictionary = {}
var _rotation_quarters := 0
var _mirrored := false
var _clipboard_fallback := ""
var _toggle_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -560.0
	offset_right = -296.0
	offset_top = 246.0
	offset_bottom = 546.0
	z_index = 2
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_controls()
	hide()
	call_deferred("_install_toggle")
	queue_redraw()

func set_input_handler(input_handler: Node) -> void:
	_input_handler = input_handler

func capture_selection() -> Dictionary:
	if _input_handler == null or not _input_handler.has_method("get_selected_entity_ids"):
		return _failure("selection_unavailable", "无法读取当前选择")
	return request_capture(_input_handler.call("get_selected_entity_ids"))

func request_capture(entity_ids: Array) -> Dictionary:
	capture_intent.emit(entity_ids.duplicate())
	return {"ok": true, "pending": true}

func accept_capture_result(result: Dictionary) -> void:
	if result.get("ok", false):
		_draft = result.blueprint.duplicate(true)
		_rotation_quarters = 0
		_mirrored = false
		queue_redraw()

func import_text(text: String) -> Dictionary:
	var result := BlueprintCodecScript.new().decode(text)
	if result.get("ok", false):
		_draft = result.blueprint.duplicate(true)
		_rotation_quarters = 0
		_mirrored = false
		queue_redraw()
	return result

func export_text() -> Dictionary:
	if _draft.is_empty():
		return _failure("empty_blueprint", "没有可导出的蓝图")
	return BlueprintCodecScript.new().encode(_draft)

func request_deployment(position: Vector2) -> Dictionary:
	if _draft.is_empty():
		return _failure("empty_blueprint", "没有可部署的蓝图")
	deployment_intent.emit(position, _rotation_quarters, _mirrored)
	return {"ok": true, "pending": true}

func accept_deployment_result(result: Dictionary) -> void:
	var message := String(result.get("message", ""))
	if not message.is_empty():
		EventBus.notice_requested.emit(message, "success" if result.get("ok", false) else "error")

func rotate_preview(clockwise: bool = true) -> int:
	_rotation_quarters = posmod(_rotation_quarters + (1 if clockwise else -1), 4)
	queue_redraw()
	return _rotation_quarters

func mirror_preview() -> bool:
	_mirrored = not _mirrored
	queue_redraw()
	return _mirrored

func get_draft() -> Dictionary:
	return _draft.duplicate(true)

func clear_draft() -> void:
	_draft.clear()
	_rotation_quarters = 0
	_mirrored = false
	queue_redraw()

func get_preview_positions() -> Array:
	var positions: Array = []
	for entity in _draft.get("entities", []):
		positions.append(_transform_preview_position(entity.get("position", Vector2.ZERO)))
	return positions

func get_preview_footprints() -> Array[Rect2]:
	var footprints: Array[Rect2] = []
	for position in get_preview_positions():
		footprints.append(Rect2(Vector2(position), FactoryGeometry.CARD_SIZE))
	return footprints

func import_from_clipboard() -> Dictionary:
	var text := DisplayServer.clipboard_get() if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) else _clipboard_fallback
	return import_text(text)

func export_to_clipboard() -> Dictionary:
	var result := export_text()
	if result.get("ok", false):
		_clipboard_fallback = String(result.text)
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			DisplayServer.clipboard_set(_clipboard_fallback)
	return result

func get_last_export_text() -> String:
	return _clipboard_fallback

func _build_controls() -> void:
	var panel := AdaptivePanel.new()
	panel.reflow = true
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var title := Label.new()
	title.text = "蓝图工作台  ·  预览"
	title.position = Vector2(12, 8)
	panel.add_child(title)
	var preview_space := Control.new()
	preview_space.custom_minimum_size.y = 100
	preview_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(preview_space)
	var controls := GridContainer.new()
	controls.name = "Controls"
	controls.columns = 2
	controls.position = Vector2(12, 132)
	controls.size = Vector2(240, 156)
	panel.add_child(controls)
	_add_button(controls, "Capture", "捕获", capture_selection)
	_add_button(controls, "RotateCCW", "↺", func() -> void: rotate_preview(false))
	_add_button(controls, "RotateCW", "↻", func() -> void: rotate_preview(true))
	_add_button(controls, "Mirror", "镜像", mirror_preview)
	_add_button(controls, "Import", "导入剪贴板", import_from_clipboard)
	_add_button(controls, "Export", "导出剪贴板", export_to_clipboard)
	_add_button(controls, "Deploy", "部署到相机", _deploy_at_camera)
	_add_button(controls, "Close", "收起", _hide_workspace)

func _install_toggle() -> void:
	if _toggle_button != null:
		return
	var inspector := get_parent().get_node_or_null("InspectorPanel") as Control
	if inspector == null:
		return
	var title := inspector.get_node_or_null("Title") as Control
	if title != null:
		title.size.x = minf(title.size.x, 112.0)
		title.set_meta("authored_size", title.size)
	_toggle_button = Button.new()
	_toggle_button.name = "BlueprintToggle"
	_toggle_button.text = "蓝图"
	_toggle_button.position = Vector2(204, 9)
	_toggle_button.size = Vector2(64, 32)
	_toggle_button.pressed.connect(_show_workspace)
	inspector.add_child(_toggle_button)

func _show_workspace() -> void:
	var workspace_shell := get_parent()
	if workspace_shell != null and workspace_shell.has_method("show_exclusive_workspace"):
		workspace_shell.call("show_exclusive_workspace", name)
	else:
		show()
	queue_redraw()

func _hide_workspace() -> void:
	hide()

func _add_button(parent: GridContainer, node_name: String, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)

func _deploy_at_camera() -> Dictionary:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return _failure("camera_unavailable", "无法读取当前相机")
	return request_deployment(camera.global_position)

func _transform_preview_position(position: Vector2) -> Vector2:
	var result := position
	for _index in range(_rotation_quarters):
		result = Vector2(-result.y, result.x)
	if _mirrored:
		result.x = -result.x
	return result

func _draw() -> void:
	var preview_rect := Rect2(12, 32, 240, 90)
	draw_rect(preview_rect, Color(0.04, 0.07, 0.09, 0.85), true)
	var footprints := get_preview_footprints()
	if footprints.is_empty():
		return
	var bounds: Rect2 = footprints[0]
	for footprint in footprints:
		bounds = bounds.merge(footprint)
	var scale_factor := minf(preview_rect.size.x / maxf(bounds.size.x, 1.0), preview_rect.size.y / maxf(bounds.size.y, 1.0)) * 0.85
	var origin := preview_rect.get_center() - bounds.size * scale_factor * 0.5
	for footprint in footprints:
		var local_rect := Rect2(origin + (footprint.position - bounds.position) * scale_factor, footprint.size * scale_factor)
		draw_rect(local_rect, Color(0.38, 0.71, 0.68, 0.24), true)
		draw_rect(local_rect, Color(0.38, 0.71, 0.68, 0.9), false, 1.5)

func _failure(reason: String, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
