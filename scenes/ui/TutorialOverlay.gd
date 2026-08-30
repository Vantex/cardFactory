class_name TutorialOverlay
extends Control

var _label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(230, 110)
	size = Vector2(390, 46)
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label = Label.new()
	_label.name = "Objective"
	_label.position = Vector2(12, 7)
	_label.size = Vector2(366, 32)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(_label)
	EventBus.progression_updated.connect(refresh_now)
	GameManager.game_state_replaced.connect(_on_state_replaced)
	refresh_now()

func refresh_now(_arg = null) -> void:
	if _label == null:
		return
	var progression := ProgressionSystem.new(GameManager.get_game_state())
	var objective := progression.get_current_objective()
	if objective.is_empty():
		_label.text = "战役目标完成 · 工厂可以继续自由扩建"
		return
	var progress := progression.get_objective_progress(String(objective.get("id", "")))
	_label.text = "%s  ·  %.0f / %.0f" % [String(objective.get("title", "当前目标")), float(progress.get("current", 0.0)), float(progress.get("required", 1.0))]

func _on_state_replaced(_state: GameState) -> void:
	refresh_now()
