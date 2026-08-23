# scripts/game/DysonSphereSystem.gd
class_name DysonSphereSystem
extends RefCounted

var game_state: GameState

# 戴森球定义
var dyson_layers: Dictionary = {}
var dyson_nodes: Dictionary = {}
var dyson_shells: Dictionary = {}

func _init(state: GameState):
    game_state = state

# === 戴森球系统功能（25个） ===

# 1. 创建戴森层
func create_dyson_layer(system_id: String) -> bool:
    var layer_id = "layer_" + str(dyson_layers.size() + 1)
    dyson_layers[layer_id] = {
        "id": layer_id,
        "system_id": system_id,
        "orbit": {"radius": 100.0, "inclination": 0.0, "longitude": 0.0},
        "nodes": [],
        "frames": [],
        "shells": []
    }
    print("Created dyson layer: ", layer_id)
    return true

# 2. 添加戴森节点
func add_dyson_node(layer_id: String, angle: float) -> bool:
    if not dyson_layers.has(layer_id):
        return false
    
    var node_id = "node_" + str(dyson_nodes.size() + 1)
    dyson_nodes[node_id] = {
        "id": node_id,
        "layer_id": layer_id,
        "angle": angle,
        "position": Vector2(cos(angle), sin(angle)) * 100
    }
    
    dyson_layers[layer_id]["nodes"].append(node_id)
    print("Added dyson node: ", node_id)
    return true

# 3. 连接戴森节点
func connect_dyson_nodes(source_id: String, target_id: String) -> bool:
    if not dyson_nodes.has(source_id) or not dyson_nodes.has(target_id):
        return false
    
    var frame_id = "frame_" + str(dyson_layers.size() + 1)
    dyson_layers[source_id]["frames"].append({
        "id": frame_id,
        "source": source_id,
        "target": target_id
    })
    
    print("Connected dyson nodes: ", source_id, " -> ", target_id)
    return true

# 4. 规划戴森壳
func plan_dyson_shell(layer_id: String) -> bool:
    if not dyson_layers.has(layer_id):
        return false
    
    var layer = dyson_layers[layer_id]
    if layer["nodes"].size() < 3:
        print("Need at least 3 nodes to create a shell")
        return false
    
    var shell_id = "shell_" + str(dyson_shells.size() + 1)
    dyson_shells[shell_id] = {
        "id": shell_id,
        "layer_id": layer_id,
        "nodes": layer["nodes"].duplicate(),
        "capacity": layer["nodes"].size() * 1000
    }
    
    layer["shells"].append(shell_id)
    print("Planned dyson shell: ", shell_id)
    return true

# 5. 获取戴森层信息
func get_dyson_layer(layer_id: String) -> Dictionary:
    return dyson_layers.get(layer_id, {})

# 6. 获取戴森节点信息
func get_dyson_node(node_id: String) -> Dictionary:
    return dyson_nodes.get(node_id, {})

# 7. 获取戴森壳信息
func get_dyson_shell(shell_id: String) -> Dictionary:
    return dyson_shells.get(shell_id, {})

# 8. 获取系统中的戴森层
func get_layers_in_system(system_id: String) -> Array:
    var result = []
    for layer_id in dyson_layers:
        if dyson_layers[layer_id]["system_id"] == system_id:
            result.append(layer_id)
    return result

# 9. 获取层中的节点
func get_nodes_in_layer(layer_id: String) -> Array:
    var layer = get_dyson_layer(layer_id)
    return layer.get("nodes", [])

# 10. 获取层中的壳
func get_shells_in_layer(layer_id: String) -> Array:
    var layer = get_dyson_layer(layer_id)
    return layer.get("shells", [])

# 11. 计算戴森球容量
func calculate_dyson_capacity(system_id: String) -> float:
    var layers = get_layers_in_system(system_id)
    var total_capacity = 0.0
    
    for layer_id in layers:
        var shells = get_shells_in_layer(layer_id)
        for shell_id in shells:
            var shell = get_dyson_shell(shell_id)
            total_capacity += shell.get("capacity", 0.0)
    
    return total_capacity

# 12. 计算戴森球发电量
func calculate_dyson_power(system_id: String) -> float:
    var capacity = calculate_dyson_capacity(system_id)
    return capacity * 1000.0  # 每容量单位1000kW

# 13. 获取戴森球状态
func get_dyson_status(system_id: String) -> Dictionary:
    var layers = get_layers_in_system(system_id)
    var total_nodes = 0
    var total_shells = 0
    
    for layer_id in layers:
        var nodes = get_nodes_in_layer(layer_id)
        var shells = get_shells_in_layer(layer_id)
        total_nodes += nodes.size()
        total_shells += shells.size()
    
    return {
        "system_id": system_id,
        "layer_count": layers.size(),
        "node_count": total_nodes,
        "shell_count": total_shells,
        "capacity": calculate_dyson_capacity(system_id),
        "power_kw": calculate_dyson_power(system_id)
    }

# 14. 删除戴森层
func remove_dyson_layer(layer_id: String) -> bool:
    if not dyson_layers.has(layer_id):
        return false
    
    # 删除层中的所有节点和壳
    var layer = dyson_layers[layer_id]
    for node_id in layer["nodes"]:
        dyson_nodes.erase(node_id)
    for shell_id in layer["shells"]:
        dyson_shells.erase(shell_id)
    
    dyson_layers.erase(layer_id)
    print("Removed dyson layer: ", layer_id)
    return true

# 15. 删除戴森节点
func remove_dyson_node(node_id: String) -> bool:
    if not dyson_nodes.has(node_id):
        return false
    
    var node = dyson_nodes[node_id]
    var layer_id = node["layer_id"]
    
    # 从层中移除节点
    if dyson_layers.has(layer_id):
        dyson_layers[layer_id]["nodes"].erase(node_id)
    
    dyson_nodes.erase(node_id)
    print("Removed dyson node: ", node_id)
    return true

# 16. 清除戴森壳
func clear_dyson_shells(layer_id: String) -> bool:
    if not dyson_layers.has(layer_id):
        return false
    
    var layer = dyson_layers[layer_id]
    for shell_id in layer["shells"]:
        dyson_shells.erase(shell_id)
    layer["shells"].clear()
    
    print("Cleared dyson shells in layer: ", layer_id)
    return true

# 17. 获取戴森球统计
func get_dyson_statistics() -> Dictionary:
    return {
        "total_layers": dyson_layers.size(),
        "total_nodes": dyson_nodes.size(),
        "total_shells": dyson_shells.size()
    }

# 18. 检查是否有戴森球
func has_dyson_sphere(system_id: String) -> bool:
    return get_layers_in_system(system_id).size() > 0

# 19. 获取戴森球信息格式化
func get_dyson_info_formatted(system_id: String) -> String:
    var status = get_dyson_status(system_id)
    var info = ""
    info += "星系: %s\n" % system_id
    info += "层数: %d\n" % status.layer_count
    info += "节点数: %d\n" % status.node_count
    info += "壳数: %d\n" % status.shell_count
    info += "容量: %.0f\n" % status.capacity
    info += "发电量: %.0f kW" % status.power_kw
    return info

# 20. 获取戴森球列表格式化
func get_dyson_list_formatted() -> String:
    var list = ""
    for layer_id in dyson_layers:
        var layer = dyson_layers[layer_id]
        list += "层 %s - 系统: %s, 节点: %d\n" % [layer_id, layer["system_id"], layer["nodes"].size()]
    return list

# 21. 检查戴森球是否完整
func is_dyson_complete(system_id: String) -> bool:
    var layers = get_layers_in_system(system_id)
    if layers.is_empty():
        return false
    
    for layer_id in layers:
        var shells = get_shells_in_layer(layer_id)
        if shells.is_empty():
            return false
    
    return true

# 22. 获取戴森球完成度
func get_dyson_completion(system_id: String) -> float:
    var layers = get_layers_in_system(system_id)
    if layers.is_empty():
        return 0.0
    
    var total_shells = 0
    var max_shells = 0
    
    for layer_id in layers:
        var shells = get_shells_in_layer(layer_id)
        var nodes = get_nodes_in_layer(layer_id)
        total_shells += shells.size()
        max_shells += max(0, nodes.size() - 2)
    
    if max_shells == 0:
        return 0.0
    
    return float(total_shells) / float(max_shells)

# 23. 获取戴森球效率
func get_dyson_efficiency(system_id: String) -> float:
    var completion = get_dyson_completion(system_id)
    return completion * 100.0

# 24. 获取戴森球建造成本
func get_dyson_build_cost(system_id: String) -> Dictionary:
    var status = get_dyson_status(system_id)
    return {
        "frame_material": status.node_count * 10,
        "solar_sail": status.shell_count * 100,
        "dyson_sphere_component": status.shell_count * 10
    }

# 25. 重置戴森球系统
func reset():
    dyson_layers.clear()
    dyson_nodes.clear()
    dyson_shells.clear()
    print("Dyson sphere system reset")
