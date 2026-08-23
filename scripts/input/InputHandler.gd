# scripts/input/InputHandler.gd
extends Node2D

# 操作模式
enum Mode {
    IDLE,
    PLACING_CARD,
    CONNECTING,
    MOVING
}

var current_mode: Mode = Mode.IDLE
var placing_building_type: String = ""
var connecting_source_id: String = ""
var moving_building_id: String = ""
var selected_building_id: String = ""
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO  # 点击位置相对于建筑位置的偏移

func _unhandled_input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _handle_left_click()
            else:
                _handle_left_release()
    
    if event is InputEventKey and event.pressed:
        _handle_key_press(event)

func _get_mouse_position() -> Vector2:
    return get_global_mouse_position()

func _handle_left_click():
    var mouse_pos = _get_mouse_position()
    
    match current_mode:
        Mode.IDLE:
            var clicked_building = _get_building_at_position(mouse_pos)
            if not clicked_building.is_empty():
                # 选中建筑
                selected_building_id = clicked_building.id
                var building_pos = clicked_building.get("position", Vector2.ZERO)
                # 计算点击位置相对于建筑位置的偏移
                drag_offset = mouse_pos - building_pos
                drag_start_pos = mouse_pos
                is_dragging = false
                print("Selected building: ", selected_building_id)
                EventBus.card_selected.emit(selected_building_id)
            else:
                # 点击空白处，取消选中
                selected_building_id = ""
                print("Deselected building")
        Mode.PLACING_CARD:
            _place_card()
        Mode.CONNECTING:
            _finish_connection()
        Mode.MOVING:
            _finish_moving()

func _handle_left_release():
    if current_mode == Mode.MOVING:
        _finish_moving()
    elif is_dragging:
        is_dragging = false
    
    # 如果只是点击（没有拖拽），保持选中状态
    if not is_dragging and not selected_building_id.is_empty():
        print("Building selected (no drag): ", selected_building_id)

func _handle_key_press(event: InputEventKey):
    match event.keycode:
        KEY_ESCAPE:
            _cancel_operation()
        KEY_DELETE:
            _delete_selected()
        KEY_Q:
            start_placing_card("miner")
        KEY_W:
            start_placing_card("smelter")
        KEY_E:
            start_placing_card("power_generator")
        KEY_R:
            start_placing_card("chemical_plant")
        KEY_T:
            start_placing_card("assembler")

func start_placing_card(building_type: String):
    current_mode = Mode.PLACING_CARD
    placing_building_type = building_type
    print("Ready to place: ", building_type)

func _place_card():
    var mouse_pos = _get_mouse_position()
    
    var building_data = {
        "type": placing_building_type,
        "position": mouse_pos,
        "status": "idle",
        "progress": 0.0,
        "input_buffer": {},
        "output_buffer": {}
    }
    
    var building_def = DataManager.get_building(placing_building_type)
    if not building_def.is_empty():
        if building_def.kind == "extractor":
            building_data.output_item = "iron_ore"
            building_data.output_rate = 60.0
    
    GameManager.get_game_state().add_building(building_data)
    print("Placed ", placing_building_type, " at ", mouse_pos)
    current_mode = Mode.IDLE

func start_connection(source_id: String):
    current_mode = Mode.CONNECTING
    connecting_source_id = source_id

func _finish_connection():
    var mouse_pos = _get_mouse_position()
    var target_building = _get_building_at_position(mouse_pos)
    
    if not target_building.is_empty() and target_building.id != connecting_source_id:
        var connection_data = {
            "source_id": connecting_source_id,
            "target_id": target_building.id,
            "item_id": "iron_ore",
            "flow_rate": 60.0
        }
        GameManager.get_game_state().add_connection(connection_data)
        print("Created connection: ", connecting_source_id, " -> ", target_building.id)
    
    is_dragging = false
    current_mode = Mode.IDLE
    connecting_source_id = ""
    queue_redraw()

func _update_moving():
    var mouse_pos = _get_mouse_position()
    var game_state = GameManager.get_game_state()
    if game_state.buildings.has(moving_building_id):
        # 使用偏移量计算新位置，保持相对位置
        var new_position = mouse_pos - drag_offset
        game_state.buildings[moving_building_id]["position"] = new_position
        queue_redraw()

func _finish_moving():
    var mouse_pos = _get_mouse_position()
    var game_state = GameManager.get_game_state()
    if game_state.buildings.has(moving_building_id):
        var new_position = mouse_pos - drag_offset
        game_state.move_entity(moving_building_id, new_position)
        print("Moved building ", moving_building_id, " to ", new_position)
    
    current_mode = Mode.IDLE
    moving_building_id = ""
    is_dragging = false
    queue_redraw()

func _delete_selected():
    if not selected_building_id.is_empty():
        GameManager.get_game_state().remove_building(selected_building_id)
        print("Deleted building: ", selected_building_id)
        selected_building_id = ""

func _cancel_operation():
    is_dragging = false
    current_mode = Mode.IDLE
    placing_building_type = ""
    connecting_source_id = ""
    moving_building_id = ""
    queue_redraw()

func _get_building_at_position(pos: Vector2) -> Dictionary:
    var game_state = GameManager.get_game_state()
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var building_pos = building.get("position", Vector2.ZERO)
        var rect = Rect2(building_pos, Vector2(200, 150))
        if rect.has_point(pos):
            return building
    return {}

func _process(_delta):
    # 检测拖拽开始
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if not selected_building_id.is_empty() and current_mode == Mode.IDLE:
            var mouse_pos = _get_mouse_position()
            var selected_building = GameManager.get_game_state().get_building(selected_building_id)
            if not selected_building.is_empty():
                var building_pos = selected_building.get("position", Vector2.ZERO)
                var rect = Rect2(building_pos, Vector2(200, 150))
                if rect.has_point(mouse_pos):
                    # 开始移动
                    current_mode = Mode.MOVING
                    moving_building_id = selected_building_id
                    is_dragging = true
                    print("Started moving building: ", moving_building_id)
    
    # 更新移动
    if current_mode == Mode.MOVING:
        _update_moving()
    
    queue_redraw()

func _draw():
    var mouse_pos = _get_mouse_position()
    
    # 绘制选中建筑的高亮
    if not selected_building_id.is_empty():
        var selected_building = GameManager.get_game_state().get_building(selected_building_id)
        if not selected_building.is_empty():
            var pos = selected_building.get("position", Vector2.ZERO)
            draw_rect(Rect2(pos, Vector2(200, 150)), Color(1, 1, 0, 0.3))
    
    # 绘制拖拽连线
    if is_dragging and current_mode == Mode.CONNECTING:
        draw_line(drag_start_pos, mouse_pos, Color.YELLOW, 2.0)
    
    # 绘制移动中的建筑
    if current_mode == Mode.MOVING:
        var game_state = GameManager.get_game_state()
        if game_state.buildings.has(moving_building_id):
            var building = game_state.buildings[moving_building_id]
            var pos = building.get("position", Vector2.ZERO)
            draw_rect(Rect2(pos, Vector2(200, 150)), Color(0, 1, 0, 0.3))
