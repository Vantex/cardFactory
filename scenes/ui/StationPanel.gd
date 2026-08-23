# scenes/ui/StationPanel.gd
extends PanelContainer

var station_system: StationSystem
var game_state: GameState
var selected_station_id: String = ""

func _ready():
    game_state = GameManager.get_game_state()
    var station_script = load("res://scripts/game/StationSystem.gd")
    station_system = station_script.new(game_state)
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "物流站配置"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 物流站信息
    var info_label = Label.new()
    info_label.name = "InfoLabel"
    info_label.text = "选择物流站查看详情"
    vbox.add_child(info_label)
    
    # 槽位配置
    var slots_container = VBoxContainer.new()
    slots_container.name = "SlotsContainer"
    vbox.add_child(slots_container)
    
    # 操作按钮
    var hbox = HBoxContainer.new()
    vbox.add_child(hbox)
    
    var supply_button = Button.new()
    supply_button.text = "设置供应"
    supply_button.pressed.connect(_on_set_supply)
    hbox.add_child(supply_button)
    
    var demand_button = Button.new()
    demand_button.text = "设置需求"
    demand_button.pressed.connect(_on_set_demand)
    hbox.add_child(demand_button)

func update_station_info(station_id: String):
    selected_station_id = station_id
    
    if station_id.is_empty():
        _clear_info()
        return
    
    var station = station_system.get_station_info(station_id)
    if station.is_empty():
        _clear_info()
        return
    
    # 更新显示
    var info_label = get_node("InfoLabel")
    if info_label:
        var station_type = station.get("type", "unknown")
        var slot_count = station.get("slot_count", 0)
        info_label.text = "类型: %s\n槽位数: %d" % [station_type, slot_count]
    
    _update_slots()

func _update_slots():
    var slots_container = get_node("SlotsContainer")
    if not slots_container:
        return
    
    # 清空
    for child in slots_container.get_children():
        child.queue_free()
    
    # 添加槽位
    var slots = station_system.get_station_slots(selected_station_id)
    for i in range(slots.size()):
        var slot = slots[i]
        var hbox = HBoxContainer.new()
        slots_container.add_child(hbox)
        
        var label = Label.new()
        label.text = "槽位%d: %s (%s)" % [i, slot.get("item_id", "空"), slot.get("mode", "storage")]
        hbox.add_child(label)

func _clear_info():
    selected_station_id = ""
    var info_label = get_node("InfoLabel")
    if info_label:
        info_label.text = "选择物流站查看详情"

func _on_set_supply():
    if selected_station_id.is_empty():
        return
    station_system.set_station_slot_mode(selected_station_id, 0, "supply")
    _update_slots()

func _on_set_demand():
    if selected_station_id.is_empty():
        return
    station_system.set_station_slot_mode(selected_station_id, 0, "demand")
    _update_slots()
