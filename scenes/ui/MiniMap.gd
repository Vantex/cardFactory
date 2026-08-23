# scenes/ui/MiniMap.gd
extends Control

const MINIMAP_SIZE = Vector2(200, 150)
const WORLD_SIZE = Vector2(2000, 1500)

var camera: Camera2D

func _ready():
    # 设置小地图位置和大小
    position = Vector2(get_viewport().get_visible_rect().size.x - MINIMAP_SIZE.x - 10, 10)
    size = MINIMAP_SIZE
    
    # 延迟获取相机引用
    call_deferred("_find_camera")

func _find_camera():
    # 在场景树中查找相机
    var cameras = get_tree().get_nodes_in_group("camera")
    if cameras.size() > 0:
        camera = cameras[0]
    else:
        # 如果没有找到，创建一个相机
        camera = Camera2D.new()
        camera.name = "Camera2D"
        camera.add_to_group("camera")
        get_parent().add_child(camera)

func _draw():
    # 绘制背景
    draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.1, 0.1, 0.1, 0.8))
    
    # 绘制建筑
    var game_state = GameManager.get_game_state()
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        var world_pos = building.get("position", Vector2.ZERO)
        var minimap_pos = world_pos / WORLD_SIZE * MINIMAP_SIZE
        
        var color = Color.GRAY
        if building.get("status") == "running":
            color = Color.GREEN
        
        draw_rect(Rect2(minimap_pos, Vector2(4, 4)), color)
    
    # 绘制相机视野
    if camera:
        var camera_pos = camera.global_position
        var viewport_size = get_viewport().get_visible_rect().size
        var camera_minimap_pos = camera_pos / WORLD_SIZE * MINIMAP_SIZE
        var camera_size = viewport_size / WORLD_SIZE * MINIMAP_SIZE
        
        draw_rect(Rect2(camera_minimap_pos - camera_size / 2, camera_size), Color.WHITE, false, 1.0)

func _input(event):
    if event is InputEventMouseButton and event.pressed:
        if Rect2(Vector2.ZERO, MINIMAP_SIZE).has_point(event.position):
            var world_pos = event.position / MINIMAP_SIZE * WORLD_SIZE
            if camera:
                camera.global_position = world_pos

func _process(_delta):
    queue_redraw()
