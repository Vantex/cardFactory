# scripts/rendering/ConnectionRenderer.gd
extends Node2D

func _draw():
    var game_state = GameManager.get_game_state()
    
    # 绘制所有连接
    for conn_id in game_state.connections:
        var connection = game_state.connections[conn_id]
        _draw_connection(connection)

func _draw_connection(connection: Dictionary):
    var source = GameManager.get_game_state().get_building(connection.source_id)
    var target = GameManager.get_game_state().get_building(connection.target_id)
    
    if source.is_empty() or target.is_empty():
        return
    
    var start_pos = source.get("position", Vector2.ZERO) + Vector2(200, 75)
    var end_pos = target.get("position", Vector2.ZERO) + Vector2(0, 75)
    
    # 绘制连线
    var color = Color.WHITE
    var line_width = 2.0
    if connection.get("active", false):
        color = Color.GREEN
        line_width = 3.0
    
    draw_line(start_pos, end_pos, color, line_width)
    
    # 绘制箭头
    var direction = (end_pos - start_pos).normalized()
    var arrow_pos = end_pos - direction * 10
    draw_line(arrow_pos, arrow_pos + direction.rotated(0.5) * 10, color, line_width)
    draw_line(arrow_pos, arrow_pos + direction.rotated(-0.5) * 10, color, line_width)
    
    # 绘制流动粒子
    if connection.get("active", false):
        _draw_flow_particles(start_pos, end_pos)
    
    # 绘制物品类型
    var item_id = connection.get("item_id", "")
    if item_id != "":
        var font = ThemeDB.fallback_font
        var mid_pos = (start_pos + end_pos) / 2
        draw_string(font, mid_pos - Vector2(20, 10), item_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _draw_flow_particles(start: Vector2, end: Vector2):
    var time = Time.get_ticks_msec() / 1000.0
    
    # 绘制多个粒子
    for i in range(3):
        var progress = fmod(time * 2.0 + i * 0.33, 1.0)
        var particle_pos = start.lerp(end, progress)
        
        # 粒子大小随时间变化
        var size = 3.0 + sin(time * 5.0 + i) * 1.0
        draw_circle(particle_pos, size, Color.YELLOW)

func _process(_delta):
    queue_redraw()  # 每帧重绘
