extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/CapacityQueryBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	result.errors.append_array(runner.rejection_errors())
	result.errors.append_array(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership_rejections())
	if result.verified_keys != runner.FUNCTIONS.map(func(function): return "commands:engine." + function): result.errors.append("actual capacity keys missing")
	var persistence: Dictionary = preload("res://scripts/test/CapacityPersistenceRegression.gd").new().run()
	result.errors.append_array(persistence.errors)
	if persistence.saves != 5: result.errors.append("five actual entity saves missing")
	print("CAPACITY ENTITY PERSISTENCE SAVES: ", persistence.saves, "; errors: ", persistence.errors.size(), "; root: ", persistence.root)
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("CAPACITY QUERY ERRORS: ", result.errors.size(), "; actual keys: ", result.verified_keys.size(), "; states: ", DSPOnlineParity.read_json(runner.FIXTURE).cases.size(), "; rejection cases: 24")
	print("PARITY CAPACITY QUERY TESTS PASSED" if result.errors.is_empty() else "PARITY CAPACITY QUERY TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
