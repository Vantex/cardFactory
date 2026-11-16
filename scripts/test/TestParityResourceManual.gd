extends Node

const RUNNER := preload("res://scripts/test/ResourceManualBehaviorRunner.gd")

func _ready() -> void:
	var result := RUNNER.new().run()
	var errors: Array = result.errors.duplicate()
	errors.append_array(RUNNER.rejection_errors())
	print("RESOURCE MANUAL: cases=", result.cases, "; claims=", result.claims.get(RUNNER.KEY, {}).get("assertions", []).size(), "; errors=", errors)
	if errors.is_empty(): print("PARITY RESOURCE MANUAL TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
