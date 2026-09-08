extends Node2D

const FactoryGeometry = preload("res://scripts/game/FactoryGeometry.gd")
const CARD_SIZE := FactoryGeometry.CARD_SIZE
const PORT_SIZE := Vector2(18, 36)
const GRID_SIZE := 20.0

const CARD_COLOR_IDLE := Color("253244")
const CARD_COLOR_RUNNING := Color("173f4e")
const CARD_COLOR_BLOCKED := Color("512b36")
const CARD_BORDER := Color("7b9fbd")
const STATUS_COLORS := {
	"idle": Color("8b9aad"),
	"running": Color("38e6c2"),
	"blocked": Color("ff6b70"),
}

var optimize_rendering := true
var profile_prefix := ""
var _styles: Dictionary = {}
var _game_state: GameState
var _input_handler: Node

func set_game_state(game_state: GameState) -> void:
	_game_state = game_state
	queue_redraw()

func set_input_handler(input_handler: Node) -> void:
	_input_handler = input_handler
	queue_redraw()

func is_building_selected(building_id: String) -> bool:
	if building_id.is_empty():
		return false
	var input_handler := _get_input_handler()
	if input_handler == null:
		return false
	if input_handler.has_method("get_selected_entity_ids"):
		return input_handler.call("get_selected_entity_ids").has(building_id)
	return input_handler.get("selected_building_id") == building_id

func needs_full_detail(building_id: String) -> bool:
	if is_building_selected(building_id): return true
	var handler := _get_input_handler()
	if handler == null: return false
	if handler.get("connecting_source_id") == building_id or handler.get("selected_building_id") == building_id: return true
	var state := _get_game_state()
	return state != null and state.buildings.has(building_id) and Rect2(state.buildings[building_id].get("position", Vector2.ZERO), CARD_SIZE).has_point(get_global_mouse_position())
func get_visible_building_ids() -> Array[String]:
	var result: Array[String] = []
	var game_state := _get_game_state()
	if game_state == null:
		return result
	for id_value in game_state.buildings:
		var building_id := String(id_value)
		var building: Dictionary = game_state.buildings[building_id]
		if String(building.get("planet_id", "")) == game_state.active_planet_id:
			result.append(building_id)
	result.sort()
	return result

func get_draw_building_ids() -> Array[String]:
	if not optimize_rendering: return get_visible_building_ids()
	var state := _get_game_state()
	var result: Array[String] = []
	if state == null: return result
	var view := world_view_rect().grow(8.0)
	var query := Rect2(view.position - CARD_SIZE, view.size + CARD_SIZE)
	for id in state.get_spatial_index().get_entities_in_rect(query):
		var building: Dictionary = state.buildings[id]
		if String(building.get("planet_id", "")) == state.active_planet_id and view.intersects(Rect2(building.get("position", Vector2.ZERO), CARD_SIZE)):
			result.append(String(id))
	result.sort()
	return result
static func get_input_port_rect(card_position: Vector2) -> Rect2:
	return Rect2(card_position + Vector2(0, (CARD_SIZE.y - PORT_SIZE.y) * 0.5), PORT_SIZE)

static func get_output_port_rect(card_position: Vector2) -> Rect2:
	return Rect2(card_position + Vector2(CARD_SIZE.x - PORT_SIZE.x, (CARD_SIZE.y - PORT_SIZE.y) * 0.5), PORT_SIZE + Vector2(1, 0))

func _draw() -> void:
	var started := GameManager.performance_monitor.begin()
	_draw_grid()
	var game_state := _get_game_state()
	if game_state == null:
		return
	for building_id in get_draw_building_ids():
		_draw_building(game_state.buildings[building_id])
	GameManager.performance_monitor.finish(profile_prefix + "card_draw_submit_ms", started)

func world_view_rect() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()

func _draw_grid() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var inverse_canvas := viewport.get_canvas_transform().affine_inverse()
	var viewport_size := viewport.get_visible_rect().size
	var world_top_left := inverse_canvas * Vector2.ZERO
	var world_bottom_right := inverse_canvas * viewport_size
	var spacing := GRID_SIZE * (2.0 if optimize_rendering and viewport.get_canvas_transform().get_scale().x < 0.7 else 1.0)
	var min_x: float = floorf(minf(world_top_left.x, world_bottom_right.x) / spacing) * spacing
	var max_x: float = ceilf(maxf(world_top_left.x, world_bottom_right.x) / spacing) * spacing
	var min_y: float = floorf(minf(world_top_left.y, world_bottom_right.y) / spacing) * spacing
	var max_y: float = ceilf(maxf(world_top_left.y, world_bottom_right.y) / spacing) * spacing
	for x in range(int(min_x), int(max_x) + 1, int(spacing)):
		for y in range(int(min_y), int(max_y) + 1, int(spacing)):
			draw_circle(Vector2(x, y), 1.0, Color(0.36, 0.52, 0.65, 0.28))

func _draw_building(building: Dictionary) -> void:
	var position: Vector2 = building.get("position", Vector2.ZERO)
	var status: String = building.get("status", "idle")
	var card_rect := Rect2(position, CARD_SIZE)
	var status_color: Color = STATUS_COLORS.get(status, STATUS_COLORS.idle)
	draw_style_box(_make_card_style(CARD_COLOR_RUNNING if status == "running" else CARD_COLOR_BLOCKED if status == "blocked" else CARD_COLOR_IDLE), card_rect)
	draw_rect(card_rect, CARD_BORDER, false, 1.5, true)

	if optimize_rendering and get_viewport().get_canvas_transform().get_scale().x < 0.6 and not needs_full_detail(String(building.get("id", ""))):
		var definition := DataManager.get_building(String(building.get("type", "")))
		draw_string(ThemeDB.fallback_font, position + Vector2(14, 36), String(definition.get("name", building.get("type", ""))), HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 28, 22, Color("edf6ff"))
		draw_circle(position + Vector2(CARD_SIZE.x - 17, 18), 5.0, status_color)
		_draw_port(get_input_port_rect(position), Color("3a8fb7"), false)
		_draw_port(get_output_port_rect(position), Color("d89b42"), true)
		return
	var font := ThemeDB.fallback_font
	var building_type: String = building.get("type", "unknown")
	var definition: Dictionary = DataManager.get_building(building_type)
	var symbol: String = definition.get("symbol", _symbol_for_type(building_type))
	var title: String = definition.get("name", building_type)
	draw_string(font, position + Vector2(14, 25), "%s  %s" % [symbol, title], HORIZONTAL_ALIGNMENT_LEFT, 178, 16, Color("edf6ff"))
	draw_circle(position + Vector2(CARD_SIZE.x - 17, 18), 5.0, status_color)

	var progress := clampf(float(building.get("progress", 0.0)), 0.0, 1.0)
	var progress_rect := Rect2(position + Vector2(14, 39), Vector2(CARD_SIZE.x - 28, 7))
	draw_rect(progress_rect, Color("101924"), true)
	draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * progress, progress_rect.size.y)), status_color, true)

	_draw_buffer_summary(font, position + Vector2(14, 68), "IN", building.get("input_buffer", {}), Color("8ec8ff"))
	_draw_buffer_summary(font, position + Vector2(14, 91), "OUT", building.get("output_buffer", {}), Color("ffc66d"))

	var power: float = float(definition.get("power_demand", definition.get("power", 0.0)))
	var speed: float = float(building.get("speed", definition.get("speed", 1.0)))
	draw_line(position + Vector2(14, 116), position + Vector2(CARD_SIZE.x - 14, 116), Color("40536a"), 1.0)
	draw_string(font, position + Vector2(14, 134), "PWR %.1f  |  SPD %.1f/s" % [power, speed], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b5c5d7"))

	_draw_port(get_input_port_rect(position), Color("3a8fb7"), false)
	_draw_port(get_output_port_rect(position), Color("d89b42"), true)
	if is_building_selected(building.get("id", "")):
		draw_rect(card_rect.grow(3.0), Color("ffe585"), false, 2.0, true)

func _draw_buffer_summary(font: Font, position: Vector2, label: String, buffer: Dictionary, color: Color) -> void:
	var entries: Array[String] = []
	for item_id in buffer:
		var amount: float = float(buffer[item_id])
		if amount > 0.0:
			entries.append("%s %.1f" % [item_id, amount])
	entries.sort()
	var summary := "—" if entries.is_empty() else ", ".join(entries)
	draw_string(font, position, "%s  %s" % [label, summary], HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 28, 11, color)

func _draw_port(port_rect: Rect2, color: Color, is_output: bool) -> void:
	draw_rect(port_rect, Color("101a26"), true)
	draw_rect(port_rect, color, false, 1.5, true)
	var center := port_rect.get_center()
	var tip_offset := 5.0 if is_output else -5.0
	draw_circle(center + Vector2(tip_offset, 0), 3.0, color)

func _make_card_style(background_color: Color) -> StyleBoxFlat:
	if optimize_rendering and _styles.has(background_color): return _styles[background_color]
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	if optimize_rendering: _styles[background_color] = style
	return style

func _symbol_for_type(building_type: String) -> String:
	match building_type:
		"miner":
			return "M"
		"smelter":
			return "S"
		"assembling_machine_mk1":
			return "A"
		"power_generator":
			return "G"
		_:
			return "#"

func _get_game_state() -> GameState:
	return _game_state if _game_state != null else GameManager.get_game_state()

func _get_input_handler() -> Node:
	return _input_handler if _input_handler != null else get_node_or_null("../InputHandler")

func _process(_delta: float) -> void:
	queue_redraw()
