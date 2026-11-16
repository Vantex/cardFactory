extends Node

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/ResearchBoundaryBehaviorRunner.gd").new().run()
	for error in result.errors: printerr("FAIL: " + error)
	print("RESEARCH BOUNDARY VERIFIED KEYS: ", result.verified_keys.size())
	if result.errors.is_empty(): print("PARITY RESEARCH BOUNDARY TESTS PASSED")
	else: printerr("PARITY RESEARCH BOUNDARY TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
