class_name GalacticExportWorkspace
extends PanelContainer

var _summary: Label
var _project: OptionButton
var _amount: SpinBox
var _priority: OptionButton
var _toggle: Button
var _feedback: Label
var _refresh_elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "本地银河出口"
	content.add_child(heading)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(hide)
	content.add_child(close)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_summary)
	_project = OptionButton.new()
	_project.name = "ExportProject"
	var labels := {"universe_archive": "宇宙矩阵档案", "solar_sail_array": "太阳帆阵列", "carrier_rocket_fleet": "运载火箭舰队", "antimatter_exchange": "反物质能源交换"}
	for id in GalacticExportSystem.PROJECTS:
		_project.add_item(labels.get(id, id))
		_project.set_item_metadata(_project.item_count - 1, id)
	_project.item_selected.connect(func(_index: int): refresh())
	content.add_child(_project)
	_amount = SpinBox.new()
	_amount.name = "ExportAmount"
	_amount.min_value = 1
	_amount.max_value = 999
	_amount.step = 1
	_amount.value = 1
	content.add_child(_amount)
	var dispatch := Button.new()
	dispatch.text = "立即出口选中项目"
	dispatch.pressed.connect(func(): _show_result(_system().dispatch(_selected_id(), int(_amount.value))))
	content.add_child(dispatch)
	_priority = OptionButton.new()
	_priority.name = "ExportPriority"
	for priority in [1, 2, 3]: _priority.add_item("优先级 %d" % priority)
	content.add_child(_priority)
	_toggle = Button.new()
	_toggle.pressed.connect(_toggle_project)
	content.add_child(_toggle)
	var auto := Button.new()
	auto.text = "切换自动出口"
	auto.pressed.connect(func(): _show_result(_system().set_automation(not _system().snapshot().state.auto_dispatch)))
	content.add_child(auto)
	for throttle in [0.25, 0.5, 1.0]:
		var button := Button.new()
		button.text = "自动速率 %d%%" % int(throttle * 100)
		button.pressed.connect(_set_throttle.bind(throttle))
		content.add_child(button)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_feedback)
	visibility_changed.connect(func():
		if visible: refresh())
	GameManager.game_state_replaced.connect(func(_state: GameState): hide())
	refresh()

func _system() -> GalacticExportSystem:
	return GalacticExportSystem.new(GameManager.get_game_state())

func _selected_id() -> String:
	return String(_project.get_item_metadata(_project.selected)) if _project.selected >= 0 else ""

func refresh() -> void:
	var data := _system().snapshot()
	var state: Dictionary = data.state
	_summary.text = "宇宙矩阵科技：%s · 自动出口：%s · 速率：%d%%\n累计出口：%d · 银河信用：%d · 银河积分：%d" % ["已完成" if data.unlocked else "未完成", "开启" if state.auto_dispatch else "关闭", int(float(state.throttle) * 100), int(state.total_exported), int(state.credits), int(state.score)]
	for id in GalacticExportSystem.PROJECTS:
		var project: Dictionary = state.projects[id]
		_summary.text += "\n%s · 等级 %d · 进度 %d/%d · 累计 %d" % [id, int(project.level), int(project.delivered), GalacticExportSystem.target_for(id, int(project.level)), int(project.total_delivered)]
	var industry := _system().industry_snapshot(GameManager.get_simulation_engine().statistics_system)
	_summary.text += "\n银河工业 · 活跃行星 %d · 运行 %d / 阻塞 %d\n生产 %.1f / 消耗 %.1f 每分钟 · 全网库存 %.0f\n实际发电 %.1f kW / 需求 %.1f kW · 无限研究总层数 %d" % [industry.activePlanets, industry.operatingEntities, industry.blockedEntities, industry.totalProductionPerMinute, industry.totalConsumptionPerMinute, industry.networkInventory, industry.generationKw, industry.demandKw, industry.infiniteResearchLevels]
	var selected := _selected_id()
	if selected.is_empty(): return
	var selected_project: Dictionary = state.projects[selected]
	_toggle.text = "关闭选中项目自动派遣" if selected_project.enabled else "开启选中项目自动派遣"
	if not _priority.has_focus(): _priority.select(int(selected_project.priority) - 1)
	_toggle.disabled = not data.unlocked

func _toggle_project() -> void:
	var id := _selected_id()
	if id.is_empty(): return
	var project: Dictionary = _system().snapshot().state.projects[id]
	_show_result(_system().configure(id, not project.enabled, _priority.selected + 1))

func _set_throttle(value: float) -> void:
	_show_result(_system().set_throttle(value))

func _show_result(result: Dictionary) -> void:
	_feedback.text = String(result.get("message", "操作失败"))
	refresh()

func _process(delta: float) -> void:
	if not visible: return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0
		refresh()
