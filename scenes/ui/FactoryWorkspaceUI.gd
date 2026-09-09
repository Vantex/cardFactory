class_name FactoryWorkspaceUI
extends CanvasLayer

const TECHNOLOGY_PANEL_SCRIPT = preload("res://scenes/ui/TechnologyPanel.gd")
const CODEX_WORKSPACE_SCRIPT = preload("res://scenes/ui/CodexWorkspace.gd")

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

const DOCK_BUILDINGS := ["miner", "smelter", "assembling_machine_mk1", "power_generator", "matrix_lab"]
const DOCK_SHORTCUTS := {
	"miner": "Q",
	"smelter": "W",
	"assembling_machine_mk1": "E",
	"power_generator": "R",
	"matrix_lab": "T",
}

var _selected_building_id := ""
var _selected_building_type := ""
var _selected_entity_ids: Array[String] = []
var _placement_building_type := ""
var _top_status: Label
var _pause_button: Button
var _speed_buttons: Array[Button] = []
var _resource_summary: Label
var _objective_label: Label
var _stock_label: Label
var _cursor_label: Label
var _handcraft_label: Label
var _production_label: Label
var _tips_label: Label
var _inspector_title: Label
var _inspector_details: Label
var _input_buffers: Label
var _output_buffers: Label
var _recipe_heading: Label
var _handcraft_quantity: SpinBox
var _recipe_list: GridContainer
var _start_connection_button: Button
var _delete_button: Button
var _delete_confirmation: ConfirmationDialog
var _construction_stock: Label
var _construction_mode: Label
var _dock_buttons: Dictionary = {}
var _toast_label: Label
var _toast_timer: Timer
var _recipe_signature := ""
const WORKSPACES := ["BlueprintWorkspace", "CampaignWorkspace", "TechnologyPanel", "CodexWorkspace", "GalaxyMap", "StationPanel", "DysonPanel", "EndgameWorkspace"]

func _ready() -> void:
	_create_workspace()
	var station_panel := preload("res://scenes/ui/StationPanel.gd").new()
	station_panel.name = "StationPanel"
	station_panel.anchor_right = 1.0
	station_panel.anchor_bottom = 1.0
	station_panel.offset_left = RESOURCE_RAIL_WIDTH + 10.0
	station_panel.offset_top = TOP_BAR_HEIGHT + 8.0
	station_panel.offset_right = -INSPECTOR_WIDTH - 10.0
	station_panel.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT - 8.0
	station_panel.z_index = 4
	station_panel.hide()
	add_child(station_panel)
	var dyson_panel := preload("res://scenes/ui/DysonUI.gd").new()
	dyson_panel.name = "DysonPanel"
	dyson_panel.anchor_right = 1.0
	dyson_panel.anchor_bottom = 1.0
	dyson_panel.offset_left = RESOURCE_RAIL_WIDTH + 10.0
	dyson_panel.offset_top = TOP_BAR_HEIGHT + 8.0
	dyson_panel.offset_right = -INSPECTOR_WIDTH - 10.0
	dyson_panel.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT - 8.0
	dyson_panel.z_index = 4
	dyson_panel.hide()
	add_child(dyson_panel)
	var endgame_panel := preload("res://scenes/ui/EndgameWorkspace.gd").new()
	endgame_panel.name = "EndgameWorkspace"
	endgame_panel.anchor_right = 1.0
	endgame_panel.anchor_bottom = 1.0
	endgame_panel.offset_left = RESOURCE_RAIL_WIDTH + 10.0
	endgame_panel.offset_top = TOP_BAR_HEIGHT + 8.0
	endgame_panel.offset_right = -INSPECTOR_WIDTH - 10.0
	endgame_panel.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT - 8.0
	endgame_panel.z_index = 4
	endgame_panel.hide()
	add_child(endgame_panel)
	var technology_panel := TECHNOLOGY_PANEL_SCRIPT.new()
	technology_panel.name = "TechnologyPanel"
	technology_panel.anchor_right = 1.0
	technology_panel.anchor_bottom = 1.0
	technology_panel.offset_left = RESOURCE_RAIL_WIDTH + 10.0
	technology_panel.offset_top = TOP_BAR_HEIGHT + 8.0
	technology_panel.offset_right = -INSPECTOR_WIDTH - 10.0
	technology_panel.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT - 8.0
	technology_panel.z_index = 4
	technology_panel.hide()
	add_child(technology_panel)
	var codex_workspace := CODEX_WORKSPACE_SCRIPT.new()
	codex_workspace.name = "CodexWorkspace"
	codex_workspace.anchor_right = 1.0
	codex_workspace.anchor_bottom = 1.0
	codex_workspace.offset_left = RESOURCE_RAIL_WIDTH + 10.0
	codex_workspace.offset_top = TOP_BAR_HEIGHT + 8.0
	codex_workspace.offset_right = -INSPECTOR_WIDTH - 10.0
	codex_workspace.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT - 8.0
	codex_workspace.z_index = 4
	codex_workspace.hide()
	add_child(codex_workspace)
	var input_handler := _get_input_handler()
	if input_handler != null and input_handler.has_signal("selection_changed"):
		input_handler.selection_changed.connect(_on_shared_selection_changed)
	if input_handler != null and input_handler.has_signal("delete_confirmation_requested"):
		input_handler.delete_confirmation_requested.connect(_request_delete_confirmation)
	EventBus.notice_requested.connect(show_notice)
	EventBus.simulation_updated.connect(refresh_now)
	EventBus.card_placed.connect(_on_state_changed)
	EventBus.card_removed.connect(_on_state_changed)
	EventBus.connection_created.connect(_on_state_changed)
	EventBus.connection_removed.connect(_on_state_changed)
	refresh_now()
	_create_settings_entry()
	get_viewport().size_changed.connect(apply_device_layout)
	apply_device_layout.call_deferred()

func set_selected_building(building_id: String) -> void:
	var input_handler := _get_input_handler()
	if input_handler != null and input_handler.has_method("get_selected_entity_ids"):
		var shared_selection: Array = input_handler.call("get_selected_entity_ids")
		if not shared_selection.is_empty() and (building_id.is_empty() or shared_selection.has(building_id)):
			set_selected_entities(shared_selection)
			return
	_selected_entity_ids.clear()
	_selected_building_id = building_id
	var building := _get_game_state().get_building(building_id)
	if building.is_empty() or String(building.get("planet_id", "")) != _get_game_state().active_planet_id:
		building = {}
		_selected_building_id = ""
	_selected_building_type = building.get("type", "")
	if not _selected_building_id.is_empty():
		_selected_entity_ids.append(_selected_building_id)
	if not building.is_empty():
		_placement_building_type = ""
	refresh_now()

func set_selected_entities(entity_ids: Array) -> void:
	_selected_entity_ids.clear()
	var state := _get_game_state()
	for id_value in entity_ids:
		var entity_id := String(id_value)
		var entity: Dictionary = state.buildings.get(entity_id, state.connections.get(entity_id, {}))
		if not _selected_entity_ids.has(entity_id) and not entity.is_empty() and String(entity.get("planet_id", "")) == state.active_planet_id:
			_selected_entity_ids.append(entity_id)
	_selected_building_id = ""
	_selected_building_type = ""
	for entity_id in _selected_entity_ids:
		if state.buildings.has(entity_id):
			_selected_building_id = entity_id
			_selected_building_type = String(state.buildings[entity_id].get("type", ""))
			break
	refresh_now()

func _on_shared_selection_changed(entity_ids: Array) -> void:
	set_selected_entities(entity_ids)

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
	_toast_label.set_meta("device_colors", {"theme_override_colors/font_color": color})
	_toast_label.add_theme_color_override("font_color", color.darkened(0.65) if LocalSettings.values.theme == "light" else color)
	var toast := get_node("Toast") as Control
	toast.visible = not message.is_empty()
	_toast_timer.stop()
	if toast.visible:
		_toast_timer.start()

func is_pointer_over_ui(viewport_position: Vector2) -> bool:
	for node_name in ["TopBar", "ResourceRail", "InspectorPanel", "ConstructionDock", "BlueprintWorkspace", "CampaignWorkspace", "MiniMap", "TechnologyPanel", "CodexWorkspace", "GalaxyMap", "StationPanel", "DysonPanel", "EndgameWorkspace"]:
		var region := get_node_or_null(node_name) as Control
		if region != null and region.visible and Rect2(Vector2.ZERO, region.size).has_point(region.get_global_transform_with_canvas().affine_inverse() * viewport_position):
			return true
	return false

func refresh_now(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	var state := _get_game_state()
	_refresh_top_bar(state)
	_refresh_resource_rail(state)
	_construction_stock.text = "施工件 %s" % _construction_stock_summary(state)
	_construction_mode.text = "当前：%s" % ("选择建筑" if _placement_building_type.is_empty() else "放置 %s" % _building_name(_placement_building_type))
	_refresh_construction_dock(state)
	_refresh_inspector(state)
	var galaxy_map := get_node_or_null("GalaxyMap")
	if galaxy_map != null and galaxy_map.has_method("refresh_now"):
		galaxy_map.call("refresh_now")

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

func _on_extraction_pressed(item_id: String) -> void:
	if _get_game_state().set_entity_extraction_item(_selected_building_id, item_id):
		show_notice("采集目标已切换", "success")
	else:
		show_notice("采集目标不可用", "error")
	_recipe_signature = ""
	refresh_now()

func _on_output_item_pressed(item_id: String) -> void:
	if _get_game_state().set_entity_output_item(_selected_building_id, item_id):
		show_notice("连接输出已切换", "success")
	else:
		show_notice("输出物品不可用", "error")
	_recipe_signature = ""
	refresh_now()

func _on_belt_config_pressed(action: String, belt_id: String) -> void:
	var state := _get_game_state()
	var config := state.get_belt_configuration(belt_id)
	if config.is_empty():
		show_notice("线路不存在", "error")
		return
	var result: Dictionary
	match action:
		"upgrade":
			var ok := state.upgrade_belt(belt_id)
			result = {"ok": ok, "message": "线路等级已升级" if ok else "线路升级失败"}
		"parallel":
			var next_parallel := int(config.parallel_count) % 4 + 1
			result = state.try_configure_belt(belt_id, {"parallel_count": next_parallel})
		"stack":
			var stack_values: Array[int] = [1, 2, 4]
			var next_stack: int = stack_values[(stack_values.find(int(config.stack_size)) + 1) % stack_values.size()]
			result = state.try_configure_belt(belt_id, {"stack_size": next_stack})
		"priority":
			result = state.try_configure_belt(belt_id, {"priority": (int(config.priority) + 1) % 3})
		"route":
			var route_values: Array[String] = ["auto", "upper", "lower", "manual", "bezier"]
			var next_route: String = route_values[(route_values.find(String(config.route_mode)) + 1) % route_values.size()]
			result = state.try_configure_belt(belt_id, {"route_mode": next_route})
		"monitor":
			result = state.try_configure_belt(belt_id, {"monitor_enabled": not bool(config.monitor_enabled)})
		"enabled":
			result = state.try_configure_belt(belt_id, {"enabled": not bool(config.enabled)})
		"sync_network":
			result = state.apply_belt_configuration_to_network(belt_id)
		"upgrade_network":
			result = state.upgrade_belt_network(belt_id)
		_:
			result = {"ok": false, "message": "未知线路命令"}
	var message := String(result.get("message", "命令成功" if result.get("ok", false) else "命令失败"))
	if result.has("results"):
		message = "成功 %d / 跳过 %d / 失败 %d" % [result.get("success", 0), result.get("skipped", 0), result.get("failed", 0)]
	show_notice(message, "success" if result.get("ok", false) else "error")
	_recipe_signature = ""
	refresh_now()

func _on_handcraft_pressed(recipe_id: String) -> void:
	var quantity := maxi(int(_handcraft_quantity.value), 1)
	var result := HandcraftSystem.new(_get_game_state()).queue_craft(recipe_id, quantity)
	show_notice(String(result.get("message", "手工制造命令失败")), "success" if result.get("ok", false) else "error")
	_recipe_signature = ""
	refresh_now()

func _on_handcraft_quantity_changed(_value: float) -> void:
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
	var selected_ids := _current_selected_entity_ids()
	var building_ids := _current_selected_building_ids()
	if building_ids.size() != selected_ids.size():
		show_notice("混合选择没有共同的删除命令", "warning")
		return
	var input_handler := _get_input_handler()
	if input_handler == null or not input_handler.has_method("request_delete_entities") or not input_handler.call("request_delete_entities", building_ids):
		show_notice("只能删除活动行星建筑", "error")

func _request_delete_confirmation(entity_ids: Array) -> void:
	var building_ids: Array[String] = []
	for id_value in entity_ids:
		var entity_id := String(id_value)
		if _get_game_state().buildings.has(entity_id) and not building_ids.has(entity_id):
			building_ids.append(entity_id)
	if building_ids.is_empty():
		return
	_delete_confirmation.set_meta("entity_ids", building_ids)
	_delete_confirmation.dialog_text = "确认删除 %d 个建筑？此操作会返还施工件和缓存。" % building_ids.size()
	_delete_confirmation.popup_centered(Vector2i(420, 160))

func _on_delete_confirmed() -> void:
	var entity_ids: Array = _delete_confirmation.get_meta("entity_ids", [])
	var active_input_handler := _get_input_handler()
	if active_input_handler == null or not active_input_handler.has_method("are_active_entities") or not active_input_handler.call("are_active_entities", entity_ids):
		show_notice("删除目标已不在活动行星", "error")
		refresh_now()
		return
	var result := _get_game_state().try_remove_entities(entity_ids)
	show_notice(String(result.get("message", "拆除命令失败")), "success" if result.get("ok", false) else "error")
	if result.get("ok", false):
		_selected_entity_ids.clear()
		_selected_building_id = ""
		_selected_building_type = ""
		var input_handler := _get_input_handler()
		if input_handler != null and input_handler.has_method("set_selected_entities"):
			input_handler.call("set_selected_entities", [])
	refresh_now()

func cancel_transient_operations() -> void:
	if _delete_confirmation != null:
		_delete_confirmation.hide()
		_delete_confirmation.remove_meta("entity_ids")

func _on_batch_lock_pressed(locked: bool) -> void:
	var selected_ids := _current_selected_entity_ids()
	var building_ids := _current_selected_building_ids()
	if building_ids.is_empty() or building_ids.size() != selected_ids.size():
		show_notice("当前选择没有共同的锁定命令", "warning")
		return
	var changed := _get_game_state().set_entities_interaction_locked(building_ids, locked)
	show_notice("已%s %d 个建筑" % ["锁定" if locked else "解锁", changed], "success")
	refresh_now()

func _on_batch_belt_config_pressed(action: String) -> void:
	var state := _get_game_state()
	var selected_ids := _current_selected_entity_ids()
	if selected_ids.size() < 2:
		show_notice("至少选择两条线路", "warning")
		return
	for belt_id in selected_ids:
		if state.get_belt_configuration(belt_id).is_empty():
			show_notice("当前选择没有共同的线路命令", "warning")
			return
	var config := state.get_belt_configuration(selected_ids[0])
	var requested: Dictionary = {}
	match action:
		"stack":
			var stack_values: Array[int] = [1, 2, 4]
			requested["stack_size"] = stack_values[(stack_values.find(int(config.stack_size)) + 1) % stack_values.size()]
		"priority":
			requested["priority"] = (int(config.priority) + 1) % 3
		"route":
			var route_values: Array[String] = ["auto", "upper", "lower", "manual", "bezier"]
			requested["route_mode"] = route_values[(route_values.find(String(config.route_mode)) + 1) % route_values.size()]
		"monitor":
			requested["monitor_enabled"] = not bool(config.monitor_enabled)
		"enabled":
			requested["enabled"] = not bool(config.enabled)
		_:
			show_notice("未知批量线路命令", "error")
			return
	var result := state.try_configure_belts(selected_ids, requested)
	show_notice(String(result.get("message", "批量线路配置失败")), "success" if result.get("ok", false) else "error")
	_recipe_signature = ""
	refresh_now()

func _on_state_changed(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	refresh_now()

func _toggle_technology_workspace() -> void:
	var technology_panel := get_node_or_null("TechnologyPanel") as Control
	if technology_panel != null:
		if technology_panel.visible:
			technology_panel.hide()
		else:
			show_exclusive_workspace("TechnologyPanel")

func _toggle_codex_workspace() -> void:
	var codex_workspace := get_node_or_null("CodexWorkspace") as Control
	if codex_workspace != null:
		if codex_workspace.visible:
			codex_workspace.hide()
		else:
			show_exclusive_workspace("CodexWorkspace")

func _toggle_galaxy_workspace() -> void:
	var galaxy_map := get_node_or_null("GalaxyMap") as Control
	if galaxy_map != null:
		if galaxy_map.visible:
			galaxy_map.hide()
		else:
			show_exclusive_workspace("GalaxyMap")

func show_exclusive_workspace(workspace_name: String) -> void:
	for candidate_name in ["TechnologyPanel", "CampaignWorkspace", "BlueprintWorkspace", "CodexWorkspace", "GalaxyMap", "StationPanel", "DysonPanel", "EndgameWorkspace"]:
		var workspace := get_node_or_null(candidate_name) as Control
		if workspace != null:
			workspace.visible = candidate_name == workspace_name
			if workspace.visible: get_parent().get_node("AppShell")._focus_first.call_deferred(workspace)

func _on_notice_timeout() -> void:
	get_node("Toast").hide()

func _create_workspace() -> void:
	_create_top_bar()
	_create_resource_rail()
	_create_inspector_panel()
	_create_construction_dock()
	_create_toast()
	_delete_confirmation = ConfirmationDialog.new()
	_delete_confirmation.name = "DeleteConfirmation"
	_delete_confirmation.title = "确认批量删除"
	_delete_confirmation.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_confirmation)

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
	var technology_button := Button.new()
	technology_button.name = "TechnologyButton"
	technology_button.text = "科技"
	technology_button.position = Vector2(344, 9)
	technology_button.size = Vector2(58, 34)
	technology_button.pressed.connect(_toggle_technology_workspace)
	top_bar.add_child(technology_button)
	var analysis_button := Button.new()
	analysis_button.name = "AnalysisButton"
	analysis_button.text = "分析"
	analysis_button.position = Vector2(408, 9)
	analysis_button.size = Vector2(58, 34)
	analysis_button.pressed.connect(_toggle_codex_workspace)
	top_bar.add_child(analysis_button)
	var galaxy_button := Button.new()
	galaxy_button.name = "GalaxyButton"
	galaxy_button.text = "星图"
	galaxy_button.position = Vector2(472, 9)
	galaxy_button.size = Vector2(58, 34)
	galaxy_button.pressed.connect(_toggle_galaxy_workspace)
	top_bar.add_child(galaxy_button)
	var dyson_button := Button.new()
	dyson_button.name = "DysonButton"
	dyson_button.text = "戴森"
	dyson_button.position = Vector2(536, 9)
	dyson_button.size = Vector2(58, 34)
	dyson_button.pressed.connect(func():
		if get_node("DysonPanel").visible: get_node("DysonPanel").hide()
		else: show_exclusive_workspace("DysonPanel"))
	top_bar.add_child(dyson_button)
	var endgame_button := Button.new()
	endgame_button.name = "EndgameButton"
	endgame_button.text = "终局"
	endgame_button.position = Vector2(600, 9)
	endgame_button.size = Vector2(58, 34)
	endgame_button.pressed.connect(func():
		if get_node("EndgameWorkspace").visible: get_node("EndgameWorkspace").hide()
		else: show_exclusive_workspace("EndgameWorkspace"))
	top_bar.add_child(endgame_button)
	_top_status.position = Vector2(664, 16)
	_top_status.size = Vector2(474, 24)
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
	_stock_label.size = Vector2(184, 78)
	_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_rail.add_child(_stock_label)
	_cursor_label = _create_label("Cursor", "", 11, ACCENT_YELLOW)
	_cursor_label.position = Vector2(16, 226)
	_cursor_label.size = Vector2(184, 24)
	resource_rail.add_child(_cursor_label)
	_handcraft_label = _create_label("Handcraft", "", 11, ACCENT_CYAN)
	_handcraft_label.position = Vector2(16, 252)
	_handcraft_label.size = Vector2(184, 46)
	_handcraft_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_rail.add_child(_handcraft_label)
	_production_label = _create_label("Production", "", 12, ACCENT_GREEN)
	_production_label.position = Vector2(16, 302)
	_production_label.size = Vector2(184, 76)
	resource_rail.add_child(_production_label)
	_tips_label = _create_label("Tips", "操作提示\nQ/W/E/R/T 建造\n空闲检查器手工制造\n拖动卡片/端口\nSpace 暂停", 11, Color("#9fb1aa"))
	_tips_label.position = Vector2(16, 382)
	_tips_label.size = Vector2(184, 110)
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
	_recipe_heading = _create_label("RecipeHeading", "配方", 12, ACCENT_YELLOW)
	_recipe_heading.position = Vector2(18, 212)
	inspector.add_child(_recipe_heading)
	_handcraft_quantity = SpinBox.new()
	_handcraft_quantity.name = "HandcraftQuantity"
	_handcraft_quantity.position = Vector2(176, 204)
	_handcraft_quantity.size = Vector2(92, 30)
	_handcraft_quantity.min_value = 1.0
	_handcraft_quantity.max_value = 99.0
	_handcraft_quantity.step = 1.0
	_handcraft_quantity.value = 1.0
	_handcraft_quantity.allow_greater = false
	_handcraft_quantity.allow_lesser = false
	_handcraft_quantity.value_changed.connect(_on_handcraft_quantity_changed)
	inspector.add_child(_handcraft_quantity)
	_recipe_list = GridContainer.new()
	_recipe_list.name = "RecipeList"
	_recipe_list.columns = 2
	_recipe_list.position = Vector2(18, 236)
	_recipe_list.size = Vector2(INSPECTOR_WIDTH - 36.0, 126.0)
	_recipe_list.add_theme_constant_override("h_separation", 4)
	_recipe_list.add_theme_constant_override("v_separation", 4)
	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.position = _recipe_list.position
	recipe_scroll.size = Vector2(INSPECTOR_WIDTH - 28.0, 118.0)
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipe_list.position = Vector2.ZERO
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_child(recipe_scroll)
	recipe_scroll.add_child(_recipe_list)
	var material_actions := HBoxContainer.new()
	material_actions.name = "MaterialActions"
	material_actions.position = Vector2(18, 360)
	inspector.add_child(material_actions)
	for action in ["SupplyRecipe", "CollectOutput"]:
		var button := Button.new()
		button.name = action
		button.text = "投料一批" if action == "SupplyRecipe" else "收取产物"
		button.custom_minimum_size = Vector2(120, 34)
		button.pressed.connect(_on_material_action.bind(action))
		material_actions.add_child(button)
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
	_construction_stock = _create_label("Points", "", 13, ACCENT_YELLOW)
	_construction_stock.position = Vector2(14, 12)
	dock.add_child(_construction_stock)
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
		button.name = _building_button_name(building_type)
		button.text = "%s %s\n已有 0 / 需要 1" % [DOCK_SHORTCUTS[building_type], _building_name(building_type)]
		button.clip_text = true
		button.tooltip_text = definition.get("description", "")
		button.custom_minimum_size = Vector2(94, 56)
		button.pressed.connect(_on_building_pressed.bind(building_type))
		buttons.add_child(button)
		_dock_buttons[building_type] = button

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
	var simulation_engine := GameManager.get_simulation_engine()
	if GameManager.get_game_state() == state and simulation_engine != null and simulation_engine.game_state == state:
		var power_info := simulation_engine.get_power_info()
		generation = float(power_info.get("generation", generation))
		consumption = float(power_info.get("consumption", consumption))
	var balance := generation - consumption
	var balance_text := "%.0f" % balance
	if balance > 0.0:
		balance_text = "+%s" % balance_text
	var speed_text := "%d" % int(state.speed) if is_equal_approx(state.speed, roundf(state.speed)) else "%.1f" % state.speed
	var total_seconds := int(state.elapsed_time)
	var time_text := "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	_top_status.text = "%s  %sx | GEN %.0f | USE %.0f | BAL %s | KITS %s | BUILDINGS %02d | LINKS %02d | %s" % ["PAUSED" if state.paused else "RUN", speed_text, generation, consumption, balance_text, _construction_stock_summary(state), _active_building_count(state), _active_connection_count(state), time_text]
	_pause_button.text = "继续" if state.paused else "暂停"
	for index in range(_speed_buttons.size()):
		_speed_buttons[index].button_pressed = is_equal_approx(state.speed, float(index + 1))

func _refresh_resource_rail(state: GameState) -> void:
	_resource_summary.text = "CONSTRUCTION\nKITS  %s\nBUILDINGS  %02d  LINKS  %02d" % [_construction_stock_summary(state), _active_building_count(state), _active_connection_count(state)]
	_objective_label.text = _beginner_objective(state)
	_stock_label.text = "行星托盘\n%s" % _format_buffer(state.get_active_planet_inventory())
	_cursor_label.text = "光标  %s" % _format_cursor_payload(state.cursor_payload)
	_handcraft_label.text = "手工队列\n%s" % _format_handcraft_queue(state.handcraft_queue)
	var counts := {"running": 0, "idle": 0, "blocked": 0, "no_power": 0, "error": 0}
	for building in state.buildings.values():
		if String(building.get("planet_id", "")) != state.active_planet_id:
			continue
		var status: String = building.get("status", "idle")
		counts[status] = counts.get(status, 0) + 1
	_production_label.text = "生产概况\n运行 %d  空闲 %d\n阻塞 %d  停电 %d\n异常 %d" % [counts.running, counts.idle, counts.blocked, counts.no_power, counts.error]

func _refresh_inspector(state: GameState) -> void:
	get_node("InspectorPanel/MaterialActions").visible = not _selected_building_id.is_empty() and state.buildings.has(_selected_building_id)
	var selected_ids := _current_selected_entity_ids()
	if selected_ids.size() > 1:
		_refresh_multi_inspector(state, selected_ids)
		return
	if selected_ids.size() == 1 and state.connections.has(selected_ids[0]):
		_refresh_belt_inspector(state, selected_ids[0])
		return
	if selected_ids.size() == 1 and state.buildings.has(selected_ids[0]):
		_selected_building_id = selected_ids[0]
	var building := state.get_building(_selected_building_id)
	_recipe_list.show()
	_delete_button.text = "删除建筑"
	if building.is_empty():
		if not _selected_building_id.is_empty():
			_selected_building_id = ""
			_selected_building_type = ""
		_inspector_title.text = "工厂概览"
		_inspector_details.text = "建筑 %d\n连接 %d\n施工件 %d" % [_active_building_count(state), _active_connection_count(state), _construction_item_total(state)]
		_input_buffers.text = "行星托盘  %s" % _format_buffer(state.get_active_planet_inventory())
		_output_buffers.text = "光标载荷  %s" % _format_cursor_payload(state.cursor_payload)
		_start_connection_button.disabled = true
		_delete_button.disabled = true
		_refresh_recipe_controls(state, {})
		return
	_selected_building_type = building.get("type", "")
	var definition := DataManager.get_building(_selected_building_type)
	var progress_percent := int(round(float(building.get("progress", 0.0)) * 100.0))
	var demand := float(definition.get("power_demand", 0.0))
	var generation := float(definition.get("power_generation", 0.0))
	var interaction_state := "已锁定" if state.is_entity_interaction_locked(_selected_building_id) else "可移动"
	_inspector_title.text = state.get_building_display_name(_selected_building_id)
	_inspector_details.text = "类型 %s\n状态 %s  进度 %d%%\n电力 消耗 %.0f / 产出 %.0f\n交互 %s" % [_selected_building_type, building.get("status", "idle"), progress_percent, demand, generation, interaction_state]
	_input_buffers.text = "输入  %s" % _format_buffer(building.get("input_buffer", {}))
	_output_buffers.text = "输出  %s" % _format_buffer(building.get("output_buffer", {}))
	_start_connection_button.disabled = false
	_delete_button.disabled = false
	_refresh_recipe_controls(state, building)

func _refresh_belt_inspector(state: GameState, belt_id: String) -> void:
	var connection: Dictionary = state.connections[belt_id]
	var config := state.get_belt_configuration(belt_id)
	var tier_label := _belt_tier_label(String(config.get("tier", "conveyor_belt_mk1")))
	var route_summary := "路由 %s" % config.get("route_mode", "auto")
	if config.get("route_mode", "auto") == "manual":
		route_summary += "  偏移 %.0f" % float(config.get("route_offset_y", 0.0))
	_inspector_title.text = "线路 %s" % belt_id
	_inspector_details.text = "%s 额定 %.0f/s  有效 %.0f/s\n并联 %d  堆叠 %d  优先级 %d\n%s  监控 %s  %s" % [tier_label, config.get("rated_throughput", 10.0), config.get("effective_throughput", 10.0), config.get("parallel_count", 1), config.get("stack_size", 1), config.get("priority", 0), route_summary, "开" if config.get("monitor_enabled", false) else "关", "启用" if config.get("enabled", true) else "禁用"]
	_input_buffers.text = "源  %s" % connection.get("source_id", "")
	_output_buffers.text = "目标  %s  |  物品 %s" % [connection.get("target_id", ""), connection.get("item_id", "")]
	_start_connection_button.disabled = true
	_delete_button.disabled = true
	_recipe_heading.text = "线路配置"
	_handcraft_quantity.hide()
	_refresh_belt_controls(belt_id, config)

func _refresh_belt_controls(belt_id: String, config: Dictionary) -> void:
	_recipe_list.show()
	_recipe_list.columns = 3
	var signature := "%s|%s" % [belt_id, JSON.stringify(config)]
	if signature == _recipe_signature:
		return
	_recipe_signature = signature
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	var actions := [
		["upgrade", "等级 +"],
		["parallel", "并联 +"],
		["stack", "堆叠切换"],
		["priority", "优先级"],
		["route", "路由切换"],
		["monitor", "监控开关"],
		["enabled", "启停"],
		["sync_network", "同步整网"],
		["upgrade_network", "升级整网"],
	]
	for action in actions:
		var button := Button.new()
		button.text = action[1]
		button.custom_minimum_size = Vector2(78, 34)
		button.pressed.connect(_on_belt_config_pressed.bind(action[0], belt_id))
		_recipe_list.add_child(button)

func _refresh_multi_inspector(state: GameState, selected_ids: Array[String]) -> void:
	var building_count := 0
	var belt_count := 0
	var movable_count := 0
	for entity_id in selected_ids:
		if state.buildings.has(entity_id):
			building_count += 1
			if not state.is_entity_interaction_locked(entity_id):
				movable_count += 1
		elif state.connections.has(entity_id):
			belt_count += 1
	var all_buildings := building_count == selected_ids.size()
	var all_belts := belt_count == selected_ids.size()
	var common_commands := "无共同批量命令"
	if all_buildings:
		common_commands = "移动 / 锁定 / 解锁 / 确认删除" if movable_count == building_count else "锁定 / 解锁 / 确认删除"
	elif all_belts:
		common_commands = "堆叠 / 优先级 / 路由 / 监控 / 启停"
	_inspector_title.text = "已选择 %d 项" % selected_ids.size()
	_inspector_details.text = "建筑 %d  线路 %d\n可移动 %d  锁定 %d\n交集命令：%s" % [building_count, belt_count, movable_count, building_count - movable_count, common_commands]
	_input_buffers.text = "交集命令  %s" % common_commands
	_output_buffers.text = "整网同步与升级仅在单选模板线路时显示" if all_belts else "线路配置仅在单选线路时显示"
	_start_connection_button.disabled = true
	_delete_button.disabled = not all_buildings
	_delete_button.text = "确认删除 (%d)" % building_count if all_buildings else "无共同删除"
	_recipe_heading.text = "批量命令"
	_handcraft_quantity.hide()
	if all_buildings:
		_refresh_multi_building_controls(selected_ids)
	elif all_belts:
		_refresh_multi_belt_controls(state, selected_ids)
	else:
		_recipe_list.hide()

func _refresh_multi_building_controls(selected_ids: Array[String]) -> void:
	_recipe_list.show()
	_recipe_list.columns = 2
	var signature := "multi-buildings|%s" % ",".join(selected_ids)
	if signature == _recipe_signature:
		return
	_recipe_signature = signature
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	var all_stations := true
	for id in selected_ids:
		if not _get_game_state().buildings[id].has("station"):
			all_stations = false
	if all_stations:
		var configure := Button.new()
		configure.text = "批量配置物流站"
		configure.pressed.connect(_open_station_panel)
		_recipe_list.add_child(configure)
	for action in [[true, "锁定"], [false, "解锁"]]:
		var button := Button.new()
		button.text = action[1]
		button.custom_minimum_size = Vector2(120, 34)
		button.pressed.connect(_on_batch_lock_pressed.bind(action[0]))
		_recipe_list.add_child(button)

func _refresh_multi_belt_controls(state: GameState, selected_ids: Array[String]) -> void:
	_recipe_list.show()
	_recipe_list.columns = 3
	var configurations: Array[Dictionary] = []
	for belt_id in selected_ids:
		configurations.append(state.get_belt_configuration(belt_id))
	var signature := "multi-belts|%s|%s" % [",".join(selected_ids), JSON.stringify(configurations)]
	if signature == _recipe_signature:
		return
	_recipe_signature = signature
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	for action in [["stack", "堆叠切换"], ["priority", "优先级"], ["route", "路由切换"], ["monitor", "监控开关"], ["enabled", "启停"]]:
		var button := Button.new()
		button.text = action[1]
		button.custom_minimum_size = Vector2(78, 34)
		button.pressed.connect(_on_batch_belt_config_pressed.bind(action[0]))
		_recipe_list.add_child(button)

func _refresh_recipe_controls(_state: GameState, building: Dictionary) -> void:
	_recipe_list.show()
	_recipe_list.columns = 2
	if building.has("station"):
		_handcraft_quantity.hide()
		_recipe_heading.text = "物流站"
		var signature := "station|" + _selected_building_id + str(building.station.slots.map(func(slot): return slot.item_id))
		if signature == _recipe_signature:
			return
		_recipe_signature = signature
		for child in _recipe_list.get_children():
			_recipe_list.remove_child(child)
			child.queue_free()
		var configure := Button.new()
		configure.text = "配置物流站"
		configure.pressed.connect(_open_station_panel)
		_recipe_list.add_child(configure)
		for item in _state.get_building_output_items(_selected_building_id):
			var output := Button.new()
			output.text = "输出：" + DataManager.get_item(item).get("name", item)
			output.pressed.connect(_on_output_item_pressed.bind(item))
			_recipe_list.add_child(output)
		return
	if building.is_empty():
		_refresh_handcraft_controls(_state)
		return
	var definition := DataManager.get_building(String(building.get("type", "")))
	if definition.get("kind", "") == "extractor":
		_refresh_extraction_controls(building, definition)
		return
	_recipe_heading.text = "配方"
	_handcraft_quantity.hide()
	var recipes: Array = []
	recipes = DataManager.get_recipes_for_building(building.get("type", ""))
	var recipe_ids: Array[String] = []
	for recipe in recipes:
		recipe_ids.append(recipe.get("id", ""))
	var signature := "%s|%s|%s|%s" % [_selected_building_id, building.get("recipe_id", ""), building.get("output_item", ""), ",".join(recipe_ids)]
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
		recipe_button.custom_minimum_size = Vector2(120, 34)
		recipe_button.pressed.connect(_on_recipe_pressed.bind(recipe_id))
		_recipe_list.add_child(recipe_button)
	var current_recipe := DataManager.get_recipe(String(building.get("recipe_id", "")))
	var outputs: Array = current_recipe.get("outputs", [])
	if outputs.size() > 1:
		var selected_output := _get_game_state().get_building_output_item(_selected_building_id)
		for output_value in outputs:
			var item_id := String(output_value.get("item_id", ""))
			var item := DataManager.get_item(item_id)
			var output_button := Button.new()
			output_button.text = "%s输出：%s" % ["✓ " if item_id == selected_output else "", item.get("name", item_id)]
			output_button.custom_minimum_size = Vector2(120, 34)
			output_button.pressed.connect(_on_output_item_pressed.bind(item_id))
			_recipe_list.add_child(output_button)

func _refresh_extraction_controls(building: Dictionary, definition: Dictionary) -> void:
	_recipe_heading.text = "采集目标"
	_handcraft_quantity.hide()
	var extraction: Dictionary = definition.get("extraction", {})
	var item_ids: Array = extraction.get("items", [extraction.get("item_id", "")])
	var selected_item := String(building.get("output_item", extraction.get("item_id", "")))
	var signature := "%s|extract|%s|%s" % [_selected_building_id, selected_item, ",".join(item_ids)]
	if signature == _recipe_signature:
		return
	_recipe_signature = signature
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	for item_value in item_ids:
		var item_id := String(item_value)
		var item := DataManager.get_item(item_id)
		var button := Button.new()
		button.text = "%s%s" % ["✓ " if item_id == selected_item else "", item.get("name", item_id)]
		button.custom_minimum_size = Vector2(120, 34)
		button.pressed.connect(_on_extraction_pressed.bind(item_id))
		_recipe_list.add_child(button)

func _on_material_action(action: String) -> void:
	var inventory := InventorySystem.new(_get_game_state())
	var result := inventory.try_supply_recipe(_selected_building_id) if action == "SupplyRecipe" else inventory.try_collect_output(_selected_building_id)
	show_notice(String(result.get("message", "")), "success" if result.get("ok", false) else "error")
	refresh_now()

func _refresh_handcraft_controls(state: GameState) -> void:
	_recipe_heading.text = "手工制造"
	_handcraft_quantity.show()
	_recipe_list.columns = 3
	var quantity := maxi(int(_handcraft_quantity.value), 1)
	var signature := "handcraft|%s|%s|%s|%d" % [JSON.stringify(state.get_active_planet_inventory()), JSON.stringify(state.construction_inventory), JSON.stringify(state.handcraft_queue), quantity]
	if signature == _recipe_signature:
		return
	_recipe_signature = signature
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	var handcraft := HandcraftSystem.new(state)
	for type in StationSystem.TYPES + DysonSphereSystem.BUILDINGS:
		var build_button := Button.new()
		build_button.text = "建造" + _building_name(type)
		build_button.tooltip_text = "已有 %d / 需要 1" % int(state.construction_inventory.get(type, 0))
		build_button.disabled = float(state.construction_inventory.get(type, 0)) < 1
		build_button.pressed.connect(_on_building_pressed.bind(type))
		_recipe_list.add_child(build_button)
	for recipe_id_value in handcraft.get_recipe_ids():
		var recipe_id := String(recipe_id_value)
		var recipe := handcraft.get_recipe(recipe_id)
		var preview := handcraft.preview_craft(recipe_id, quantity)
		var button := Button.new()
		button.text = "%s ×%d" % [recipe.get("name", recipe_id), quantity]
		button.custom_minimum_size = Vector2(80, 34)
		button.clip_text = true
		button.disabled = not preview.get("can_queue", false)
		button.tooltip_text = "%s\n%s" % [recipe.get("name", recipe_id), _format_handcraft_preview(preview)]
		button.pressed.connect(_on_handcraft_pressed.bind(recipe_id))
		_recipe_list.add_child(button)

func _beginner_objective(state: GameState) -> String:
	var progression := ProgressionSystem.new(state)
	var objective := progression.get_current_objective()
	if objective.is_empty():
		return "单人战役\n当前目标已完成"
	var progress := progression.get_objective_progress(String(objective.get("id", "")))
	return "当前目标\n%s  %.0f/%.0f" % [String(objective.get("title", "")), float(progress.get("current", 0.0)), float(progress.get("required", 1.0))]

func _format_buffer(buffer: Dictionary) -> String:
	var item_ids := buffer.keys()
	item_ids.sort()
	var parts: Array[String] = []
	for item_id in item_ids:
		var amount := float(buffer[item_id])
		if amount > 0.0:
			parts.append("%s %.1f" % [item_id, amount])
	return "无" if parts.is_empty() else ", ".join(parts)

func _format_cursor_payload(cursor: Dictionary) -> String:
	var item_id := String(cursor.get("item_id", ""))
	var amount := float(cursor.get("amount", 0.0))
	return "无" if item_id.is_empty() or amount <= 0.0 else "%s %.1f" % [item_id, amount]

func _format_handcraft_queue(queue: Array) -> String:
	if queue.is_empty():
		return "空"
	var job: Dictionary = queue[0]
	var recipe := HandcraftSystem.new(_get_game_state()).get_recipe(String(job.get("recipe_id", "")))
	return "%s ×%d  %.0f%%" % [recipe.get("name", job.get("recipe_id", "")), int(job.get("quantity_remaining", 0)), float(job.get("progress", 0.0)) / maxf(float(recipe.get("duration", 1.0)), 0.0000001) * 100.0]

func _format_handcraft_preview(preview: Dictionary) -> String:
	if not preview.get("ok", false):
		return String(preview.get("message", "配方不可用"))
	var missing: Dictionary = preview.get("missing", {})
	return "材料齐备" if missing.is_empty() else "缺少 %s" % _format_buffer(missing)

func _construction_item_total(state: GameState) -> int:
	var total := 0.0
	for building_type in DOCK_BUILDINGS:
		total += float(state.construction_inventory.get(building_type, 0.0))
	return int(floor(total))

func _construction_stock_summary(state: GameState) -> String:
	var summary := "%02d" % _construction_item_total(state)
	var legacy_credit := int(floor(float(state.construction_inventory.get("legacy_credit", 0.0))))
	return "%s+L%02d" % [summary, legacy_credit] if legacy_credit > 0 else summary

func _refresh_construction_dock(state: GameState) -> void:
	var construction := ConstructionSystem.new(state)
	for building_type in DOCK_BUILDINGS:
		var button := _dock_buttons.get(building_type) as Button
		if button == null:
			continue
		var owned := int(floor(construction.get_owned_count(building_type)))
		var missing_reason := construction.get_missing_reason(building_type)
		var legacy_credit := int(floor(float(state.construction_inventory.get("legacy_credit", 0.0))))
		var legacy_cost := int(ConstructionSystem.LEGACY_COSTS.get(building_type, 0.0))
		button.text = "%s %s\n已有 %d / 需要 1" % [DOCK_SHORTCUTS[building_type], _building_name(building_type), owned]
		if owned < 1 and legacy_credit > 0:
			button.text = "%s %s\n旧额度 %d / 需要 %d" % [DOCK_SHORTCUTS[building_type], _building_name(building_type), legacy_credit, legacy_cost]
		button.disabled = not missing_reason.is_empty()
		button.tooltip_text = DataManager.get_building(building_type).get("description", "") if missing_reason.is_empty() else missing_reason

func _create_panel(node_name: String, color: Color) -> Panel:
	var panel: Panel = Panel.new() if node_name == "Toast" else AdaptivePanel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	add_child(panel)
	return panel

func _create_settings_entry() -> void:
	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.text = "设置"
	settings.position = Vector2(664, 9)
	settings.size = Vector2(58, 34)
	settings.pressed.connect(func(): get_parent().get_node("AppShell").open_settings())
	get_node("TopBar").add_child(settings)
	var save_button := Button.new()
	save_button.name = "SaveButton"
	save_button.text = "立即保存"
	save_button.position = Vector2(728, 9)
	save_button.size = Vector2(90, 34)
	save_button.pressed.connect(func(): GameManager.save_current_game())
	get_node("TopBar").add_child(save_button)
	var save_status := Label.new()
	save_status.name = "SaveStatus"
	save_status.text = GameManager.get_save_status().message
	save_status.position = Vector2(824, 16)
	save_status.size = Vector2(80, 24)
	save_status.clip_text = true
	GameManager.save_status_changed.connect(_on_save_status_changed)
	get_node("TopBar").add_child(save_status)
	_top_status.position.x = 910
	_top_status.size.x = 228
	_top_status.clip_text = true

func apply_device_layout() -> void:
	if get_node_or_null("TopBar") == null: return
	var viewport_size := get_viewport().get_visible_rect().size
	var metrics := DesktopLayout.metrics(viewport_size, LocalSettings.values)
	var enlarged: bool = not metrics.authored
	var left_width: float = metrics.left_width
	var right_width: float = metrics.right_width
	var gap: float = metrics.gap
	var dock_height: float = metrics.dock_height
	var top := get_node("TopBar") as AdaptivePanel
	top.horizontal = true
	top.reflow = enlarged
	top.offset_bottom = metrics.top_height
	for panel_name in ["ResourceRail", "InspectorPanel", "ConstructionDock"]:
		var panel := get_node(panel_name) as AdaptivePanel
		panel.reflow = enlarged
		panel.horizontal = panel_name == "ConstructionDock"
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.offset_top = top.offset_bottom
		panel.offset_bottom = -dock_height
		if panel_name == "ResourceRail": panel.offset_right = left_width - viewport_size.x
		elif panel_name == "InspectorPanel": panel.offset_left = viewport_size.x - right_width
		else:
			panel.offset_left = left_width
			panel.offset_right = -right_width
			panel.offset_top = viewport_size.y - dock_height
			panel.offset_bottom = 0
		panel.arrange()
	for workspace_name in WORKSPACES:
		var workspace := get_node_or_null(workspace_name) as Control
		if workspace == null: continue
		if not workspace.has_meta("device_layout"):
			var authored := {}
			for property in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom", "z_index"]: authored[property] = workspace.get(property)
			workspace.set_meta("device_layout", authored)
		if enlarged:
			workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			workspace.offset_top = top.size.y + 4
			workspace.offset_bottom = -dock_height - 4
			workspace.offset_left = left_width + gap
			workspace.offset_right = -right_width - gap
			workspace.z_index = 7
		else:
			for property in workspace.get_meta("device_layout"): workspace.set(property, workspace.get_meta("device_layout")[property])
		workspace.custom_minimum_size = Vector2.ZERO
	for optional in ["MiniMap", "TutorialOverlay"]:
		var node := get_node_or_null(optional) as Control
		if node != null:
			if optional == "MiniMap":
				if not node.has_meta("device_position"): node.set_meta("device_position", node.position)
				node.size = MiniMap.MINIMAP_SIZE * float(metrics.automatic_scale)
				node.position = Vector2(viewport_size.x - right_width - node.size.x - gap, top.size.y + 10) if enlarged else Vector2(node.get_meta("device_position"))
				node.show()
			else: node.visible = not enlarged
	top.arrange()

func close_active_workspace() -> bool:
	for workspace_name in WORKSPACES:
		var workspace := get_node_or_null(workspace_name) as Control
		if workspace != null and workspace.visible:
			workspace.hide()
			get_parent().get_node("AppShell")._focus_first(get_node("TopBar"))
			return true
	return false

func get_canvas_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var top: Control = get_node("TopBar")
	var left: Control = get_node("ResourceRail")
	var right: Control = get_node("InspectorPanel")
	return Rect2(left.size.x, top.size.y, maxf(0, right.position.x - left.size.x), maxf(0, viewport_size.y - top.size.y - get_node("ConstructionDock").size.y))

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

func _building_button_name(building_type: String) -> String:
	var result := ""
	for part in building_type.split("_", false):
		result += part.capitalize().replace(" ", "")
	return "%sButton" % result

func _current_selected_entity_ids() -> Array[String]:
	var input_handler := _get_input_handler()
	if input_handler != null and input_handler.has_method("get_selected_entity_ids"):
		var shared: Array = input_handler.call("get_selected_entity_ids")
		var normalized: Array[String] = []
		for id_value in shared:
			var entity_id := String(id_value)
			var state := _get_game_state()
			var entity: Dictionary = state.buildings.get(entity_id, state.connections.get(entity_id, {}))
			if not entity.is_empty() and String(entity.get("planet_id", "")) == state.active_planet_id:
				normalized.append(entity_id)
		return normalized
	if not _selected_entity_ids.is_empty():
		var local_selection: Array[String] = []
		local_selection.assign(_selected_entity_ids)
		return local_selection
	var fallback: Array[String] = []
	if not _selected_building_id.is_empty():
		fallback.append(_selected_building_id)
	return fallback

func _current_selected_building_ids() -> Array[String]:
	var result: Array[String] = []
	for entity_id in _current_selected_entity_ids():
		if _get_game_state().buildings.has(entity_id):
			result.append(entity_id)
	return result

func _belt_tier_label(tier: String) -> String:
	match tier:
		"conveyor_belt_mk2":
			return "Mk.II"
		"conveyor_belt_mk3":
			return "Mk.III"
		_:
			return "Mk.I"

func _get_input_handler() -> Node:
	var parent := get_parent()
	return parent.get_node_or_null("InputHandler") if parent != null else null

func _get_game_state() -> GameState:
	return GameManager.get_game_state()

func _active_building_count(state: GameState) -> int:
	var count := 0
	for building in state.buildings.values():
		if String(building.get("planet_id", "")) == state.active_planet_id:
			count += 1
	return count

func _active_connection_count(state: GameState) -> int:
	var count := 0
	for connection in state.connections.values():
		if String(connection.get("planet_id", "")) == state.active_planet_id:
			count += 1
	return count

func _open_station_panel() -> void:
	var ids: Array = []
	var state := _get_game_state()
	for id in _current_selected_building_ids():
		if not state.buildings[id].has("station"):
			show_notice("请选择物流站", "error")
			return
		ids.append(id)
	if ids.is_empty():
		return
	show_exclusive_workspace("StationPanel")
	get_node("StationPanel").open_stations(ids)

func _on_save_status_changed(status: Dictionary) -> void:
	var label := get_node_or_null("TopBar/SaveStatus") as Label
	if label == null: return
	label.text = status.message
	label.tooltip_text = status.message
