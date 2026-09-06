extends PanelContainer

signal locate_requested(building_id: String, world_position: Vector2)

var content: VBoxContainer
var details: Label
var status: Label
var start_button: Button
var reward_button: Button
var confirmation: ConfirmationDialog
var expected_planet_id := ""
var refresh_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_label("单机终局 · 星际文明计划")
	_button("关闭", hide)
	details = _label("")
	status = _label("材料必须汇入来源行星托盘。启动后不可撤回投入。")
	start_button = _button("检查并确认启动", request_start)
	reward_button = _button("领取待发奖励", func(): _show_result(_model().claim_reward()))
	for item in EndgameSystem.get_rules().cost:
		_button("定位" + String(DataManager.get_item(item).get("name", item)) + "生产", locate_producer.bind(item))
	_button("查看戴森工程", func(): get_parent().show_exclusive_workspace("DysonPanel"))
	confirmation = ConfirmationDialog.new()
	confirmation.title = "确认一次性终局投入"
	confirmation.confirmed.connect(confirm_start)
	add_child(confirmation)
	visibility_changed.connect(func():
		if visible: refresh()
		else: confirmation.hide())
	GameManager.game_state_replaced.connect(func(_state: GameState):
		expected_planet_id = ""
		hide()
		confirmation.hide())
	EventBus.active_planet_changed.connect(func(_id: String):
		expected_planet_id = ""
		confirmation.hide()
		if visible: refresh())
	refresh()

func _model() -> EndgameSystem:
	return EndgameSystem.new(GameManager.get_game_state())

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func refresh() -> void:
	var snapshot := _model().get_snapshot()
	var names := {"preparing": "准备", "running": "运行", "won": "单机胜利"}
	var planet := GalaxySystem.new(GameManager.get_game_state()).get_planet(snapshot.planet_id)
	details.text = "阶段：%s\n来源：%s / %s\n戴森功率：%.0f / %.0f kW\n进度：%.1f / %.1f 模拟秒" % [names[snapshot.phase], planet.get("name", snapshot.planet_id), snapshot.system_id, snapshot.power_kw, snapshot.required_power_kw, float(snapshot.progress_ticks) / 60, float(snapshot.duration_ticks) / 60]
	for item in snapshot.cost:
		details.text += "\n%s：投入 %.0f · 缺口 %.0f" % [DataManager.get_item(item).get("name", item), snapshot.cost[item], snapshot.missing[item]]
	if snapshot.phase == "won":
		details.text += "\n星际文明计划完成！工厂继续运行。\n" + ("一次性奖励已领取。" if snapshot.reward_claimed else "奖励待领取：请为来源行星的 10 白矩阵腾出空间。")
	else:
		details.text += "\n速率：%.0f%% · 剩余运行时间：%.1f 模拟秒" % [float(snapshot.rate) * 100, snapshot.remaining_seconds]
		details.text += "\n" + ("游戏已暂停" if GameManager.get_game_state().paused else String(snapshot.reason) if not snapshot.reason.is_empty() else "条件满足")
		details.text += "\n" + ("预计 %.1f 秒后完成（当前游戏速度）" % (float(snapshot.remaining_seconds) / GameManager.get_game_state().speed) if float(snapshot.rate) > 0 else "预计完成时间：等待运行条件恢复")
		details.text += "\n功率不足时进度保留；完成奖励 10 白矩阵。"
	start_button.disabled = not snapshot.can_start
	reward_button.visible = snapshot.phase == "won" and not snapshot.reward_claimed

func request_start() -> void:
	var snapshot := _model().get_snapshot()
	if not snapshot.can_start:
		_show_result({"message": snapshot.reason if snapshot.phase == "preparing" else "终局已经启动"})
		return
	expected_planet_id = snapshot.planet_id
	confirmation.dialog_text = "从行星 %s 一次扣除：" % expected_planet_id
	for item in snapshot.cost:
		confirmation.dialog_text += "\n%s ×%.0f" % [DataManager.get_item(item).get("name", item), snapshot.cost[item]]
	confirmation.dialog_text += "\n投入不可撤回；不足功率时暂停推进，保留进度。确认启动？"
	confirmation.popup_centered(Vector2i(440, 240))

func confirm_start() -> void:
	_show_result(_model().try_start(expected_planet_id, true))
	expected_planet_id = ""
	confirmation.hide()

func locate_producer(item: String) -> void:
	var producer := _model().find_producer(item)
	if producer.is_empty():
		status.text = "尚无已配置的生产设备，请在资料库查看该物品配方。"
		return
	locate_requested.emit(producer.building_id, producer.position)
	hide()

func _show_result(result: Dictionary) -> void:
	status.text = result.message
	refresh()

func _process(delta: float) -> void:
	if not visible: return
	refresh_time += delta
	if refresh_time >= 0.25:
		refresh_time = 0
		refresh()
