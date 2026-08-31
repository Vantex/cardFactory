class_name TechnologyPanel
extends PanelContainer

## Intent-only research workspace.  It reads GameState through TechnologySystem
## and refreshes from domain events instead of polling simulation state.
var game_state: GameState
var _filter_text := ""
var _scroll_offset := 0.0
var _list: VBoxContainer
var _queue: Label
var _current: Label
var _progress: ProgressBar

func _ready() -> void:
	custom_minimum_size = Vector2(330, 420)
	mouse_filter = Control.MOUSE_FILTER_STOP
	game_state = GameManager.get_game_state()
	_build_ui()
	for signal_name in ["technology_research_started", "technology_research_completed", "technology_research_progressed", "technology_research_queue_changed", "technology_research_paused", "technology_research_resumed", "technology_research_cancelled"]:
		EventBus.connect(signal_name, _refresh)
	GameManager.game_state_replaced.connect(_on_game_state_replaced)
	_refresh()

func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	add_child(layout)
	var title := Label.new()
	title.text = "科技工作区"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "搜索科技"
	search.text_changed.connect(_on_search_changed)
	layout.add_child(search)
	_current = Label.new()
	_current.name = "Current"
	layout.add_child(_current)
	_progress = ProgressBar.new()
	_progress.name = "Progress"
	_progress.show_percentage = true
	layout.add_child(_progress)
	_queue = Label.new()
	_queue.name = "Queue"
	_queue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_queue)
	var scroll := ScrollContainer.new()
	scroll.name = "CatalogScroll"
	scroll.custom_minimum_size = Vector2(0, 230)
	layout.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "Catalog"
	scroll.add_child(_list)

func _on_game_state_replaced(state: GameState) -> void:
	game_state = state
	_refresh()

func _on_search_changed(text: String) -> void:
	_filter_text = text
	_refresh()

func _refresh(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	if game_state == null:
		return
	var current_id := game_state.research_current_id
	var current_tech := DataManager.get_technology(current_id)
	_current.text = "当前：无" if current_id.is_empty() else "当前：%s%s" % [String(current_tech.get("name", current_id)), "（已暂停）" if game_state.research_paused else ""]
	_progress.max_value = maxf(float(current_tech.get("duration", 0.0)), 1.0)
	_progress.value = game_state.get_technology_progress(current_id)
	_queue.text = "队列：%s" % ("空" if game_state.research_queue.is_empty() else ", ".join(game_state.research_queue))
	for child in _list.get_children():
		child.queue_free()
	var ids := DataManager.get_all_technologies().keys()
	ids.sort()
	for id_value in ids:
		var tech_id := String(id_value)
		var tech := DataManager.get_technology(tech_id)
		var haystack := (tech_id + " " + String(tech.get("name", tech_id)) + " " + String(tech.get("description", ""))).to_lower()
		if not _filter_text.strip_edges().is_empty() and not haystack.contains(_filter_text.to_lower()):
			continue
		var row := HBoxContainer.new()
		var detail := Label.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var prerequisites: Array = tech.get("prerequisites", [])
		var prefix := "✓ " if game_state.completed_technologies.has(tech_id) else ""
		detail.text = "%s%s [%s]\n前置：%s\n%s" % [prefix, String(tech.get("name", tech_id)), String(tech.get("tier", "planetary")), "无" if prerequisites.is_empty() else ", ".join(prerequisites), String(tech.get("description", ""))]
		row.add_child(detail)
		var action := Button.new()
		action.text = "研究" if current_id.is_empty() else "排队"
		action.disabled = game_state.completed_technologies.has(tech_id) and not tech.has("repeatable")
		action.pressed.connect(_on_technology_intent.bind(tech_id))
		row.add_child(action)
		_list.add_child(row)

func _on_technology_intent(tech_id: String) -> void:
	if not game_state.research_current_id.is_empty():
		EventBus.technology_queue_requested.emit(tech_id)
	else:
		EventBus.technology_start_requested.emit(tech_id)
	_refresh()

func get_filter_text() -> String:
	return _filter_text

func set_scroll_offset(value: float) -> void:
	_scroll_offset = maxf(value, 0.0)
	var scroll := get_node_or_null("Layout/CatalogScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(_scroll_offset)

func get_scroll_offset() -> float:
	return _scroll_offset
