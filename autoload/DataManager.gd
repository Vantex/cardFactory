# autoload/DataManager.gd
extends Node

var all_items: Dictionary = {}
var all_buildings: Dictionary = {}
var all_recipes: Dictionary = {}
var all_technologies: Dictionary = {}
var mandatory_items: Array[String] = []
var _item_sources: Dictionary = {}
var _building_sources: Dictionary = {}
var _recipe_sources: Dictionary = {}
var _technology_sources: Dictionary = {}
var _validation_errors: Array = []
var _loaded_data_files: Array[String] = []

func _ready():
    _load_all_data()
    print("DataManager loaded: ", all_items.size(), " items, ", all_buildings.size(), " buildings, ", all_recipes.size(), " recipes")

func _load_all_data():
    all_items.clear()
    all_buildings.clear()
    all_recipes.clear()
    all_technologies.clear()
    mandatory_items.clear()
    _item_sources.clear()
    _building_sources.clear()
    _recipe_sources.clear()
    _technology_sources.clear()
    _validation_errors.clear()
    _loaded_data_files.clear()

    var dir = DirAccess.open("res://data")
    if dir:
        var file_names: Array[String] = []
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                file_names.append(file_name)
            file_name = dir.get_next()
        dir.list_dir_end()
        file_names.sort()
        for data_file_name in file_names:
            _load_data_file("res://data/" + data_file_name)
        _validation_errors.append_array(validate_catalog({
            "items": all_items,
            "buildings": all_buildings,
            "recipes": all_recipes,
            "technologies": all_technologies,
            "mandatory_items": mandatory_items,
        }))
    else:
        _validation_errors.append({
            "code": "data_directory_unavailable",
            "source": "res://data",
            "id": "res://data",
            "message": "Could not open data directory",
        })
        print("ERROR: Could not open data directory")

func _load_data_file(path: String):
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        if error == OK:
            var data = json.data
            if not data is Dictionary:
                _validation_errors.append({
                    "code": "data_file_root_not_dictionary",
                    "source": path,
                    "id": path,
                    "message": "JSON root is not a Dictionary: %s" % path,
                })
                print("Error parsing JSON root: ", path)
                return

            _load_entries(data.get("items", {}), all_items, _item_sources, "items", path)
            _load_entries(data.get("buildings", {}), all_buildings, _building_sources, "buildings", path)
            _load_entries(data.get("recipes", {}), all_recipes, _recipe_sources, "recipes", path)
            _load_entries(data.get("technologies", {}), all_technologies, _technology_sources, "technologies", path)
            for mandatory_value in data.get("mandatory_items", []):
                var mandatory_item_id := String(mandatory_value)
                if mandatory_items.has(mandatory_item_id):
                    _validation_errors.append(_make_error("duplicate_mandatory_item", path, mandatory_item_id, "Mandatory item '%s' is declared more than once" % mandatory_item_id))
                else:
                    mandatory_items.append(mandatory_item_id)

            _loaded_data_files.append(path)
            print("Loaded data file: ", path)
        else:
            _validation_errors.append({
                "code": "data_file_parse_failed",
                "source": path,
                "id": path,
                "message": "Error parsing JSON: %s" % path,
            })
            print("Error parsing JSON: ", path)
    else:
        _validation_errors.append({
            "code": "data_file_open_failed",
            "source": path,
            "id": path,
            "message": "Error opening file: %s" % path,
        })
        print("Error opening file: ", path)

func _load_entries(entries: Dictionary, destination: Dictionary, sources: Dictionary, kind: String, source: String):
    for entry_id in entries:
        if destination.has(entry_id):
            _validation_errors.append({
                "code": "duplicate_id",
                "source": source,
                "id": "%s/%s" % [kind, entry_id],
                "message": "Duplicate %s ID '%s'; first defined in %s" % [kind, entry_id, sources[entry_id]],
            })
            continue
        destination[entry_id] = entries[entry_id]
        sources[entry_id] = source

func validate_catalog(catalog: Dictionary) -> Array:
    var errors: Array = []
    var items: Dictionary = catalog.get("items", {})
    var buildings: Dictionary = catalog.get("buildings", {})
    var recipes: Dictionary = catalog.get("recipes", {})
    var technologies: Dictionary = catalog.get("technologies", {})
    var required_items: Array = catalog.get("mandatory_items", [])

    for building_key in buildings:
        var building_id := String(building_key)
        var building: Dictionary = buildings[building_key]
        var source := String(_building_sources.get(building_id, "catalog"))
        _validate_positive_number(errors, building.get("speed", 1.0), "invalid_speed", source, building_id, "Building speed must be positive")
        _validate_nonnegative_number(errors, building.get("power_demand", 0.0), "invalid_power", source, building_id, "Building power demand must be nonnegative")
        _validate_nonnegative_number(errors, building.get("power_generation", 0.0), "invalid_power", source, building_id, "Building power generation must be nonnegative")
        for capacity_key in ["input_buffer_capacity", "output_buffer_capacity"]:
            if building.has(capacity_key):
                _validate_positive_number(errors, building[capacity_key], "invalid_buffer_capacity", source, building_id, "%s must be positive" % capacity_key)
        var extraction: Dictionary = building.get("extraction", {})
        if building.get("kind", "") == "extractor":
            var resource_id := String(extraction.get("item_id", ""))
            if not items.has(resource_id):
                errors.append(_make_error("missing_item_reference", source, resource_id, "Extractor '%s' references undefined item '%s'" % [building_id, resource_id]))
            var extraction_items: Array = extraction.get("items", [resource_id])
            for extraction_item_value in extraction_items:
                var extraction_item_id := String(extraction_item_value)
                if not items.has(extraction_item_id):
                    errors.append(_make_error("missing_item_reference", source, extraction_item_id, "Extractor '%s' references undefined resource '%s'" % [building_id, extraction_item_id]))
            _validate_positive_number(errors, extraction.get("rate_per_minute", 0.0), "invalid_extraction_rate", source, building_id, "Extractor rate must be positive")
        var fuel: Dictionary = building.get("fuel", {})
        if not fuel.is_empty():
            var fuel_item_id := String(fuel.get("item_id", ""))
            if not items.has(fuel_item_id):
                errors.append(_make_error("missing_item_reference", source, fuel_item_id, "Generator '%s' references undefined fuel '%s'" % [building_id, fuel_item_id]))
            _validate_positive_number(errors, fuel.get("burn_duration", 0.0), "invalid_fuel_duration", source, building_id, "Fuel burn duration must be positive")

    for recipe_key in recipes:
        var recipe_id := String(recipe_key)
        var recipe: Dictionary = recipes[recipe_key]
        var source := String(_recipe_sources.get(recipe_id, "catalog"))
        var recipe_building_ids: Array = recipe.get("building_ids", [recipe.get("building_id", "")])
        for building_id_value in recipe_building_ids:
            var building_id := String(building_id_value)
            if not buildings.has(building_id):
                errors.append(_make_error("missing_building_reference", source, building_id, "Recipe '%s' references undefined building '%s'" % [recipe_id, building_id]))
        _validate_positive_number(errors, recipe.get("duration", 0.0), "invalid_duration", source, recipe_id, "Recipe duration must be positive")
        for list_name in ["inputs", "outputs"]:
            var references: Array = recipe.get(list_name, [])
            if list_name == "outputs" and references.is_empty():
                errors.append(_make_error("missing_recipe_output", source, recipe_id, "Recipe '%s' must declare at least one output" % recipe_id))
            var seen_items: Dictionary = {}
            for item_reference_value in references:
                if not item_reference_value is Dictionary:
                    errors.append(_make_error("invalid_item_reference", source, recipe_id, "Recipe '%s' contains a malformed %s entry" % [recipe_id, list_name]))
                    continue
                var item_reference: Dictionary = item_reference_value
                var item_id := String(item_reference.get("item_id", ""))
                if not items.has(item_id):
                    errors.append(_make_error("missing_item_reference", source, item_id, "Recipe '%s' %s references undefined item '%s'" % [recipe_id, list_name, item_id]))
                _validate_positive_number(errors, item_reference.get("amount", 0.0), "invalid_amount", source, "%s/%s" % [recipe_id, item_id], "Recipe item amount must be positive")
                if seen_items.has(item_id):
                    errors.append(_make_error("duplicate_recipe_item", source, "%s/%s" % [recipe_id, item_id], "Recipe '%s' repeats item '%s' in %s" % [recipe_id, item_id, list_name]))
                seen_items[item_id] = true

    for technology_key in technologies:
        var technology_id := String(technology_key)
        var technology: Dictionary = technologies[technology_key]
        var source := String(_technology_sources.get(technology_id, "catalog"))
        if String(technology.get("id", "")) != technology_id:
            errors.append(_make_error("technology_id_mismatch", source, technology_id, "Technology key and stable id must match"))
        if technology.has("repeatable") and (not technology.get("repeatable") is Dictionary or String(technology.get("repeatable", {}).get("cost_rule", "")) != "fixed"):
            errors.append(_make_error("invalid_repeatable_rule", source, technology_id, "Technology repeatable must declare a fixed cost rule"))
        _validate_positive_number(errors, technology.get("duration", 0.0), "invalid_duration", source, technology_id, "Technology duration must be positive")
        for cost_key in technology.get("cost", {}):
            var item_id := String(cost_key)
            if not items.has(item_id):
                errors.append(_make_error("missing_item_reference", source, item_id, "Technology '%s' references undefined cost item '%s'" % [technology_id, item_id]))
            _validate_positive_number(errors, technology.get("cost", {})[cost_key], "invalid_amount", source, "%s/%s" % [technology_id, item_id], "Technology cost must be positive")
        for prerequisite_value in technology.get("prerequisites", []):
            var prerequisite_id := String(prerequisite_value)
            if not technologies.has(prerequisite_id):
                errors.append(_make_error("missing_technology_reference", source, prerequisite_id, "Technology '%s' references undefined prerequisite '%s'" % [technology_id, prerequisite_id]))
        for unlock_value in technology.get("unlocks", []):
            _validate_unlock(errors, technology_id, unlock_value, source, items, buildings, recipes, technologies)

    var visit_state: Dictionary = {}
    var technology_ids := technologies.keys()
    technology_ids.sort()
    for technology_id_value in technology_ids:
        _detect_technology_cycle(String(technology_id_value), technologies, visit_state, [], errors)

    var producible_items := _get_producible_items(items, buildings, recipes)
    for mandatory_value in required_items:
        var mandatory_item_id := String(mandatory_value)
        if not producible_items.has(mandatory_item_id):
            errors.append(_make_error("uncraftable_mandatory_item", "catalog", mandatory_item_id, "Mandatory item '%s' cannot be produced from catalog resources" % mandatory_item_id))
    return errors

func _validate_unlock(errors: Array, technology_id: String, unlock_value: Variant, source: String, items: Dictionary, buildings: Dictionary, recipes: Dictionary, technologies: Dictionary) -> void:
    if not unlock_value is Dictionary:
        errors.append(_make_error("invalid_unlock", source, technology_id, "Technology unlocks must declare kind and id"))
        return
    var unlock: Dictionary = unlock_value
    var unlock_kind := String(unlock.get("kind", ""))
    var unlock_id := String(unlock.get("id", ""))
    var collections := {"item": items, "building": buildings, "recipe": recipes, "technology": technologies}
    if not collections.has(unlock_kind) or not collections[unlock_kind].has(unlock_id):
        errors.append(_make_error("missing_unlock_reference", source, unlock_id, "Technology '%s' has invalid %s unlock '%s'" % [technology_id, unlock_kind, unlock_id]))

func _detect_technology_cycle(technology_id: String, technologies: Dictionary, visit_state: Dictionary, path: Array, errors: Array) -> void:
    var state := int(visit_state.get(technology_id, 0))
    if state == 2:
        return
    if state == 1:
        errors.append(_make_error("technology_cycle", String(_technology_sources.get(technology_id, "catalog")), technology_id, "Technology prerequisites contain a cycle through '%s'" % technology_id))
        return
    visit_state[technology_id] = 1
    path.append(technology_id)
    var technology: Dictionary = technologies.get(technology_id, {})
    for prerequisite_value in technology.get("prerequisites", []):
        var prerequisite_id := String(prerequisite_value)
        if technologies.has(prerequisite_id):
            _detect_technology_cycle(prerequisite_id, technologies, visit_state, path, errors)
    path.pop_back()
    visit_state[technology_id] = 2

func _get_producible_items(items: Dictionary, buildings: Dictionary, recipes: Dictionary) -> Dictionary:
    var producible: Dictionary = {}
    for building_value in buildings.values():
        var building: Dictionary = building_value
        var extraction: Dictionary = building.get("extraction", {})
        var resource_ids: Array = extraction.get("items", [extraction.get("item_id", "")])
        for resource_value in resource_ids:
            var item_id := String(resource_value)
            if items.has(item_id):
                producible[item_id] = true
    var changed := true
    while changed:
        changed = false
        for recipe_value in recipes.values():
            var recipe: Dictionary = recipe_value
            var inputs_available := true
            for input_value in recipe.get("inputs", []):
                if not producible.has(String(input_value.get("item_id", ""))):
                    inputs_available = false
                    break
            if not inputs_available:
                continue
            for output_value in recipe.get("outputs", []):
                var output_id := String(output_value.get("item_id", ""))
                if items.has(output_id) and not producible.has(output_id):
                    producible[output_id] = true
                    changed = true
    return producible

func _validate_positive_number(errors: Array, value: Variant, code: String, source: String, entry_id: String, message: String) -> void:
    if not _is_finite_number(value) or float(value) <= 0.0:
        errors.append(_make_error(code, source, entry_id, message))

func _validate_nonnegative_number(errors: Array, value: Variant, code: String, source: String, entry_id: String, message: String) -> void:
    if not _is_finite_number(value) or float(value) < 0.0:
        errors.append(_make_error(code, source, entry_id, message))

func _is_finite_number(value: Variant) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value))

func _make_error(code: String, source: String, entry_id: String, message: String) -> Dictionary:
    return {"code": code, "source": source, "id": entry_id, "message": message}

func get_validation_errors() -> Array:
    return _validation_errors.duplicate()

func get_loaded_data_files() -> Array[String]:
    return _loaded_data_files.duplicate()

func get_item(item_id: String) -> Dictionary:
    return all_items.get(item_id, {})

func get_building(building_id: String) -> Dictionary:
    return all_buildings.get(building_id, {})

func get_recipe(recipe_id: String) -> Dictionary:
    return all_recipes.get(recipe_id, {})

func get_technology(technology_id: String) -> Dictionary:
    return all_technologies.get(technology_id, {})

func get_all_technologies() -> Dictionary:
    return all_technologies.duplicate(true)

func get_mandatory_items() -> Array[String]:
    return mandatory_items.duplicate()

func get_buildings_by_kind(kind: String) -> Array:
    var result = []
    for building_id in all_buildings:
        var building = all_buildings[building_id]
        if building.get("kind") == kind:
            result.append(building)
    return result

func get_recipes_for_building(building_id: String) -> Array:
    var result = []
    for recipe_id in all_recipes:
        var recipe = all_recipes[recipe_id]
        if is_recipe_supported_by_building(recipe, building_id):
            result.append(recipe)
    return result

func is_recipe_supported_by_building(recipe: Dictionary, building_id: String) -> bool:
    var building_ids: Array = recipe.get("building_ids", [recipe.get("building_id", "")])
    return building_ids.has(building_id)
