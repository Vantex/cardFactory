class_name SaveSlotsPanel
extends Control

signal new_game_requested(slot: int)
signal continue_requested(slot: int)
signal delete_requested(slot: int)
signal recovery_requested(slot: int)
signal back_requested

const BACKGROUND := Color("#0b1110")
const PANEL := Color("#131c19")
const PANEL_ALT := Color("#182522")
const BORDER := Color("#315f59")
const TEXT := Color("#e6ece9")
const MUTED := Color("#90a39e")
const ACCENT := Color("#62b5ae")
const WARNING := Color("#e1b452")
const ERROR := Color("#df7666")

var _slots: GridContainer
var _error_label: Label
var _confirmation: ConfirmationDialog
var _pending_delete_slot := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()

func refresh_slots(saves: Array) -> void:
	var saves_by_slot: Dictionary = {}
	for value in saves:
		if value is Dictionary:
			var info: Dictionary = value
			saves_by_slot[int(info.get("slot", -1))] = info
	for child in _slots.get_children():
		child.free()
	for slot in range(SaveSystem.MAX_SAVES):
		_slots.add_child(_create_slot(slot, saves_by_slot.get(slot, {})))

func show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = not message.is_empty()

func _create_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var layout := ScrollContainer.new()
	layout.follow_focus = true
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(900, 570)
	card.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER))
	layout.add_child(card)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	var heading := HBoxContainer.new()
	heading.name = "Heading"
	content.add_child(heading)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	var title := _label("Title", "本地存档", 25, TEXT)
	titles.add_child(title)
	var subtitle := _label("Subtitle", "主档、最近备份与紧急恢复点可分别检查", 13, MUTED)
	titles.add_child(subtitle)
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(90, 38)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	heading.add_child(back_button)

	_slots = GridContainer.new()
	_slots.name = "Slots"
	_slots.columns = 2
	_slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots.add_theme_constant_override("h_separation", 10)
	_slots.add_theme_constant_override("v_separation", 10)
	content.add_child(_slots)

	_error_label = _label("ErrorLabel", "", 13, ERROR)
	_error_label.visible = false
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_error_label)

	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "DeleteConfirmation"
	_confirmation.title = "删除本地存档"
	_confirmation.ok_button_text = "删除"
	_confirmation.cancel_button_text = "取消"
	_confirmation.confirmed.connect(_on_delete_confirmed)
	add_child(_confirmation)
	refresh_slots([])

func _create_slot(slot: int, info: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % slot
	panel.custom_minimum_size = Vector2(410, 78)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_ALT, BORDER))

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	var occupied := not info.is_empty()
	var slot_title := _label("SlotLabel", "槽位 %02d" % (slot + 1), 15, TEXT)
	summary.add_child(slot_title)
	var details := "空槽位"
	if occupied:
		details = "%s · 建筑 %d · %s" % [
			_format_duration(float(info.get("elapsed_time", 0.0))),
			int(info.get("building_count", 0)),
			String(info.get("active_planet", "home")),
		]
	var detail_label := _label("Details", details, 12, MUTED)
	summary.add_child(detail_label)

	if occupied:
		var continue_button := _small_button("ContinueButton", "继续", ACCENT)
		continue_button.disabled = not info.get("valid", true)
		continue_button.pressed.connect(func() -> void: continue_requested.emit(slot))
		row.add_child(continue_button)
		var recovery := _small_button("RecoveryButton", "恢复", ACCENT)
		recovery.pressed.connect(func(): recovery_requested.emit(slot))
		row.add_child(recovery)
		var delete_button := _small_button("DeleteButton", "删除", WARNING)
		delete_button.pressed.connect(_request_delete.bind(slot))
		row.add_child(delete_button)
	else:
		var new_game_button := _small_button("NewGameButton", "新游戏", ACCENT)
		new_game_button.pressed.connect(func() -> void: new_game_requested.emit(slot))
		row.add_child(new_game_button)
	return panel

func _request_delete(slot: int) -> void:
	_pending_delete_slot = slot
	_confirmation.dialog_text = "确定删除槽位 %02d？此操作会同时删除其本地备份。" % (slot + 1)
	_confirmation.popup_centered(Vector2i(420, 170))

func _on_delete_confirmed() -> void:
	if _pending_delete_slot < 0:
		return
	delete_requested.emit(_pending_delete_slot)
	_pending_delete_slot = -1

func _small_button(node_name: String, text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(68, 36)
	button.add_theme_color_override("font_color", color)
	return button

func _label(node_name: String, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _format_duration(total_seconds: float) -> String:
	var seconds := maxi(int(total_seconds), 0)
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
