extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/SailLifetimeBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	result.errors.append_array(runner.rejection_errors())
	result.errors.append_array(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership_rejections())
	if result.verified_keys != [runner.KEY]: result.errors.append("actual sail lifetime key missing")
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("SAIL LIFETIME ERRORS: ", result.errors.size(), "; actual keys: ", result.verified_keys.size(), "; states: ", DSPOnlineParity.read_json(runner.FIXTURE).cases.size(), "; rejection cases: 20")
	print("PARITY SAIL LIFETIME TESTS PASSED" if result.errors.is_empty() else "PARITY SAIL LIFETIME TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
