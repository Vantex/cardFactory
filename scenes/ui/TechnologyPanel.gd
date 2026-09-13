class_name TechnologyPanel
extends ScrollContainer

const TIER_OPTIONS := [
	["全部层级", "all"],
	["行星", "planetary"],
	["星际", "interstellar"],
	["戴森", "dyson"],
	["无限", "infinite"],
]
const STATUS_OPTIONS := [
	["全部状态", "all"],
	["可研究", "available"],
	["研究中", "researching"],
	["队列中", "queued"],
	["已完成", "completed"],
	["前置锁定", "locked"],
]
const EFFECT_NAMES := {"production_speed": "生产速度"}
const UNLOCK_KIND_NAMES := {
	"building": "建筑",
	"recipe": "配方",
	"item": "物品",
	"technology": "科技",
}

var game_state: GameState
var _filter_text := ""
var _tier_filter := "all"
var _status_filter := "all"
var _scroll_offset := 0.0
var _list: VBoxContainer
var _queue_list: VBoxContainer
var _queue: Label
var _wait_reason: Label
var _current: Label
var _progress: ProgressBar
var _scroll: ScrollContainer
var _pause_button: Button
var _resume_button: Button
var _cancel_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(300, 420)
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
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	var filters := HBoxContainer.new()
	filters.name = "Filters"
	layout.add_child(filters)
	var tier_filter := _create_option_button("TierFilter", TIER_OPTIONS)
	tier_filter.item_selected.connect(_on_tier_selected)
	filters.add_child(tier_filter)
	var status_filter := _create_option_button("StatusFilter", STATUS_OPTIONS)
	status_filter.item_selected.connect(_on_status_selected)
	filters.add_child(status_filter)

	_current = Label.new()
	_current.name = "Current"
	layout.add_child(_current)
	_progress = ProgressBar.new()
	_progress.name = "Progress"
	_progress.show_percentage = true
	layout.add_child(_progress)

	var current_actions := HBoxContainer.new()
	current_actions.name = "CurrentActions"
	layout.add_child(current_actions)
	_pause_button = _create_intent_button("Pause", "暂停", EventBus.technology_pause_requested.emit)
	_resume_button = _create_intent_button("Resume", "恢复", EventBus.technology_resume_requested.emit)
	_cancel_button = _create_intent_button("Cancel", "取消并保留投入", EventBus.technology_cancel_requested.emit)
	current_actions.add_child(_pause_button)
	current_actions.add_child(_resume_button)
	current_actions.add_child(_cancel_button)

	_queue = Label.new()
	_queue.name = "Queue"
	_queue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_queue)
	_queue_list = VBoxContainer.new()
	_queue_list.name = "QueueList"
	layout.add_child(_queue_list)
	_wait_reason = Label.new()
	_wait_reason.name = "WaitReason"
	_wait_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_wait_reason)

	_scroll = ScrollContainer.new()
	_scroll.name = "CatalogScroll"
	_scroll.custom_minimum_size = Vector2(0, 190)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "Catalog"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

func _create_option_button(node_name: String, options: Array) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option_value in options:
		option.add_item(String(option_value[0]))
		option.set_item_metadata(option.item_count - 1, String(option_value[1]))
	return option

func _create_intent_button(node_name: String, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.pressed.connect(callback)
	return button

func _on_game_state_replaced(state: GameState) -> void:
	game_state = state
	_refresh()

func _on_search_changed(text: String) -> void:
	_filter_text = text
	_refresh()

func _on_tier_selected(index: int) -> void:
	var option := get_node("Layout/Filters/TierFilter") as OptionButton
	_tier_filter = String(option.get_item_metadata(index))
	_refresh()

func _on_status_selected(index: int) -> void:
	var option := get_node("Layout/Filters/StatusFilter") as OptionButton
	_status_filter = String(option.get_item_metadata(index))
	_refresh()

func _on_scroll_changed(value: float) -> void:
	_scroll_offset = maxf(value, 0.0)

func _refresh(_arg_1 = null, _arg_2 = null, _arg_3 = null) -> void:
	if game_state == null or _list == null:
		return
	var desired_scroll := _scroll_offset
	_refresh_current()
	_refresh_queue()
	_clear_container(_list)
	var ids := DataManager.get_all_technologies().keys()
	ids.sort()
	for id_value in ids:
		var tech_id := String(id_value)
		var technology := DataManager.get_technology(tech_id)
		var status := _technology_status(tech_id, technology)
		if _matches_filters(tech_id, technology, status):
			_list.add_child(_create_technology_row(tech_id, technology, status))
	call_deferred("_restore_scroll", desired_scroll)

func _refresh_current() -> void:
	var current_id := game_state.research_current_id
	var current_technology := DataManager.get_technology(current_id)
	_current.text = "当前：无" if current_id.is_empty() else "当前：%s%s" % [String(current_technology.get("name", current_id)), "（已暂停）" if game_state.research_paused else ""]
	_progress.max_value = maxf(float(current_technology.get("duration", 0.0)), 1.0)
	_progress.value = game_state.get_technology_progress(current_id)
	_pause_button.disabled = current_id.is_empty() or game_state.research_paused
	_resume_button.disabled = current_id.is_empty() or not game_state.research_paused
	_cancel_button.disabled = current_id.is_empty()

func _refresh_queue() -> void:
	var queue_names: Array[String] = []
	for technology_id_value in game_state.research_queue:
		var technology_id := String(technology_id_value)
		queue_names.append(String(DataManager.get_technology(technology_id).get("name", technology_id)))
	_queue.text = "队列：%s" % ("空" if queue_names.is_empty() else " → ".join(queue_names))
	_clear_container(_queue_list)
	for technology_id_value in game_state.research_queue:
		var technology_id := String(technology_id_value)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(DataManager.get_technology(technology_id).get("name", technology_id))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove := Button.new()
		remove.text = "移出队列"
		remove.set_meta("technology_id", technology_id)
		remove.pressed.connect(_on_remove_queue_intent.bind(technology_id))
		row.add_child(remove)
		_queue_list.add_child(row)
	_wait_reason.text = "等待：%s" % game_state.research_queue_wait_reason
	_wait_reason.visible = not game_state.research_queue_wait_reason.is_empty()

func _create_technology_row(tech_id: String, technology: Dictionary, status: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var detail := Label.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var prefix := "✓ " if game_state.completed_technologies.has(tech_id) else ""
	detail.text = "%s%s [%s]\n状态：%s  前置：%s\n成本：%s\n解锁：%s\n效果：%s\n%s" % [
		prefix, String(technology.get("name", tech_id)), String(technology.get("tier", "")),
		_status_name(status), _format_prerequisites(technology.get("prerequisites", [])),
		_format_cost(technology.get("cost", {})), _format_unlocks(technology.get("unlocks", [])),
		_format_effects(technology.get("effects", {})), String(technology.get("description", "")),
	]
	if technology.get("source_research_bridge", false):
		detail.text += "\n在矩阵实验室切换科研模式并投放材料；已有实验室也可使用。"
	row.add_child(detail)
	var action := Button.new()
	action.text = "排队" if not game_state.research_current_id.is_empty() or not game_state.research_queue.is_empty() else "研究"
	if game_state.completed_technologies.has(tech_id) and technology.has("repeatable"):
		action.text = "研究下一层" if game_state.research_current_id.is_empty() and game_state.research_queue.is_empty() else "下一层排队"
	action.disabled = status == "researching" or status == "queued" or (status == "completed" and not technology.has("repeatable"))
	action.pressed.connect(_on_technology_intent.bind(tech_id))
	row.add_child(action)
	return row

func _matches_filters(tech_id: String, technology: Dictionary, status: String) -> bool:
	var haystack := (tech_id + " " + String(technology.get("name", tech_id)) + " " + String(technology.get("description", ""))).to_lower()
	if not _filter_text.strip_edges().is_empty() and not haystack.contains(_filter_text.strip_edges().to_lower()):
		return false
	if _tier_filter != "all" and String(technology.get("tier", "")) != _tier_filter:
		return false
	return _status_filter == "all" or status == _status_filter

func _technology_status(tech_id: String, technology: Dictionary) -> String:
	if game_state.research_current_id == tech_id:
		return "researching"
	if game_state.research_queue.has(tech_id):
		return "queued"
	if game_state.completed_technologies.has(tech_id):
		return "completed"
	for prerequisite_value in technology.get("prerequisites", []):
		if not game_state.completed_technologies.has(String(prerequisite_value)):
			return "locked"
	return "available"

func _status_name(status: String) -> String:
	return {"available": "可研究", "researching": "研究中", "queued": "队列中", "completed": "已完成", "locked": "前置锁定"}.get(status, status)

func _format_prerequisites(prerequisites_value: Variant) -> String:
	if not prerequisites_value is Array or prerequisites_value.is_empty():
		return "无"
	var names: Array[String] = []
	for technology_id_value in prerequisites_value:
		var technology_id := String(technology_id_value)
		names.append(String(DataManager.get_technology(technology_id).get("name", technology_id)))
	return "、".join(names)

func _format_cost(cost_value: Variant) -> String:
	if not cost_value is Dictionary or cost_value.is_empty():
		return "无"
	var parts: Array[String] = []
	var item_ids: Array = cost_value.keys()
	item_ids.sort()
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		parts.append("%s ×%s" % [String(DataManager.get_item(item_id).get("name", item_id)), _format_amount(float(cost_value[item_id_value]))])
	return "、".join(parts)

func _format_unlocks(unlocks_value: Variant) -> String:
	if not unlocks_value is Array or unlocks_value.is_empty():
		return "无"
	var parts: Array[String] = []
	for unlock_value in unlocks_value:
		if not unlock_value is Dictionary:
			continue
		var kind := String(unlock_value.get("kind", ""))
		var unlock_id := String(unlock_value.get("id", ""))
		parts.append("%s：%s" % [String(UNLOCK_KIND_NAMES.get(kind, kind)), _catalog_entry_name(kind, unlock_id)])
	return "、".join(parts) if not parts.is_empty() else "无"

func _catalog_entry_name(kind: String, entry_id: String) -> String:
	match kind:
		"building": return String(DataManager.get_building(entry_id).get("name", entry_id))
		"recipe": return String(DataManager.get_recipe(entry_id).get("name", entry_id))
		"item": return String(DataManager.get_item(entry_id).get("name", entry_id))
		"technology": return String(DataManager.get_technology(entry_id).get("name", entry_id))
	return entry_id

func _format_effects(effects_value: Variant) -> String:
	if not effects_value is Dictionary or effects_value.is_empty():
		return "无"
	var parts: Array[String] = []
	var effect_keys: Array = effects_value.keys()
	effect_keys.sort()
	for effect_key_value in effect_keys:
		var effect_key := String(effect_key_value)
		parts.append("%s ×%.2f" % [String(EFFECT_NAMES.get(effect_key, effect_key)), float(effects_value[effect_key_value])])
	return "、".join(parts)

func _format_amount(value: float) -> String:
	return "%d" % int(value) if is_equal_approx(value, floor(value)) else "%.2f" % value

func _on_technology_intent(tech_id: String) -> void:
	if not game_state.research_current_id.is_empty() or not game_state.research_queue.is_empty():
		EventBus.technology_queue_requested.emit(tech_id)
	else:
		EventBus.technology_start_requested.emit(tech_id)

func _on_remove_queue_intent(tech_id: String) -> void:
	EventBus.technology_remove_queue_requested.emit(tech_id)

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _restore_scroll(value: float) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = int(value)

func get_filter_text() -> String:
	return _filter_text

func set_scroll_offset(value: float) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = int(maxf(value, 0.0))

func get_scroll_offset() -> float:
	return float(_scroll.scroll_vertical) if _scroll != null else 0.0
