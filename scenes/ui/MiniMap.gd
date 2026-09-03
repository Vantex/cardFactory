class_name MiniMap
extends Control

const MINIMAP_SIZE := Vector2(200, 150)

var camera: Camera2D
var _spatial_index: SpatialIndex
var _uses_external_spatial_index := false
var _world_rect := Rect2(Vector2.ZERO, Vector2(2000, 1500))
var _world_rect_explicit := false
var _regions: Dictionary = {}
var _bookmarks: Dictionary = {}
var _dragging := false

func _ready() -> void:
	custom_minimum_size = MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if size == Vector2.ZERO:
		size = MINIMAP_SIZE
	call_deferred("_find_live_camera")

func set_camera(value: Camera2D) -> void:
	camera = value
	queue_redraw()

func set_spatial_index(value: SpatialIndex) -> void:
	_spatial_index = value
	_uses_external_spatial_index = value != null
	queue_redraw()

func set_world_rect(value: Rect2) -> void:
	if value.size.x > 0.0 and value.size.y > 0.0:
		_world_rect = value.abs()
		_world_rect_explicit = true
	queue_redraw()

func clear_world_rect_override() -> void:
	_world_rect_explicit = false
	queue_redraw()

func get_effective_world_rect() -> Rect2:
	if _world_rect_explicit:
		return _world_rect
	var state := GameManager.get_game_state()
	var bounds := Rect2()
	var has_bounds := false
	if camera != null:
		var viewport_size := get_viewport_rect().size / camera.zoom
		bounds = Rect2(camera.global_position - viewport_size * 0.5, viewport_size)
		has_bounds = true
	if state != null:
		for building in state.buildings.values():
			if String(building.get("planet_id", "")) != state.active_planet_id:
				continue
			var building_rect := FactoryGeometry.card_rect(building.get("position", Vector2.ZERO))
			bounds = bounds.merge(building_rect) if has_bounds else building_rect
			has_bounds = true
	if not has_bounds:
		return _world_rect
	return bounds.grow(128.0)

func add_region(region_name: String, world_bounds: Rect2, color: Color = Color(0.38, 0.71, 0.68, 0.25)) -> void:
	if not region_name.is_empty() and world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0:
		_regions[region_name] = {"rect": world_bounds.abs(), "color": color}
	queue_redraw()

func remove_region(region_name: String) -> void:
	_regions.erase(region_name)
	queue_redraw()

func add_bookmark(bookmark_name: String, world_position: Vector2) -> void:
	if not bookmark_name.is_empty():
		_bookmarks[bookmark_name] = world_position
	queue_redraw()

func remove_bookmark(bookmark_name: String) -> void:
	_bookmarks.erase(bookmark_name)
	queue_redraw()

func navigate_to_bookmark(bookmark_name: String) -> bool:
	if camera == null or not _bookmarks.has(bookmark_name):
		return false
	camera.global_position = Vector2(_bookmarks[bookmark_name])
	camera.force_update_scroll()
	queue_redraw()
	return true

func get_visible_entity_ids() -> Array[String]:
	var result: Array[String] = []
	if not _uses_external_spatial_index:
		var state := GameManager.get_game_state()
		if state != null and state.has_method("get_spatial_index"):
			_spatial_index = state.get_spatial_index()
	if _spatial_index == null:
		return result
	for id_value in _spatial_index.get_entities_in_rect(get_effective_world_rect()):
		var entity_id := String(id_value)
		var state := GameManager.get_game_state()
		if state == null or not state.buildings.has(entity_id) or String(state.buildings[entity_id].get("planet_id", "")) != state.active_planet_id:
			continue
		if not result.has(entity_id):
			result.append(entity_id)
	result.sort()
	return result

func _find_live_camera() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
	queue_redraw()

func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
	queue_redraw()

func _draw() -> void:
	var world_rect := get_effective_world_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.1, 0.9))
	for region_value in _regions.values():
		var region: Dictionary = region_value
		var rect: Rect2 = region.rect
		var mini_rect := Rect2(_world_to_local(rect.position), rect.size / world_rect.size * size)
		draw_rect(mini_rect, region.color, true)
		draw_rect(mini_rect, Color(region.color).lightened(0.25), false, 1.0)
	var state := GameManager.get_game_state()
	for entity_id in get_visible_entity_ids():
		if not state.buildings.has(entity_id):
			continue
		var building: Dictionary = state.buildings[entity_id]
		var color := Color.GREEN if building.get("status", "") == "running" else Color(0.65, 0.7, 0.75)
		draw_rect(Rect2(_world_to_local(building.get("position", Vector2.ZERO)) - Vector2(2, 2), Vector2(4, 4)), color)
	for bookmark_position in _bookmarks.values():
		draw_circle(_world_to_local(Vector2(bookmark_position)), 3.0, Color(1.0, 0.8, 0.25))
	if camera != null:
		var viewport_size := get_viewport_rect().size / camera.zoom
		var camera_rect := Rect2(camera.global_position - viewport_size * 0.5, viewport_size)
		var mini_camera_rect := Rect2(_world_to_local(camera_rect.position), camera_rect.size / world_rect.size * size)
		draw_rect(mini_camera_rect, Color.WHITE, false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_move_camera_to_local(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		_move_camera_to_local(event.position)
		accept_event()

func _move_camera_to_local(local_position: Vector2) -> void:
	if camera == null:
		return
	var normalized := Vector2(clampf(local_position.x / maxf(size.x, 1.0), 0.0, 1.0), clampf(local_position.y / maxf(size.y, 1.0), 0.0, 1.0))
	var world_rect := get_effective_world_rect()
	camera.global_position = world_rect.position + normalized * world_rect.size
	camera.force_update_scroll()
	queue_redraw()

func _world_to_local(world_position: Vector2) -> Vector2:
	var world_rect := get_effective_world_rect()
	return (world_position - world_rect.position) / world_rect.size * size
