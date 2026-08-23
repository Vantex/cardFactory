# scenes/ui/BuildingPanel.gd
extends PanelContainer

var selected_building_id: String = ""
var game_state: GameState

# 建筑类型列表
var building_types = [
    {"id": "miner", "name": "矿机", "key": "Q", "description": "开采矿物"},
    {"id": "smelter", "name": "熔炉", "key": "W", "description": "冶炼矿石"},
    {"id": "assembling_machine_mk1", "name": "制造台", "key": "E", "description": "组装物品"},
    {"id": "power_generator", "name": "发电机", "key": "R", "description": "产生电力"},
    {"id": "solar_panel", "name": "太阳能板", "key": "T", "description": "太阳能发电"},
    {"id": "chemical_plant", "name": "化工厂", "key": "Y", "description": "化工生产"},
    {"id": "planetary_logistics_station", "name": "物流站", "key": "U", "description": "物流中转"}
]

func _ready():
    game_state = GameManager.get_game_state()
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "建筑选择"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 创建建筑按钮
    for building in building_types:
        var button = Button.new()
        button.text = "%s (%s)" % [building.name, building.key]
        button.tooltip_text = building.description
        button.pressed.connect(_on_building_selected.bind(building.id))
        vbox.add_child(button)
    
    # 分隔线
    var separator = HSeparator.new()
    vbox.add_child(separator)
    
    # 建筑信息区域
    var info_label = Label.new()
    info_label.name = "InfoLabel"
    info_label.text = "点击建筑查看详情"
    vbox.add_child(info_label)
    
    # 升级按钮
    var upgrade_button = Button.new()
    upgrade_button.name = "UpgradeButton"
    upgrade_button.text = "升级建筑"
    upgrade_button.disabled = true
    upgrade_button.pressed.connect(_on_upgrade_pressed)
    vbox.add_child(upgrade_button)
    
    # 删除按钮
    var delete_button = Button.new()
    delete_button.name = "DeleteButton"
    delete_button.text = "删除建筑"
    delete_button.disabled = true
    delete_button.pressed.connect(_on_delete_pressed)
    vbox.add_child(delete_button)

func _on_building_selected(building_id: String):
    # 设置建筑类型到GameManager
    GameManager.get_game_state().selected_building_type = building_id
    print("Selected building type: ", building_id)

func update_building_info(building_id: String):
    selected_building_id = building_id
    
    if building_id.is_empty():
        _clear_info()
        return
    
    var building = game_state.get_building(building_id)
    if building.is_empty():
        _clear_info()
        return
    
    # 更新显示
    var info_label = get_node("InfoLabel")
    var upgrade_button = get_node("UpgradeButton")
    var delete_button = get_node("DeleteButton")
    
    if info_label:
        var building_type = building.get("type", "unknown")
        var status = building.get("status", "idle")
        info_label.text = "类型: %s\n状态: %s" % [building_type, status]
    
    if upgrade_button:
        upgrade_button.disabled = false
    if delete_button:
        delete_button.disabled = false

func _clear_info():
    selected_building_id = ""
    
    var info_label = get_node("InfoLabel")
    var upgrade_button = get_node("UpgradeButton")
    var delete_button = get_node("DeleteButton")
    
    if info_label:
        info_label.text = "点击建筑查看详情"
    if upgrade_button:
        upgrade_button.disabled = true
    if delete_button:
        delete_button.disabled = true

func _on_upgrade_pressed():
    if selected_building_id.is_empty():
        return
    
    var result = game_state.upgrade_entity(selected_building_id)
    if result:
        print("升级成功: ", selected_building_id)
        update_building_info(selected_building_id)
    else:
        print("升级失败: ", selected_building_id)

func _on_delete_pressed():
    if selected_building_id.is_empty():
        return
    
    game_state.remove_building(selected_building_id)
    print("删除建筑: ", selected_building_id)
    _clear_info()
