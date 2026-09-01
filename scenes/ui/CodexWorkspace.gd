class_name CodexWorkspace
extends PanelContainer

signal locate_requested(building_id: String, world_position: Vector2)

const STATISTICS_PANEL_SCRIPT = preload("res://scenes/ui/StatisticsPanel.gd")
const ACCENT_CYAN := Color("#62b5ae")
const ACCENT_YELLOW := Color("#e1b452")

var _statistics_panel: Control
var _diagnostics_panel: Control
var _codex_panel: Control
var _diagnostics_results: VBoxContainer
var _codex_results: VBoxContainer
var _diagnostics_scroll: ScrollContainer
var _codex_scroll: ScrollContainer
var _diagnostics_filter := ""
var _codex_filter := ""
var _chain_depth := 2
var _diagnostics_scroll_offset := 0.0
var _codex_scroll_offset := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	EventBus.simulation_updated.connect(_on_simulation_updated)
	GameManager.game_state_replaced.connect(_on_game_state_replaced)
	hide()

func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "生产分析"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", ACCENT_YELLOW)
	layout.add_child(heading)

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	layout.add_child(tabs)
	_add_tab(tabs, "Statistics", "统计", _show_view.bind("StatisticsPanel"))
	_add_tab(tabs, "Diagnostics", "诊断", _show_view.bind("DiagnosticsPanel"))
	_add_tab(tabs, "Codex", "资料库", _show_view.bind("CodexPanel"))

	var content := Control.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(content)

	_statistics_panel = STATISTICS_PANEL_SCRIPT.new()
	_statistics_panel.name = "StatisticsPanel"
	_fill_parent(_statistics_panel)
	content.add_child(_statistics_panel)
	_diagnostics_panel = _build_diagnostics_panel()
	content.add_child(_diagnostics_panel)
	_codex_panel = _build_codex_panel()
	content.add_child(_codex_panel)
	_show_view("StatisticsPanel")

func _build_diagnostics_panel() -> Control:
	var panel := Control.new()
	panel.name = "DiagnosticsPanel"
	_fill_parent(panel)
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "搜索诊断代码、消息或实体"
	search.anchor_right = 1.0
	search.offset_bottom = 36.0
	search.text_changed.connect(_on_diagnostics_search_changed)
	panel.add_child(search)
	_diagnostics_scroll = ScrollContainer.new()
	_diagnostics_scroll.name = "ResultsScroll"
	_diagnostics_scroll.anchor_right = 1.0
	_diagnostics_scroll.anchor_bottom = 1.0
	_diagnostics_scroll.offset_top = 44.0
	_diagnostics_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_diagnostics_scroll.get_v_scroll_bar().value_changed.connect(func(value: float): _diagnostics_scroll_offset = maxf(value, 0.0))
	panel.add_child(_diagnostics_scroll)
	_diagnostics_results = VBoxContainer.new()
	_diagnostics_results.name = "Results"
	_diagnostics_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagnostics_results.add_theme_constant_override("separation", 6)
	_diagnostics_scroll.add_child(_diagnostics_results)
	return panel

func _build_codex_panel() -> Control:
	var panel := Control.new()
	panel.name = "CodexPanel"
	_fill_parent(panel)
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "搜索物品或配方"
	search.anchor_right = 1.0
	search.offset_right = -180.0
	search.offset_bottom = 36.0
	search.text_changed.connect(_on_codex_search_changed)
	panel.add_child(search)
	var depth := OptionButton.new()
	depth.name = "ChainDepth"
	depth.anchor_left = 1.0
	depth.anchor_right = 1.0
	depth.offset_left = -170.0
	depth.offset_bottom = 36.0
	depth.add_item("两层上游")
	depth.set_item_metadata(0, 2)
	depth.add_item("完整链")
	depth.set_item_metadata(1, -1)
	depth.item_selected.connect(_on_chain_depth_selected)
	panel.add_child(depth)
	_codex_scroll = ScrollContainer.new()
	_codex_scroll.name = "ResultsScroll"
	_codex_scroll.anchor_right = 1.0
	_codex_scroll.anchor_bottom = 1.0
	_codex_scroll.offset_top = 44.0
	_codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_scroll.get_v_scroll_bar().value_changed.connect(func(value: float): _codex_scroll_offset = maxf(value, 0.0))
	panel.add_child(_codex_scroll)
	_codex_results = VBoxContainer.new()
	_codex_results.name = "Results"
	_codex_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_results.add_theme_constant_override("separation", 8)
	_codex_scroll.add_child(_codex_results)
	return panel

func _show_view(view_name: String) -> void:
	for panel in [_statistics_panel, _diagnostics_panel, _codex_panel]:
		if panel != null:
			panel.visible = panel.name == view_name
	if is_visible_in_tree():
		call_deferred("_refresh_active_view")

func _refresh_diagnostics() -> void:
	if not is_visible_in_tree() or not _diagnostics_panel.visible:
		return
	var desired_scroll := _diagnostics_scroll_offset
	_clear_container(_diagnostics_results)
	for entry_value in ProductionDiagnostics.new(GameManager.get_game_state()).get_all_diagnostics():
		var entry: Dictionary = entry_value
		if _matches_diagnostic(entry):
			_diagnostics_results.add_child(_create_diagnostic_row(entry))
	call_deferred("_restore_scroll", _diagnostics_scroll, desired_scroll)

func _create_diagnostic_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("entity_id", String(entry.get("entity_id", "")))
	row.custom_minimum_size.y = 54.0
	var detail := Label.new()
	detail.name = "Details"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "%s · %s\n%s" % [String(entry.get("code", "")), String(entry.get("entity_id", "")), String(entry.get("message", ""))]
	detail.add_theme_color_override("font_color", ACCENT_CYAN)
	row.add_child(detail)
	var building_id := String(entry.get("building_id", ""))
	if not building_id.is_empty():
		var locate := Button.new()
		locate.name = "Locate"
		locate.text = "定位"
		locate.set_meta("building_id", building_id)
		locate.set_meta("world_position", entry.get("world_position", Vector2.ZERO))
		locate.pressed.connect(_on_locate_pressed.bind(building_id, entry.get("world_position", Vector2.ZERO)))
		row.add_child(locate)
	return row

func _refresh_codex() -> void:
	if not is_visible_in_tree() or not _codex_panel.visible:
		return
	var desired_scroll := _codex_scroll_offset
	_clear_container(_codex_results)
	var items := DataManager.get_all_items()
	var graph := RecipeGraph.new(items, DataManager.get_all_recipes(), DataManager.get_all_buildings())
	var item_ids: Array = items.keys()
	item_ids.sort_custom(func(left, right): return _catalog_sort_key(items, String(left)) < _catalog_sort_key(items, String(right)))
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		var item: Dictionary = items[item_id]
		if _matches_codex(item_id, item, graph):
			_codex_results.add_child(_create_codex_row(item_id, item, graph))
	call_deferred("_restore_scroll", _codex_scroll, desired_scroll)

func _create_codex_row(item_id: String, item: Dictionary, graph: RecipeGraph) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.set_meta("item_id", item_id)
	var title := Label.new()
	title.text = "%s  [%s]" % [String(item.get("name", item_id)), item_id]
	title.add_theme_color_override("font_color", ACCENT_YELLOW)
	row.add_child(title)
	var producers := graph.get_producers(item_id)
	var consumers := graph.get_consumers(item_id)
	var chain := graph.build_upstream_chain(item_id, _chain_depth)
	var detail := Label.new()
	detail.name = "Details"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "生产：%s\n消耗：%s\n上游链（%s）：%d 节点\n%s\n关系：\n%s\n缺口：%s\n循环：%s" % [
		_format_recipe_rates(producers, item_id, graph),
		_format_recipe_names(consumers),
		"两层" if _chain_depth == 2 else "完整",
		chain.get("nodes", []).size(),
		_format_chain_nodes(chain, graph),
		_format_chain_edges(chain),
		_format_item_identities(chain.get("gaps", [])),
		_format_cycles(chain.get("cycles", [])),
	]
	detail.add_theme_color_override("font_color", Color("#d7e2de"))
	row.add_child(detail)
	return row

func _on_visibility_changed() -> void:
	if visible:
		call_deferred("_refresh_active_view")

func _refresh_active_view() -> void:
	if not is_visible_in_tree():
		return
	if _statistics_panel.visible:
		_statistics_panel.refresh_now()
	elif _diagnostics_panel.visible:
		_refresh_diagnostics()
	else:
		_refresh_codex()

func _on_simulation_updated(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	if is_visible_in_tree() and _diagnostics_panel.visible:
		_refresh_diagnostics()

func _on_game_state_replaced(_state: GameState) -> void:
	if not is_visible_in_tree():
		return
	if _diagnostics_panel.visible:
		_refresh_diagnostics()
	elif _codex_panel.visible:
		_refresh_codex()

func _on_diagnostics_search_changed(text: String) -> void:
	_diagnostics_filter = text.strip_edges().to_lower()
	_refresh_diagnostics()

func _on_codex_search_changed(text: String) -> void:
	_codex_filter = text.strip_edges().to_lower()
	_refresh_codex()

func _on_chain_depth_selected(index: int) -> void:
	var depth := _codex_panel.get_node("ChainDepth") as OptionButton
	_chain_depth = int(depth.get_item_metadata(index))
	_refresh_codex()

func _on_locate_pressed(building_id: String, world_position: Vector2) -> void:
	locate_requested.emit(building_id, world_position)

func _matches_diagnostic(entry: Dictionary) -> bool:
	if _diagnostics_filter.is_empty():
		return true
	var searchable := "%s %s %s %s %s" % [entry.get("code", ""), entry.get("message", ""), entry.get("entity_id", ""), entry.get("building_id", ""), entry.get("planet_id", "")]
	return searchable.to_lower().contains(_diagnostics_filter)

func _matches_codex(item_id: String, item: Dictionary, graph: RecipeGraph) -> bool:
	if _codex_filter.is_empty():
		return true
	var searchable := "%s %s %s" % [item_id, item.get("name", ""), _format_recipe_names(graph.get_producers(item_id) + graph.get_consumers(item_id))]
	return searchable.to_lower().contains(_codex_filter)

func _format_recipe_rates(recipe_ids: Array, item_id: String, graph: RecipeGraph) -> String:
	if recipe_ids.is_empty():
		return "无"
	var parts: Array[String] = []
	for recipe_id_value in recipe_ids:
		var recipe_id := String(recipe_id_value)
		var recipe := DataManager.get_recipe(recipe_id)
		parts.append("%s %.2f/min · 支持建筑：%s" % [recipe.get("name", recipe_id), graph.get_theoretical_rate_per_minute(recipe_id, item_id), _format_recipe_buildings(recipe_id, graph)])
	return "，".join(parts)

func _format_chain_nodes(chain: Dictionary, graph: RecipeGraph) -> String:
	var parts: Array[String] = []
	for node_value in chain.get("nodes", []):
		var node: Dictionary = node_value
		var node_id := String(node.get("id", ""))
		if String(node.get("kind", "")) == "recipe":
			var recipe := DataManager.get_recipe(node_id)
			var rates: Dictionary = chain.get("rates_per_minute", {}).get(node_id, {})
			parts.append("配方 %s [%s] · 支持建筑：%s · 理论产能：%s" % [recipe.get("name", node_id), node_id, _format_recipe_buildings(node_id, graph), _format_rate_map(rates)])
		else:
			parts.append("物品 %s" % _format_catalog_identity(node_id))
	return "\n".join(parts) if not parts.is_empty() else "无"

func _format_chain_edges(chain: Dictionary) -> String:
	var parts: Array[String] = []
	for edge_value in chain.get("edges", []):
		var edge: Dictionary = edge_value
		var relation := "生产" if String(edge.get("kind", "")) == "produces" else "消耗"
		parts.append("%s → %s（%s）" % [_format_catalog_identity(String(edge.get("from", ""))), _format_catalog_identity(String(edge.get("to", ""))), relation])
	return "\n".join(parts) if not parts.is_empty() else "无"

func _format_cycles(cycles: Array) -> String:
	if cycles.is_empty():
		return "无"
	var parts: Array[String] = []
	for cycle_value in cycles:
		var identities: Array[String] = []
		for item_id_value in cycle_value:
			identities.append(_format_catalog_identity(String(item_id_value)))
		parts.append(" → ".join(identities))
	return "；".join(parts)

func _format_recipe_buildings(recipe_id: String, graph: RecipeGraph) -> String:
	var building_names: Array[String] = []
	for building_id_value in graph.get_recipe_buildings(recipe_id):
		var building_id := String(building_id_value)
		building_names.append(String(DataManager.get_building(building_id).get("name", building_id)))
	return "、".join(building_names) if not building_names.is_empty() else "无"

func _format_rate_map(rates: Dictionary) -> String:
	if rates.is_empty():
		return "无"
	var item_ids: Array = rates.keys()
	item_ids.sort()
	var parts: Array[String] = []
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		parts.append("%s %.2f/min" % [_format_catalog_identity(item_id), float(rates[item_id])])
	return "，".join(parts)

func _format_catalog_identity(id: String) -> String:
	var recipe := DataManager.get_recipe(id)
	if not recipe.is_empty():
		return "%s [%s]" % [recipe.get("name", id), id]
	var item := DataManager.get_item(id)
	return "%s [%s]" % [item.get("name", id), id]

func _format_recipe_names(recipe_ids: Array) -> String:
	if recipe_ids.is_empty():
		return "无"
	var parts: Array[String] = []
	for recipe_id_value in recipe_ids:
		var recipe_id := String(recipe_id_value)
		parts.append(String(DataManager.get_recipe(recipe_id).get("name", recipe_id)))
	return "，".join(parts)

func _format_item_identities(item_ids: Array) -> String:
	if item_ids.is_empty():
		return "无"
	var parts: Array[String] = []
	for item_id_value in item_ids:
		parts.append(_format_catalog_identity(String(item_id_value)))
	return "，".join(parts)

func _catalog_sort_key(items: Dictionary, item_id: String) -> String:
	return "%s|%s" % [String(items[item_id].get("name", item_id)).to_lower(), item_id]

func _add_tab(parent: Container, node_name: String, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func _fill_parent(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _restore_scroll(scroll: ScrollContainer, value: float) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(value)

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101715")
	style.border_color = ACCENT_CYAN.darkened(0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	return style
