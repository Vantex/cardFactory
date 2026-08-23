class_name FactoryWorkspaceUI
extends CanvasLayer

const TOP_BAR_HEIGHT := 52.0
const RESOURCE_RAIL_WIDTH := 216.0
const INSPECTOR_WIDTH := 286.0
const CONSTRUCTION_DOCK_HEIGHT := 92.0
const TOAST_DURATION := 2.5

const PANEL_DARK := Color("#101715")
const PANEL_LIGHT := Color("#151e1b")
const ACCENT_CYAN := Color("#62b5ae")
const ACCENT_GREEN := Color("#70bb85")
const ACCENT_YELLOW := Color("#e1b452")
const ACCENT_ERROR := Color("#df7666")

const DOCK_BUILDINGS := ["miner", "smelter", "assembling_machine_mk1", "power_generator"]
const DOCK_SHORTCUTS := {
	"miner": "Q",
	"smelter": "W",
	"assembling_machine_mk1": "E",
	"power_generator": "R",
}

var _selected_building_id := ""
var _selected_building_type := ""
var _placement_building_type := ""
var _top_status: Label
var _pause_button: Button
var _speed_buttons: Array[Button] = []
var _resource_summary: Label
var _objective_label: Label
var _stock_label: Label
var _production_label: Label
var _tips_label: Label
var _inspector_title: Label
var _inspector_details: Label
var _input_buffers: Label
var _output_buffers: Label
var _recipe_list: VBoxContainer
var _start_connection_button: Button
var _delete_button: Button
var _construction_points: Label
var _construction_mode: Label
var _toast_label: Label
var _toast_timer: Timer
var _recipe_signature := ""

func _ready() -> void:
	_create_workspace()
	EventBus.notice_requested.connect(show_notice)
	EventBus.simulation_updated.connect(refresh_now)
	EventBus.card_placed.connect(_on_state_changed)
	EventBus.card_removed.connect(_on_state_changed)
	EventBus.connection_created.connect(_on_state_changed)
	EventBus.connection_removed.connect(_on_state_changed)
	refresh_now()

func set_selected_building(building_id: String) -> void:
	_selected_building_id = building_id
	var building := _get_game_state().get_building(building_id)
	if building.is_empty():
		_selected_building_id = ""
	_selected_building_type = building.get("type", "")
	if not building.is_empty():
		_placement_building_type = ""
	refresh_now()

func get_selected_building_type() -> String:
	return _selected_building_type

func get_placement_building_type() -> String:
	return _placement_building_type

func set_placement_mode(building_type: String) -> void:
	if _placement_building_type == building_type:
		return
	_placement_building_type = building_type
	refresh_now()

func show_notice(message: String, tone: String = "info") -> void:
	var color := ACCENT_CYAN
	if tone == "success":
		color = ACCENT_GREEN
	elif tone == "warning":
		color = ACCENT_YELLOW
	elif tone == "error":
		color = ACCENT_ERROR
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)
	var toast := get_node("Toast") as Control
	toast.visible = not message.is_empty()
	_toast_timer.stop()
	if toast.visible:
		_toast_timer.start()

func is_pointer_over_ui(viewport_position: Vector2) -> bool:
	for node_name in ["TopBar", "ResourceRail", "InspectorPanel", "ConstructionDock"]:
		var region := get_node_or_null(node_name) as Control
		if region != null and region.visible and Rect2(Vector2.ZERO, region.size).has_point(region.get_global_transform_with_canvas().affine_inverse() * viewport_position):
			return true
	return false

func refresh_now(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	var state := _get_game_state()
	_refresh_top_bar(state)
	_refresh_resource_rail(state)
	_construction_points.text = "建造点 %02d" % state.construction_points
	_construction_mode.text = "当前：%s" % ("选择建筑" if _placement_building_type.is_empty() else "放置 %s" % _building_name(_placement_building_type))
	_refresh_inspector(state)

func _on_building_pressed(building_type: String) -> void:
	_selected_building_id = ""
	_selected_building_type = ""
	_placement_building_type = building_type
	EventBus.placement_requested.emit(building_type)
	show_notice("放置 %s" % _building_name(building_type), "info")
	refresh_now()

func _on_recipe_pressed(recipe_id: String) -> void:
	if _selected_building_id.is_empty():
		return
	if _get_game_state().set_entity_recipe(_selected_building_id, recipe_id):
		show_notice("配方已配置", "success")
	else:
		show_notice("配方不可用", "error")
	_recipe_signature = ""
	refresh_now()

func _on_pause_pressed() -> void:
	EventBus.pause_toggled_requested.emit()

func _on_speed_pressed(speed: float) -> void:
	EventBus.speed_requested.emit(speed)

func _on_start_connection_pressed() -> void:
	if not _selected_building_id.is_empty():
		EventBus.start_connection_requested.emit(_selected_building_id)

func _on_delete_pressed() -> void:
	if not _selected_building_id.is_empty():
		EventBus.delete_building_requested.emit(_selected_building_id)

func _on_state_changed(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	refresh_now()

func _on_notice_timeout() -> void:
	get_node("Toast").hide()

func _create_workspace() -> void:
	_create_top_bar()
	_create_resource_rail()
	_create_inspector_panel()
	_create_construction_dock()
	_create_toast()

func _create_top_bar() -> void:
	var top_bar := _create_panel("TopBar", PANEL_DARK)
	top_bar.anchor_right = 1.0
	top_bar.offset_right = 0.0
	top_bar.offset_bottom = TOP_BAR_HEIGHT
	var brand := _create_label("Brand", "CARD FACTORY", 15, ACCENT_CYAN)
	brand.position = Vector2(14, 15)
	top_bar.add_child(brand)
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.position = Vector2(132, 9)
	_pause_button.size = Vector2(64, 34)
	_pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(_pause_button)
	var speed_controls := HBoxContainer.new()
	speed_controls.name = "SpeedButtons"
	speed_controls.position = Vector2(202, 9)
	speed_controls.size = Vector2(132, 34)
	speed_controls.add_theme_constant_override("separation", 4)
	top_bar.add_child(speed_controls)
	for speed_index in range(1, 4):
		var speed_button := Button.new()
		speed_button.name = "Speed%d" % speed_index
		speed_button.text = "%dx" % speed_index
		speed_button.toggle_mode = true
		speed_button.custom_minimum_size = Vector2(40, 34)
		speed_button.pressed.connect(_on_speed_pressed.bind(float(speed_index)))
		speed_controls.add_child(speed_button)
		_speed_buttons.append(speed_button)
	_top_status = _create_label("Status", "", 12, ACCENT_GREEN)
	_top_status.position = Vector2(344, 16)
	_top_status.size = Vector2(794, 24)
	_top_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(_top_status)

func _create_resource_rail() -> void:
	var resource_rail := _create_panel("ResourceRail", PANEL_LIGHT)
	resource_rail.anchor_bottom = 1.0
	resource_rail.offset_top = TOP_BAR_HEIGHT
	resource_rail.offset_right = RESOURCE_RAIL_WIDTH
	resource_rail.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT
	_resource_summary = _create_label("Summary", "", 13, ACCENT_GREEN)
	_resource_summary.position = Vector2(16, 14)
	_resource_summary.size = Vector2(184, 52)
	resource_rail.add_child(_resource_summary)
	_objective_label = _create_label("Objective", "", 13, ACCENT_YELLOW)
	_objective_label.position = Vector2(16, 76)
	_objective_label.size = Vector2(184, 60)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_rail.add_child(_objective_label)
	_stock_label = _create_label("Stock", "", 12, ACCENT_CYAN)
	_stock_label.position = Vector2(16, 146)
	_stock_label.size = Vector2(184, 106)
	_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_rail.add_child(_stock_label)
	_production_label = _create_label("Production", "", 12, ACCENT_GREEN)
	_production_label.position = Vector2(16, 262)
	_production_label.size = Vector2(184, 76)
	resource_rail.add_child(_production_label)
	_tips_label = _create_label("Tips", "操作提示\nQ/W/E/R 建造\n拖动卡片移动\n拖动端口连接\nSpace 暂停", 11, Color("#9fb1aa"))
	_tips_label.position = Vector2(16, 350)
	_tips_label.size = Vector2(184, 120)
	resource_rail.add_child(_tips_label)

func _create_inspector_panel() -> void:
	var inspector := _create_panel("InspectorPanel", PANEL_LIGHT)
	inspector.anchor_left = 1.0
	inspector.anchor_right = 1.0
	inspector.anchor_bottom = 1.0
	inspector.offset_left = -INSPECTOR_WIDTH
	inspector.offset_top = TOP_BAR_HEIGHT
	inspector.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT
	_inspector_title = _create_label("Title", "工厂概览", 16, ACCENT_YELLOW)
	_inspector_title.position = Vector2(18, 14)
	_inspector_title.size = Vector2(250, 28)
	inspector.add_child(_inspector_title)
	_inspector_details = _create_label("Details", "", 12, Color("#d7e2de"))
	_inspector_details.position = Vector2(18, 46)
	_inspector_details.size = Vector2(250, 76)
	inspector.add_child(_inspector_details)
	_input_buffers = _create_label("InputBuffers", "", 11, ACCENT_CYAN)
	_input_buffers.position = Vector2(18, 124)
	_input_buffers.size = Vector2(250, 42)
	_input_buffers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(_input_buffers)
	_output_buffers = _create_label("OutputBuffers", "", 11, ACCENT_GREEN)
	_output_buffers.position = Vector2(18, 166)
	_output_buffers.size = Vector2(250, 42)
	_output_buffers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(_output_buffers)
	var recipe_heading := _create_label("RecipeHeading", "配方", 12, ACCENT_YELLOW)
	recipe_heading.position = Vector2(18, 212)
	inspector.add_child(recipe_heading)
	_recipe_list = VBoxContainer.new()
	_recipe_list.name = "RecipeList"
	_recipe_list.position = Vector2(18, 236)
	_recipe_list.size = Vector2(INSPECTOR_WIDTH - 36.0, 126.0)
	inspector.add_child(_recipe_list)
	_start_connection_button = Button.new()
	_start_connection_button.name = "StartConnectionButton"
	_start_connection_button.text = "开始连接"
	_start_connection_button.position = Vector2(18, 400)
	_start_connection_button.size = Vector2(118, 38)
	_start_connection_button.pressed.connect(_on_start_connection_pressed)
	inspector.add_child(_start_connection_button)
	_delete_button = Button.new()
	_delete_button.name = "DeleteButton"
	_delete_button.text = "删除建筑"
	_delete_button.position = Vector2(150, 400)
	_delete_button.size = Vector2(118, 38)
	_delete_button.pressed.connect(_on_delete_pressed)
	inspector.add_child(_delete_button)

func _create_construction_dock() -> void:
	var dock := _create_panel("ConstructionDock", PANEL_DARK)
	dock.anchor_left = 0.0
	dock.anchor_right = 1.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = RESOURCE_RAIL_WIDTH
	dock.offset_right = -INSPECTOR_WIDTH
	dock.offset_top = -CONSTRUCTION_DOCK_HEIGHT
	_construction_points = _create_label("Points", "", 13, ACCENT_YELLOW)
	_construction_points.position = Vector2(14, 12)
	dock.add_child(_construction_points)
	_construction_mode = _create_label("Mode", "", 11, ACCENT_CYAN)
	_construction_mode.position = Vector2(14, 42)
	_construction_mode.size = Vector2(112, 38)
	_construction_mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(_construction_mode)
	var buttons := HBoxContainer.new()
	buttons.name = "BuildingButtons"
	buttons.position = Vector2(126, 13)
	buttons.size = Vector2(510, 64)
	buttons.add_theme_constant_override("separation", 8)
	dock.add_child(buttons)
	for building_type in DOCK_BUILDINGS:
		var definition := DataManager.get_building(building_type)
		var button := Button.new()
		button.name = "%sButton" % building_type.capitalize()
		button.text = "%s %s\n%d 点" % [DOCK_SHORTCUTS[building_type], _building_name(building_type), GameState.BUILDING_COSTS[building_type]]
		button.tooltip_text = definition.get("description", "")
		button.custom_minimum_size = Vector2(116, 56)
		button.pressed.connect(_on_building_pressed.bind(building_type))
		buttons.add_child(button)

func _create_toast() -> void:
	var toast := _create_panel("Toast", PANEL_DARK)
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -190.0
	toast.offset_right = 190.0
	toast.offset_top = TOP_BAR_HEIGHT + 14.0
	toast.offset_bottom = TOP_BAR_HEIGHT + 52.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _create_label("Message", "", 14, ACCENT_CYAN)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	toast.add_child(_toast_label)
	_toast_timer = Timer.new()
	_toast_timer.name = "HideTimer"
	_toast_timer.one_shot = true
	_toast_timer.wait_time = TOAST_DURATION
	_toast_timer.timeout.connect(_on_notice_timeout)
	toast.add_child(_toast_timer)
	toast.hide()

func _refresh_top_bar(state: GameState) -> void:
	var generation := state.calculate_total_power_generation()
	var consumption := state.calculate_total_power_demand()
	var balance := generation - consumption
	var balance_text := "%.0f" % balance
	if balance > 0.0:
		balance_text = "+%s" % balance_text
	var speed_text := "%d" % int(state.speed) if is_equal_approx(state.speed, roundf(state.speed)) else "%.1f" % state.speed
	var total_seconds := int(state.elapsed_time)
	var time_text := "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	_top_status.text = "%s  %sx | GEN %.0f | USE %.0f | BAL %s | POINTS %02d | BUILDINGS %02d | LINKS %02d | %s" % ["PAUSED" if state.paused else "RUN", speed_text, generation, consumption, balance_text, state.construction_points, state.buildings.size(), state.connections.size(), time_text]
	_pause_button.text = "继续" if state.paused else "暂停"
	for index in range(_speed_buttons.size()):
		_speed_buttons[index].button_pressed = is_equal_approx(state.speed, float(index + 1))

func _refresh_resource_rail(state: GameState) -> void:
	_resource_summary.text = "CONSTRUCTION\nPOINTS  %02d\nBUILDINGS  %02d  LINKS  %02d" % [state.construction_points, state.buildings.size(), state.connections.size()]
	_objective_label.text = _beginner_objective(state)
	_stock_label.text = "库存\n%s" % _format_stock(state)
	var counts := {"running": 0, "idle": 0, "blocked": 0, "error": 0}
	for building in state.buildings.values():
		var status: String = building.get("status", "idle")
		counts[status] = counts.get(status, 0) + 1
	_production_label.text = "生产概况\n运行 %d  空闲 %d\n阻塞 %d  异常 %d" % [counts.running, counts.idle, counts.blocked, counts.error]

func _refresh_inspector(state: GameState) -> void:
	var building := state.get_building(_selected_building_id)
	if building.is_empty():
		if not _selected_building_id.is_empty():
			_selected_building_id = ""
			_selected_building_type = ""
		_inspector_title.text = "工厂概览"
		_inspector_details.text = "建筑 %d\n连接 %d\n建造点 %d" % [state.buildings.size(), state.connections.size(), state.construction_points]
		_input_buffers.text = "选择建筑查看输入"
		_output_buffers.text = "选择建筑查看输出"
		_start_connection_button.disabled = true
		_delete_button.disabled = true
		_refresh_recipe_controls(state, {})
		return
	_selected_building_type = building.get("type", "")
	var definition := DataManager.get_building(_selected_building_type)
	var progress_percent := int(round(float(building.get("progress", 0.0)) * 100.0))
	var demand := float(definition.get("power_demand", 0.0))
	var generation := float(definition.get("power_generation", 0.0))
	_inspector_title.text = state.get_building_display_name(_selected_building_id)
	_inspector_details.text = "类型 %s\n状态 %s  进度 %d%%\n电力 消耗 %.0f / 产出 %.0f" % [_selected_building_type, building.get("status", "idle"), progress_percent, demand, generation]
	_input_buffers.text = "输入  %s" % _format_buffer(building.get("input_buffer", {}))
	_output_buffers.text = "输出  %s" % _format_buffer(building.get("output_buffer", {}))
	_start_connection_button.disabled = false
	_delete_button.disabled = false
	_refresh_recipe_controls(state, building)

func _refresh_recipe_controls(_state: GameState, building: Dictionary) -> void:
	var recipes: Array = []
	if not building.is_empty():
		recipes = DataManager.get_recipes_for_building(building.get("type", ""))
	var recipe_ids: Array[String] = []
	for recipe in recipes:
		recipe_ids.append(recipe.get("id", ""))
	var signature := "%s|%s|%s" % [_selected_building_id, building.get("recipe_id", ""), ",".join(recipe_ids)]
	if signature == _recipe_signature:
		return
	_recipe_signature = signature
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	for recipe in recipes:
		var recipe_id: String = recipe.get("id", "")
		var recipe_button := Button.new()
		recipe_button.text = "%s%s" % ["✓ " if recipe_id == building.get("recipe_id", "") else "", recipe.get("name", recipe_id)]
		recipe_button.pressed.connect(_on_recipe_pressed.bind(recipe_id))
		_recipe_list.add_child(recipe_button)

func _beginner_objective(state: GameState) -> String:
	if state.buildings.is_empty() or state.get_buildings_by_type("miner").is_empty():
		return "新手目标\n放置矿机（Q）"
	if state.get_buildings_by_type("smelter").is_empty():
		return "新手目标\n放置熔炉（W）"
	if state.connections.is_empty():
		return "新手目标\n连接矿机与熔炉"
	return "新手目标\n让生产链持续运行"

func _format_stock(state: GameState) -> String:
	var aggregate := {}
	for building in state.buildings.values():
		for buffer_name in ["input_buffer", "output_buffer"]:
			for item_id in building.get(buffer_name, {}):
				var amount := float(building[buffer_name][item_id])
				if amount > 0.0:
					aggregate[item_id] = aggregate.get(item_id, 0.0) + amount
	return _format_buffer(aggregate)

func _format_buffer(buffer: Dictionary) -> String:
	var item_ids := buffer.keys()
	item_ids.sort()
	var parts: Array[String] = []
	for item_id in item_ids:
		var amount := float(buffer[item_id])
		if amount > 0.0:
			parts.append("%s %.1f" % [item_id, amount])
	return "无" if parts.is_empty() else ", ".join(parts)

func _create_panel(node_name: String, color: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	add_child(panel)
	return panel

func _create_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = ACCENT_CYAN.darkened(0.45)
	style.set_border_width_all(1)
	return style

func _building_name(building_type: String) -> String:
	return DataManager.get_building(building_type).get("name", building_type)

func _get_game_state() -> GameState:
	return GameManager.get_game_state()
