extends Node

func _ready() -> void:
	var result: Dictionary = preload("res://scripts/test/CampaignControlBehaviorRunner.gd").new().run()
	for error in result.errors: printerr("FAIL: " + error)
	if result.errors.is_empty(): print("PARITY CAMPAIGN CONTROL DOMAIN TESTS PASSED")
	else: printerr("PARITY CAMPAIGN CONTROL DOMAIN TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
