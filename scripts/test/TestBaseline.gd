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
		"res://data/dyson.json", "res://data/electronics.json",
		"res://data/galaxy.json",
		"res://data/infinite_research.json",
		"res://data/power_storage.json",
		"res://data/production_catalog.json",
		"res://data/progression.json",
		"res://data/technologies.json",
	]
	var loaded_data_files = DataManager.get_loaded_data_files()
	_expect(loaded_data_files is Array, "DataManager loaded data files are an Array")
	if loaded_data_files is Array:
		_expect(loaded_data_files.size() == expected_loaded_data_files.size(), "DataManager loaded exactly eleven data files")
		for expected_path in expected_loaded_data_files:
			_expect(loaded_data_files.has(expected_path), "DataManager loaded %s" % expected_path)
		loaded_data_files.clear()
		_expect(DataManager.get_loaded_data_files() == expected_loaded_data_files, "DataManager loaded data files API returns a shallow copy")

	_test_catalog_validation_contract()
	_test_technology_schema_validation()

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
			"cycle_a": {"id": "cycle_a_wrong", "cost": {"ore": 1.0}, "duration": 1.0, "prerequisites": ["cycle_b"], "unlocks": [], "repeatable": true},
			"cycle_b": {"id": "cycle_b", "cost": {"ore": 1.0}, "duration": 1.0, "prerequisites": ["cycle_a"], "unlocks": []},
		},
		"mandatory_items": ["ore"],
	}
	var errors: Array = DataManager.validate_catalog(invalid_catalog)
	var codes: Array[String] = []
	for error_value in errors:
		codes.append(String(error_value.get("code", "")))
	for expected_code in ["missing_building_reference", "missing_item_reference", "invalid_amount", "invalid_duration", "technology_cycle", "technology_id_mismatch", "invalid_repeatable_rule", "uncraftable_mandatory_item"]:
		_expect(codes.has(expected_code), "catalog validation rejects %s" % expected_code)

func _test_technology_schema_validation() -> void:
	var valid_technology := {
		"id": "valid",
		"name": "Valid technology",
		"description": "A complete technology definition.",
		"tier": "planetary",
		"cost": {"matrix_science_1": 1.0},
		"duration": 1.0,
		"prerequisites": [],
		"unlocks": [],
		"effects": {"production_speed": 1.01},
	}
	var technologies := {"valid": valid_technology}
	var bad_definitions := {
		"missing_name": {"name": ""},
		"missing_description": {"description": ""},
		"missing_tier": {"tier": ""},
		"bad_tier": {"tier": "galactic"},
		"free_research": {"cost": {}},
		"bad_cost_shape": {"cost": []},
		"bad_cost_amount": {"cost": {"matrix_science_1": 0.0}},
		"unknown_cost_item": {"cost": {"missing_matrix": 1.0}},
		"missing_effects": {"effects": {}},
		"bad_effects_shape": {"effects": []},
		"unknown_effect": {"effects": {"free_everything": 1.0}},
		"bad_effect_value": {"effects": {"production_speed": 0.0}},
		"bad_duration": {"duration": 0.0},
		"bad_prerequisites_shape": {"prerequisites": {"valid": true}},
		"bad_prerequisite_entry": {"prerequisites": [42]},
		"bad_unlocks_shape": {"unlocks": {"kind": "building", "id": "missing"}},
		"bad_unlock_entry": {"unlocks": [{"kind": "", "id": ""}]},
	}
	for technology_id in bad_definitions:
		var definition: Dictionary = valid_technology.duplicate(true)
		definition["id"] = technology_id
		for field in bad_definitions[technology_id]:
			definition[field] = bad_definitions[technology_id][field]
		technologies[technology_id] = definition

	var errors := DataManager.validate_catalog({
		"items": {"matrix_science_1": {"id": "matrix_science_1"}},
		"buildings": {},
		"recipes": {},
		"technologies": technologies,
		"mandatory_items": [],
	})
	var expected_errors := {
		"missing_name": "missing_technology_name",
		"missing_description": "missing_technology_description",
		"missing_tier": "invalid_technology_tier",
		"bad_tier": "invalid_technology_tier",
		"free_research": "invalid_technology_cost",
		"bad_cost_shape": "invalid_technology_cost",
		"bad_cost_amount": "invalid_technology_cost_amount",
		"unknown_cost_item": "missing_item_reference",
		"missing_effects": "invalid_technology_effects",
		"bad_effects_shape": "invalid_technology_effects",
		"unknown_effect": "unknown_technology_effect",
		"bad_effect_value": "invalid_technology_effect_value",
		"bad_duration": "invalid_duration",
		"bad_prerequisites_shape": "invalid_technology_prerequisites",
		"bad_prerequisite_entry": "invalid_technology_prerequisite",
		"bad_unlocks_shape": "invalid_technology_unlocks",
		"bad_unlock_entry": "invalid_unlock",
	}
	for technology_id in expected_errors:
		_expect(_has_validation_error(errors, expected_errors[technology_id], technology_id), "technology schema rejects %s with %s" % [technology_id, expected_errors[technology_id]])
	_expect(_has_validation_error(errors, "invalid_technology_cost", "free_research"), "technology validation rejects a zero-cost save-bypass definition at the catalog boundary")

func _has_validation_error(errors: Array, code: String, entry_id: String) -> bool:
	for error_value in errors:
		if String(error_value.get("code", "")) == code and String(error_value.get("id", "")).begins_with(entry_id):
			return true
	return false

func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return

	_failures += 1
	printerr("FAIL: %s" % description)
