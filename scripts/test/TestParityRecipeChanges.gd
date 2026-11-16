extends Node

func _ready() -> void:
	var result := preload("res://scripts/test/RecipeCommandBehaviorRunner.gd").new().run()
	result.errors.append_array(preload("res://scripts/test/SpecialRecipeCommandRegression.gd").new().run())
	for failure in result.errors: printerr("FAIL: " + failure)
	if result.errors.is_empty(): print("PARITY RECIPE COMMAND TESTS PASSED")
	else: printerr("PARITY RECIPE COMMAND TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
