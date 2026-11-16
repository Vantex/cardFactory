class_name GalaxyMap
extends ScrollContainer

signal explore_requested(system_id: String)
signal colonize_requested(planet_id: String)
signal travel_requested(planet_id: String)
signal fleet_transfer_requested(item_id: String, amount: int)

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
var _fleet_button: Button
var _profile_summary: Label
var _source_controls: VBoxContainer
var _local_name: LineEdit
var _local_note: LineEdit
var _local_tags: LineEdit
var _system_name: LineEdit
var _tray_limit: SpinBox
var _discard_item: OptionButton
var _discard_amount: SpinBox
var _discard_dialog: ConfirmationDialog
var _discard_planet := ""
var _discard_selected := ""
var _discard_count := 0.0
var _discard_state: GameState
var _role: OptionButton
var _metadata_notice: Label
var _editing_planet_id := ""
var _editing_system_id := ""

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
	if not system_ids.has(_selected_system_id):
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
	if not planet_ids.has(_selected_planet_id):
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
	var background := StyleBoxFlat.new()
	background.bg_color = PANEL_DARK
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_profile_summary = _make_wrapped_label("IndustrialProfile", TEXT_MUTED)
	details.add_child(_profile_summary)
	_source_controls = VBoxContainer.new()
	_source_controls.name = "SourceWorldControls"
	details.add_child(_source_controls)
	_local_name = _metadata_input("PlanetLocalName", "行星自定义名称（32 字）")
	_local_note = _metadata_input("PlanetLocalNote", "本地备注（240 字）")
	_local_tags = _metadata_input("PlanetLocalTags", "本地标签，用逗号分隔")
	_role = OptionButton.new()
	_role.name = "PlanetIndustryRole"
	var role_names := ["自动识别", "采矿前哨", "冶炼基地", "制造中心", "化工基地", "科研中心", "物流枢纽", "能源基地"]
	for title in role_names: _role.add_item(title)
	_source_controls.add_child(_role)
	_role.item_selected.connect(func(index):
		var result := SourceGalaxySystem.new(game_state).set_role(_selected_planet_id, SourceGalaxySystem.ROLES[index])
		_metadata_notice.text = result.message
		refresh_now())
	_source_controls.add_child(_make_action_button("SavePlanetMetadata", "保存行星说明", _save_planet_metadata))
	_system_name = _metadata_input("SystemLocalName", "星系自定义名称（32 字）")
	_source_controls.add_child(_make_action_button("SaveSystemMetadata", "保存星系名称", _save_system_metadata))
	_tray_limit = SpinBox.new()
	_tray_limit.name = "PlanetTrayLimit"
	_tray_limit.min_value = PlanetTraySystem.MIN_LIMIT
	_tray_limit.max_value = PlanetTraySystem.MAX_LIMIT
	_tray_limit.step = 1000
	_tray_limit.prefix = "单物品容量 "
	_source_controls.add_child(_tray_limit)
	_source_controls.add_child(_make_action_button("SavePlanetTrayLimit", "设置托盘容量", func():
		_metadata_notice.text = PlanetTraySystem.new(game_state).set_limit(_selected_planet_id, _tray_limit.value).message))
	_discard_item = OptionButton.new()
	_discard_item.name = "DiscardTrayItem"
	for item in DataManager.all_items:
		_discard_item.add_item(DataManager.get_item(item).get("name", item))
		_discard_item.set_item_metadata(_discard_item.item_count - 1, item)
	_source_controls.add_child(_discard_item)
	_discard_amount = SpinBox.new()
	_discard_amount.min_value = 1
	_discard_amount.max_value = PlanetTraySystem.MAX_LIMIT
	_discard_amount.value = 1
	_source_controls.add_child(_discard_amount)
	_source_controls.add_child(_make_action_button("DiscardTrayStock", "丢弃托盘物料…", func():
		_discard_state = game_state
		_discard_planet = _selected_planet_id
		_discard_selected = str(_discard_item.get_item_metadata(_discard_item.selected))
		_discard_count = _discard_amount.value
		_discard_dialog.dialog_text = "确认丢弃 %s × %d？丢弃后不能恢复。" % [DataManager.get_item(_discard_selected).name, _discard_count]
		_discard_dialog.popup_centered()))
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.name = "DiscardTrayConfirmation"
	_discard_dialog.confirmed.connect(_confirm_tray_discard)
	_discard_dialog.canceled.connect(_clear_tray_discard)
	add_child(_discard_dialog)
	_metadata_notice = _make_wrapped_label("MetadataNotice", ACCENT_YELLOW)
	_source_controls.add_child(_metadata_notice)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 6)
	details_pane.add_child(actions)
	_explore_button = _make_action_button("ExploreButton", "勘探", _on_explore_pressed)
	_fleet_button = _make_action_button("FleetButton", "载具入队", _on_fleet_pressed)
	_colonize_button = _make_action_button("ColonizeButton", "殖民", _on_colonize_pressed)
	_travel_button = _make_action_button("TravelButton", "前往", _on_travel_pressed)
	actions.add_child(_explore_button)
	actions.add_child(_fleet_button)
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
	var exploration: Dictionary = system.get("exploration", {})
	_description.text = "%s\n距离 %.1f 光年 · 勘探 %.0f%%\n环境倍率：太阳能 %.2f×" % [String(system.get("description", "")), float(system.get("distance", 0.0)), float(exploration.get("progress", 0.0)) * 100.0, float(planet.get("solar_multiplier", 1.0))]
	_resource_summary.text = "资源\n%s" % _resource_site_text(planet.get("resource_sites", []))
	var colonization: Dictionary = planet.get("colonization", {})
	_colonization_summary.text = "殖民\n状态：%s\n成本：%s" % ["活动" if colonization.get("active", false) else ("已殖民" if colonization.get("colonized", false) else "未殖民"), _cost_text(colonization.get("requirements", {}))]
	if not game_state.source_galaxy.is_empty(): _colonization_summary.text += "\n" + String(colonization.get("source_requirements", {}).get("reason", ""))
	var industry: Dictionary = planet.get("industry", {})
	_industry_summary.text = "工业\n建筑 %d · 运行 %d · 阻塞 %d · 线路 %d · 资源点 %d\n发电 %.1f · 需求 %.1f\n托盘：%s" % [int(industry.get("building_count", 0)), int(industry.get("running_count", 0)), int(industry.get("blocked_count", 0)), int(industry.get("connection_count", 0)), int(industry.get("resource_site_count", 0)), float(industry.get("generation", 0.0)), float(industry.get("demand", 0.0)), _inventory_text(industry.get("inventory", {}))]
	_source_controls.visible = not game_state.source_galaxy.is_empty()
	_profile_summary.visible = _source_controls.visible
	if _source_controls.visible and not planet.is_empty():
		var profile: Dictionary = planet.get("industrial_profile", {})
		var orbital := []
		for item in profile.orbitalYields: orbital.append("%s %.2f / 秒" % [DataManager.get_item(item).get("name", item), profile.orbitalYields[item]])
		var ocean: String = {"water": "水", "sulfuric-acid": "硫酸", "ice": "冰", "none": "无", "salt-water": "盐水"}.get(profile.oceanType, profile.oceanType)
		_profile_summary.text = "%s\n风力 %.2f× · 地热 %.2f× · 采矿 %.2f×\n储量 %.2f× · 航行 %.2f× · 轨道采集 %.2f×\n海洋：%s · 恒星光度 %.2f×\n轨道资源：%s" % [profile.specializationName, profile.windMultiplier, profile.geothermalMultiplier, profile.miningMultiplier, profile.reserveScale, profile.travelTimeMultiplier, profile.orbitalYieldMultiplier, ocean, system.get("luminosity", 1.0), "、".join(orbital) if not orbital.is_empty() else "无"]
		if _editing_planet_id != _selected_planet_id:
			_editing_planet_id = _selected_planet_id
			_tray_limit.value = PlanetTraySystem.new(game_state).limit(_selected_planet_id)
			var metadata: Dictionary = game_state.source_galaxy.planetMetadata.get(_selected_planet_id, {})
			_local_name.text = metadata.get("customName", "")
			_local_note.text = metadata.get("note", "")
			_local_tags.text = ", ".join(metadata.get("tags", []))
			_role.select(SourceGalaxySystem.ROLES.find(planet.get("industry_role", "auto")))
		if _editing_system_id != _selected_system_id:
			_editing_system_id = _selected_system_id
			_system_name.text = game_state.source_galaxy.systemMetadata.get(_selected_system_id, {}).get("customName", "")
	_refresh_action_states(system, planet)

func _metadata_input(node_name: String, placeholder: String) -> LineEdit:
	var control := LineEdit.new()
	control.name = node_name
	control.placeholder_text = placeholder
	_source_controls.add_child(control)
	return control

func _confirm_tray_discard() -> void:
	if _discard_state == null or _discard_state != game_state:
		_metadata_notice.text = "工厂会话已变化，未执行丢弃"
		_clear_tray_discard()
		return
	_metadata_notice.text = PlanetTraySystem.new(game_state).discard(_discard_planet, _discard_selected, _discard_count, true).message
	_clear_tray_discard()
	_refresh_details()

func _clear_tray_discard() -> void:
	_discard_state = null
	_discard_planet = ""
	_discard_selected = ""
	_discard_count = 0.0

func _save_planet_metadata() -> void:
	var tags := []
	for part in _local_tags.text.replace("，", ",").split(",", false):
		tags.append(part)
	var result := SourceGalaxySystem.new(game_state).set_metadata(_selected_planet_id, _local_name.text, _local_note.text, tags)
	_metadata_notice.text = result.message
	_system_signature = ""
	_planet_signature = ""
	refresh_now()

func _save_system_metadata() -> void:
	var result := SourceGalaxySystem.new(game_state).set_metadata(_selected_system_id, _system_name.text, "", [], true)
	_metadata_notice.text = result.message
	_system_signature = ""
	_planet_signature = ""
	refresh_now()

func _refresh_action_states(system: Dictionary, planet: Dictionary) -> void:
	var requirements: Dictionary = system.get("exploration", {}).get("requirements", {})
	_set_button_availability(_explore_button, not requirements.is_empty() and requirements.get("available", false), String(requirements.get("message", "请选择星系")))
	var colonize_availability := _colonization_availability(planet)
	var fleet_availability := _fleet_availability(planet)
	_set_button_availability(_fleet_button, fleet_availability.get("ok", false), String(fleet_availability.get("message", "请选择需要载具的行星")))
	_set_button_availability(_colonize_button, colonize_availability.get("ok", false), String(colonize_availability.get("message", "请选择行星")))
	var travel_availability := _travel_availability(planet)
	_set_button_availability(_travel_button, travel_availability.get("ok", false), String(travel_availability.get("message", "请选择行星")))

func _colonization_availability(planet: Dictionary) -> Dictionary:
	if planet.is_empty():
		return {"ok": false, "message": "目标行星不存在"}
	if not game_state.source_galaxy.is_empty():
		var requirements: Dictionary = planet.get("colonization", {}).get("source_requirements", {})
		return {"ok": requirements.get("status") == "ready", "message": requirements.get("reason", "请选择行星")}
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
	if not game_state.source_galaxy.is_empty():
		var available := planet_system.is_source_planet_colonized(planet_id) and galaxy_system.is_source_system_unlocked(String(planet.get("system_id", ""))) and game_state.active_planet_id != planet_id
		return {"ok": available, "message": "可以前往" if available else "目标行星不可前往或已是活动行星"}
	if not game_state.colonized_planet_ids.has(planet_id):
		return {"ok": false, "message": "目标行星尚未殖民"}
	if not game_state.explored_system_ids.has(String(planet.get("system_id", ""))):
		return {"ok": false, "message": "目标星系尚未探索"}
	if not game_state.planet_inventories.has(planet_id):
		return {"ok": false, "message": "目标行星没有可用托盘"}
	return {"ok": true, "message": "可以前往"}

func _fleet_availability(planet: Dictionary) -> Dictionary:
	if not game_state.source_galaxy.is_empty():
		for item in ["logistics_drone", "logistics_vessel"]:
			var amount := int(floorf(float(game_state.planet_inventory.get(item, 0))))
			if amount > 0: return {"ok": true, "message": "转入全局随身编队", "item_id": item, "amount": amount}
		return {"ok": false, "message": "活动行星托盘中没有可入队的载具"}
	if planet.is_empty():
		return {"ok": false, "message": "目标行星不存在"}
	var requirements: Dictionary = planet.get("colonization", {}).get("requirements", {})
	var vehicle_ids: Array = requirements.get("vehicles", {}).keys()
	vehicle_ids.sort()
	for item_id_value in vehicle_ids:
		var item_id := String(item_id_value)
		var required := int(requirements["vehicles"][item_id])
		var missing := maxi(required - int(game_state.portable_fleet.get(item_id, 0)), 0)
		if missing <= 0:
			continue
		if float(game_state.planet_inventory.get(item_id, 0.0)) + 0.0000001 < float(missing):
			return {"ok": false, "message": "活动行星托盘中的%s不足" % DataManager.get_item(item_id).get("name", item_id), "item_id": item_id, "amount": missing}
		return {"ok": true, "message": "转入殖民所需载具", "item_id": item_id, "amount": missing}
	return {"ok": false, "message": "目标不需要更多物流载具"}

func _set_button_availability(button: Button, available: bool, reason: String) -> void:
	button.disabled = not available
	button.tooltip_text = "" if available else reason

func _resource_names(item_ids: Array) -> String:
	var names: Array[String] = []
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		names.append(String(DataManager.get_item(item_id).get("name", item_id)))
	return "、".join(names) if not names.is_empty() else "无目录资源"

func _resource_site_text(sites: Array) -> String:
	var entries: Array[String] = []
	for site_value in sites:
		if not site_value is Dictionary:
			continue
		var site: Dictionary = site_value
		var item_id := String(site.get("item_id", ""))
		var reserve := "无限" if preload("res://scripts/game/SourceResourceReserveSystem.gd").is_infinite(game_state, site) else "剩余 %.0f / %.0f" % [float(site.get("remaining", 0.0)), float(site.get("capacity", 0.0))]
		entries.append("%s [%s] %s" % [DataManager.get_item(item_id).get("name", item_id), String(site.get("id", "")), reserve])
	return "\n".join(entries) if not entries.is_empty() else "无目录资源"

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

func _on_fleet_pressed() -> void:
	var planet := galaxy_system.get_planet_summary(_selected_planet_id)
	var availability := _fleet_availability(planet)
	if availability.get("ok", false):
		fleet_transfer_requested.emit(String(availability.get("item_id", "")), int(availability.get("amount", 0)))

func _on_travel_pressed() -> void:
	travel_requested.emit(_selected_planet_id)
