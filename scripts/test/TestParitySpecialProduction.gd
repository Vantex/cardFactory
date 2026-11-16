extends Node

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/SpecialProductionBehaviorRunner.gd").new().run()
	var errors: Array = result.errors
	for error in errors: printerr("FAIL: " + error)
	if errors.is_empty(): print("PARITY SPECIAL PRODUCTION TESTS PASSED")
	else: printerr("PARITY SPECIAL PRODUCTION TESTS FAILED")
	get_tree().quit(0 if errors.is_empty() else 1)
