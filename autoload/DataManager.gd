# autoload/DataManager.gd
extends Node

var all_items: Dictionary = {}
var all_buildings: Dictionary = {}
var all_recipes: Dictionary = {}

func _ready():
    _load_all_data()
    print("DataManager loaded: ", all_items.size(), " items, ", all_buildings.size(), " buildings, ", all_recipes.size(), " recipes")

func _load_all_data():
    var dir = DirAccess.open("res://data")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                _load_data_file("res://data/" + file_name)
            file_name = dir.get_next()
    else:
        print("ERROR: Could not open data directory")

func _load_data_file(path: String):
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        if error == OK:
            var data = json.data
            
            # 加载物品
            for item_id in data.get("items", {}):
                all_items[item_id] = data.items[item_id]
            
            # 加载建筑
            for building_id in data.get("buildings", {}):
                all_buildings[building_id] = data.buildings[building_id]
            
            # 加载配方
            for recipe_id in data.get("recipes", {}):
                all_recipes[recipe_id] = data.recipes[recipe_id]
            
            print("Loaded data file: ", path)
        else:
            print("Error parsing JSON: ", path)
    else:
        print("Error opening file: ", path)

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
