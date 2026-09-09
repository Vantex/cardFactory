class_name RecoveryWorkspace
extends PanelContainer

signal dismissed
signal restore_requested(slot: int, source: String)
var content: VBoxContainer
var message: Label
var confirmation: ConfirmationDialog
var selected_slot := -1
var selected_source := ""
var selected_snapshots: Array = []
var delete_confirmation: ConfirmationDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "恢复所选存档"
	confirmation.ok_button_text = "恢复并保存"
	confirmation.cancel_button_text = "取消"
	confirmation.confirmed.connect(func(): restore_requested.emit(selected_slot, selected_source))
	add_child(confirmation)
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.title = "删除所选恢复快照"
	delete_confirmation.dialog_text = "只删除勾选的快照；主档、备份和紧急恢复点保持不变。"
	delete_confirmation.ok_button_text = "删除所选"
	delete_confirmation.cancel_button_text = "取消"
	delete_confirmation.confirmed.connect(func():
		var result := GameManager.get_save_system().delete_snapshots(selected_slot, selected_snapshots)
		open(selected_slot)
		if not result.ok: show_error(result.error.message))
	add_child(delete_confirmation)
	hide()

func open(slot: int) -> void:
	selected_slot = slot
	selected_snapshots.clear()
	for child in content.get_children(): child.free()
	var heading := _label("槽位 %02d · 恢复来源" % (slot + 1))
	heading.focus_mode = Control.FOCUS_ALL
	_label("检查列表不会修改文件。恢复旧版本会回滚工厂进度，过去的离线时间不再补算。")
	for source in GameManager.get_save_system().get_recovery_sources(slot):
		var metadata: Dictionary = source.metadata
		var label: String = {"primary": "主档", "backup": "最近有效备份", "emergency": "紧急恢复点"}.get(source.source, "手动恢复快照")
		var status := "校验通过" if source.valid else String(source.error.get("message", "不可用"))
		var timestamp := Time.get_datetime_string_from_unix_time(int(metadata.get("saved_at", 0))).replace("T", " ") + " UTC" if source.valid else "—"
		_label("%s · %s\n保存时间 %s · 游玩 %.0f 秒 · 版本 %s" % [label, status, timestamp, float(metadata.get("elapsed_time", 0)), str(metadata.get("source_schema_version", "—"))])
		var button := Button.new()
		button.name = "Restore_" + source.source
		button.text = "恢复" + label
		button.disabled = not source.valid
		button.pressed.connect(_confirm.bind(String(source.source), label))
		content.add_child(button)
		if String(source.source).begins_with("snapshot_"):
			var select := CheckBox.new()
			select.text = "选择此快照用于删除"
			select.toggled.connect(func(checked: bool):
				if checked: selected_snapshots.append(source.source)
				else: selected_snapshots.erase(source.source))
			content.add_child(select)
	var remove := Button.new()
	remove.text = "删除勾选的快照"
	remove.pressed.connect(func():
		if selected_snapshots.is_empty(): show_error("请先选择要删除的快照")
		else: delete_confirmation.popup_centered(Vector2i(480, 180)))
	content.add_child(remove)
	message = _label("")
	var back := Button.new()
	back.name = "BackButton"
	back.text = "返回"
	back.pressed.connect(func(): hide(); dismissed.emit())
	content.add_child(back)
	show()

func show_error(text: String) -> void:
	message.text = text

func _confirm(source: String, label: String) -> void:
	selected_source = source
	confirmation.dialog_text = "将从%s恢复槽位 %02d。确认后先验证并写入，成功后才进入工厂。" % [label, selected_slot + 1]
	confirmation.popup_centered(Vector2i(500, 180))

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label
