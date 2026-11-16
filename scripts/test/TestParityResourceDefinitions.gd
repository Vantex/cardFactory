extends Node

const RUNNER := preload("res://scripts/test/ResourceDefinitionBehaviorRunner.gd")

func _ready() -> void:
	var result := RUNNER.new().run()
	var errors: Array = result.errors.duplicate()
	if result.cases != 240 or result.verified_keys.size() != 19: errors.append("sixteen resource and three extractor claims required")
	var broken := DSPOnlineParity.read_json(RUNNER.FIXTURE)
	broken.cases[0].expected.output += 1
	var rejected := RUNNER.new().run(broken)
	if rejected.errors.is_empty() or not rejected.verified_keys.is_empty() or not rejected.proofs.is_empty(): errors.append("resource definition source drift accepted")
	print("RESOURCE DEFINITIONS: cases=", result.cases, "; keys=", result.verified_keys.size(), "; failures=", errors.size(), "; examples=", errors.slice(0, 12))
	if errors.is_empty(): print("PARITY RESOURCE DEFINITION TESTS PASSED")
	get_tree().quit(0 if errors.is_empty() else 1)
