# scripts/utils/SpatialIndex.gd
class_name SpatialIndex
extends RefCounted

const CELL_SIZE = 256
var cells: Dictionary = {}

func add_entity(entity_id: String, position: Vector2):
    var cell_key = _get_cell_key(position)
    if not cells.has(cell_key):
        cells[cell_key] = []
    cells[cell_key].append(entity_id)

func remove_entity(entity_id: String, position: Vector2):
    var cell_key = _get_cell_key(position)
    if cells.has(cell_key):
        cells[cell_key].erase(entity_id)

func update_entity(entity_id: String, old_position: Vector2, new_position: Vector2):
    remove_entity(entity_id, old_position)
    add_entity(entity_id, new_position)

func get_entities_in_rect(rect: Rect2) -> Array:
    var result = []
    var start_x = int(rect.position.x / CELL_SIZE)
    var start_y = int(rect.position.y / CELL_SIZE)
    var end_x = int((rect.position.x + rect.size.x) / CELL_SIZE)
    var end_y = int((rect.position.y + rect.size.y) / CELL_SIZE)
    
    for x in range(start_x, end_x + 1):
        for y in range(start_y, end_y + 1):
            var cell_key = Vector2i(x, y)
            if cells.has(cell_key):
                result.append_array(cells[cell_key])
    
    return result

func get_entities_near_position(position: Vector2, radius: float) -> Array:
    var rect = Rect2(position - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
    return get_entities_in_rect(rect)

func _get_cell_key(position: Vector2) -> Vector2i:
    return Vector2i(int(position.x / CELL_SIZE), int(position.y / CELL_SIZE))

func clear():
    cells.clear()

func get_entity_count() -> int:
    var count = 0
    for cell_key in cells:
        count += cells[cell_key].size()
    return count

func get_cell_count() -> int:
    return cells.size()
