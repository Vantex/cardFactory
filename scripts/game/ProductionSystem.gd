# scripts/game/ProductionSystem.gd
class_name ProductionSystem
extends RefCounted

var game_state: GameState

func _init(state: GameState):
    game_state = state

func update(delta: float):
    for building_id in game_state.buildings:
        var building = game_state.buildings[building_id]
        _update_building(building, delta)

func _update_building(building: Dictionary, delta: float):
    var building_type = building.get("type", "")
    var recipe_id = building.get("recipe_id", "")
    
    # 采矿机特殊逻辑
    if building_type == "miner":
        _update_miner(building, delta)
        return
    
    # 加工设备逻辑
    if recipe_id.is_empty():
        building.status = "idle"
        return
    
    var recipe = DataManager.get_recipe(recipe_id)
    if recipe.is_empty():
        building.status = "error"
        return
    
    # 检查输入
    if not _has_required_inputs(building, recipe):
        building.status = "blocked"
        return
    
    # 检查输出空间
    if not _has_output_space(building, recipe):
        building.status = "blocked"
        return
    
    # 更新进度
    building["progress"] = building.get("progress", 0.0) + delta * building.get("speed", 1.0)
    building.status = "running"
    
    # 检查是否完成
    if building.get("progress", 0.0) >= recipe.duration:
        _consume_inputs(building, recipe)
        _produce_outputs(building, recipe)
        building["progress"] = 0.0
        EventBus.production_completed.emit(building.id, recipe.outputs[0].item_id, recipe.outputs[0].amount)

func _update_miner(building: Dictionary, delta: float):
    # 采矿机持续生产，无需输入
    var output_item = building.get("output_item", "iron_ore")
    var output_rate = building.get("output_rate", 10.0) / 60.0  # 转换为每秒
    
    if not building.has("output_buffer"):
        building.output_buffer = {}
    
    var current_amount = building.output_buffer.get(output_item, 0.0)
    building.output_buffer[output_item] = current_amount + output_rate * delta
    building.status = "running"

func _has_required_inputs(building: Dictionary, recipe: Dictionary) -> bool:
    for input in recipe.inputs:
        var item_id = input.item_id
        var required = input.amount
        var buffered = building.get("input_buffer", {}).get(item_id, 0.0)
        if buffered < required:
            return false
    return true

func _has_output_space(building: Dictionary, recipe: Dictionary) -> bool:
    for output in recipe.outputs:
        var item_id = output.item_id
        var amount = output.amount
        var buffered = building.get("output_buffer", {}).get(item_id, 0.0)
        if buffered + amount > 60:  # 最大缓冲60
            return false
    return true

func _consume_inputs(building: Dictionary, recipe: Dictionary):
    if not building.has("input_buffer"):
        building.input_buffer = {}
    for input in recipe.inputs:
        var item_id = input.item_id
        building.input_buffer[item_id] = building.input_buffer.get(item_id, 0.0) - input.amount

func _produce_outputs(building: Dictionary, recipe: Dictionary):
    if not building.has("output_buffer"):
        building.output_buffer = {}
    for output in recipe.outputs:
        var item_id = output.item_id
        building.output_buffer[item_id] = building.output_buffer.get(item_id, 0.0) + output.amount
