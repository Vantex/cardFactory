class_name CampaignWorkspace
extends Control

signal locate_requested(building_id: String, world_position: Vector2)

var _source_search: LineEdit
var _source_chapter: OptionButton
var _source_status: OptionButton
var _source_tasks: OptionButton
var _source_detail: Label
var _source_ids: Array[String] = []
var _source_rows: Array = []
var _source_achievements: Label
var _objective_label: Label
var _progress_label: Label
var _chapter_label: Label
var _achievement_label: Label
var _toggle_button: Button
var _blocked_reward_ids: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(230, 170)
	size = Vector2(320, 300)
	z_index = 3
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_controls()
	hide()
	call_deferred("_install_toggle")
	EventBus.progression_updated.connect(_on_progression_updated)
	GameManager.game_state_replaced.connect(_on_state_replaced)
	refresh_now()

func refresh_now(_arg = null) -> void:
	if _objective_label == null:
		return
	var snapshot := ProgressionSystem.new(GameManager.get_game_state()).get_campaign_snapshot()
	var objective: Dictionary = snapshot.get("current_objective", {})
	var progress: Dictionary = snapshot.get("current_progress", {})
	_chapter_label.text = "单人战役  ·  %d 个章节/支线" % int(snapshot.get("chapter_count", 0))
	if objective.is_empty():
		_objective_label.text = "当前目标：战役目标已全部完成"
		_progress_label.text = "你仍可继续优化工厂和解锁本地成就。"
	else:
		_objective_label.text = "当前目标：%s" % String(objective.get("title", objective.get("id", "")))
		_progress_label.text = "%s\n进度 %.0f / %.0f" % [String(objective.get("description", "")), float(progress.get("current", 0.0)), float(progress.get("required", 1.0))]
	_achievement_label.text = "已完成目标 %d  ·  本地成就 %d" % [snapshot.get("completed_objective_ids", []).size(), snapshot.get("completed_achievement_ids", []).size()]
	_refresh_source_tasks()
	if not _blocked_reward_ids.is_empty():
		_achievement_label.text += "\n奖励待领取：请先腾出库存空间"

func request_locate_stopped_building() -> Dictionary:
	var location := ObjectiveSystem.new().find_stopped_building(GameManager.get_game_state())
	if location.is_empty():
		EventBus.notice_requested.emit("当前没有可定位的停工建筑", "info")
		return {"ok": false, "reason": "no_stopped_building"}
	locate_requested.emit(String(location.get("building_id", "")), location.get("position", Vector2.ZERO))
	return {"ok": true, "building_id": location.get("building_id", ""), "position": location.get("position", Vector2.ZERO)}

func _build_controls() -> void:
	var panel := AdaptivePanel.new()
	panel.reflow = true
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_chapter_label = _make_label("Chapter", "单人战役", Vector2(16, 14), Vector2(288, 28), 16)
	panel.add_child(_chapter_label)
	_objective_label = _make_label("Objective", "", Vector2(16, 54), Vector2(288, 48), 14)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_objective_label)
	_progress_label = _make_label("Progress", "", Vector2(16, 108), Vector2(288, 80), 12)
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_progress_label)
	_achievement_label = _make_label("Achievements", "", Vector2(16, 194), Vector2(288, 32), 12)
	_achievement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_achievement_label)
	var locate := Button.new()
	locate.name = "LocateStopped"
	locate.text = "定位停工建筑"
	locate.position = Vector2(16, 238)
	locate.size = Vector2(136, 42)
	locate.pressed.connect(request_locate_stopped_building)
	panel.add_child(locate)
	var close := Button.new()
	close.name = "Close"
	close.text = "收起"
	close.position = Vector2(168, 238)
	close.size = Vector2(136, 42)
	close.pressed.connect(hide)
	panel.add_child(close)
	_build_source_controls(panel)

func _install_toggle() -> void:
	if _toggle_button != null:
		return
	var inspector := get_parent().get_node_or_null("InspectorPanel") as Control
	if inspector == null:
		return
	var title := inspector.get_node_or_null("Title") as Control
	if title != null:
		title.size.x = minf(title.size.x, 112.0)
		title.set_meta("authored_size", title.size)
	_toggle_button = Button.new()
	_toggle_button.name = "CampaignToggle"
	_toggle_button.text = "任务"
	_toggle_button.position = Vector2(136, 9)
	_toggle_button.size = Vector2(64, 32)
	_toggle_button.pressed.connect(_show_workspace)
	inspector.add_child(_toggle_button)

func _show_workspace() -> void:
	refresh_now()
	var workspace_shell := get_parent()
	if workspace_shell != null and workspace_shell.has_method("show_exclusive_workspace"):
		workspace_shell.call("show_exclusive_workspace", name)
	else:
		show()

func _on_progression_updated(result: Dictionary) -> void:
	_blocked_reward_ids = result.get("blocked_reward_ids", []).duplicate()
	refresh_now()

func _on_state_replaced(_state: GameState) -> void:
	refresh_now()

func _make_label(node_name: String, text_value: String, position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _build_source_controls(panel: Control) -> void:
	_source_search = LineEdit.new()
	_source_search.name = "SourceSearch"
	_source_search.placeholder_text = "搜索完整战役任务"
	_source_search.text_changed.connect(func(_text): _refresh_source_tasks())
	panel.add_child(_source_search)
	_source_chapter = OptionButton.new()
	_source_chapter.name = "SourceChapter"
	_source_chapter.add_item("全部章节")
	_source_chapter.set_item_metadata(0, "")
	for chapter in ObjectiveSystem.load_catalog().chapters:
		if chapter.has("source_id"):
			_source_chapter.add_item(chapter.title)
			_source_chapter.set_item_metadata(_source_chapter.item_count - 1, chapter.id)
	_source_chapter.item_selected.connect(func(_index): _refresh_source_tasks())
	panel.add_child(_source_chapter)
	_source_status = OptionButton.new()
	_source_status.name = "SourceStatus"
	for label in ["全部状态", "可推进", "前置锁定", "已完成"]: _source_status.add_item(label)
	_source_status.item_selected.connect(func(_index): _refresh_source_tasks())
	panel.add_child(_source_status)
	_source_tasks = OptionButton.new()
	_source_tasks.name = "SourceTasks"
	_source_tasks.item_selected.connect(func(_index): _refresh_source_detail())
	panel.add_child(_source_tasks)
	_source_detail = Label.new()
	_source_detail.name = "SourceDetails"
	_source_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_source_detail)
	for label in ["跟踪所选任务", "前往目标", "手动采集一份铁矿", "重试待领任务奖励"]:
		var button := Button.new()
		button.text = label
		button.pressed.connect(_source_action.bind(label))
		panel.add_child(button)
	_source_achievements = Label.new()
	_source_achievements.name = "SourceAchievements"
	_source_achievements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_source_achievements)

func _refresh_source_tasks() -> void:
	if _source_tasks == null: return
	var previous := _source_ids[_source_tasks.selected] if _source_tasks.selected >= 0 and _source_tasks.selected < _source_ids.size() else ""
	_source_ids.clear()
	_source_tasks.clear()
	var state := GameManager.get_game_state()
	_source_rows = ProgressionSystem.new(state).get_source_objectives()
	var chapter := String(_source_chapter.get_item_metadata(_source_chapter.selected))
	var status: String = ["", "available", "locked", "completed"][_source_status.selected]
	for row in _source_rows:
		if not chapter.is_empty() and row.chapter_id != chapter: continue
		if not status.is_empty() and row.status != status: continue
		if not _source_search.text.strip_edges().is_empty() and not (String(row.title) + String(row.description)).to_lower().contains(_source_search.text.strip_edges().to_lower()): continue
		_source_ids.append(row.id)
		_source_tasks.add_item(("✓ " if row.status == "completed" else "") + String(row.title))
	if _source_ids.has(previous): _source_tasks.select(_source_ids.find(previous))
	_refresh_source_detail()
	var names: Array[String] = []
	for achievement in ObjectiveSystem.load_catalog().achievements:
		if achievement.has("source_id"):
			names.append(("✓ " if state.completed_achievement_ids.has(achievement.id) else "○ ") + String(achievement.title))
	_source_achievements.text = "本地成就\n" + " · ".join(names)

func _selected_source_row() -> Dictionary:
	if _source_tasks.selected < 0 or _source_tasks.selected >= _source_ids.size(): return {}
	for row in _source_rows:
		if row.id == _source_ids[_source_tasks.selected]: return row
	return {}

func _refresh_source_detail() -> void:
	var row := _selected_source_row()
	if row.is_empty():
		_source_detail.text = "没有匹配任务"
		return
	var state := GameManager.get_game_state()
	var details: Array[String] = [String(row.description), "进度 %.0f / %.0f" % [row.progress.current, row.progress.required]]
	if row.status == "locked": details.append("前置任务尚未完成")
	var requirements: Array = row.get("requirements", []).duplicate(true)
	var navigation: Dictionary = row.get("navigation", {})
	if requirements.is_empty() and navigation.get("kind") == "technology":
		for item in DataManager.get_technology("dsp_" + String(navigation.techId)).get("cost", {}): requirements.append({"itemId": item, "amount": DataManager.get_technology("dsp_" + String(navigation.techId)).cost[item]})
	if requirements.is_empty() and navigation.get("kind") == "recipe":
		for recipe in DataManager.all_recipes.values():
			if not recipe.has("source_id"): continue
			if recipe.get("outputs", []).any(func(output): return output.item_id == navigation.itemId):
				for item in recipe.inputs: requirements.append({"itemId": item.item_id, "amount": item.amount})
				break
	for requirement in requirements:
		var item := String(requirement.itemId)
		var stock := SourceProgressionFacts.network_stock(state, item)
		details.append("%s：需要 %.0f，缺少 %.0f" % [DataManager.get_item(item).get("name", item), float(requirement.amount), maxf(0, float(requirement.amount) - stock)])
	var reward: Dictionary = row.get("reward", {})
	for item in reward.get("planet_inventory", {}): details.append("奖励 %s ×%s" % [DataManager.get_item(item).get("name", item), reward.planet_inventory[item]])
	for item in reward.get("construction_inventory", {}): details.append("奖励 %s ×%s" % [DataManager.get_building(item).get("name", item), reward.construction_inventory[item]])
	if state.completed_objective_ids.has(row.id) and not state.claimed_progression_reward_ids.has("objective:" + String(row.id)): details.append("奖励待领取：库存空间不足")
	_source_detail.text = "\n".join(details)

func _source_action(action: String) -> void:
	var state := GameManager.get_game_state()
	var row := _selected_source_row()
	if action == "跟踪所选任务":
		if row.is_empty() or not ProgressionSystem.new(state).select_objective(row.id): EventBus.notice_requested.emit("只能跟踪前置已完成的未完成任务", "warning")
	elif action == "前往目标":
		if not row.is_empty(): _navigate_source(row.get("navigation", {}))
	elif action == "手动采集一份铁矿":
		var found := false
		for site in state.resource_sites.values():
			if site.planet_id == state.active_planet_id and site.item_id == "iron_ore":
				var result := SourceProgressionFacts.mine(state, site.id)
				EventBus.notice_requested.emit(result.message, "info" if result.ok else "warning")
				found = true
				break
		if not found: EventBus.notice_requested.emit("当前行星没有可采集的铁矿脉", "warning")
	_blocked_reward_ids = ProgressionSystem.new(state).evaluate().blocked_reward_ids
	refresh_now()

func _navigate_source(navigation: Dictionary) -> void:
	var shell := get_parent()
	var target := "ProductionCatalogWorkspace"
	match String(navigation.get("kind", "")):
		"technology":
			target = "TechnologyPanel"
			var panel := shell.get_node(target)
			panel.navigate_to("dsp_" + String(navigation.techId))
		"planet", "system": target = "GalaxyMap"
		"dyson": target = "DysonPanel"
		"galactic": target = "EndgameWorkspace"
		"recipe", "building", "construction":
			var catalog := shell.get_node(target)
			catalog.navigate_to(navigation)
		_: return
	if shell.has_method("show_exclusive_workspace"): shell.show_exclusive_workspace(target)
