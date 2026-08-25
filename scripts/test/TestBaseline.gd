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
		"res://data/progression.json",
	]
	var loaded_data_files = DataManager.get_loaded_data_files()
	_expect(loaded_data_files is Array, "DataManager loaded data files are an Array")
	if loaded_data_files is Array:
		_expect(loaded_data_files.size() == expected_loaded_data_files.size(), "DataManager loaded exactly five data files")
		for expected_path in expected_loaded_data_files:
			_expect(loaded_data_files.has(expected_path), "DataManager loaded %s" % expected_path)
		loaded_data_files.clear()
		_expect(DataManager.get_loaded_data_files() == expected_loaded_data_files, "DataManager loaded data files API returns a shallow copy")

	_test_catalog_validation_contract()

	var unavailable_save_system := SaveSystem.new("invalid://baseline/")
	_expect(not unavailable_save_system.is_storage_available(), "SaveSystem reports invalid storage as unavailable")
	_expect(not unavailable_save_system.save_game(0, GameState.new()), "SaveSystem safely rejects saves when storage is unavailable")
	var cloud_sync_result: Variant = unavailable_save_system.sync_to_cloud(0)
	var cloud_backup_result: Variant = unavailable_save_system.backup_to_cloud(0)
	var cloud_restore_result: Variant = unavailable_save_system.restore_from_cloud(0)
	var compression_result: Variant = unavailable_save_system.compress_save(0)
	var decompression_result: Variant = unavailable_save_system.decompress_save(0)
	var migration_result: Variant = unavailable_save_system.migrate_save(0, 1)
	_expect(typeof(cloud_sync_result) == TYPE_INT and int(cloud_sync_result) == ERR_UNAVAILABLE, "SaveSystem reports cloud sync as unavailable")
	_expect(typeof(cloud_backup_result) == TYPE_INT and int(cloud_backup_result) == ERR_UNAVAILABLE, "SaveSystem reports cloud backup as unavailable")
	_expect(typeof(cloud_restore_result) == TYPE_INT and int(cloud_restore_result) == ERR_UNAVAILABLE, "SaveSystem reports cloud restore as unavailable")
	_expect(typeof(compression_result) == TYPE_INT and int(compression_result) == ERR_UNAVAILABLE, "SaveSystem reports save compression as unavailable")
	_expect(typeof(decompression_result) == TYPE_INT and int(decompression_result) == ERR_UNAVAILABLE, "SaveSystem reports save decompression as unavailable")
	_expect(typeof(migration_result) == TYPE_INT and int(migration_result) == ERR_UNAVAILABLE, "SaveSystem reports save migration as unavailable")

	var performance_system := PerformanceSystem.new(game_state)
	_expect(not performance_system.use_web_workers(), "PerformanceSystem does not report worker support as enabled")

	var local_save_system := SaveSystem.new("res://.godot/test_saves/")
	_expect(local_save_system.is_storage_available(), "SaveSystem creates an available local test storage")
	_expect(local_save_system.save_game(0, GameState.new()), "SaveSystem writes a local save used for size verification")
	_expect(local_save_system.get_save_size(0) > 0, "SaveSystem reports the stored file size")
	_expect(local_save_system.delete_save(0), "SaveSystem removes the local size-verification save")

	if _failures > 0:
		printerr("BASELINE TESTS FAILED")
		get_tree().quit(1)
		return

	print("BASELINE TESTS PASSED")
	get_tree().quit(0)

func _test_catalog_validation_contract() -> void:
	_expect(DataManager.get_item("matrix_science_1").get("name", "") != "", "catalog defines the first research matrix")
	_expect(DataManager.get_recipe("basic_matrix_recipe").get("building_id", "") == "matrix_lab", "catalog maps the first matrix recipe to research equipment")
	_expect(DataManager.is_recipe_supported_by_building(DataManager.get_recipe("circuit_recipe"), "assembler"), "catalog preserves the legacy assembler recipe mapping for schema-v2 saves")
	_expect(DataManager.get_technology("factory_foundations").get("prerequisites", null) is Array, "technologies are loaded through DataManager")
	_expect(DataManager.get_mandatory_items().has("matrix_science_1"), "catalog declares the tutorial matrix as mandatory progression content")

	var invalid_catalog := {
		"items": {"ore": {"id": "ore"}},
		"buildings": {"processor": {"id": "processor", "kind": "processor", "power_demand": 0.0, "speed": 1.0}},
		"recipes": {
			"broken": {
				"id": "broken",
				"building_id": "missing_building",
				"inputs": [{"item_id": "missing_item", "amount": 0.0}],
				"outputs": [{"item_id": "ore", "amount": -1.0}],
				"duration": 0.0,
			},
		},
		"technologies": {
			"cycle_a": {"id": "cycle_a", "cost": {"ore": 1.0}, "duration": 1.0, "prerequisites": ["cycle_b"], "unlocks": []},
			"cycle_b": {"id": "cycle_b", "cost": {"ore": 1.0}, "duration": 1.0, "prerequisites": ["cycle_a"], "unlocks": []},
		},
		"mandatory_items": ["ore"],
	}
	var errors: Array = DataManager.validate_catalog(invalid_catalog)
	var codes: Array[String] = []
	for error_value in errors:
		codes.append(String(error_value.get("code", "")))
	for expected_code in ["missing_building_reference", "missing_item_reference", "invalid_amount", "invalid_duration", "technology_cycle", "uncraftable_mandatory_item"]:
		_expect(codes.has(expected_code), "catalog validation rejects %s" % expected_code)

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
