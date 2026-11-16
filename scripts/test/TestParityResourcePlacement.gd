extends Node

func _ready() -> void:
	var paid := preload("res://scripts/test/ResourcePlacementRegression.gd")
	var result: Dictionary = paid.new().run()
	result.errors.append_array(paid.rejection_errors())
	if result.bindings != 16 or result.saves != 16: result.errors.append("sixteen actual funded source resource placements and primary roundtrips missing")
	var boundaries := preload("res://scripts/test/ResourcePlacementBoundaryRegression.gd").new().run()
	result.errors.append_array(boundaries.errors)
	if boundaries.cases != 15: result.errors.append("fifteen atomic placement/native/custom boundary checks missing")
	var ui: Dictionary = await preload("res://scripts/test/ResourceSelectionUIRegression.gd").new().run(get_tree())
	result.errors.append_array(ui.errors)
	if ui.selections != 16 or ui.rebindings != 13 or ui.rejections != 15 or ui.saves != 16: result.errors.append("formal source resource Inspector selections/rebindings/rejections/primary saves incomplete")
	print("RESOURCE PLACEMENT SUMMARY: bindings ", result.bindings, "; paid saves ", result.saves, "; boundaries ", boundaries.cases, "; UI selections ", ui.selections, "; UI saves ", ui.saves, "; fixture rejections 23; errors ", result.errors.size())
	for error in result.errors: printerr("FAIL: " + error)
	print("PARITY RESOURCE PLACEMENT TESTS PASSED" if result.errors.is_empty() else "PARITY RESOURCE PLACEMENT TESTS FAILED")
	get_tree().quit(0 if result.errors.is_empty() else 1)
