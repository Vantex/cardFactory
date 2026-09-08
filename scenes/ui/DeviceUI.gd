extends Node

var _root: Node
var _theme: Theme
var _pending: Dictionary = {}
var _metrics: Dictionary = {}

func _ready() -> void:
	_root = get_parent()
	LocalSettings.changed.connect(refresh)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(refresh)
	refresh()

func _on_node_added(node: Node) -> void:
	if node is Control or node is Window:
		_pending[node.get_instance_id()] = weakref(node)
		_apply_pending.call_deferred()

func _apply_pending() -> void:
	var pending := _pending.values()
	_pending.clear()
	for reference in pending:
		var node: Node = reference.get_ref()
		if node != null and _root.is_ancestor_of(node): _style(node)

func refresh() -> void:
	_metrics = DesktopLayout.metrics(get_viewport().get_visible_rect().size, LocalSettings.values)
	_theme = Theme.new()
	_theme.default_font_size = roundi(16 * float(_metrics.font_scale))
	var light: bool = LocalSettings.values.theme == "light"
	var ink := Color("172c29") if light else Color("e6ece9")
	var background := Color("f0f5f3") if light else Color("131c19")
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "TextEdit", "RichTextLabel", "PopupMenu", "TabBar"]:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "default_color"]:
			_theme.set_color(key, type, ink)
		_theme.set_color("font_disabled_color", type, Color("52655f") if light else Color("a0b0ab"))
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("005eaa") if light else Color("ffe082")
		focus.set_border_width_all(maxi(3, roundi(3 * float(_metrics.automatic_scale))))
		_theme.set_stylebox("focus", type, focus)
		for state in [] if type in ["Label", "RichTextLabel"] else ["normal", "hover", "pressed", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = background.lightened(0.07) if state == "hover" else background
			box.border_color = Color("58756d") if light else Color("72968b")
			box.set_border_width_all(1)
			box.content_margin_left = 8
			box.content_margin_right = 8
			box.content_margin_top = 5
			box.content_margin_bottom = 5
			_theme.set_stylebox(state, type, box)
	for type in ["Panel", "PanelContainer", "PopupPanel", "Window"]:
		var box := StyleBoxFlat.new()
		box.bg_color = background
		_theme.set_stylebox("panel", type, box)
	_walk(_root)
	var workspace := _root.get_node_or_null("FactoryWorkspaceUI")
	if workspace != null: workspace.apply_device_layout()

func _walk(node: Node) -> void:
	if node is Control or node is Window: _style(node)
	for child in node.get_children(): _walk(child)

func _style(node: Node) -> void:
	node.theme = _theme
	if node is Window:
		if node is AcceptDialog:
			node.get_ok_button().text = "确认" if node.get_ok_button().text == "OK" else node.get_ok_button().text
			if node is ConfirmationDialog: node.get_cancel_button().text = "取消"
		return
	var control := node as Control
	if control is AdaptivePanel: control.ui_scale = float(_metrics.automatic_scale)
	if not control.has_meta("device_base_font"):
		control.set_meta("device_base_font", control.get_theme_font_size("font_size") if control.has_theme_font_size_override("font_size") else 16)
	control.add_theme_font_size_override("font_size", roundi(float(control.get_meta("device_base_font")) * float(_metrics.font_scale)))
	if not control.has_meta("device_base_minimum"): control.set_meta("device_base_minimum", control.custom_minimum_size)
	if control is BaseButton:
		control.focus_mode = Control.FOCUS_ALL
		control.custom_minimum_size.y = maxf(Vector2(control.get_meta("device_base_minimum")).y, (44 if LocalSettings.values.density == "comfortable" else 34) * float(_metrics.automatic_scale))
		if control is Button: control.clip_text = false
	if control is ScrollContainer:
		control.follow_focus = true
		control.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if not control.has_meta("device_colors"):
		var original := {}
		for property in control.get_property_list():
			if String(property.name).begins_with("theme_override_colors/") and control.get(property.name) is Color: original[property.name] = control.get(property.name)
		control.set_meta("device_colors", original)
	for key in control.get_meta("device_colors"):
		var color: Color = control.get_meta("device_colors")[key]
		control.set(key, color.darkened(0.65) if LocalSettings.values.theme == "light" else color)
	for state in ["panel", "normal", "hover", "pressed", "disabled"]:
		if control.has_theme_stylebox_override(state): control.remove_theme_stylebox_override(state)
	if control is ColorRect:
		if not control.has_meta("device_background"): control.set_meta("device_background", control.color)
		control.color = Color("e7efeb") if LocalSettings.values.theme == "light" else control.get_meta("device_background")
	if control is BoxContainer:
		if not control.has_meta("device_separation"): control.set_meta("device_separation", control.get_theme_constant("separation"))
		control.add_theme_constant_override("separation", int(control.get_meta("device_separation")) + (6 if LocalSettings.values.density == "comfortable" else 0))
	if control is GridContainer:
		if not control.has_meta("device_columns"): control.set_meta("device_columns", control.columns)
		control.columns = 1 if LocalSettings.values.font_scale > 1.3 else int(control.get_meta("device_columns"))
	if control.name == "Card" and control.get_parent() is ScrollContainer:
		control.custom_minimum_size = Vector2(minf((900 if control.get_parent().get_parent() is SaveSlotsPanel else 520) * float(_metrics.automatic_scale), get_viewport().get_visible_rect().size.x - 24), 0)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control.get_parent() is ScrollContainer and not control is ScrollBar:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
