class_name GalaxyMap
extends Control

signal explore_requested(system_id: String)
signal colonize_requested(planet_id: String)
signal travel_requested(planet_id: String)

const PANEL_DARK := Color("#101715")
const ACCENT_CYAN := Color("#62b5ae")
const ACCENT_GREEN := Color("#70bb85")
const ACCENT_YELLOW := Color("#e1b452")
const TEXT_MUTED := Color("#9fb1aa")

var game_state: GameState
var galaxy_system: GalaxySystem
var planet_system: PlanetSystem

var _selected_system_id := ""
var _selected_planet_id := ""
var _system_signature := ""
var _planet_signature := ""
var _search: LineEdit
var _system_scroll: ScrollContainer
var _system_list: VBoxContainer
var _planet_scroll: ScrollContainer
var _planet_list: VBoxContainer
var _details_scroll: ScrollContainer
var _system_heading: Label
var _planet_heading: Label
var _description: Label
var _resource_summary: Label
var _colonization_summary: Label
var _industry_summary: Label
var _explore_button: Button
var _colonize_button: Button
var _travel_button: Button

func _ready() -> void:
	_build_ui()
	if not EventBus.simulation_updated.is_connected(refresh_now):
		EventBus.simulation_updated.connect(refresh_now)
	refresh_now()

func configure(state: GameState, galaxy: GalaxySystem, planets: PlanetSystem) -> void:
	game_state = state
	galaxy_system = galaxy
	planet_system = planets
	refresh_now()

func refresh_now() -> void:
	if _search == null or galaxy_system == null or planet_system == null or game_state == null:
		return
	var system_scroll_value := _system_scroll.scroll_vertical
	var planet_scroll_value := _planet_scroll.scroll_vertical
	var details_scroll_value := _details_scroll.scroll_vertical
	var results := galaxy_system.search(_search.text)
	var system_ids: Array = results.get("system_ids", []).duplicate()
	for planet_id_value in results.get("planet_ids", []):
		var parent_id := String(galaxy_system.get_planet(String(planet_id_value)).get("system_id", ""))
		if not parent_id.is_empty() and not system_ids.has(parent_id):
			system_ids.append(parent_id)
	system_ids.sort()
	if _selected_system_id.is_empty() or not galaxy_system.system_exists(_selected_system_id):
		_selected_system_id = String(system_ids[0]) if not system_ids.is_empty() else ""
	_refresh_system_buttons(system_ids)
	var planet_ids: Array = galaxy_system.get_system_planets(_selected_system_id)
	if not _search.text.strip_edges().is_empty():
		var matching_planets: Array = results.get("planet_ids", [])
		var filtered: Array = []
		for planet_id_value in planet_ids:
			if matching_planets.has(planet_id_value) or results.get("system_ids", []).has(_selected_system_id):
				filtered.append(planet_id_value)
		planet_ids = filtered
	if _selected_planet_id.is_empty() or not galaxy_system.get_system_planets(_selected_system_id).has(_selected_planet_id):
		_selected_planet_id = String(planet_ids[0]) if not planet_ids.is_empty() else ""
	_refresh_planet_buttons(planet_ids)
	_refresh_details()
	_system_scroll.scroll_vertical = system_scroll_value
	_planet_scroll.scroll_vertical = planet_scroll_value
	_details_scroll.scroll_vertical = details_scroll_value

func get_selected_system_id() -> String:
	return _selected_system_id

func get_selected_planet_id() -> String:
	return _selected_planet_id

func _build_ui() -> void:
	if get_node_or_null("Margin") != null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = PANEL_DARK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 10)
	margin.add_child(columns)

	var system_pane := _make_pane("SystemPane", 155.0)
	columns.add_child(system_pane)
	system_pane.add_child(_make_heading("Title", "星系目录"))
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "搜索名称 / 代码 / 资源 / 环境"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_changed)
	system_pane.add_child(_search)
	_system_scroll = ScrollContainer.new()
	_system_scroll.name = "SystemScroll"
	_system_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_system_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	system_pane.add_child(_system_scroll)
	_system_list = VBoxContainer.new()
	_system_list.name = "SystemList"
	_system_list.custom_minimum_size = Vector2(135, 520)
	_system_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_scroll.add_child(_system_list)

	var planet_pane := _make_pane("PlanetPane", 150.0)
	columns.add_child(planet_pane)
	planet_pane.add_child(_make_heading("Title", "行星目录"))
	_planet_scroll = ScrollContainer.new()
	_planet_scroll.name = "PlanetScroll"
	_planet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_planet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	planet_pane.add_child(_planet_scroll)
	_planet_list = VBoxContainer.new()
	_planet_list.name = "PlanetList"
	_planet_list.custom_minimum_size = Vector2(130, 520)
	_planet_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_planet_scroll.add_child(_planet_list)

	var details_pane := _make_pane("DetailsPane", 250.0)
	details_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(details_pane)
	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "DetailsScroll"
	_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_pane.add_child(_details_scroll)
	var details := VBoxContainer.new()
	details.name = "Details"
	details.custom_minimum_size = Vector2(250, 560)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	_details_scroll.add_child(details)
	_system_heading = _make_heading("SystemHeading", "选择星系")
	details.add_child(_system_heading)
	_planet_heading = _make_heading("PlanetHeading", "选择行星")
	details.add_child(_planet_heading)
	_description = _make_wrapped_label("Description", TEXT_MUTED)
	details.add_child(_description)
	_resource_summary = _make_wrapped_label("ResourceSummary", ACCENT_CYAN)
	details.add_child(_resource_summary)
	_colonization_summary = _make_wrapped_label("ColonizationSummary", ACCENT_YELLOW)
	details.add_child(_colonization_summary)
	_industry_summary = _make_wrapped_label("IndustrySummary", ACCENT_GREEN)
	details.add_child(_industry_summary)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 6)
	details_pane.add_child(actions)
	_explore_button = _make_action_button("ExploreButton", "勘探", _on_explore_pressed)
	_colonize_button = _make_action_button("ColonizeButton", "殖民", _on_colonize_pressed)
	_travel_button = _make_action_button("TravelButton", "前往", _on_travel_pressed)
	actions.add_child(_explore_button)
	actions.add_child(_colonize_button)
	actions.add_child(_travel_button)

func _make_pane(node_name: String, minimum_width: float) -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.name = node_name
	pane.custom_minimum_size = Vector2(minimum_width, 0)
	pane.add_theme_constant_override("separation", 8)
	return pane

func _make_heading(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_color_override("font_color", ACCENT_YELLOW)
	label.add_theme_font_size_override("font_size", 16)
	return label

func _make_wrapped_label(node_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 76
	return label

func _make_action_button(node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _refresh_system_buttons(system_ids: Array) -> void:
	var signature := JSON.stringify(system_ids)
	if signature == _system_signature:
		_update_pressed_buttons(_system_list, _selected_system_id)
		return
	_system_signature = signature
	_clear_children(_system_list)
	for system_id_value in system_ids:
		var system_id := String(system_id_value)
		var summary := galaxy_system.get_system_summary(system_id)
		var button := Button.new()
		button.name = "System_%s" % system_id
		button.text = "%s\n%s" % [summary.get("name", system_id), summary.get("code", system_id)]
		button.tooltip_text = String(summary.get("description", ""))
		button.toggle_mode = true
		button.button_pressed = system_id == _selected_system_id
		button.pressed.connect(_on_system_selected.bind(system_id))
		_system_list.add_child(button)

func _refresh_planet_buttons(planet_ids: Array) -> void:
	var signature := "%s|%s" % [_selected_system_id, JSON.stringify(planet_ids)]
	if signature == _planet_signature:
		_update_pressed_buttons(_planet_list, _selected_planet_id)
		return
	_planet_signature = signature
	_clear_children(_planet_list)
	for planet_id_value in planet_ids:
		var planet_id := String(planet_id_value)
		var summary := galaxy_system.get_planet_summary(planet_id)
		var button := Button.new()
		button.name = "Planet_%s" % planet_id
		button.text = "%s\n%s" % [summary.get("name", planet_id), summary.get("code", planet_id)]
		button.toggle_mode = true
		button.button_pressed = planet_id == _selected_planet_id
		button.pressed.connect(_on_planet_selected.bind(planet_id))
		_planet_list.add_child(button)

func _refresh_details() -> void:
	var system := galaxy_system.get_system_summary(_selected_system_id)
	var planet := galaxy_system.get_planet_summary(_selected_planet_id)
	_system_heading.text = "%s · %s" % [system.get("name", "选择星系"), system.get("star_type", "")]
	_planet_heading.text = "%s · %s" % [planet.get("name", "选择行星"), planet.get("planet_type", "")]
	_description.text = String(system.get("description", ""))
	_resource_summary.text = "资源\n%s" % _resource_names(planet.get("resource_item_ids", []))
	var colonization: Dictionary = planet.get("colonization", {})
	_colonization_summary.text = "殖民\n状态：%s\n成本：%s" % ["活动" if colonization.get("active", false) else ("已殖民" if colonization.get("colonized", false) else "未殖民"), _cost_text(colonization.get("requirements", {}))]
	var industry: Dictionary = planet.get("industry", {})
	_industry_summary.text = "工业\n建筑 %d · 线路 %d · 资源点 %d\n托盘：%s" % [int(industry.get("building_count", 0)), int(industry.get("connection_count", 0)), int(industry.get("resource_site_count", 0)), _inventory_text(industry.get("inventory", {}))]
	_refresh_action_states(system, planet)

func _refresh_action_states(system: Dictionary, planet: Dictionary) -> void:
	var requirements: Dictionary = system.get("exploration", {}).get("requirements", {})
	_set_button_availability(_explore_button, not requirements.is_empty() and requirements.get("available", false), String(requirements.get("message", "请选择星系")))
	var colonize_availability := _colonization_availability(planet)
	_set_button_availability(_colonize_button, colonize_availability.get("ok", false), String(colonize_availability.get("message", "请选择行星")))
	var travel_availability := _travel_availability(planet)
	_set_button_availability(_travel_button, travel_availability.get("ok", false), String(travel_availability.get("message", "请选择行星")))

func _colonization_availability(planet: Dictionary) -> Dictionary:
	if planet.is_empty():
		return {"ok": false, "message": "目标行星不存在"}
	var planet_id := String(planet.get("id", ""))
	if game_state.colonized_planet_ids.has(planet_id):
		return {"ok": false, "message": "目标行星已殖民"}
	if not game_state.explored_system_ids.has(String(planet.get("system_id", ""))):
		return {"ok": false, "message": "目标星系尚未探索"}
	var technology_id := String(planet.get("required_technology_id", ""))
	if not technology_id.is_empty() and not game_state.completed_technologies.has(technology_id):
		return {"ok": false, "message": "缺少殖民所需科技"}
	var requirements: Dictionary = planet.get("colonization", {}).get("requirements", {})
	for item_id_value in requirements.get("vehicles", {}):
		var item_id := String(item_id_value)
		if float(game_state.portable_fleet.get(item_id, 0.0)) + 0.0000001 < float(requirements["vehicles"][item_id]):
			return {"ok": false, "message": "全局物流载具不足"}
	for item_id_value in requirements.get("materials", {}):
		var item_id := String(item_id_value)
		if float(game_state.planet_inventory.get(item_id, 0.0)) + 0.0000001 < float(requirements["materials"][item_id]):
			return {"ok": false, "message": "活动行星材料不足"}
	return {"ok": true, "message": "可以殖民"}

func _travel_availability(planet: Dictionary) -> Dictionary:
	if planet.is_empty():
		return {"ok": false, "message": "目标行星不存在"}
	var planet_id := String(planet.get("id", ""))
	if not game_state.colonized_planet_ids.has(planet_id):
		return {"ok": false, "message": "目标行星尚未殖民"}
	if not game_state.explored_system_ids.has(String(planet.get("system_id", ""))):
		return {"ok": false, "message": "目标星系尚未探索"}
	if not game_state.planet_inventories.has(planet_id):
		return {"ok": false, "message": "目标行星没有可用托盘"}
	return {"ok": true, "message": "可以前往"}

func _set_button_availability(button: Button, available: bool, reason: String) -> void:
	button.disabled = not available
	button.tooltip_text = "" if available else reason

func _resource_names(item_ids: Array) -> String:
	var names: Array[String] = []
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		names.append(String(DataManager.get_item(item_id).get("name", item_id)))
	return "、".join(names) if not names.is_empty() else "无目录资源"

func _cost_text(requirements: Dictionary) -> String:
	var costs: Array[String] = []
	for group_name in ["materials", "vehicles"]:
		var group: Dictionary = requirements.get(group_name, {})
		var ids := group.keys()
		ids.sort()
		for item_id_value in ids:
			var item_id := String(item_id_value)
			costs.append("%s %.0f" % [DataManager.get_item(item_id).get("name", item_id), float(group[item_id])])
	return "、".join(costs) if not costs.is_empty() else "无"

func _inventory_text(inventory: Dictionary) -> String:
	var ids := inventory.keys()
	ids.sort()
	var entries: Array[String] = []
	for item_id_value in ids:
		var item_id := String(item_id_value)
		entries.append("%s %.1f" % [DataManager.get_item(item_id).get("name", item_id), float(inventory[item_id])])
	return "、".join(entries) if not entries.is_empty() else "空"

func _update_pressed_buttons(parent: VBoxContainer, selected_id: String) -> void:
	for child in parent.get_children():
		if child is Button:
			child.button_pressed = not selected_id.is_empty() and child.name.ends_with(selected_id)

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _on_search_changed(_query: String) -> void:
	_system_signature = ""
	_planet_signature = ""
	refresh_now()

func _on_system_selected(system_id: String) -> void:
	_selected_system_id = system_id
	var planet_ids := galaxy_system.get_system_planets(system_id)
	if not planet_ids.has(_selected_planet_id):
		_selected_planet_id = String(planet_ids[0]) if not planet_ids.is_empty() else ""
	_planet_signature = ""
	refresh_now()

func _on_planet_selected(planet_id: String) -> void:
	_selected_planet_id = planet_id
	refresh_now()

func _on_explore_pressed() -> void:
	explore_requested.emit(_selected_system_id)

func _on_colonize_pressed() -> void:
	colonize_requested.emit(_selected_planet_id)

func _on_travel_pressed() -> void:
	travel_requested.emit(_selected_planet_id)
