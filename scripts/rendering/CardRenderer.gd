# scripts/rendering/CardRenderer.gd
extends Node2D

# 绘制配置
const CARD_WIDTH = 200
const CARD_HEIGHT = 150
const CARD_COLOR_IDLE = Color(0.4, 0.4, 0.4)
const CARD_COLOR_RUNNING = Color(0.0, 0.94, 1.0)
const CARD_COLOR_BLOCKED = Color(1.0, 0.27, 0.27)

func _draw():
    var game_state = GameManager.get_game_state()
    
    # 绘制所有建筑
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        _draw_building(building)

func _draw_building(building: Dictionary):
    var pos = building.get("position", Vector2.ZERO)
    var status = building.get("status", "idle")
    var color = CARD_COLOR_IDLE
    
    # 动画效果
    var card_scale = 1.0
    var alpha = 1.0
    
    match status:
        "running":
            color = CARD_COLOR_RUNNING
            # 呼吸动画
            card_scale = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.02
        "blocked":
            color = CARD_COLOR_BLOCKED
            # 闪烁动画
            alpha = 0.7 + sin(Time.get_ticks_msec() * 0.01) * 0.3
        "idle":
            color = CARD_COLOR_IDLE
    
    # 绘制卡片背景（带缩放）
    var rect = Rect2(pos, Vector2(CARD_WIDTH, CARD_HEIGHT) * card_scale)
    var draw_color = Color(color, alpha)
    draw_rect(rect, draw_color)
    draw_rect(rect, Color.WHITE, false, 2.0)
    
    # 绘制文字
    var font = ThemeDB.fallback_font
    var building_type = building.get("type", "unknown")
    draw_string(font, pos + Vector2(10, 25), building_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    
    # 绘制状态
    draw_string(font, pos + Vector2(10, 45), "状态: " + status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
    
    # 绘制输入缓冲区
    var input_buffer = building.get("input_buffer", {})
    if input_buffer.size() > 0:
        var y_offset = 65
        draw_string(font, pos + Vector2(10, y_offset), "输入:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
        y_offset += 15
        for item_id in input_buffer:
            var amount = input_buffer[item_id]
            if amount > 0:
                draw_string(font, pos + Vector2(15, y_offset), item_id + ": " + str(snapped(amount, 0.1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
                y_offset += 12
    
    # 绘制输出缓冲区
    var output_buffer = building.get("output_buffer", {})
    if output_buffer.size() > 0:
        var y_offset = 110
        draw_string(font, pos + Vector2(10, y_offset), "输出:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
        y_offset += 15
        for item_id in output_buffer:
            var amount = output_buffer[item_id]
            if amount > 0:
                draw_string(font, pos + Vector2(15, y_offset), item_id + ": " + str(snapped(amount, 0.1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
                y_offset += 12

func _process(_delta):
    queue_redraw()  # 每帧重绘
