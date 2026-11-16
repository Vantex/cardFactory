extends Node

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/ProgressionBehaviorRunner.gd").new().run()
	if result.verified_keys.size() != 45: result.errors.append("all 32 campaign and 13 achievement definitions require complete passing evidence")
	for error in result.errors: printerr("FAIL: " + error)
	print("PROGRESSION VERIFIED KEYS: ", result.verified_keys.size())
	if result.errors.is_empty(): print("PARITY PROGRESSION TESTS PASSED")
	else: printerr("PARITY PROGRESSION TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
