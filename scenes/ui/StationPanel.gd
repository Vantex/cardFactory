extends PanelContainer

var stack_target: SpinBox
var world_stations: OptionButton
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
var warper_target: SpinBox
var slot_choice: OptionButton
var scope_choice: OptionButton
var minimum_stock: SpinBox
var maximum_stock: SpinBox
var fleet_target: SpinBox
var quantum_capacity: LineEdit
var route_policy: OptionButton
var warper_budget: SpinBox
var hub_priority: SpinBox
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
	world_stations = OptionButton.new()
	world_stations.name = "WorldStationSelection"
	world_stations.item_selected.connect(func(index): open_stations([world_stations.get_item_metadata(index)]))
	content.add_child(world_stations)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	slot_choice = OptionButton.new()
	for i in range(4):
		slot_choice.add_item("槽位 %d" % (i + 1))
	slot_choice.item_selected.connect(func(i: int):
		slot_index = i
		_load_slot())
	content.add_child(slot_choice)
	scope_choice = OptionButton.new()
	scope_choice.add_item("本行星物流")
	scope_choice.add_item("跨行星物流")
	scope_choice.item_selected.connect(func(_i): _load_slot())
	content.add_child(scope_choice)
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
	minimum_stock = _number("供应保留库存", 0, 100000000, 0)
	maximum_stock = _number("需求最大库存（0 使用额定容量）", 0, 100000000, 0)
	_button("设置首站当前槽库存限额", _limits)
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
	stack_target = _number("源物流站堆叠数量", 1, 100000000, 1)
	_button("使用施工件调整首站堆叠", func():
		if selected_ids.is_empty(): return
		_notice(StationSystem.new(GameManager.get_game_state(), true).set_stack_target(selected_ids[0], int(stack_target.value))))
	fleet_target = _number("舰队总数目标（包含在途）", 0, 50, 0)
	_button("从便携舰队设置运输机 / 飞船目标", _fleet_target)
	warper_target = _number("自动补充翘曲器目标", 1, 50, 50)
	_button("开启翘曲器自动补充", _set_warper_refill.bind(true))
	_button("停止翘曲器自动补充", _set_warper_refill.bind(false))
	_button("允许跨恒星翘曲", _set_warp_enabled.bind(true))
	_button("禁止跨恒星翘曲", _set_warp_enabled.bind(false))
	route_policy = OptionButton.new()
	for text in ["直接航线", "优先选择高效中继", "必须经中继"]: route_policy.add_item(text)
	content.add_child(route_policy)
	warper_budget = _number("每艘飞船最多翘曲段数", 1, 4, 2)
	_button("设置首站当前槽航线策略", _route_options)
	hub_priority = _number("中继优先级（2 最高）", 0, 2, 1)
	_button("开放首站为跨星中继", _hub.bind(true))
	_button("停止首站作为新航线中继", _hub.bind(false))
	_button("升级首站 Mk.II（需量子科技，无材料成本）", _quantum_action.bind("upgrade"))
	_button("挂接首站量子网络", _quantum_action.bind("attach"))
	_button("取消首站量子挂接", _quantum_action.bind("cancel"))
	_button("挂接全部合格星际站", _quantum_action.bind("all"))
	quantum_capacity = LineEdit.new()
	quantum_capacity.placeholder_text = "量子物品容量：10000～10000000000"
	quantum_capacity.text = "10000000000"
	content.add_child(quantum_capacity)
	_button("设置所选物品的量子容量", _quantum_capacity)
	_button("量子库存 → 行星托盘", _quantum_withdraw)
	_button("采集器：选择当前物品作为产物", _collector_item)
	_button("采集器：切换量子上传", _collector_mode.bind(true))
	_button("采集器：恢复传统物流", _collector_mode.bind(false))
	_button("全部采集器：切换量子上传", _all_collectors.bind(true))
	_button("全部采集器：恢复传统物流", _all_collectors.bind(false))

func open_stations(ids: Array) -> void:
	world_stations.clear()
	var current := GameManager.get_game_state()
	for id in current.buildings:
		var b: Dictionary = current.buildings[id]
		if not b.has("station") or b.get("interaction_locked", false): continue
		world_stations.add_item("%s · %s · %s" % [b.planet_id, DataManager.get_building(b.type).get("name", b.type), id])
		world_stations.set_item_metadata(world_stations.item_count - 1, id)
		if id in ids: world_stations.select(world_stations.item_count - 1)
	selected_ids = ids.duplicate()
	if not ids.is_empty():
		var building: Dictionary = current.buildings[ids[0]]
		stack_target.value = StationSystem.stack_count(building)
		capacity.max_value = 1000 * StationSystem.stack_count(building) if StationSystem.is_source(building.type) else 999
		fleet_target.max_value = StationSystem.fleet_capacity(building, "logistics_drone")
		warper_target.max_value = StationSystem.fleet_capacity(building, "space_warper")
	var state := GameManager.get_game_state()
	var count: int = state.buildings.get(selected_ids[0], {}).get("station", {}).get("slots", []).size() if not selected_ids.is_empty() else 0
	slot_choice.clear()
	for index in range(count): slot_choice.add_item("槽位 %d" % (index + 1))
	slot_index = mini(slot_index, maxi(0, count - 1))
	if count > 0: slot_choice.select(slot_index)
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
	var info := StationSystem.new(GameManager.get_game_state(), true).get_station_info(selected_ids[0])
	if info.is_empty():
		hide()
		return
	var slot: Dictionary = info.slots[slot_index]
	var building: Dictionary = GameManager.get_game_state().buildings[selected_ids[0]]
	capacity.max_value = 2000 if building.type == OrbitalCollectorSystem.TYPE else 1000 if StationSystem.is_source(building.type) else 999
	for i in range(item_choice.item_count):
		if item_choice.get_item_metadata(i) == slot.item_id:
			item_choice.select(i)
	mode_choice.select(["supply", "demand", "storage"].find(StationSystem.mode_for(building, slot, scope_choice.selected == 1)))
	capacity.value = slot.capacity
	minimum.value = slot.min_load
	priority.value = slot.priority
	minimum_stock.value = float(slot.get("min_stock", 0))
	maximum_stock.value = float(slot.get("max_stock", 0))
	route_policy.select(["direct", "relay-preferred", "relay-required"].find(slot.get("route_policy", "relay-preferred")))
	warper_budget.value = int(slot.get("warper_budget", 2))
	hub_priority.value = int(info.get("hub_priority", 1))
	_refresh_status()

func _refresh_status() -> void:
	var state := GameManager.get_game_state()
	if selected_ids.is_empty() or not state.buildings.has(selected_ids[0]):
		hide()
		return
	var info := StationSystem.new(state, true).get_station_info(selected_ids[0])
	var lines: Array[String] = ["选中 %d 站 · 转移仅作用于首站 %s" % [selected_ids.size(), selected_ids[0]]]
	for i in range(info.slots.size()):
		var slot: Dictionary = info.slots[i]
		lines.append("槽 %d：%s  %.1f / %.0f" % [i + 1, DataManager.get_item(slot.item_id).get("name", "空"), slot.amount, slot.capacity])
		if StationSystem.is_source(state.buildings[selected_ids[0]].type): lines.append("本地 %s / 远程 %s · 保留 %.0f · 上限 %.0f" % [slot.local_mode, slot.remote_mode, slot.min_stock, slot.max_stock])
	lines.append("调度：" + ("启用" if info.enabled else "停发"))
	lines.append("停泊运输机 %d / 飞船 %d / 翘曲器 %d" % [info.fleet.logistics_drone, info.fleet.logistics_vessel, info.fleet.space_warper])
	if StationSystem.is_interstellar(state.buildings[selected_ids[0]].type):
		lines.append("跨恒星翘曲：%s · 自动补充：%s · 目标 %d" % ["开启" if info.get("warp_enabled", true) else "关闭", "开启" if info.get("warper_auto_refill", false) else "关闭", int(info.get("warper_target", 50))])
		lines.append("Mk.%d · 量子模式 %s" % [int(info.get("tier", 1)), info.get("quantum_mode", "legacy")])
		lines.append("中继：%s · 优先级 %d" % ["开放" if info.get("hub_enabled", false) else "关闭", int(info.get("hub_priority", 1))])
	var quantum := QuantumLogisticsSystem.new(state).snapshot()
	lines.append("量子网络：%d 塔 · 上传/下载 %.0f 件/分钟\n库存：%s" % [quantum.active_towers, quantum.per_minute, str(quantum.network.inventory)])
	if state.buildings[selected_ids[0]].type == OrbitalCollectorSystem.TYPE: lines.append("采集物品：%s · 量子模式 %s" % [state.buildings[selected_ids[0]].get("collector_item", "hydrogen"), info.get("quantum_mode", "legacy")])
	lines.append(GameManager.get_simulation_engine().logistics_system.diagnostics.get(selected_ids[0], "等待供需匹配"))
	for route in state.logistics_routes.values():
		if route.source_id == selected_ids[0] or route.target_id == selected_ids[0]:
			lines.append("%s → %s：%s %.1f，%s %.1f 秒" % [route.source_id, route.target_id, route.item_id, route.amount, "返航" if route.phase == "returning" else "运输", route.remaining])
			if route.has("waypoint_ids"): lines.append("航程 %.2f 光年 · 每船 %d 翘曲器 · 中继 %s" % [route.distance_ly, route.warpers_per_vessel, ", ".join(route.waypoint_ids)])
	status.text = "\n".join(lines)

func _apply() -> void:
	var result := StationSystem.new(GameManager.get_game_state(), true).configure_slots(selected_ids, slot_index, item_choice.get_selected_metadata(), ["supply", "demand", "storage"][mode_choice.selected], capacity.value, minimum.value, int(priority.value), "remote" if scope_choice.selected == 1 else "local")
	_notice(result)

func _cargo(deposit: bool) -> void:
	if not selected_ids.is_empty():
		_notice(StationSystem.new(GameManager.get_game_state(), true).transfer_cargo(selected_ids[0], slot_index, quantity.value, deposit))

func _fleet(deposit: bool) -> void:
	if not selected_ids.is_empty():
		_notice(StationSystem.new(GameManager.get_game_state(), true).transfer_fleet(selected_ids[0], StationSystem.FLEET_ITEMS[fleet_choice.selected], int(quantity.value), deposit))

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
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_enabled(selected_ids, enabled))

func _set_warper_refill(enabled: bool) -> void:
	if selected_ids.is_empty(): return
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_warper_refill(selected_ids[0], enabled, int(warper_target.value)))

func _set_warp_enabled(enabled: bool) -> void:
	if selected_ids.is_empty(): return
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_warp_enabled(selected_ids[0], enabled))

func _limits() -> void:
	if selected_ids.is_empty(): return
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_slot_limits(selected_ids[0], slot_index, int(minimum_stock.value), int(maximum_stock.value)))

func _route_options() -> void:
	if selected_ids.is_empty(): return
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_route_options(selected_ids[0], slot_index, ["direct", "relay-preferred", "relay-required"][route_policy.selected], int(warper_budget.value)))

func _hub(enabled: bool) -> void:
	if selected_ids.is_empty(): return
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_hub(selected_ids[0], enabled, int(hub_priority.value)))

func _fleet_target() -> void:
	if selected_ids.is_empty() or fleet_choice.selected == 2: return
	_notice(StationSystem.new(GameManager.get_game_state(), true).set_fleet_target(selected_ids[0], StationSystem.FLEET_ITEMS[fleet_choice.selected], int(fleet_target.value)))

func _quantum_action(action: String) -> void:
	if selected_ids.is_empty(): return
	var service := QuantumLogisticsSystem.new(GameManager.get_game_state())
	match action:
		"upgrade": _notice(service.upgrade_station(selected_ids[0]))
		"attach": _notice(service.attach(selected_ids[0]))
		"cancel": _notice(service.cancel(selected_ids[0]))
		"all": _notice(service.attach_all())

func _quantum_capacity() -> void:
	_notice(QuantumLogisticsSystem.new(GameManager.get_game_state()).set_item_capacity(String(item_choice.get_selected_metadata()), quantum_capacity.text.strip_edges()))

func _quantum_withdraw() -> void:
	_notice(QuantumLogisticsSystem.new(GameManager.get_game_state()).withdraw(String(item_choice.get_selected_metadata()), int(quantity.value)))

func _collector_item() -> void:
	if selected_ids.is_empty(): return
	_notice(OrbitalCollectorSystem.new(GameManager.get_game_state()).select_item(selected_ids[0], String(item_choice.get_selected_metadata())))

func _collector_mode(enabled: bool) -> void:
	if selected_ids.is_empty(): return
	_notice(QuantumLogisticsSystem.new(GameManager.get_game_state()).set_collector_mode(selected_ids[0], enabled))

func _all_collectors(enabled: bool) -> void:
	_notice(QuantumLogisticsSystem.new(GameManager.get_game_state()).set_all_collectors(enabled))
