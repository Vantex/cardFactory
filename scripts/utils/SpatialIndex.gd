class_name SpatialIndex
extends RefCounted

const CELL_SIZE := 256
var cells: Dictionary = {}
var _positions: Dictionary = {}

func add_entity(id: String, position: Vector2) -> void:
	if _positions.has(id): remove_entity(id, _positions[id])
	var key := _get_cell_key(position)
	if not cells.has(key): cells[key] = []
	cells[key].append(id)
	_positions[id] = position

func remove_entity(id: String, _position: Vector2) -> void:
	if not _positions.has(id): return
	var key := _get_cell_key(_positions[id])
	cells[key].erase(id)
	if cells[key].is_empty(): cells.erase(key)
	_positions.erase(id)

func update_entity(id: String, _old_position: Vector2, new_position: Vector2) -> void:
	add_entity(id, new_position)

# Broad-phase candidates; callers apply their own geometry and planet filters.
func get_entities_in_rect(rect: Rect2) -> Array:
	var result: Array = []
	var start := _get_cell_key(rect.abs().position)
	var end := _get_cell_key(rect.abs().end)
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			result.append_array(cells.get(Vector2i(x, y), []))
	return result

func get_entities_near_position(position: Vector2, radius: float) -> Array:
	return get_entities_in_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2))

func _get_cell_key(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func clear() -> void:
	cells.clear()
	_positions.clear()

func get_entity_count() -> int:
	return _positions.size()

func get_cell_count() -> int:
	return cells.size()

# Public state dictionaries can also be mutated by import/undo paths. Check the
# actual positions rather than relying on a signal that those paths may omit.
func synchronize(buildings: Dictionary) -> void:
	for id in _positions.keys():
		if not buildings.has(id): remove_entity(id, _positions[id])
	for id in buildings:
		var position: Vector2 = buildings[id].get("position", Vector2.ZERO)
		if not _positions.has(id) or _positions[id] != position:
			add_entity(String(id), position)
