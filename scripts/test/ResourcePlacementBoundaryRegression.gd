extends RefCounted

const OWNER := preload("res://scripts/test/EffectQueryBehaviorRunner.gd")
var errors: Array[String] = []
var cases := 0

func _site(item: String, position: Vector2 = Vector2.ZERO, remaining: float = 10, planet: String = "home") -> Dictionary:
	return {"id": "site", "planet_id": planet, "item_id": item, "position": position, "capacity": 10, "remaining": remaining, "infinite": false}

func _case(label: String, sites: Dictionary, type: String, position: Vector2, kits: int, expected: String) -> void:
	var state := GameState.new()
	state.emit_canvas_events = false
	SourceGalaxySystem.new(state).initialize(240721, false)
	PlanetSystem.new(state).initialize_colonized_resource_sites()
	state.resource_sites = sites.duplicate(true)
	for id in state.resource_sites: state.resource_sites[id].id = id
	state.construction_inventory = {type: kits}
	state.command_history.redo_entries.append({"label": "failed placement redo sentinel", "changes": []})
	state._spatial_index.add_entity("boundary-sentinel", Vector2(500, 500))
	var before := OWNER._ownership(state)
	var placed := state.try_place_building(type, position)
	if expected.is_empty():
		if placed.ok or OWNER._ownership(state) != before: errors.append(label + ": rejected placement must preserve all raw/canonical ownership")
	else:
		if not placed.ok or state.construction_inventory[type] != kits - 1 or state.buildings[placed.id].resource_site_id != expected or state.buildings[placed.id].output_item != sites[expected].item_id: errors.append(label + ": accepted placement must bind exactly selected eligible site and consume one funded kit")
	cases += 1

func run() -> Dictionary:
	errors.clear()
	cases = 0
	var source := "dsp_mining_machine"
	_case("source copper", {"copper": _site("copper_ore")}, source, Vector2.ZERO, 1, "copper")
	_case("source empty", {}, source, Vector2.ZERO, 1, "")
	_case("source wrong fluid", {"water": _site("water")}, source, Vector2.ZERO, 1, "")
	_case("source depleted", {"copper": _site("copper_ore", Vector2.ZERO, 0)}, source, Vector2.ZERO, 1, "")
	_case("source foreign", {"copper": _site("copper_ore", Vector2.ZERO, 10, "ashen")}, source, Vector2.ZERO, 1, "")
	_case("source outside", {"copper": _site("copper_ore")}, source, Vector2(181, 0), 1, "")
	_case("source radius inclusive", {"copper": _site("copper_ore")}, source, Vector2(180, 0), 1, "copper")
	_case("source no kit", {"copper": _site("copper_ore")}, source, Vector2.ZERO, 0, "")
	_case("source tie reverse insertion", {"b": _site("copper_ore", Vector2(10, 0)), "a": _site("iron_ore", Vector2(-10, 0))}, source, Vector2.ZERO, 1, "a")
	_case("source tie forward insertion", {"a": _site("iron_ore", Vector2(-10, 0)), "b": _site("copper_ore", Vector2(10, 0))}, source, Vector2.ZERO, 1, "a")
	_case("source ignores depleted closer", {"a": _site("iron_ore", Vector2.ZERO, 0), "b": _site("copper_ore", Vector2(10, 0))}, source, Vector2.ZERO, 1, "b")
	_case("native default iron", {"iron": _site("iron_ore")}, "miner", Vector2.ZERO, 1, "iron")
	_case("native retains default only", {"copper": _site("copper_ore")}, "miner", Vector2.ZERO, 1, "")
	var custom: Dictionary = DataManager.get_building("miner").duplicate(true)
	custom.id = "placement_custom_extractor"
	custom.extraction.items = ["iron_ore", "copper_ore"]
	DataManager.all_buildings[custom.id] = custom
	DataManager.construction[custom.id] = {"id": custom.id}
	_case("custom default iron", {"iron": _site("iron_ore")}, custom.id, Vector2.ZERO, 1, "iron")
	_case("custom retains default only", {"copper": _site("copper_ore")}, custom.id, Vector2.ZERO, 1, "")
	DataManager.all_buildings.erase(custom.id)
	DataManager.construction.erase(custom.id)
	print("RESOURCE PLACEMENT BOUNDARIES: ", cases, "; errors: ", JSON.stringify(errors))
	return {"errors": errors.duplicate(), "cases": cases}
