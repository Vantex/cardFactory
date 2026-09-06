extends PanelContainer

var selected_ids: Array = []
var slot_index := 0
var content: VBoxContainer
var status: Label
var item_choice: OptionButton
var mode_choice: OptionButton
var capacity: SpinBox
var minimum: SpinBox
var priority: SpinBox
var quantity: SpinBox
var fleet_choice: OptionButton
var _refresh_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.active_planet_changed.connect(func(_id: String): hide())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var title := Label.new()
	title.text = "物流站 · 配置与运输"
	content.add_child(title)
	_button("关闭", hide)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	var slot_choice := OptionButton.new()
	for i in range(4):
		slot_choice.add_item("槽位 %d" % (i + 1))
	slot_choice.item_selected.connect(func(i: int):
		slot_index = i
		_load_slot())
	content.add_child(slot_choice)
	item_choice = OptionButton.new()
	item_choice.add_item("空槽")
	item_choice.set_item_metadata(0, "")
	var items := DataManager.get_all_items().keys()
	items.sort()
	for item in items:
		item_choice.add_item(DataManager.get_item(item).get("name", item))
		item_choice.set_item_metadata(item_choice.item_count - 1, item)
	content.add_child(item_choice)
	mode_choice = OptionButton.new()
	for text in ["供应", "需求", "存储"]:
		mode_choice.add_item(text)
	content.add_child(mode_choice)
	capacity = _number("槽位容量", 1, 999, 100)
	minimum = _number("最低装载比例", 0.01, 1, 0.1, 0.01)
	priority = _number("优先级（2 最高）", 0, 2, 0)
	_button("应用到选中物流站", _apply)
	_button("停止派遣（等待返航后可改槽）", _set_enabled.bind(false))
	_button("恢复派遣", _set_enabled.bind(true))
	quantity = _number("货物 / 载具转移数量", 1, 999, 1)
	_button("行星托盘 → 当前槽", _cargo.bind(true))
	_button("当前槽 → 行星托盘", _cargo.bind(false))
	fleet_choice = OptionButton.new()
	for text in ["物流运输机", "物流飞船", "空间翘曲器"]:
		fleet_choice.add_item(text)
	content.add_child(fleet_choice)
	_button("从托盘装入载具 / 翘曲器", _fleet.bind(true))
	_button("取回停泊载具 / 翘曲器", _fleet.bind(false))

func open_stations(ids: Array) -> void:
	selected_ids = ids.duplicate()
	_load_slot()
	show()

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_time += delta
	if _refresh_time >= 0.25:
		_refresh_time = 0
		_refresh_status()

func _load_slot() -> void:
	if selected_ids.is_empty():
		return
	var info := StationSystem.new(GameManager.get_game_state()).get_station_info(selected_ids[0])
	if info.is_empty():
		hide()
		return
	var slot: Dictionary = info.slots[slot_index]
	for i in range(item_choice.item_count):
		if item_choice.get_item_metadata(i) == slot.item_id:
			item_choice.select(i)
	mode_choice.select(["supply", "demand", "storage"].find(slot.mode))
	capacity.value = slot.capacity
	minimum.value = slot.min_load
	priority.value = slot.priority
	_refresh_status()

func _refresh_status() -> void:
	var state := GameManager.get_game_state()
	if selected_ids.is_empty() or not state.buildings.has(selected_ids[0]) or state.buildings[selected_ids[0]].planet_id != state.active_planet_id:
		hide()
		return
	var info := StationSystem.new(state).get_station_info(selected_ids[0])
	var lines: Array[String] = ["选中 %d 站 · 转移仅作用于首站 %s" % [selected_ids.size(), selected_ids[0]]]
	for i in range(4):
		var slot: Dictionary = info.slots[i]
		lines.append("槽 %d：%s  %.1f / %.0f" % [i + 1, DataManager.get_item(slot.item_id).get("name", "空"), slot.amount, slot.capacity])
	lines.append("调度：" + ("启用" if info.enabled else "停发"))
	lines.append("停泊运输机 %d / 飞船 %d / 翘曲器 %d" % [info.fleet.logistics_drone, info.fleet.logistics_vessel, info.fleet.space_warper])
	lines.append(GameManager.get_simulation_engine().logistics_system.diagnostics.get(selected_ids[0], "等待供需匹配"))
	for route in state.logistics_routes.values():
		if route.source_id == selected_ids[0] or route.target_id == selected_ids[0]:
			lines.append("%s → %s：%s %.1f，%s %.1f 秒" % [route.source_id, route.target_id, route.item_id, route.amount, "返航" if route.phase == "returning" else "运输", route.remaining])
	status.text = "\n".join(lines)

func _apply() -> void:
	var result := StationSystem.new(GameManager.get_game_state()).configure_slots(selected_ids, slot_index, item_choice.get_selected_metadata(), ["supply", "demand", "storage"][mode_choice.selected], capacity.value, minimum.value, int(priority.value))
	_notice(result)

func _cargo(deposit: bool) -> void:
	if not selected_ids.is_empty():
		_notice(StationSystem.new(GameManager.get_game_state()).transfer_cargo(selected_ids[0], slot_index, quantity.value, deposit))

func _fleet(deposit: bool) -> void:
	if not selected_ids.is_empty():
		_notice(StationSystem.new(GameManager.get_game_state()).transfer_fleet(selected_ids[0], StationSystem.FLEET_ITEMS[fleet_choice.selected], int(quantity.value), deposit))

func _notice(result: Dictionary) -> void:
	EventBus.notice_requested.emit(result.message, "info" if result.ok else "error")
	_refresh_status()

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	content.add_child(button)

func _number(text: String, low: float, high: float, value: float, step: float = 1) -> SpinBox:
	var label := Label.new()
	label.text = text
	content.add_child(label)
	var control := SpinBox.new()
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = value
	content.add_child(control)
	return control



func _set_enabled(enabled: bool) -> void:
	_notice(StationSystem.new(GameManager.get_game_state()).set_enabled(selected_ids, enabled))
