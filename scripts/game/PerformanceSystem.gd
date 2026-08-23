# scripts/game/PerformanceSystem.gd
class_name PerformanceSystem
extends RefCounted

var game_state: GameState

# 性能配置
var config: Dictionary = {
    "max_buildings_per_frame": 100,
    "max_connections_per_frame": 100,
    "use_spatial_index": true,
    "use_batch_rendering": true,
    "adaptive_quality": true
}

# 性能统计
var stats: Dictionary = {
    "fps": 0.0,
    "frame_time": 0.0,
    "building_count": 0,
    "connection_count": 0,
    "update_time": 0.0,
    "render_time": 0.0
}

func _init(state: GameState):
    game_state = state

func update(delta: float):
    _update_stats()
    _optimize_performance()

func _update_stats():
    stats.building_count = game_state.buildings.size()
    stats.connection_count = game_state.connections.size()

func _optimize_performance():
    # 根据建筑数量调整优化策略
    if stats.building_count > 1000:
        config.max_buildings_per_frame = 50
        config.use_batch_rendering = true
    elif stats.building_count > 500:
        config.max_buildings_per_frame = 100
        config.use_batch_rendering = true
    else:
        config.max_buildings_per_frame = 200
        config.use_batch_rendering = false

func get_performance_stats() -> Dictionary:
    return stats

func get_config() -> Dictionary:
    return config

func set_config(new_config: Dictionary):
    config = new_config

# Web Worker支持（简化实现）
func use_web_workers() -> bool:
    return false

# 模拟批处理
func get_simulation_batch_size() -> int:
    return config.max_buildings_per_frame

# 视锥体剔除
func is_in_viewport(position: Vector2, viewport_size: Vector2) -> bool:
    return position.x >= 0 and position.x <= viewport_size.x and \
           position.y >= 0 and position.y <= viewport_size.y

# 层级渲染
func get_lod_level(distance: float) -> int:
    if distance < 100:
        return 0  # 高细节
    elif distance < 500:
        return 1  # 中细节
    else:
        return 2  # 低细节
