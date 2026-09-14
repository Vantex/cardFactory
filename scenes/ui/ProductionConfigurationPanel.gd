extends VBoxContainer
var selected := ""
var selected_ids: Array = []
var tier: OptionButton
var mode: OptionButton
var fuel: OptionButton
var fuel_ids: Array[String] = []
var message: Label
var runtime_status: Label

func _ready() -> void:
	custom_minimum_size.x = 210
	var label := Label.new()
	label.text = "喷涂与燃料"
	add_child(label)
	tier = OptionButton.new()
	for text in ["一级增产剂", "二级增产剂", "三级增产剂"]: tier.add_item(text)
	add_child(tier)
	mode = OptionButton.new()
	for text in ["普通生产", "生产加速", "额外产物"]: mode.add_item(text)
	add_child(mode)
	_button("安装 / 应用喷涂", func(): _show_result(ProliferatorSystem.new(GameManager.game_state).configure_batch(selected_ids, tier.selected + 1, ["normal", "speed", "extra"][mode.selected])))
	_button("投放 1 件所选增产剂", func(): _supply("proliferator_mk%d" % (tier.selected + 1)))
	_button("拆卸喷涂模块并返还", func(): _show_result(ProliferatorSystem.new(GameManager.game_state).remove(selected)))
	_button("投放当前研究所需材料", func(): _show_result(TechnologySystem.new(GameManager.game_state).supply_source_lab(selected)))
	fuel = OptionButton.new()
	fuel.item_selected.connect(func(index):
		if selected_ids.size() == 1: _show_result(GameManager.game_state.set_fuel_item(selected, fuel_ids[index])))
	add_child(fuel)
	_button("投放 1 件所选燃料", func():
		if not fuel_ids.is_empty(): _supply(fuel_ids[maxi(fuel.selected, 0)]))
	runtime_status = Label.new()
	runtime_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(runtime_status)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func():
		if selected_ids.size() != 1 and text != "安装 / 应用喷涂":
			_show_result({"ok": false, "message": "投料和拆卸时请只选择一台设备"})
			return
		GameManager.game_state.command_history.execute(GameManager.game_state, text, action))
	add_child(button)

func refresh(ids: Array) -> void:
	selected_ids = ids.duplicate()
	visible = not ids.is_empty()
	if not visible: return
	var id := String(ids[0])
	var current: Dictionary = GameManager.game_state.buildings.get(id, {})
	runtime_status.text = "剩余喷涂点：%.1f\n%s" % [current.get("proliferator_points", 0), current.get("automation_status", "")]
	if id == selected: return
	selected = id
	var building: Dictionary = GameManager.game_state.buildings.get(selected, {})
	tier.select(maxi(int(building.get("proliferator_tier", 1)) - 1, 0))
	mode.select(maxi(["normal", "speed", "extra"].find(building.get("proliferator_mode", "normal")), 0))
	fuel.clear()
	fuel_ids.clear()
	for item in DataManager.get_building(String(building.get("type", ""))).get("fuel_options", {}):
		fuel_ids.append(item)
		fuel.add_item(DataManager.get_item(item).get("name", item))
	if not fuel_ids.is_empty(): fuel.select(maxi(fuel_ids.find(building.get("fuel_item", "")), 0))
	fuel.disabled = fuel_ids.is_empty()
	message.text = ""

func _supply(item: String) -> void:
	var building: Dictionary = GameManager.game_state.buildings.get(selected, {})
	if selected_ids.size() != 1 or building.is_empty() or building.get("interaction_locked", false): return
	var capacity := float(DataManager.get_building(building.type).get("input_buffer_capacity", 60))
	var buffer: Dictionary = building.get("input_buffer", {})
	if float(buffer.get(item, 0)) + 1 > capacity:
		_show_result({"ok": false, "message": "输入缓存已满"})
		return
	var result := InventorySystem.new(GameManager.game_state).try_remove(item, 1, String(building.planet_id))
	if result.ok:
		buffer[item] = float(buffer.get(item, 0)) + 1
		building.input_buffer = buffer
	_show_result(result)

func _show_result(result: Dictionary) -> void:
	message.text = result.get("message", "")
	EventBus.notice_requested.emit(message.text, "success" if result.ok else "error")
