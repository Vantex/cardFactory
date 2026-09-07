extends PanelContainer

signal dismissed
signal return_requested
var text: Label
var discard_button: Button
var retry_button: Button
var close_button: Button
var menu_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)
	discard_button = _button(content, "放弃尚未提交的收益，继续游戏", func(): GameManager.discard_offline_settlement())
	retry_button = _button(content, "重试结算", func():
		var result := GameManager.retry_offline_settlement()
		if not result.ok: text.text = String(result.error.message))
	close_button = _button(content, "进入工厂", func(): hide(); dismissed.emit())
	menu_button = _button(content, "返回菜单，保留恢复记录", func(): hide(); return_requested.emit())
	hide()

func _button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func display(snapshot: Dictionary) -> void:
	show()
	var phase := String(snapshot.get("phase", ""))
	discard_button.visible = snapshot.get("can_discard", false)
	retry_button.visible = phase == "error"
	close_button.visible = phase == "complete"
	menu_button.visible = phase != "complete"
	if phase == "error":
		text.text = "离线结算未提交\n" + String(snapshot.get("error", {}).get("message", "写入失败，请重试"))
		return
	if phase != "complete":
		text.text = "正在精确重放离线时间\n进度 %.1f / %.1f 模拟秒\n本次最多处理 120 秒；计算期间原存档保持不变。\n关闭程序后可从已验证起点恢复，放弃会跳过本次整个离线时段。" % [float(snapshot.get("ticks_done", 0)) / 60, float(snapshot.get("ticks_total", 0)) / 60]
		return
	var report: Dictionary = snapshot.get("report", {})
	text.text = "离线报告 · 已保存\n真实离线 %.1f 秒 · 模拟 %.1f 秒 · 跳过 %.1f 秒\n精确结算上限 %.0f 秒，按 1× 模拟。" % [report.get("actual_seconds", 0), report.get("simulated_seconds", 0), report.get("skipped_seconds", 0), report.get("cap_seconds", 120)]
	if report.get("discarded", false): text.text += "\n已按你的选择放弃本次未提交收益。"
	if report.get("clock_rollback", false): text.text += "\n系统时间回拨：未补收益，已处理时间边界保持不变。"
	if report.get("unknown_start_time", false): text.text += "\n旧档缺少可信离线起点：本次只建立时间边界。"
	text.text += "\n实际产出："
	var produced: Dictionary = report.get("produced", {})
	if produced.is_empty(): text.text += "无"
	for item in produced:
		text.text += "\n%s ×%.1f" % [DataManager.get_item(item).get("name", item), produced[item]]
	text.text += "\n新完成科技：%s\n新完成目标：%s\n终局阶段：%s" % [_names(report.get("technologies", []), true), _names(report.get("objectives", []), false), {"preparing": "准备", "running": "运行", "won": "单机胜利"}.get(report.get("endgame_phase", "preparing"), "准备")]
	var reasons := {"blocked": "缺料或输出已满", "no_power": "断电", "no_fuel": "缺少燃料", "error": "设备配置错误"}
	text.text += "\n结束时阻塞："
	if report.get("blocked", {}).is_empty(): text.text += "无"
	for reason in report.get("blocked", {}): text.text += "\n%s：%d 台" % [reasons.get(reason, reason), report.blocked[reason]]

func _names(ids: Array, technologies: bool) -> String:
	var names := PackedStringArray()
	var objectives := {}
	if not technologies:
		for objective in ObjectiveSystem.load_catalog().get("objectives", []):
			objectives[objective.id] = objective.get("title", objective.id)
	for id in ids:
		names.append(String(DataManager.get_technology(id).get("name", id)) if technologies else String(objectives.get(id, id)))
	return "、".join(names) if not names.is_empty() else "无"