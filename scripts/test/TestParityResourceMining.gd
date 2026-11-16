extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var result := preload("res://scripts/test/ResourceMiningRegression.gd").new().run()
	var rejects := preload("res://scripts/test/ResourceMiningRegression.gd").rejection_errors()
	result.errors.append_array(rejects.errors)
	var fixture := DSPOnlineParity.read_json(preload("res://scripts/test/ResourceMiningRegression.gd").FIXTURES.live60)
	var paid := preload("res://scripts/test/ResourceMiningPersistenceRegression.gd").new().run(fixture)
	result.errors.append_array(paid.errors)
	var legacy := preload("res://scripts/test/LegacyMiningCompatibilityRegression.gd").new().run()
	result.errors.append_array(legacy.errors)
	if result.cases != 11520 or rejects.rejections != 64 or paid.saves != 32 or paid.panels != 33 or legacy.saves != 6 or legacy.rejections != 27 or legacy.boundaries != 3: result.errors.append("source mining numeric/paid/legacy/rejection counts incomplete")
	print("RESOURCE MINING SUMMARY: cases ", result.cases, "; paid saves ", paid.saves, "; paid panels ", paid.panels, "; legacy saves ", legacy.saves, "; debt rejects ", legacy.rejections, "; boundaries ", legacy.boundaries, "; fixture rejects ", rejects.rejections, "; errors ", result.errors.size())
	for error in result.errors: printerr("FAIL: " + error)
	print("PARITY RESOURCE MINING TESTS PASSED" if result.errors.is_empty() else "PARITY RESOURCE MINING TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
