extends Node

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/FiniteResearchBehaviorRunner.gd").new().run()
	for error in result.errors: printerr("FAIL: " + error)
	print("FINITE RESEARCH VERIFIED KEYS: ", result.verified_keys.size())
	if result.errors.is_empty(): print("PARITY FINITE RESEARCH TESTS PASSED")
	else: printerr("PARITY FINITE RESEARCH TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
