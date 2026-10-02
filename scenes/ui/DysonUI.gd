extends PanelContainer

var content: VBoxContainer
var system_choice: OptionButton
var orbit_choice: OptionButton
var layer_choice: OptionButton
var launcher_choice: OptionButton
var radius: SpinBox
var inclination: SpinBox
var longitude: SpinBox
var angle: SpinBox
var quantity: SpinBox
var status: Label
var summary: Label
var preview: Control
var refresh_time := 0.0
var node_source: OptionButton
var node_target: OptionButton
var launch_mode: OptionButton
var launch_throttle: OptionButton
var standard_count: SpinBox
var layer_clipboard: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.active_planet_changed.connect(func(_id: String): hide())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_label("戴森工程 · 轨道与结构规划")
	_button("关闭", hide)
	status = _label("规划不消耗材料；发射设备需要供电和真实耗材。")
	summary = _label("")
	_label("俯视规划示意 · 青色轨道 / 黄色待建节点 / 绿色完成结构")
	preview = Control.new()
	preview.custom_minimum_size = Vector2(200, 180)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(_draw_plan)
	content.add_child(preview)
	system_choice = _choice("恒星系")
	system_choice.item_selected.connect(func(_i: int): _refresh_plans())
	orbit_choice = _choice("太阳帆轨道")
	layer_choice = _choice("戴森层")
	radius = _number("半径", 5000, 50000, 10000)
	inclination = _number("倾角（度）", -90, 90, 0)
	longitude = _number("升交点经度（度）", 0, 359, 0)
	_button("创建太阳帆轨道", func(): _result(_model().create_orbit(_selected(system_choice), radius.value, inclination.value, longitude.value)))
	_button("创建层并关联所选轨道", func(): _result(_model().create_layer(_selected(system_choice), _selected(orbit_choice), radius.value, inclination.value, longitude.value)))
	angle = _number("节点角度（度）", 0, 359, 0)
	_button("添加结构节点", func(): _result(_model().add_node(_selected(system_choice), _selected(layer_choice), angle.value)))
	_button("规划壳面（至少三个节点）", func(): _result(_model().plan_shell(_selected(system_choice), _selected(layer_choice))))
	_button("删除空轨道", func(): _result(_model().remove_plan(_selected(system_choice), _selected(orbit_choice), "orbits")))
	_button("删除空层", func(): _result(_model().remove_plan(_selected(system_choice), _selected(layer_choice), "layers")))
	_label("源戴森工程 · 框架与壳面")
	standard_count = _number("标准壳层节点数", 3, 16, 8)
	_button("创建标准壳层", func(): _result(_source().standard_layer(_selected(system_choice), _selected(orbit_choice), int(standard_count.value))))
	node_source = _choice("起点节点")
	node_target = _choice("终点 / 删除节点")
	layer_choice.item_selected.connect(func(_i: int): _refresh_nodes())
	_button("连接所选节点", func(): _result(_source().connect_nodes(_selected(system_choice), _selected(layer_choice), _selected(node_source), _selected(node_target))))
	_button("自动连接相邻节点", func(): _result(_source().auto_connect(_selected(system_choice), _selected(layer_choice))))
	_button("删除所选节点及相连框架", func(): _result(_source().remove_node(_selected(system_choice), _selected(layer_choice), _selected(node_target))))
	_button("清空壳面规划", func(): _result(_source().clear_shells(_selected(system_choice), _selected(layer_choice))))
	_button("应用几何到所选层", func(): _result(_source().set_geometry(_selected(system_choice), _selected(layer_choice), "layers", radius.value, inclination.value, longitude.value)))
	_button("应用几何到所选轨道", func(): _result(_source().set_geometry(_selected(system_choice), _selected(orbit_choice), "orbits", radius.value, inclination.value, longitude.value)))
	_button("复制所选壳层模板", func():
		layer_clipboard = _source().copy_template(_selected(system_choice), _selected(layer_choice))
		status.text = "壳层模板已复制" if not layer_clipboard.is_empty() else "请选择源戴森层")
	_button("粘贴壳层模板", func(): _result(_source().paste_template(_selected(system_choice), _selected(orbit_choice), layer_clipboard)))
	launch_mode = _choice("全局发射模式")
	for mode in [["balanced", "均衡"], ["swarm", "太阳帆"], ["sphere", "结构火箭"]]:
		launch_mode.add_item(mode[1])
		launch_mode.set_item_metadata(launch_mode.item_count - 1, mode[0])
	launch_throttle = _choice("全局发射节流")
	for throttle in [0.25, 0.5, 0.75, 1.0]:
		launch_throttle.add_item("%.0f%%" % (throttle * 100))
		launch_throttle.set_item_metadata(launch_throttle.item_count - 1, throttle)
	launch_throttle.select(3)
	_button("应用并启用全局发射计划", func(): _result(_source().configure_schedule(_selected(launch_mode), float(launch_throttle.get_item_metadata(launch_throttle.selected)), true)))
	_button("暂停全局发射计划", func(): _result(_source().configure_schedule(_selected(launch_mode), float(launch_throttle.get_item_metadata(launch_throttle.selected)), false)))
	launcher_choice = _choice("当前行星发射设备")
	_button("绑定所选轨道 / 层并启动", _configure.bind(true, false))
	_button("停止发射", _configure.bind(false, false))
	_button("解除目标", _configure.bind(false, true))
	quantity = _number("装载耗材数量", 1, 60, 1)
	_button("从当前行星托盘装载", func(): _result(_model().load_ammo(_selected(launcher_choice), int(quantity.value))))
	visibility_changed.connect(func():
		if visible: refresh())
	refresh()

func _source() -> SourceDysonEngineering:
	return SourceDysonEngineering.new(GameManager.get_game_state())

func _model() -> DysonSphereSystem:
	return DysonSphereSystem.new(GameManager.get_game_state())

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	content.add_child(button)

func _choice(text: String) -> OptionButton:
	_label(text)
	var choice := OptionButton.new()
	content.add_child(choice)
	return choice

func _number(text: String, minimum: float, maximum: float, initial: float) -> SpinBox:
	_label(text)
	var value := SpinBox.new()
	value.min_value = minimum
	value.max_value = maximum
	value.value = initial
	content.add_child(value)
	return value

func _selected(choice: OptionButton) -> String:
	return String(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else ""

func _fill(choice: OptionButton, entries: Dictionary) -> void:
	var previous := _selected(choice)
	choice.clear()
	for id in entries:
		choice.add_item(String(entries[id]))
		choice.set_item_metadata(choice.item_count - 1, id)
		if id == previous: choice.select(choice.item_count - 1)

func refresh() -> void:
	var state := GameManager.get_game_state()
	var entries := {}
	for id in state.explored_system_ids:
		entries[id] = GalaxySystem.new(state).get_star_system(id).get("name", id)
	_fill(system_choice, entries)
	entries = {}
	for id in state.buildings:
		var building: Dictionary = state.buildings[id]
		if building.type in DysonSphereSystem.AMMO and building.planet_id == state.active_planet_id:
			entries[id] = "%s · %s" % [DataManager.get_building(building.type).get("name", building.type), id]
	_fill(launcher_choice, entries)
	_refresh_plans()

func _refresh_plans() -> void:
	var system := _model().get_system(_selected(system_choice))
	var entries := {}
	for id in system.get("orbits", {}):
		var orbit: Dictionary = system.orbits[id]
		entries[id] = "%s · R %d · 倾角 %d°" % [id, orbit.radius, orbit.inclination]
	_fill(orbit_choice, entries)
	entries = {}
	for id in system.get("layers", {}):
		var layer: Dictionary = system.layers[id]
		entries[id] = "%s · %d 节点 · 壳面 %d 帆" % [id, layer.nodes.size(), layer.shell.get("sails", 0)]
	_fill(layer_choice, entries)
	_refresh_nodes()
	_update_summary()

func _refresh_nodes() -> void:
	if node_source == null: return
	var layer := _source().layer_for(_selected(system_choice), _selected(layer_choice))
	var entries := {}
	for node in layer.get("nodes", {}).values(): entries[node.id] = "%s · %.1f° · %d/%d" % [node.id, node.angle, node.points, node.get("required_points", 2)]
	_fill(node_source, entries)
	_fill(node_target, entries)

func _update_summary() -> void:
	preview.queue_redraw()
	var data := _model().get_summary(_selected(system_choice))
	summary.text = "在轨 %d / 已吸附 %d / 已到期 %d\n结构点 %d · 尚缺火箭 %d / 太阳帆 %d\n当前 %.0f kW · 规划结构完成后 %.0f kW\n太阳帆寿命 600 秒；接收器共享本恒星系可用功率。" % [data.live_sails, data.absorbed_sails, data.expired_sails, data.structure_points, data.missing_rockets, data.missing_sails, data.power_kw, data.planned_power_kw]

	if not GameManager.get_game_state().source_galaxy.is_empty():
		summary.text = "在轨 %d / 已吸附 %d / 已到期 %d\n结构点 %d · 尚缺火箭 %d / 太阳帆 %d\n框架 %d · 壳面 %d · 激活容量 %d / 规划容量 %d\n当前 %.0f kW · 规划完成 %.0f kW\n太阳帆基础寿命 1200 秒；发电乘以恒星光度和研究系数。" % [data.live_sails, data.absorbed_sails, data.expired_sails, data.structure_points, data.missing_rockets, data.missing_sails, data.get("frames", 0), data.get("shells", 0), data.get("active_capacity", 0), data.get("planned_capacity", 0), data.power_kw, data.planned_power_kw]
	quantity.max_value = _model().ammo_capacity(_selected(launcher_choice))
	var building: Dictionary = GameManager.get_game_state().buildings.get(_selected(launcher_choice), {})
	if not building.is_empty():
		var config: Dictionary = building.get("dyson", {})
		summary.text += "\n设备 %s · 目标 %s · 供电 %.0f%%\n发射进度 %.2f 秒 · 输入 %s" % ["启用" if config.get("enabled", false) else "停止", config.get("target_id", "未绑定"), float(building.get("power_efficiency", 0)) * 100, config.get("progress", 0), str(building.get("input_buffer", {}))]

func _configure(enabled: bool, unbind: bool) -> void:
	var id := _selected(launcher_choice)
	var building: Dictionary = GameManager.get_game_state().buildings.get(id, {})
	var target := _selected(orbit_choice) if building.get("type") in ["solar_sail_ejector", "dsp_em_rail_ejector"] else _selected(layer_choice)
	if not enabled: target = String(building.get("dyson", {}).get("target_id", ""))
	_result(_model().configure_launcher(id, "" if unbind else target, enabled))

func _result(result: Dictionary) -> void:
	status.text = result.message
	_refresh_plans()

func _process(delta: float) -> void:
	if not visible: return
	refresh_time += delta
	if refresh_time >= 0.5:
		refresh_time = 0
		_update_summary()

func _draw_plan() -> void:
	var center := preview.size / 2
	preview.draw_circle(center, 9, Color("#e1b452"))
	var system := _model().get_system(_selected(system_choice))
	for orbit in system.get("orbits", {}).values():
		var r := 24.0 + float(orbit.radius) / 50000 * 55
		preview.draw_arc(center, r, 0, TAU, 80, Color("#62b5ae"), 1.0, true)
	for layer in system.get("layers", {}).values():
		var r := 24.0 + float(layer.radius) / 50000 * 55
		var points := PackedVector2Array()
		var nodes: Array = layer.nodes.values()
		nodes.sort_custom(func(a: Dictionary, b: Dictionary): return a.angle < b.angle)
		for node in nodes:
			var point := center + Vector2.from_angle(deg_to_rad(float(node.angle))) * r
			points.append(point)
			preview.draw_circle(point, 4, Color("#70bb85") if int(node.points) == int(node.get("required_points", 2)) else Color("#e1b452"))
		for frame in layer.get("frames", {}).values():
			var a := center + Vector2.from_angle(deg_to_rad(float(layer.nodes[frame.source_id].angle))) * r
			var b := center + Vector2.from_angle(deg_to_rad(float(layer.nodes[frame.target_id].angle))) * r
			preview.draw_line(a, b, Color("#70bb85") if int(frame.points) == int(frame.required_points) else Color("#e1b452"), 1.0, true)
		if not layer.shell.is_empty() and points.size() >= 3:
			points.append(points[0])
			preview.draw_polyline(points, Color("#70bb85"), 1.0, true)
