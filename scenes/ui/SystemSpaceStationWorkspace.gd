class_name SystemSpaceStationWorkspace
extends PanelContainer

var content: VBoxContainer
var systems: OptionButton
var materials: OptionButton
var amount: SpinBox
var modules: OptionButton
var module_count: SpinBox
var summary: Label
var feedback: Label
var elapsed := 0.0
var elevator_station: OptionButton
var output_item: OptionButton
var output_port: SpinBox
var first_confirmation: ConfirmationDialog
var second_confirmation: ConfirmationDialog
var pending_output := {}
var policy_reserve: LineEdit
var policy_target: LineEdit
var policy_enabled: CheckBox

func model() -> SystemSpaceStationSystem: return SystemSpaceStationSystem.new(GameManager.get_game_state())
func selected() -> String: return String(systems.get_item_metadata(systems.selected)) if systems.selected >= 0 else ""

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	label("恒星系空间站 · 四阶段建设")
	button("关闭", hide)
	systems = OptionButton.new()
	systems.name = "SystemChoice"
	content.add_child(systems)
	systems.item_selected.connect(func(_index): refresh())
	summary = label("")
	button("开始建设并锁定研究折扣", func(): action(model().start(selected())))
	materials = OptionButton.new()
	materials.name = "ConstructionMaterial"
	content.add_child(materials)
	var seen := {}
	for phase in SystemSpaceStationSystem.PHASES:
		if seen.has(phase[1]): continue
		seen[phase[1]] = true
		materials.add_item(DataManager.get_item(phase[1]).get("name", phase[1]))
		materials.set_item_metadata(materials.item_count - 1, phase[1])
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 999
	amount.value = 1
	content.add_child(amount)
	button("从当前行星托盘交付", func(): action(model().deliver(selected(), String(materials.get_item_metadata(materials.selected)), int(amount.value))))
	label("施工平台需接入电网，通过四种物料输入自动交付。每颗行星最多一座；未使用材料留在工程缓存。")
	modules = OptionButton.new()
	content.add_child(modules)
	for pair in [["骨干模块", "backbone"], ["能源模块", "energy"], ["星际模块", "interstellar"]]:
		modules.add_item(pair[0])
		modules.set_item_metadata(modules.item_count - 1, pair[1])
	label("模块目标数量（每十个成本翻倍，拆回返还一半）")
	module_count = SpinBox.new()
	module_count.max_value = 1000000
	content.add_child(module_count)
	button("使用空间站库存调整模块", func(): action(model().set_module_count(selected(), String(modules.get_item_metadata(modules.selected)), int(module_count.value))))
	label("太空电梯 · 当前行星 Mk.II 星际站")
	elevator_station = OptionButton.new()
	elevator_station.name = "ElevatorStation"
	content.add_child(elevator_station)
	button("升级本系全部合格星际站为 Mk.II", func(): action(QuantumLogisticsSystem.new(GameManager.get_game_state()).upgrade_all(selected())))
	button("升级所选站为 Mk.II", func(): action(QuantumLogisticsSystem.new(GameManager.get_game_state()).upgrade_station(elevator_id())))
	button("切换为太空电梯", func(): action(SystemHubLogisticsSystem.new(GameManager.get_game_state()).request_mode(elevator_id(), "elevator")))
	button("切回传统物流", func(): action(SystemHubLogisticsSystem.new(GameManager.get_game_state()).request_mode(elevator_id(), "legacy")))
	output_port = SpinBox.new()
	output_port.min_value = 1
	output_port.max_value = 5
	output_port.value = 1
	label("输出口编号")
	content.add_child(output_port)
	output_item = OptionButton.new()
	content.add_child(output_item)
	output_item.add_item("空输出口")
	output_item.set_item_metadata(0, "")
	for item in DataManager.all_items:
		output_item.add_item(DataManager.get_item(item).get("name", item))
		output_item.set_item_metadata(output_item.item_count - 1, item)
	button("配置输出口（两次确认并退回原线路）", request_output)
	first_confirmation = ConfirmationDialog.new()
	first_confirmation.dialog_text = "更换输出口会拆除该口现有线路并退回施工件，缓存物资保留。继续？"
	add_child(first_confirmation)
	second_confirmation = ConfirmationDialog.new()
	second_confirmation.dialog_text = "再次确认：执行所选输出口的物品变更并拆回原线路？"
	add_child(second_confirmation)
	first_confirmation.confirmed.connect(func(): second_confirmation.popup_centered())
	second_confirmation.confirmed.connect(func():
		if not pending_output.is_empty(): action(SystemHubLogisticsSystem.new(GameManager.get_game_state()).set_output(pending_output.id, pending_output.port, pending_output.item, 2))
		pending_output = {})
	label("跨恒星系物流 · 使用上方所选物品设置当前恒星系策略")
	label("保留库存：高于此数量的库存可供给其他恒星系")
	policy_reserve = LineEdit.new()
	policy_reserve.name = "HubReserve"
	policy_reserve.placeholder_text = "保留库存（非负整数，最多 256 位）"
	policy_reserve.text = "0"
	policy_reserve.max_length = 256
	content.add_child(policy_reserve)
	label("需求目标：低于此数量时请求其他恒星系供货")
	policy_target = LineEdit.new()
	policy_target.name = "HubTarget"
	policy_target.placeholder_text = "需求目标（非负整数，最多 256 位）"
	policy_target.text = "0"
	policy_target.max_length = 256
	content.add_child(policy_target)
	policy_enabled = CheckBox.new()
	policy_enabled.text = "启用该物品的跨系供需"
	content.add_child(policy_enabled)
	button("读取所选物品策略", read_policy)
	button("保存跨系供需策略", func(): action(SystemHubLogisticsSystem.new(GameManager.get_game_state()).set_policy(selected(), String(output_item.get_item_metadata(output_item.selected)), policy_reserve.text, policy_target.text, policy_enabled.button_pressed)))
	button("按交付数量装入全局翘曲器", func(): action(SystemHubLogisticsSystem.new(GameManager.get_game_state()).load_warpers(int(amount.value))))
	label("需要统一恒星系物流协议。船只来自电梯站，运输占用期间不能拆除；每艘往返消耗两枚翘曲器。")
	feedback = label("")
	visibility_changed.connect(func():
		if visible: refresh_systems()
		else:
			first_confirmation.hide()
			second_confirmation.hide()
			pending_output = {})
	GameManager.game_state_replaced.connect(func(_state): hide())
	refresh_systems()

func label(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(node)
	return node

func button(text: String, callback: Callable) -> void:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	content.add_child(node)

func action(outcome: Dictionary) -> void:
	feedback.text = outcome.message
	refresh()

func refresh_systems() -> void:
	var previous := selected()
	systems.clear()
	var state := GameManager.get_game_state()
	var previous_station := elevator_id()
	elevator_station.clear()
	for id in state.buildings:
		var building: Dictionary = state.buildings[id]
		if building.type != SystemHubLogisticsSystem.STATION_TYPE or building.planet_id != state.active_planet_id: continue
		elevator_station.add_item("星际站 " + id)
		elevator_station.set_item_metadata(elevator_station.item_count - 1, id)
		if id == previous_station: elevator_station.select(elevator_station.item_count - 1)
	for id in state.explored_system_ids:
		systems.add_item(GalaxySystem.new(state).get_star_system(id).get("name", id))
		systems.set_item_metadata(systems.item_count - 1, id)
		if id == previous: systems.select(systems.item_count - 1)
	refresh()

func refresh() -> void:
	if selected().is_empty(): return
	var station := model().snapshot(selected())
	var lines := PackedStringArray()
	lines.append("状态：%s · 建设成本 %.0f%% · 阶段 %d / 4" % [{"not-started": "未开工", "building": "建设中", "operational": "运行中"}[station.status], float(station.cost_multiplier_basis_points) / 100, int(station.phase_index) / 4])
	if station.status != "operational":
		var rows := SystemSpaceStationSystem.requirements(int(station.cost_multiplier_basis_points))
		for index in range(int(station.phase_index), mini(int(station.phase_index) + 4, rows.size())):
			var row: Dictionary = rows[index]
			lines.append("%s · %s：%s / %s（工程缓存 %s）" % [row.name, DataManager.get_item(row.item_id).get("name", row.item_id), station.delivered.get(row.item_id, "0"), row.required, station.construction_buffer.get(row.item_id, "0")])
	lines.append("模块：骨干 %d · 能源 %d · 星际 %d" % [station.modules.backbone, station.modules.energy, station.modules.interstellar])
	var elevator: Dictionary = GameManager.get_game_state().buildings.get(elevator_id(), {})
	if not elevator.is_empty():
		var config: Dictionary = elevator.station
		lines.append("所选站：%s%s" % ["太空电梯" if config.get("operation_mode") == "elevator" else "传统物流", " · 等待关联航线完成" if config.has("mode_transition") else ""])
		var ports := PackedStringArray()
		for item in config.get("elevator_output_items", []): ports.append(DataManager.get_item(item).get("name", "空"))
		if not ports.is_empty(): lines.append("五个输出口：" + " / ".join(ports))
	for item in station.inventory:
		if station.inventory[item] != "0": lines.append("共享库存 %s：%s" % [DataManager.get_item(item).get("name", item), station.inventory[item]])
	var network: Dictionary = GameManager.get_game_state().galactic_hub_network
	lines.append("枢纽舰队 %d · 在途 %d · 翘曲器 %s" % [network.get("fleet_installed", 0), network.get("fleet_busy", 0), network.get("warpers", "0")])
	summary.text = "\n".join(lines)

func _process(delta: float) -> void:
	if not visible: return
	elapsed += delta
	if elapsed >= 0.5:
		elapsed = 0
		refresh()

func elevator_id() -> String:
	return String(elevator_station.get_item_metadata(elevator_station.selected)) if elevator_station != null and elevator_station.selected >= 0 else ""

func request_output() -> void:
	pending_output = {"id": elevator_id(), "port": int(output_port.value) - 1, "item": String(output_item.get_item_metadata(output_item.selected))}
	first_confirmation.popup_centered()

func read_policy() -> void:
	var item := String(output_item.get_item_metadata(output_item.selected))
	var policy: Dictionary = model().snapshot(selected()).item_policies.get(item, {})
	policy_reserve.text = policy.get("reserve", "0")
	policy_target.text = policy.get("target", "0")
	policy_enabled.button_pressed = policy.get("interstellar_enabled", false)
