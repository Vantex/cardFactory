extends Node

const RUNNER := preload("res://scripts/test/ResourceInstallBehaviorRunner.gd")

func _ready() -> void:
	var result := RUNNER.new().run({}, true)
	var errors: Array = result.errors.duplicate()
	if result.cases != 703 or result.saves != 16: errors.append("complete install command/group primary coverage required")
	print("RESOURCE INSTALL: cases=", result.cases, "; saves=", result.saves, "; failures=", errors.size(), "; examples=", errors.slice(0, 16))
	if errors.is_empty(): print("PARITY RESOURCE INSTALL TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
