class_name CampaignWorkspace
extends Control

signal locate_requested(building_id: String, world_position: Vector2)

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
	var panel := Panel.new()
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

func _install_toggle() -> void:
	if _toggle_button != null:
		return
	var inspector := get_parent().get_node_or_null("InspectorPanel") as Control
	if inspector == null:
		return
	var title := inspector.get_node_or_null("Title") as Control
	if title != null:
		title.size.x = minf(title.size.x, 112.0)
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
