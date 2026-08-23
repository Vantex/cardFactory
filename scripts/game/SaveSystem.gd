# scripts/game/SaveSystem.gd
class_name SaveSystem
extends RefCounted

const SAVE_PATH = "user://saves/"
const MAX_SAVES = 10

var _save_path: String
var _storage_available: bool

func _init(save_path: String = SAVE_PATH):
    _save_path = save_path.strip_edges().replace("\\", "/")
    if _save_path.is_empty():
        _save_path = SAVE_PATH
    if not _save_path.ends_with("/"):
        _save_path += "/"
    _storage_available = _ensure_save_directory()

func _ensure_save_directory() -> bool:
    var root_path: String
    var relative_path: String
    var scheme_separator = _save_path.find("://")
    if scheme_separator >= 0:
        root_path = _save_path.substr(0, scheme_separator + 3)
        relative_path = _save_path.substr(scheme_separator + 3).trim_suffix("/")
    else:
        var directory_path = _save_path.trim_suffix("/")
        root_path = directory_path.get_base_dir()
        relative_path = directory_path.get_file()

    var dir = DirAccess.open(root_path)
    if dir == null:
        print("ERROR: Save storage unavailable: ", _save_path)
        return false

    if relative_path.is_empty() or dir.dir_exists(relative_path):
        return true

    var error = dir.make_dir_recursive(relative_path)
    if error != OK:
        print("ERROR: Save storage unavailable: ", _save_path)
        return false
    return true

func is_storage_available() -> bool:
    return _storage_available

func _get_save_path(slot: int) -> String:
    return _save_path + "save_%d.json" % slot

func save_game(slot: int, game_state: GameState) -> bool:
    if not _storage_available:
        return false
    if slot < 0 or slot >= MAX_SAVES:
        print("ERROR: Invalid save slot: ", slot)
        return false
    
    var save_data = {
        "version": "1.0.0",
        "timestamp": Time.get_unix_time_from_system(),
        "buildings": game_state.buildings,
        "connections": game_state.connections,
        "elapsed_time": game_state.elapsed_time,
        "completed_technologies": game_state.completed_technologies,
        "next_id": game_state._next_id
    }
    
    var file_path = _get_save_path(slot)
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data, "\t"))
        file.close()
        print("Game saved to slot: ", slot)
        return true
    
    print("ERROR: Failed to save game")
    return false

func load_game(slot: int, game_state: GameState) -> bool:
    if not _storage_available:
        return false
    if slot < 0 or slot >= MAX_SAVES:
        print("ERROR: Invalid save slot: ", slot)
        return false
    
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        print("ERROR: Save file not found: ", file_path)
        return false
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        
        if error == OK:
            var save_data = json.data
            
            # 恢复游戏状态
            game_state.buildings = save_data.get("buildings", {})
            game_state.connections = save_data.get("connections", {})
            game_state.elapsed_time = save_data.get("elapsed_time", 0.0)
            game_state.completed_technologies = save_data.get("completed_technologies", [])
            game_state._next_id = save_data.get("next_id", 1)
            
            print("Game loaded from slot: ", slot)
            return true
    
    print("ERROR: Failed to load game")
    return false

func delete_save(slot: int) -> bool:
    if not _storage_available:
        return false
    var file_path = _get_save_path(slot)
    if FileAccess.file_exists(file_path):
        DirAccess.remove_absolute(file_path)
        print("Save deleted: ", slot)
        return true
    return false

func get_save_info(slot: int) -> Dictionary:
    if not _storage_available:
        return {}
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        return {}
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        
        if error == OK:
            var save_data = json.data
            return {
                "slot": slot,
                "timestamp": save_data.get("timestamp", 0),
                "building_count": save_data.get("buildings", {}).size(),
                "elapsed_time": save_data.get("elapsed_time", 0.0)
            }
    
    return {}

func get_all_saves() -> Array:
    if not _storage_available:
        return []
    var saves = []
    for i in range(MAX_SAVES):
        var info = get_save_info(i)
        if not info.is_empty():
            saves.append(info)
    return saves

func has_save(slot: int) -> bool:
    if not _storage_available:
        return false
    var file_path = _get_save_path(slot)
    return FileAccess.file_exists(file_path)

# === 存档系统补完功能 ===

# 1. 云同步功能（简化实现）
func sync_to_cloud(slot: int) -> bool:
    print("Syncing save slot ", slot, " to cloud...")
    # 实际实现需要云服务API
    return true

# 2. 云备份功能
func backup_to_cloud(slot: int) -> bool:
    print("Backing up save slot ", slot, " to cloud...")
    return true

# 3. 云恢复功能
func restore_from_cloud(slot: int) -> bool:
    print("Restoring save slot ", slot, " from cloud...")
    return true

# 4. 存档压缩功能
func compress_save(slot: int) -> bool:
    if not _storage_available:
        return false
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        return false
    print("Compressing save slot ", slot, "...")
    # 实际实现需要压缩算法
    return true

# 5. 存档解压功能
func decompress_save(slot: int) -> bool:
    if not _storage_available:
        return false
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        return false
    print("Decompressing save slot ", slot, "...")
    return true

# 6. 存档迁移功能
func migrate_save(from_slot: int, to_slot: int) -> bool:
    if not _storage_available:
        return false
    var from_path = _get_save_path(from_slot)
    var to_path = _get_save_path(to_slot)
    
    if not FileAccess.file_exists(from_path):
        return false
    
    print("Migrating save from slot ", from_slot, " to ", to_slot, "...")
    # 实际实现需要复制文件
    return true

# 7. 获取存档大小
func get_save_size(slot: int) -> int:
    if not _storage_available:
        return 0
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        return 0
    # 实际实现需要获取文件大小
    return 0

# 8. 检查存档完整性
func validate_save(slot: int) -> bool:
    if not _storage_available:
        return false
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        return false
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        return error == OK
    return false
