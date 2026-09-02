class_name StatisticsPanel
extends Control

const SUPPORTED_WINDOWS := [60, 300, 600]

var stats_system: StatisticsSystem
var game_state: GameState
var _window_seconds := 60
var _filter_text := ""
var _scroll_offset := 0.0
var _last_rendered_sample_generation := -1
var _results: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	EventBus.simulation_updated.connect(_on_simulation_updated)
	GameManager.game_state_replaced.connect(_on_game_state_replaced)
	refresh_now()

func _build_ui() -> void:
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "生产统计"
	heading.position = Vector2(0.0, 8.0)
	heading.size = Vector2(92.0, 30.0)
	heading.add_theme_color_override("font_color", Color("#e1b452"))
	add_child(heading)

	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "搜索物品"
	search.position = Vector2(96.0, 2.0)
	search.size = Vector2(210.0, 36.0)
	search.text_changed.connect(_on_search_changed)
	add_child(search)

	var window := OptionButton.new()
	window.name = "Window"
	window.anchor_left = 1.0
	window.anchor_right = 1.0
	window.offset_left = -170.0
	window.offset_right = 0.0
	window.offset_top = 2.0
	window.offset_bottom = 38.0
	for seconds in SUPPORTED_WINDOWS:
		window.add_item("最近 %d 秒" % seconds)
		window.set_item_metadata(window.item_count - 1, seconds)
	window.item_selected.connect(_on_window_selected)
	add_child(window)

	_scroll = ScrollContainer.new()
	_scroll.name = "ResultsScroll"
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	_scroll.offset_top = 44.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	add_child(_scroll)
	_results = VBoxContainer.new()
	_results.name = "Results"
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 6)
	_scroll.add_child(_results)

func refresh_now(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	if not is_visible_in_tree() or _results == null:
		return
	_bind_current_simulation()
	_refresh_rows(true)

func _refresh_rows(force_refresh: bool) -> void:
	if not is_visible_in_tree() or _results == null or stats_system == null:
		return
	var sample_generation := stats_system.get_sample_generation()
	if not force_refresh and sample_generation == _last_rendered_sample_generation:
		return
	var desired_scroll := _scroll_offset
	_clear_results()
	var summary: Dictionary = stats_system.get_statistics_summary(_window_seconds)
	var item_rates: Dictionary = summary.get("items", {})
	var item_ids: Array = item_rates.keys()
	item_ids.sort_custom(func(left, right): return _item_sort_key(String(left)) < _item_sort_key(String(right)))
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		var item := DataManager.get_item(item_id)
		var display_name := String(item.get("name", item_id))
		if not _matches_filter(item_id, display_name):
			continue
		_results.add_child(_create_rate_row(item_id, display_name, item_rates[item_id]))
	_last_rendered_sample_generation = sample_generation
	call_deferred("_restore_scroll", desired_scroll)

func _create_rate_row(item_id: String, display_name: String, rates: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("item_id", item_id)
	row.custom_minimum_size.y = 48.0
	var identity := Label.new()
	identity.name = "Identity"
	identity.text = "%s\n%s" % [display_name, item_id]
	identity.custom_minimum_size.x = 150.0
	identity.add_theme_color_override("font_color", Color("#62b5ae"))
	row.add_child(identity)
	var rates_label := Label.new()
	rates_label.name = "Rates"
	rates_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rates_label.text = "生产 %8.2f/min    消耗 %8.2f/min    净值 %+8.2f/min    吞吐 %8.2f/min" % [
		float(rates.get("produced_per_minute", 0.0)),
		float(rates.get("consumed_per_minute", 0.0)),
		float(rates.get("net_per_minute", 0.0)),
		float(rates.get("transferred_per_minute", 0.0)),
	]
	rates_label.add_theme_color_override("font_color", Color("#d7e2de"))
	row.add_child(rates_label)
	return row

func _bind_current_simulation(state: GameState = null) -> void:
	game_state = state if state != null else GameManager.get_game_state()
	var simulation_engine := GameManager.get_simulation_engine()
	var current_statistics: StatisticsSystem = simulation_engine.statistics_system if simulation_engine != null else null
	if stats_system != current_statistics:
		_last_rendered_sample_generation = -1
	stats_system = current_statistics

func _on_game_state_replaced(state: GameState) -> void:
	_bind_current_simulation(state)
	if is_visible_in_tree():
		_refresh_rows(true)

func _on_simulation_updated(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	if not is_visible_in_tree():
		return
	_refresh_rows(false)

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh_now()

func _on_search_changed(text: String) -> void:
	_filter_text = text.strip_edges().to_lower()
	refresh_now()

func _on_window_selected(index: int) -> void:
	var window := get_node("Window") as OptionButton
	_window_seconds = int(window.get_item_metadata(index))
	refresh_now()

func _on_scroll_changed(value: float) -> void:
	_scroll_offset = maxf(value, 0.0)

func _restore_scroll(value: float) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(value)

func _matches_filter(item_id: String, display_name: String) -> bool:
	return _filter_text.is_empty() or item_id.to_lower().contains(_filter_text) or display_name.to_lower().contains(_filter_text)

func _item_sort_key(item_id: String) -> String:
	var display_name := String(DataManager.get_item(item_id).get("name", item_id))
	return "%s|%s" % [display_name.to_lower(), item_id]

func _clear_results() -> void:
	for child in _results.get_children():
		_results.remove_child(child)
		child.queue_free()
