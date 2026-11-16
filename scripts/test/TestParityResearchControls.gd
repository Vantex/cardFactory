extends Node

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/ResearchControlBehaviorRunner.gd").new().run()
	if result.verified_keys.size() != 5: result.errors.append("all five control endpoints require passing claims")
	for error in result.errors: printerr("FAIL: " + error)
	print("RESEARCH CONTROL VERIFIED KEYS: ", result.verified_keys.size())
	if result.errors.is_empty(): print("PARITY RESEARCH CONTROL TESTS PASSED")
	else: printerr("PARITY RESEARCH CONTROL TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
