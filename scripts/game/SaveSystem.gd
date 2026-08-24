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

# 延期能力必须返回明确错误，不能把占位实现报告为成功。
func sync_to_cloud(_slot: int) -> Error:
    return ERR_UNAVAILABLE

func backup_to_cloud(_slot: int) -> Error:
    return ERR_UNAVAILABLE

func restore_from_cloud(_slot: int) -> Error:
    return ERR_UNAVAILABLE

func compress_save(_slot: int) -> Error:
    return ERR_UNAVAILABLE

func decompress_save(_slot: int) -> Error:
    return ERR_UNAVAILABLE

func migrate_save(_from_slot: int, _to_slot: int) -> Error:
    return ERR_UNAVAILABLE

func get_save_size(slot: int) -> int:
    if not _storage_available:
        return 0
    var file_path = _get_save_path(slot)
    if not FileAccess.file_exists(file_path):
        return 0

    var file = FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        return 0

    var file_size = file.get_length()
    file.close()
    return file_size

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
