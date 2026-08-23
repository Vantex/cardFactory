# autoload/DataManager.gd
extends Node

var all_items: Dictionary = {}
var all_buildings: Dictionary = {}
var all_recipes: Dictionary = {}
var _item_sources: Dictionary = {}
var _building_sources: Dictionary = {}
var _recipe_sources: Dictionary = {}
var _validation_errors: Array = []
var _loaded_data_files: Array[String] = []

func _ready():
    _load_all_data()
    print("DataManager loaded: ", all_items.size(), " items, ", all_buildings.size(), " buildings, ", all_recipes.size(), " recipes")

func _load_all_data():
    all_items.clear()
    all_buildings.clear()
    all_recipes.clear()
    _item_sources.clear()
    _building_sources.clear()
    _recipe_sources.clear()
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
        _validate_recipe_references()
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

func _validate_recipe_references():
    var recipe_ids := all_recipes.keys()
    recipe_ids.sort()
    for recipe_id in recipe_ids:
        var recipe: Dictionary = all_recipes[recipe_id]
        var source: String = _recipe_sources[recipe_id]
        var building_id: String = recipe.get("building_id", "")
        if not all_buildings.has(building_id):
            _validation_errors.append({
                "code": "missing_building_reference",
                "source": source,
                "id": building_id,
                "message": "Recipe '%s' references undefined building '%s'" % [recipe_id, building_id],
            })

        for list_name in ["inputs", "outputs"]:
            for item_reference in recipe.get(list_name, []):
                var item_id: String = item_reference.get("item_id", "")
                if not all_items.has(item_id):
                    _validation_errors.append({
                        "code": "missing_item_reference",
                        "source": source,
                        "id": item_id,
                        "message": "Recipe '%s' %s references undefined item '%s'" % [recipe_id, list_name, item_id],
                    })

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
        if recipe.get("building_id") == building_id:
            result.append(recipe)
    return result
