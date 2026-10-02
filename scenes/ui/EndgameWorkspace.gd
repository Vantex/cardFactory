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
var warp_devices: OptionButton
var warp_requested: SpinBox
var warp_status: Label
var warp_device_signature := ""
var pure_idle_mode: OptionButton
var pure_idle_status: Label
var black_hole_devices: OptionButton
var black_hole_status: Label
var black_hole_confirmation: ConfirmationDialog
var black_hole_signature := ""

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
	_button("查看本地轨道空间站", func(): get_parent().show_exclusive_workspace("LocalSpaceStationWorkspace"))
	_button("查看恒星系空间站", func(): get_parent().show_exclusive_workspace("SystemSpaceStationWorkspace"))
	_button("查看本地银河出口", func(): get_parent().show_exclusive_workspace("GalacticExportWorkspace"))
	_label("时间扭曲 · 消耗主控所在电网剩余功率；普通离线按 1×")
	warp_devices = OptionButton.new()
	warp_devices.name = "TimeWarpDevices"
	content.add_child(warp_devices)
	warp_requested = SpinBox.new()
	warp_requested.name = "TimeWarpRequested"
	warp_requested.min_value = 5
	warp_requested.max_value = 307
	warp_requested.step = 1
	warp_requested.value = 5
	content.add_child(warp_requested)
	_button("设为时间扭曲主控", _select_warp_controller)
	_button("设置请求倍率", _set_warp_multiplier)
	_button("启用 / 停止时间扭曲", _toggle_warp)
	warp_status = _label("")
	_label("纯挂机 · 普通模式与时间扭曲；每 30 秒结算一次")
	pure_idle_mode = OptionButton.new()
	pure_idle_mode.name = "PureIdleMode"
	pure_idle_mode.add_item("稳定 · 每 600 秒重新校验")
	pure_idle_mode.add_item("极限 · 跳过周期校验")
	content.add_child(pure_idle_mode)
	var pure_button := _button("启用 / 停止纯挂机", _toggle_pure_idle)
	pure_button.name = "PureIdleToggle"
	pure_idle_status = _label("")
	_label("微型黑洞 · 三端口永久销毁物资")
	black_hole_devices = OptionButton.new()
	black_hole_devices.name = "BlackHoleDevices"
	content.add_child(black_hole_devices)
	_button("暂停选中黑洞", _pause_black_hole)
	_button("确认启动选中黑洞", _request_black_hole_start)
	black_hole_status = _label("")
	black_hole_confirmation = ConfirmationDialog.new()
	black_hole_confirmation.title = "确认不可逆的物资销毁"
	black_hole_confirmation.dialog_text = "启动后，三个输入端口送达的物资会永久销毁。确认启动？"
	black_hole_confirmation.confirmed.connect(_confirm_black_hole_start)
	add_child(black_hole_confirmation)
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
	_refresh_warp()
	_refresh_black_hole()
	var idle := GameManager.get_game_state().pure_idle
	pure_idle_status.text = "%s · 待结算 %.1f 秒\n上次模拟 %.1f 秒 · 宏观推进 %.1f 秒" % ["已启用" if idle.get("enabled", false) else "已停止", float(idle.get("carry_seconds", 0)), float(idle.get("report", {}).get("simulated_seconds", 0)), float(idle.get("report", {}).get("macro_seconds", 0))]
	var snapshot := _model().get_snapshot()
	var names := {"preparing": "准备", "running": "运行", "won": "单机胜利"}
	var planet := GalaxySystem.new(GameManager.get_game_state()).get_planet(snapshot.planet_id)
	details.text = "阶段：%s\n来源：%s / %s\n戴森功率：%.0f / %.0f kW\n进度：%.1f / %.1f 模拟秒" % [names[snapshot.phase], planet.get("name", snapshot.planet_id), snapshot.system_id, snapshot.power_kw, snapshot.required_power_kw, float(snapshot.progress_ticks) / 60, float(snapshot.duration_ticks) / 60]
	for item in snapshot.cost:
		details.text += "\n%s：投入 %.0f · 缺口 %.0f" % [DataManager.get_item(item).get("name", item), snapshot.cost[item], snapshot.missing[item]]
	if GameManager.get_game_state().save_mode == "speedrun":
		var mode := GameModeSystem.new(GameManager.get_game_state())
		var progress := mode.get_progress()
		var milestones: Dictionary = GameManager.get_game_state().speedrun_state.get("milestones", {})
		details.text += "\n速通计时 %.1f 秒 · 科技 %d/69 · 火箭 %d/10000 · 宇宙矩阵 %.0f/1000000" % [float(GameManager.get_game_state().speedrun_state.get("elapsed_active_seconds", 0)), int(progress.all_technologies), int(progress.dyson_rockets_10000), float(progress.white_matrix_1m)]
		for id in milestones: details.text += "\n%s：%.1f 秒达成" % [id, float(milestones[id])]
	if snapshot.phase == "won":
		details.text += "\n星际文明计划完成！工厂继续运行。\n" + ("一次性奖励已领取。" if snapshot.reward_claimed else "奖励待领取：请为来源行星的 10 白矩阵腾出空间。")
	else:
		details.text += "\n速率：%.0f%% · 剩余运行时间：%.1f 模拟秒" % [float(snapshot.rate) * 100, snapshot.remaining_seconds]
		details.text += "\n" + ("游戏已暂停" if GameManager.get_game_state().paused else String(snapshot.reason) if not snapshot.reason.is_empty() else "条件满足")
		details.text += "\n" + ("预计 %.1f 秒后完成（当前游戏速度）" % (float(snapshot.remaining_seconds) / GameManager.get_game_state().speed) if float(snapshot.rate) > 0 else "预计完成时间：等待运行条件恢复")
		details.text += "\n功率不足时进度保留；完成奖励 10 白矩阵。"
	start_button.disabled = not snapshot.can_start
	reward_button.visible = snapshot.phase == "won" and not snapshot.reward_claimed

func _refresh_warp() -> void:
	var state := GameManager.get_game_state()
	var ids := state.buildings.keys()
	ids.sort()
	var available := []
	for id in ids:
		if state.buildings[id].get("type") == "dsp_time_warp_device": available.append(id)
	var signature := JSON.stringify(available)
	if signature != warp_device_signature:
		var selected := String(warp_devices.get_item_metadata(warp_devices.selected)) if warp_devices.selected >= 0 else ""
		warp_devices.clear()
		for id in available:
			warp_devices.add_item("%s · %s" % [id, state.buildings[id].get("planet_id", "")])
			warp_devices.set_item_metadata(warp_devices.item_count - 1, id)
		if warp_devices.item_count > 0:
			for index in range(warp_devices.item_count):
				if warp_devices.get_item_metadata(index) == selected: warp_devices.select(index)
		warp_device_signature = signature
	var warp := state.time_warp
	if not warp_requested.has_focus(): warp_requested.value = int(warp.get("requested", 5))
	warp_status.text = "主控：%s · %s\n请求 %dx · 实际 %.0fx · 供电 %.0f / %.0f kW" % [warp.get("controller_id", "未选择"), "已启用" if warp.get("enabled", false) else "已停止", int(warp.get("requested", 5)), TimeWarpSystem.new(state).effective_multiplier(), float(warp.get("allocated_kw", 0)), float(warp.get("required_kw", 0))]

func _refresh_black_hole() -> void:
	var state := GameManager.get_game_state()
	var ids := []
	for id in state.buildings:
		if state.buildings[id].get("type") == BlackHoleSystem.TYPE: ids.append(id)
	ids.sort()
	var signature := JSON.stringify(ids)
	if signature != black_hole_signature:
		var selected := _selected_black_hole()
		black_hole_devices.clear()
		for id in ids:
			black_hole_devices.add_item("%s · %s" % [id, state.buildings[id].get("planet_id", "")])
			black_hole_devices.set_item_metadata(black_hole_devices.item_count - 1, id)
			if id == selected: black_hole_devices.select(black_hole_devices.item_count - 1)
		black_hole_signature = signature
	var building: Dictionary = state.buildings.get(_selected_black_hole(), {})
	if building.is_empty():
		black_hole_status.text = "没有可控制的微型黑洞连接器。"
	else:
		black_hole_status.text = "%s · 端口销毁：%s" % ["暂停" if building.get("black_hole_paused", true) else "运行", str(building.get("black_hole_ports", []))]

func _selected_black_hole() -> String:
	return String(black_hole_devices.get_item_metadata(black_hole_devices.selected)) if black_hole_devices.selected >= 0 else ""

func _pause_black_hole() -> void:
	var result := BlackHoleSystem.new(GameManager.get_game_state()).set_paused(_selected_black_hole(), true)
	status.text = String(result.message)
	refresh()

func _request_black_hole_start() -> void:
	if _selected_black_hole().is_empty(): return
	black_hole_confirmation.popup_centered(Vector2i(440, 180))

func _confirm_black_hole_start() -> void:
	var result := BlackHoleSystem.new(GameManager.get_game_state()).set_paused(_selected_black_hole(), false, true)
	status.text = String(result.message)
	refresh()

func _select_warp_controller() -> void:
	var id := String(warp_devices.get_item_metadata(warp_devices.selected)) if warp_devices.selected >= 0 else ""
	status.text = "主控已选择" if TimeWarpSystem.new(GameManager.get_game_state()).select_controller(id) else "请选择可用的时间扭曲装置"
	refresh()

func _set_warp_multiplier() -> void:
	status.text = "请求倍率已设置" if TimeWarpSystem.new(GameManager.get_game_state()).set_requested(int(warp_requested.value)) else "倍率需为 5～307 的整数"
	refresh()

func _toggle_pure_idle() -> void:
	var result := GameManager.configure_pure_idle(not GameManager.get_game_state().pure_idle.get("enabled", false), "stable" if pure_idle_mode.selected == 0 else "extreme")
	status.text = String(result.get("message", result.get("error", {}).get("message", "设置失败")))
	refresh()

func _toggle_warp() -> void:
	var warp := TimeWarpSystem.new(GameManager.get_game_state())
	status.text = "时间扭曲设置已更新" if warp.set_enabled(not GameManager.get_game_state().time_warp.get("enabled", false)) else "请先选择未锁定的主控装置"
	refresh()

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
