class_name RecipeGraph
extends RefCounted

var _items: Dictionary
var _recipes: Dictionary
var _buildings: Dictionary
var _producers_by_item: Dictionary = {}
var _consumers_by_item: Dictionary = {}
var _extractors_by_item: Dictionary = {}
var _buildings_by_recipe: Dictionary = {}
var _rates_by_recipe: Dictionary = {}

func _init(items: Dictionary, recipes: Dictionary, buildings: Dictionary) -> void:
	_items = items.duplicate(true)
	_recipes = recipes.duplicate(true)
	_buildings = buildings.duplicate(true)
	_build_indexes()

func get_producers(item_id: String) -> Array:
	return _producers_by_item.get(item_id, []).duplicate()

func get_consumers(item_id: String) -> Array:
	return _consumers_by_item.get(item_id, []).duplicate()

func get_recipe_buildings(recipe_id: String) -> Array:
	return _buildings_by_recipe.get(recipe_id, []).duplicate()

func get_theoretical_rate_per_minute(recipe_id: String, item_id: String = "") -> float:
	var rates: Dictionary = _rates_by_recipe.get(recipe_id, {})
	if item_id.is_empty():
		var total := 0.0
		for rate in rates.values():
			total += float(rate)
		return total
	return float(rates.get(item_id, 0.0))

func get_recipe_rates_per_minute(recipe_id: String) -> Dictionary:
	return _rates_by_recipe.get(recipe_id, {}).duplicate(true)

func build_upstream_chain(item_id: String, max_depth: int = -1) -> Dictionary:
	var result := {
		"nodes": [],
		"edges": [],
		"cycles": [],
		"gaps": [],
		"rates_per_minute": {},
		"max_depth": max_depth,
	}
	if item_id.is_empty():
		return result
	var node_ids: Dictionary = {}
	var edge_ids: Dictionary = {}
	var gaps: Dictionary = {}
	var cycle_ids: Dictionary = {}
	_walk_item(item_id, 0, max_depth, [], result, node_ids, edge_ids, gaps, cycle_ids)
	result["nodes"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["id"]) < String(right["id"])
	)
	result["edges"].sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%s/%s/%s" % [left["from"], left["to"], left["kind"]] < "%s/%s/%s" % [right["from"], right["to"], right["kind"]]
	)
	result["cycles"].sort_custom(func(left: Array, right: Array) -> bool:
		return "/".join(left) < "/".join(right)
	)
	result["gaps"] = gaps.keys()
	result["gaps"].sort()
	return result

func _build_indexes() -> void:
	var building_ids: Array = _buildings.keys()
	building_ids.sort()
	for building_id_value in building_ids:
		var building_id := String(building_id_value)
		var building_value: Variant = _buildings[building_id_value]
		if not building_value is Dictionary:
			continue
		var extraction: Dictionary = building_value.get("extraction", {})
		if extraction.is_empty():
			continue
		var extracted_items: Array = extraction.get("items", []).duplicate()
		var default_item := String(extraction.get("item_id", ""))
		if not default_item.is_empty() and not extracted_items.has(default_item):
			extracted_items.append(default_item)
		for item_id_value in extracted_items:
			_append_index(_extractors_by_item, String(item_id_value), building_id)
	var recipe_ids: Array = _recipes.keys()
	recipe_ids.sort()
	for recipe_id_value in recipe_ids:
		var recipe_id := String(recipe_id_value)
		var recipe_value: Variant = _recipes[recipe_id_value]
		if not recipe_value is Dictionary:
			continue
		var recipe: Dictionary = recipe_value
		for output_value in recipe.get("outputs", []):
			if output_value is Dictionary:
				_append_index(_producers_by_item, String(output_value.get("item_id", "")), recipe_id)
		for input_value in recipe.get("inputs", []):
			if input_value is Dictionary:
				_append_index(_consumers_by_item, String(input_value.get("item_id", "")), recipe_id)
		var supported: Array = recipe.get("building_ids", [recipe.get("building_id", "")]).duplicate()
		supported = supported.map(func(value): return String(value)).filter(func(value): return not value.is_empty() and _buildings.has(value))
		supported.sort()
		_buildings_by_recipe[recipe_id] = supported
		_rates_by_recipe[recipe_id] = _output_rates(recipe)

func _append_index(index: Dictionary, item_id: String, value_id: String) -> void:
	if item_id.is_empty():
		return
	if not index.has(item_id):
		index[item_id] = []
	if not index[item_id].has(value_id):
		index[item_id].append(value_id)
	index[item_id].sort()

func _output_rates(recipe: Dictionary) -> Dictionary:
	var rates: Dictionary = {}
	var duration := float(recipe.get("duration", 0.0))
	if duration <= 0.0:
		return rates
	for output_value in recipe.get("outputs", []):
		if not output_value is Dictionary:
			continue
		var output: Dictionary = output_value
		var item_id := String(output.get("item_id", ""))
		if not item_id.is_empty():
			rates[item_id] = float(output.get("amount", 0.0)) / duration * 60.0
	return rates

func _walk_item(item_id: String, depth: int, max_depth: int, path: Array, result: Dictionary, node_ids: Dictionary, edge_ids: Dictionary, gaps: Dictionary, cycle_ids: Dictionary) -> void:
	_add_node(result, node_ids, item_id, "item")
	if max_depth >= 0 and depth >= max_depth:
		return
	var producers := get_producers(item_id)
	if producers.is_empty():
		if not _extractors_by_item.has(item_id):
			gaps[item_id] = true
		return
	for recipe_id_value in producers:
		var recipe_id := String(recipe_id_value)
		var recipe: Dictionary = _recipes.get(recipe_id, {})
		if recipe.is_empty():
			continue
		_add_node(result, node_ids, recipe_id, "recipe")
		_add_edge(result, edge_ids, recipe_id, item_id, "produces")
		result["rates_per_minute"][recipe_id] = get_recipe_rates_per_minute(recipe_id)
		for input_value in recipe.get("inputs", []):
			if not input_value is Dictionary:
				continue
			var input_item := String(input_value.get("item_id", ""))
			if input_item.is_empty():
				continue
			_add_node(result, node_ids, input_item, "item")
			_add_edge(result, edge_ids, input_item, recipe_id, "consumes")
			if path.has(input_item) or item_id == input_item:
				var cycle := path.duplicate()
				cycle.append(item_id)
				cycle.append(input_item)
				var cycle_key := "/".join(cycle)
				if not cycle_ids.has(cycle_key):
					cycle_ids[cycle_key] = true
					result["cycles"].append(cycle)
				continue
			var next_path := path.duplicate()
			next_path.append(item_id)
			_walk_item(input_item, depth + 1, max_depth, next_path, result, node_ids, edge_ids, gaps, cycle_ids)

func _add_node(result: Dictionary, node_ids: Dictionary, id: String, kind: String) -> void:
	var key := "%s:%s" % [kind, id]
	if node_ids.has(key):
		return
	node_ids[key] = true
	result["nodes"].append({"id": id, "kind": kind})

func _add_edge(result: Dictionary, edge_ids: Dictionary, from: String, to: String, kind: String) -> void:
	var key := "%s:%s:%s" % [from, to, kind]
	if edge_ids.has(key):
		return
	edge_ids[key] = true
	result["edges"].append({"from": from, "to": to, "kind": kind})
