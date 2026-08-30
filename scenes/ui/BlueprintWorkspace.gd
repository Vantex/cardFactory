class_name BlueprintWorkspace
extends Control

const BlueprintCodecScript = preload("res://scripts/game/BlueprintCodec.gd")

signal deployment_intent(position: Vector2, rotation_quarters: int, mirrored: bool)
signal capture_intent(entity_ids: Array)

var _input_handler: Node
var _draft: Dictionary = {}
var _rotation_quarters := 0
var _mirrored := false

func set_input_handler(input_handler: Node) -> void:
	_input_handler = input_handler

func capture_selection() -> Dictionary:
	if _input_handler == null or not _input_handler.has_method("get_selected_entity_ids"):
		return _failure("selection_unavailable", "无法读取当前选择")
	return request_capture(_input_handler.call("get_selected_entity_ids"))

func request_capture(entity_ids: Array) -> Dictionary:
	capture_intent.emit(entity_ids.duplicate())
	return {"ok": true, "pending": true}

func accept_capture_result(result: Dictionary) -> void:
	if result.get("ok", false):
		_draft = result.blueprint.duplicate(true)
		_rotation_quarters = 0
		_mirrored = false

func import_text(text: String) -> Dictionary:
	var result := BlueprintCodecScript.new().decode(text)
	if result.get("ok", false):
		_draft = result.blueprint.duplicate(true)
		_rotation_quarters = 0
		_mirrored = false
	return result

func export_text() -> Dictionary:
	if _draft.is_empty():
		return _failure("empty_blueprint", "没有可导出的蓝图")
	return BlueprintCodecScript.new().encode(_draft)

func request_deployment(position: Vector2) -> Dictionary:
	if _draft.is_empty():
		return _failure("empty_blueprint", "没有可部署的蓝图")
	deployment_intent.emit(position, _rotation_quarters, _mirrored)
	return {"ok": true, "pending": true}

func accept_deployment_result(result: Dictionary) -> void:
	var message := String(result.get("message", ""))
	if not message.is_empty():
		EventBus.notice_requested.emit(message, "success" if result.get("ok", false) else "error")

func rotate_preview(clockwise: bool = true) -> int:
	_rotation_quarters = posmod(_rotation_quarters + (1 if clockwise else -1), 4)
	return _rotation_quarters

func mirror_preview() -> bool:
	_mirrored = not _mirrored
	return _mirrored

func get_draft() -> Dictionary:
	return _draft.duplicate(true)

func _failure(reason: String, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
