class_name LocalSpaceStationWorkspace
extends PanelContainer

var _summary: Label
var _item: OptionButton
var _quantity: SpinBox
var _start: Button
var _deliver: Button
var _feedback: Label
var _signature := ""
var _contracts: Label
var _contract_choice: OptionButton
var _contract_item: OptionButton
var _contract_signature := ""
var _refresh_elapsed := 0.0
var _terminal_choice: OptionButton
var _terminal_summary: Label
var _terminal_signature := ""
var _terminal_port: SpinBox
var _clear_confirmation: ConfirmationDialog
var _clear_target := ""
var _clear_index := 0
var _history_choice: OptionButton
var _history_summary: Label
var _history_signature := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "本地轨道空间站"
	content.add_child(heading)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(hide)
	content.add_child(close)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_summary)
	_start = Button.new()
	_start.text = "开始建设空间站核心"
	_start.pressed.connect(func(): _show_result(_system().start()))
	content.add_child(_start)
	_item = OptionButton.new()
	_item.name = "MaterialChoice"
	content.add_child(_item)
	_quantity = SpinBox.new()
	_quantity.name = "DeliveryAmount"
	_quantity.min_value = 1
	_quantity.max_value = 999
	_quantity.step = 1
	_quantity.value = 1
	content.add_child(_quantity)
	_deliver = Button.new()
	_deliver.text = "从当前行星托盘交付"
	_deliver.pressed.connect(_deliver_selected)
	content.add_child(_deliver)
	var quantum_construction := Button.new()
	quantum_construction.text = "确认从量子库存交付建设材料"
	quantum_construction.pressed.connect(func():
		if _item.selected >= 0: _show_result(_system().deliver_quantum(String(_item.get_item_metadata(_item.selected)), int(_quantity.value))))
	content.add_child(quantum_construction)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_feedback)
	var contract_heading := Label.new()
	contract_heading.text = "本地合同板 · 北京时间每日刷新，最多接受 3 份"
	content.add_child(contract_heading)
	_contracts = Label.new()
	_contracts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_contracts)
	_contract_choice = OptionButton.new()
	_contract_choice.name = "ContractChoice"
	_contract_choice.item_selected.connect(func(_index: int): _refresh_contract_materials())
	content.add_child(_contract_choice)
	_contract_item = OptionButton.new()
	_contract_item.name = "ContractMaterial"
	content.add_child(_contract_item)
	var accept := Button.new()
	accept.text = "接受选中报价"
	accept.pressed.connect(func(): _contract_result(StationContractSystem.new(GameManager.get_game_state()).accept(_selected_contract())))
	content.add_child(accept)
	var deliver_contract := Button.new()
	deliver_contract.text = "从当前行星托盘交付合同物资"
	deliver_contract.pressed.connect(_deliver_contract)
	content.add_child(deliver_contract)
	var quantum_contract := Button.new()
	quantum_contract.text = "确认从量子库存交付合同物资"
	quantum_contract.pressed.connect(func():
		if _contract_item.selected >= 0: _contract_result(StationContractSystem.new(GameManager.get_game_state()).deliver_quantum(_selected_contract(), String(_contract_item.get_item_metadata(_contract_item.selected)), int(_quantity.value))))
	content.add_child(quantum_contract)
	var claim := Button.new()
	claim.text = "领取已完成合同奖励"
	claim.pressed.connect(func(): _contract_result(StationContractSystem.new(GameManager.get_game_state()).claim(_selected_contract())))
	content.add_child(claim)
	var abandon := Button.new()
	abandon.text = "放弃选中合同并结算已有进度"
	abandon.pressed.connect(func(): _contract_result(StationContractSystem.new(GameManager.get_game_state()).abandon(_selected_contract())))
	content.add_child(abandon)
	_history_summary = Label.new()
	_history_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_history_summary)
	_history_choice = OptionButton.new()
	_history_choice.name = "ContractHistory"
	content.add_child(_history_choice)
	var feature := Button.new()
	feature.text = "展示选中已完成合同"
	feature.pressed.connect(func():
		if _history_choice.selected >= 0: _contract_result(StationContractSystem.new(GameManager.get_game_state()).set_featured(String(_history_choice.get_item_metadata(_history_choice.selected)))))
	content.add_child(feature)
	var clear_feature := Button.new()
	clear_feature.text = "取消精选合同展示"
	clear_feature.pressed.connect(func(): _contract_result(StationContractSystem.new(GameManager.get_game_state()).set_featured("")))
	content.add_child(clear_feature)
	var presentation := StationPresentationPanel.new()
	presentation.name = "StationPresentation"
	content.add_child(presentation)
	_terminal_summary = Label.new()
	_terminal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_terminal_summary)
	_terminal_choice = OptionButton.new()
	_terminal_choice.name = "OrbitalCargoTerminal"
	_terminal_choice.item_selected.connect(func(_index): _refresh_terminals())
	content.add_child(_terminal_choice)
	for pair in [["货运终端 → 当前建设阶段", "construction"], ["货运终端 → 选中已接受合同", "contract"], ["停止终端自动交付（保留缓存）", ""]]:
		var binding_button := Button.new()
		binding_button.text = pair[0]
		binding_button.pressed.connect(_bind_terminal.bind(pair[1]))
		content.add_child(binding_button)
	_terminal_port = SpinBox.new()
	_terminal_port.min_value = 1
	_terminal_port.max_value = 4
	_terminal_port.step = 1
	content.add_child(_terminal_port)
	var clear_port := Button.new()
	clear_port.text = "清空所选终端端口，退回线路和缓存"
	clear_port.pressed.connect(_request_clear_port)
	content.add_child(clear_port)
	_clear_confirmation = ConfirmationDialog.new()
	_clear_confirmation.title = "确认清空轨道货运端口"
	_clear_confirmation.confirmed.connect(func(): _show_result(OrbitalCargoTerminalSystem.new(GameManager.get_game_state()).clear_port(_clear_target, _clear_index, true)))
	add_child(_clear_confirmation)
	visibility_changed.connect(func():
		if visible: refresh()
		else: _clear_confirmation.hide())
	GameManager.game_state_replaced.connect(func(_state: GameState):
		_signature = ""
		_clear_target = ""
		_clear_confirmation.hide()
		hide())
	refresh()

func _system() -> LocalSpaceStationSystem:
	return LocalSpaceStationSystem.new(GameManager.get_game_state())

func refresh() -> void:
	var snapshot := _system().snapshot()
	var stage := String(snapshot.stage)
	var labels := {"locked": "未解锁", "eligible": "可建设", "core": "建设核心", "dock": "建设船坞", "showcase": "建设展示区", "operational": "已建成"}
	_summary.text = "阶段：%s\n每档仅有一座空间站；标准存档累计生产 1 个宇宙矩阵后解锁。\n交付材料不退还，可分批完成。" % labels.get(stage, stage)
	_start.visible = stage == "eligible"
	var remaining: Dictionary = snapshot.remaining
	for item in remaining:
		_summary.text += "\n%s：尚需 %d" % [DataManager.get_item(item).get("name", item), int(remaining[item])]
	var keys := remaining.keys()
	keys.sort()
	var signature := JSON.stringify(keys)
	if signature != _signature:
		_item.clear()
		for item in keys:
			_item.add_item(String(DataManager.get_item(item).get("name", item)))
			_item.set_item_metadata(_item.item_count - 1, item)
		_signature = signature
	_item.visible = not keys.is_empty()
	_quantity.visible = not keys.is_empty() or stage in ["showcase", "operational"]
	_deliver.visible = not keys.is_empty()
	_deliver.disabled = keys.is_empty() or stage == "eligible"
	_refresh_contracts()
	_refresh_terminals()

func _terminal_id() -> String:
	return String(_terminal_choice.get_item_metadata(_terminal_choice.selected)) if _terminal_choice != null and _terminal_choice.selected >= 0 else ""

func _refresh_terminals() -> void:
	if _terminal_choice == null: return
	var state := GameManager.get_game_state()
	var ids := []
	for building in state.buildings.values():
		if building.type == OrbitalCargoTerminalSystem.TYPE and building.planet_id == state.active_planet_id: ids.append(building.id)
	ids.sort()
	var signature := JSON.stringify(ids)
	if signature != _terminal_signature:
		var previous := _terminal_id()
		_terminal_choice.clear()
		for id in ids:
			_terminal_choice.add_item("轨道货运终端 " + id)
			_terminal_choice.set_item_metadata(_terminal_choice.item_count - 1, id)
			if id == previous: _terminal_choice.select(_terminal_choice.item_count - 1)
		_terminal_signature = signature
	var building: Dictionary = state.buildings.get(_terminal_id(), {})
	_terminal_summary.text = "轨道货运终端：四端口共享 20000 件/分钟上传能力，按端口轮转分配；自动交付遵守来源行星限制。"
	if building.is_empty():
		_terminal_summary.text += "\n当前行星没有货运终端。"
		return
	var target := "已停止自动交付"
	if building.orbital_cargo_binding.get("kind") == "construction": target = "当前空间站建设阶段"
	elif building.orbital_cargo_binding.get("kind") == "contract": target = "已接受合同"
	var buffer := []
	for item in building.input_buffer:
		if float(building.input_buffer[item]) > 0: buffer.append("%s ×%.2f" % [DataManager.get_item(item).get("name", item), float(building.input_buffer[item])])
	_terminal_summary.text += "\n目标：%s · 累计上传 %s 件\n缓存：%s" % [target, building.orbital_cargo_total, "、".join(buffer) if not buffer.is_empty() else "空"]
	for index in range(4): _terminal_summary.text += "\n端口 %d：%s" % [index + 1, DataManager.get_item(building.orbital_cargo_ports[index]).get("name", "空")]

func _bind_terminal(kind: String) -> void:
	var binding := {"kind": kind} if not kind.is_empty() else {}
	if kind == "contract": binding["contract_id"] = _selected_contract()
	_show_result(OrbitalCargoTerminalSystem.new(GameManager.get_game_state()).bind_target(_terminal_id(), binding))

func _request_clear_port() -> void:
	_clear_target = _terminal_id()
	_clear_index = int(_terminal_port.value) - 1
	var check := OrbitalCargoTerminalSystem.new(GameManager.get_game_state()).clear_check(_clear_target, _clear_index)
	if not check.ok:
		_show_result(check)
	elif check.requires_confirmation:
		_clear_confirmation.dialog_text = check.message
		_clear_confirmation.popup_centered()
	else: _show_result(OrbitalCargoTerminalSystem.new(GameManager.get_game_state()).clear_port(_clear_target, _clear_index))

func _refresh_contracts() -> void:
	var snapshot := StationContractSystem.new(GameManager.get_game_state()).snapshot()
	if not snapshot.unlocked:
		_contracts.text = "船坞完成后解锁本地合同。"
		_contract_choice.hide()
		_contract_item.hide()
		return
	_contract_choice.show()
	_contract_item.show()
	var board: Dictionary = snapshot.board
	_contracts.text = "轨道印记 %s · 声望 %s · 已完成 %d · 进行中 %d/%d" % [StationContractSystem.economy_text(board.marks), StationContractSystem.economy_text(board.reputation), int(board.completed), board.accepted.size(), StationContractSystem.ACCEPT_LIMIT]
	_refresh_history(board)
	var rows := []
	for contract in board.offers + board.accepted:
		var remaining := []
		for requirement in contract.requirements:
			var origin_names := []
			for origin in requirement.source_planet_ids: origin_names.append(GalaxySystem.new(GameManager.get_game_state()).get_planet(origin).name)
			remaining.append("%s %d/%d · %s %s" % [DataManager.get_item(requirement.item).get("name", requirement.item), int(requirement.delivered), int(requirement.amount), "仅量子" if requirement.channel == "quantum" else "指定来源" if not origin_names.is_empty() else "任意来源", "、".join(origin_names)])
		rows.append({"id": contract.id, "label": "%s · %s · %s" % ["可接" if contract.status == "offered" else "待领" if contract.status == "claimable" else "进行中", contract.difficulty, "、".join(remaining)]})
	var signature := JSON.stringify(rows)
	if signature != _contract_signature:
		var previous := _selected_contract()
		_contract_choice.clear()
		for row in rows:
			_contract_choice.add_item(row.label)
			_contract_choice.set_item_metadata(_contract_choice.item_count - 1, row.id)
			if row.id == previous: _contract_choice.select(_contract_choice.item_count - 1)
		_contract_signature = signature
		_refresh_contract_materials()

func _selected_contract() -> String:
	return String(_contract_choice.get_item_metadata(_contract_choice.selected)) if _contract_choice.selected >= 0 else ""

func _refresh_contract_materials() -> void:
	if _contract_item == null: return
	var previous := String(_contract_item.get_item_metadata(_contract_item.selected)) if _contract_item.selected >= 0 else ""
	_contract_item.clear()
	var board: Dictionary = StationContractSystem.new(GameManager.get_game_state()).snapshot().board
	for contract in board.accepted:
		if contract.id != _selected_contract(): continue
		for requirement in contract.requirements:
			_contract_item.add_item(String(DataManager.get_item(requirement.item).get("name", requirement.item)))
			_contract_item.set_item_metadata(_contract_item.item_count - 1, requirement.item)
			if requirement.item == previous: _contract_item.select(_contract_item.item_count - 1)

func _deliver_contract() -> void:
	if _contract_item.selected < 0: return
	_contract_result(StationContractSystem.new(GameManager.get_game_state()).deliver(_selected_contract(), String(_contract_item.get_item_metadata(_contract_item.selected)), int(_quantity.value)))

func _contract_result(result: Dictionary) -> void:
	_feedback.text = String(result.get("message", "操作失败"))
	refresh()

func _deliver_selected() -> void:
	if _item.selected < 0: return
	var item_id := String(_item.get_item_metadata(_item.selected))
	_show_result(_system().deliver(item_id, int(_quantity.value)))

func _show_result(result: Dictionary) -> void:
	_feedback.text = String(result.get("message", "操作失败"))
	refresh()

func _process(delta: float) -> void:
	if not visible: return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0
		refresh()

func _refresh_history(board: Dictionary) -> void:
	_history_summary.text = "历史合同（最近 %d 份） · 精选：%s" % [board.history.size(), board.get("featured_id", "") if board.get("featured_id", "") != "" else "未选择"]
	var signature := JSON.stringify(board.history)
	if signature == _history_signature: return
	var previous := String(_history_choice.get_item_metadata(_history_choice.selected)) if _history_choice.selected >= 0 else ""
	_history_choice.clear()
	for contract in board.history:
		_history_choice.add_item("%s · %s · 完成 %.2f%%" % [contract.difficulty, {"completed": "已完成", "expired": "已到期", "abandoned": "已放弃"}.get(contract.get("settlement_reason"), "已结算"), float(contract.get("completion_basis_points", 0)) / 100.0])
		_history_choice.set_item_metadata(_history_choice.item_count - 1, contract.id)
		if contract.id == previous: _history_choice.select(_history_choice.item_count - 1)
	_history_signature = signature
