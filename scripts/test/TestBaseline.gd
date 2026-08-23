extends Node

var _failures := 0

func _ready() -> void:
	print("BASELINE TESTS STARTED")

	var game_state := GameState.new()
	var simulation_engine := SimulationEngine.new(game_state)
	var statistics = simulation_engine.get_statistics()

	_expect(statistics is Dictionary, "get_statistics() returns a Dictionary")
	if statistics is Dictionary:
		for key in ["total_buildings", "total_connections", "elapsed_time", "production", "consumption"]:
			_expect(statistics.has(key), "statistics contains %s" % key)

	var validation_errors = DataManager.get_validation_errors()
	_expect(validation_errors is Array, "DataManager validation errors are an Array")
	if validation_errors is Array:
		_expect(validation_errors.is_empty(), "DataManager validation errors are empty")
		for validation_error in validation_errors:
			print("VALIDATION ERROR: %s" % validation_error)
			_expect(validation_error is Dictionary, "DataManager validation error is a Dictionary")
			if validation_error is Dictionary:
				for key in ["code", "source", "id", "message"]:
					_expect(validation_error.has(key), "DataManager validation error contains %s" % key)

	var expected_loaded_data_files: Array[String] = [
		"res://data/advanced_buildings.json",
		"res://data/base_metals.json",
		"res://data/chemicals.json",
		"res://data/electronics.json",
	]
	var loaded_data_files = DataManager.get_loaded_data_files()
	_expect(loaded_data_files is Array, "DataManager loaded data files are an Array")
	if loaded_data_files is Array:
		_expect(loaded_data_files.size() == expected_loaded_data_files.size(), "DataManager loaded exactly four data files")
		for expected_path in expected_loaded_data_files:
			_expect(loaded_data_files.has(expected_path), "DataManager loaded %s" % expected_path)
		loaded_data_files.clear()
		_expect(DataManager.get_loaded_data_files() == expected_loaded_data_files, "DataManager loaded data files API returns a shallow copy")

	var unavailable_save_system := SaveSystem.new("invalid://baseline/")
	_expect(not unavailable_save_system.is_storage_available(), "SaveSystem reports invalid storage as unavailable")
	_expect(not unavailable_save_system.save_game(0, GameState.new()), "SaveSystem safely rejects saves when storage is unavailable")

	if _failures > 0:
		printerr("BASELINE TESTS FAILED")
		get_tree().quit(1)
		return

	print("BASELINE TESTS PASSED")
	get_tree().quit(0)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
