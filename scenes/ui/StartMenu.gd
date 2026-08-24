class_name StartMenu
extends Control

signal new_game_requested
signal continue_requested(slot: int)
signal slots_requested

const BACKGROUND := Color("#0b1110")
const PANEL := Color("#131c19")
const BORDER := Color("#315f59")
const TEXT := Color("#e6ece9")
const MUTED := Color("#90a39e")
const ACCENT := Color("#62b5ae")
const ERROR := Color("#df7666")

var _continue_button: Button
var _summary_label: Label
var _error_label: Label
var _recent_slot := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()

func refresh_saves(saves: Array) -> void:
	_recent_slot = -1
	var newest_timestamp := -1.0
	var newest_info: Dictionary = {}
	for save_value in saves:
		if not save_value is Dictionary:
			continue
		var save_info: Dictionary = save_value
		var saved_at := float(save_info.get("saved_at", 0.0))
		if _recent_slot < 0 or saved_at > newest_timestamp:
			_recent_slot = int(save_info.get("slot", -1))
			newest_timestamp = saved_at
			newest_info = save_info
	_continue_button.disabled = _recent_slot < 0
	if _recent_slot < 0:
		_summary_label.text = "尚无本地存档。选择一个空槽开始建设。"
		return
	_summary_label.text = "最近存档  槽位 %02d  ·  %s  ·  建筑 %d" % [
		_recent_slot + 1,
		_format_duration(float(newest_info.get("elapsed_time", 0.0))),
		int(newest_info.get("building_count", 0)),
	]

func show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = not message.is_empty()

func clear_error() -> void:
	show_error("")

func _create_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var layout := CenterContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(520, 430)
	card.add_theme_stylebox_override("panel", _panel_style())
	layout.add_child(card)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)

	var eyebrow := _label("Eyebrow", "LOCAL FACTORY SESSION", 13, ACCENT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)

	var title := _label("Title", "CARD FACTORY", 34, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var subtitle := _label("Subtitle", "离线工业建造 · 存档保存在本机", 15, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	content.add_child(HSeparator.new())
	_summary_label = _label("SaveSummary", "正在检查本地存档…", 14, MUTED)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_summary_label)

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 9)
	content.add_child(actions)

	var new_game_button := _button("NewGameButton", "新游戏", true)
	new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
	actions.add_child(new_game_button)

	_continue_button = _button("ContinueButton", "继续最近游戏", false)
	_continue_button.disabled = true
	_continue_button.pressed.connect(func() -> void:
		if _recent_slot >= 0:
			continue_requested.emit(_recent_slot)
	)
	actions.add_child(_continue_button)

	var slots_button := _button("SlotsButton", "管理存档槽位", false)
	slots_button.pressed.connect(func() -> void: slots_requested.emit())
	actions.add_child(slots_button)

	_error_label = _label("ErrorLabel", "", 14, ERROR)
	_error_label.visible = false
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_error_label)

	var footer := _label("Footer", "无需账号 · 无云同步 · 可随时离线游玩", 12, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(footer)

func _button(node_name: String, text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#245c55") if primary else Color("#182522")
	normal.border_color = ACCENT if primary else BORDER
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal)
	return button

func _label(node_name: String, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	return style

func _format_duration(total_seconds: float) -> String:
	var seconds := maxi(int(total_seconds), 0)
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
