extends VBoxContainer
var selected_ids: Array = []
var grid: OptionButton
var use_priority: OptionButton
var generation: OptionButton
var mode: OptionButton
var status: Label
var updating := false
func _ready() -> void:
	custom_minimum_size = Vector2(210, 0)
	grid = _choice("电网", ["A 网", "B 网", "C 网"], "power_grid_id")
	use_priority = _choice("用电优先级", ["1 · 低", "2 · 普通", "3 · 高"], "power_priority")
	generation = _choice("发电优先级", ["1 · 低", "2 · 普通", "3 · 高"], "generation_priority")
	mode = _choice("能量枢纽", ["充电", "放电", "停用"], "energy_mode")
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
func _choice(title: String, options: Array, key: String) -> OptionButton:
	var label := Label.new()
	label.text = title
	add_child(label)
	var choice := OptionButton.new()
	choice.name = key
	for text in options: choice.add_item(text)
	choice.item_selected.connect(func(index: int):
		if updating: return
		var value: Variant = ["grid-a", "grid-b", "grid-c"][index] if key == "power_grid_id" else ["charge", "discharge", "idle"][index] if key == "energy_mode" else index + 1
		var result := GameManager.game_state.try_configure_power_entities(selected_ids, {key: value})
		EventBus.notice_requested.emit(result.message, "success" if result.ok else "error")
		refresh(selected_ids))
	add_child(choice)
	return choice
func refresh(ids: Array) -> void:
	selected_ids = ids.duplicate()
	visible = not selected_ids.is_empty()
	if not visible or grid == null: return
	var state := GameManager.game_state
	var building: Dictionary = state.buildings.get(selected_ids[0], {})
	if building.is_empty(): hide(); return
	updating = true
	grid.select(["grid-a", "grid-b", "grid-c"].find(PowerGridSystem.grid_id(building)))
	use_priority.select(int(building.get("power_priority", 2)) - 1)
	generation.select(PowerGridSystem.generation_priority(building) - 1)
	mode.select(["charge", "discharge", "idle"].find(String(building.get("energy_mode", "charge"))))
	mode.disabled = selected_ids.any(func(id): return state.buildings[id].get("type") != "energy_exchanger")
	var info := GameManager.simulation_engine.power_system.get_grid_info(String(building.get("planet_id", "home")), PowerGridSystem.grid_id(building))
	status.text = "选中 %d 台 · 配置应用到全部\n%s\n获得 %.1f / 需求 %.1f kW\n本机储能 %.3f MJ\n电网充电 %.1f / 放电 %.1f kW" % [selected_ids.size(), "已接入电网" if building.get("power_covered", false) else "电网无电源", building.get("power_input", 0), building.get("power_requested", 0), building.get("stored_energy_mj", 0), info.get("storage_charge", 0), info.get("storage_discharge", 0)]
	if float(building.get("power_efficiency", 1)) < 1: status.text += "\n供电不足：检查优先级、燃料和电网"
	updating = false
