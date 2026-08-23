class_name FactoryWorkspaceUI
extends CanvasLayer

const TOP_BAR_HEIGHT := 52.0
const RESOURCE_RAIL_WIDTH := 216.0
const INSPECTOR_WIDTH := 286.0
const CONSTRUCTION_DOCK_HEIGHT := 92.0

const PANEL_DARK := Color("#101715")
const PANEL_LIGHT := Color("#151e1b")
const ACCENT_CYAN := Color("#62b5ae")
const ACCENT_GREEN := Color("#70bb85")
const ACCENT_YELLOW := Color("#e1b452")
const ACCENT_ERROR := Color("#df7666")

const DOCK_BUILDINGS := ["miner", "smelter", "assembling_machine_mk1", "power_generator"]

var _selected_building_id := ""
var _selected_building_type := ""
var _top_status: Label
var _resource_summary: Label
var _inspector_title: Label
var _recipe_list: VBoxContainer
var _construction_points: Label
var _toast_label: Label

func _ready() -> void:
	_create_workspace()
	refresh_now()

func set_selected_building(building_id: String) -> void:
	_selected_building_id = building_id
	var building := _get_game_state().get_building(building_id)
	_selected_building_type = building.get("type", "")
	refresh_now()

func get_selected_building_type() -> String:
	return _selected_building_type

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
	get_node("Toast").visible = not message.is_empty()

func is_pointer_over_ui(screen_position: Vector2) -> bool:
	for node_name in ["TopBar", "ResourceRail", "InspectorPanel", "ConstructionDock", "Toast"]:
		var region := get_node_or_null(node_name) as Control
		if region != null and region.visible and region.get_global_rect().has_point(screen_position):
			return true
	return false

func refresh_now() -> void:
	var state := _get_game_state()
	_top_status.text = "FACTORY // ONLINE"
	_resource_summary.text = "CONSTRUCTION\n\nPOINTS  %02d\nBUILDINGS  %02d" % [state.construction_points, state.buildings.size()]
	_construction_points.text = "POINTS  %02d" % state.construction_points
	_refresh_inspector(state)

func _on_building_pressed(building_type: String) -> void:
	_selected_building_id = ""
	_selected_building_type = building_type
	EventBus.placement_requested.emit(building_type)
	show_notice("PLACE %s" % _building_name(building_type), "info")
	refresh_now()

func _on_recipe_pressed(recipe_id: String) -> void:
	if _selected_building_id.is_empty():
		return
	if _get_game_state().set_entity_recipe(_selected_building_id, recipe_id):
		show_notice("RECIPE CONFIGURED", "success")
	else:
		show_notice("RECIPE UNAVAILABLE", "error")
	refresh_now()

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
	_top_status = _create_label("Status", "", 16, ACCENT_CYAN)
	_top_status.position = Vector2(18, 15)
	top_bar.add_child(_top_status)

func _create_resource_rail() -> void:
	var resource_rail := _create_panel("ResourceRail", PANEL_LIGHT)
	resource_rail.anchor_bottom = 1.0
	resource_rail.offset_top = TOP_BAR_HEIGHT
	resource_rail.offset_right = RESOURCE_RAIL_WIDTH
	resource_rail.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT
	_resource_summary = _create_label("Summary", "", 14, ACCENT_GREEN)
	_resource_summary.position = Vector2(18, 18)
	resource_rail.add_child(_resource_summary)

func _create_inspector_panel() -> void:
	var inspector := _create_panel("InspectorPanel", PANEL_LIGHT)
	inspector.anchor_left = 1.0
	inspector.anchor_right = 1.0
	inspector.anchor_bottom = 1.0
	inspector.offset_left = -INSPECTOR_WIDTH
	inspector.offset_top = TOP_BAR_HEIGHT
	inspector.offset_bottom = -CONSTRUCTION_DOCK_HEIGHT
	_inspector_title = _create_label("Title", "INSPECTOR", 16, ACCENT_YELLOW)
	_inspector_title.position = Vector2(18, 18)
	inspector.add_child(_inspector_title)
	_recipe_list = VBoxContainer.new()
	_recipe_list.name = "RecipeList"
	_recipe_list.position = Vector2(18, 58)
	_recipe_list.size = Vector2(INSPECTOR_WIDTH - 36.0, 260.0)
	inspector.add_child(_recipe_list)

func _create_construction_dock() -> void:
	var dock := _create_panel("ConstructionDock", PANEL_DARK)
	dock.anchor_left = 0.0
	dock.anchor_right = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = RESOURCE_RAIL_WIDTH
	dock.offset_right = -INSPECTOR_WIDTH
	dock.offset_top = -CONSTRUCTION_DOCK_HEIGHT
	_construction_points = _create_label("Points", "", 13, ACCENT_YELLOW)
	_construction_points.position = Vector2(18, 14)
	dock.add_child(_construction_points)
	var buttons := HBoxContainer.new()
	buttons.name = "BuildingButtons"
	buttons.position = Vector2(132, 13)
	buttons.size = Vector2(600, 64)
	buttons.add_theme_constant_override("separation", 8)
	dock.add_child(buttons)
	for building_type in DOCK_BUILDINGS:
		var button := Button.new()
		button.name = "%sButton" % building_type.capitalize()
		button.text = _building_name(building_type)
		button.custom_minimum_size = Vector2(110, 56)
		button.pressed.connect(_on_building_pressed.bind(building_type))
		buttons.add_child(button)

func _create_toast() -> void:
	var toast := _create_panel("Toast", PANEL_DARK)
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -150.0
	toast.offset_right = 150.0
	toast.offset_top = TOP_BAR_HEIGHT + 14.0
	toast.offset_bottom = TOP_BAR_HEIGHT + 52.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _create_label("Message", "", 14, ACCENT_CYAN)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	toast.add_child(_toast_label)
	toast.hide()

func _refresh_inspector(state: GameState) -> void:
	for child in _recipe_list.get_children():
		child.queue_free()
	if _selected_building_id.is_empty():
		_inspector_title.text = "INSPECTOR"
		return
	var building := state.get_building(_selected_building_id)
	if building.is_empty():
		_inspector_title.text = "INSPECTOR"
		return
	_inspector_title.text = state.get_building_display_name(_selected_building_id).to_upper()
	for recipe in DataManager.get_recipes_for_building(building.get("type", "")):
		var recipe_button := Button.new()
		recipe_button.text = recipe.get("name", recipe.get("id", ""))
		recipe_button.pressed.connect(_on_recipe_pressed.bind(recipe.get("id", "")))
		_recipe_list.add_child(recipe_button)

func _create_panel(node_name: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
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
