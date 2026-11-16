extends Node

func _ready() -> void:
	var runner := preload("res://scripts/test/SlotCapacityBehaviorRunner.gd")
	var result: Dictionary = runner.new().run()
	result.errors.append_array(runner.rejection_errors())
	result.errors.append_array(preload("res://scripts/test/EffectQueryBehaviorRunner.gd")._ownership_rejections())
	if result.verified_keys != [runner.KEY] or not result.claims.has(runner.KEY) or result.proofs.get(runner.KEY, {}).get("assertions", []).size() != 5648: result.errors.append("complete2824query/5648assertion actual slot proof missing")
	var persistence := preload("res://scripts/test/SlotCapacityPersistenceRegression.gd").new().run()
	result.errors.append_array(persistence.errors)
	if persistence.saves != 12: result.errors.append("twelve actual paid/legacy/arrival boundary saves missing")
	print("SLOT CAPACITY ACTUAL SAVES: ", persistence.saves, "; errors: ", persistence.errors.size(), "; root: ", persistence.root)
	for error in result.errors.slice(0, 20): printerr("FAIL: " + error)
	print("SLOT CAPACITY ERRORS: ", result.errors.size(), "; actual keys: ", result.verified_keys.size(), "; states: ", DSPOnlineParity.read_json(runner.FIXTURE).cases.size(), "; rejection cases: 25")
	print("PARITY SLOT CAPACITY TESTS PASSED" if result.errors.is_empty() else "PARITY SLOT CAPACITY TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
