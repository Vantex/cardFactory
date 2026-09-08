class_name AdaptivePanel
extends Panel

var horizontal := false
var ui_scale := 1.0
var reflow := false
var _vertical: VScrollBar
var _horizontal: HScrollBar
var _origins: Dictionary = {}
var _arranging := false

func _ready() -> void:
	clip_contents = true
	_vertical = VScrollBar.new()
	_horizontal = HScrollBar.new()
	add_child(_vertical)
	add_child(_horizontal)
	get_viewport().gui_focus_changed.connect(_reveal_focus)

func _process(_delta: float) -> void:
	if is_visible_in_tree(): arrange()

func arrange() -> void:
	if _vertical == null or _arranging: return
	_arranging = true
	var cursor := Vector2(12, 12) * ui_scale
	var bar_width := 16 * ui_scale
	var extent := Vector2.ZERO
	var children: Array[Control] = []
	for child in get_children():
		if not child is Control or child == _vertical or child == _horizontal: continue
		children.append(child)
		if not child.has_meta("authored_position"): child.set_meta("authored_position", child.position)
		if not child.has_meta("authored_size"): child.set_meta("authored_size", child.size)
		if not child.visible: continue
		var origin: Vector2 = child.get_meta("authored_position")
		if reflow:
			child.set_anchors_preset(Control.PRESET_TOP_LEFT)
			origin = cursor
			var minimum: Vector2 = child.get_combined_minimum_size()
			if child is Label:
				child.autowrap_mode = TextServer.AUTOWRAP_OFF if horizontal else TextServer.AUTOWRAP_WORD_SMART
				child.size.x = maxf(size.x - 44 * ui_scale, 80) if not horizontal else maxf(minimum.x, 180)
				minimum = child.get_combined_minimum_size()
			if horizontal:
				child.size = Vector2(maxf(minimum.x, 44), maxf(minimum.y, 34))
				cursor.x += child.size.x + 10 * ui_scale
			else:
				child.size = Vector2(maxf(size.x - 44 * ui_scale, minimum.x), maxf(minimum.y, 34))
				if child is ScrollContainer: child.size.y = maxf(130, size.y * 0.35)
				cursor.y += child.size.y + 10 * ui_scale
		else:
			child.size = Vector2(child.get_meta("authored_size")).max(child.get_combined_minimum_size())
		_origins[child.get_instance_id()] = origin
		extent = extent.max(origin + child.size + Vector2(12, 12) * ui_scale)
	_vertical.position = Vector2(maxf(0, size.x - bar_width), 0)
	_vertical.size = Vector2(bar_width, maxf(0, size.y - bar_width))
	_vertical.page = maxf(1, size.y - bar_width)
	_vertical.max_value = maxf(_vertical.page, extent.y)
	_vertical.visible = extent.y > _vertical.page
	_horizontal.position = Vector2(0, maxf(0, size.y - bar_width))
	_horizontal.size = Vector2(maxf(0, size.x - bar_width), bar_width)
	_horizontal.page = maxf(1, size.x - bar_width)
	_horizontal.max_value = maxf(_horizontal.page, extent.x)
	_horizontal.visible = extent.x > _horizontal.page
	for child in children:
		if child.visible: child.position = Vector2(_origins.get(child.get_instance_id(), Vector2.ZERO)) - Vector2(_horizontal.value, _vertical.value)
	_vertical.move_to_front()
	_horizontal.move_to_front()
	_arranging = false

func _reveal_focus(control: Control) -> void:
	if not is_ancestor_of(control) or control == _vertical or control == _horizontal: return
	var rect := Rect2(control.global_position - global_position, control.size)
	if rect.position.y < 0: _vertical.value += rect.position.y - 8
	elif rect.end.y > size.y - 20: _vertical.value += rect.end.y - size.y + 24
	if rect.position.x < 0: _horizontal.value += rect.position.x - 8
	elif rect.end.x > size.x - 20: _horizontal.value += rect.end.x - size.x + 24
	arrange()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var amount := -48 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 48
		if _vertical.visible: _vertical.value += amount
		else: _horizontal.value += amount
		accept_event()
