# scenes/ui/SavePanel.gd
extends PanelContainer

var save_system: SaveSystem
var game_state: GameState

func _ready():
    game_state = GameManager.get_game_state()
    var save_script = load("res://scripts/game/SaveSystem.gd")
    save_system = save_script.new()
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "存档管理"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 存档槽位
    var slots_container = VBoxContainer.new()
    slots_container.name = "SlotsContainer"
    vbox.add_child(slots_container)
    
    # 操作按钮
    var hbox = HBoxContainer.new()
    vbox.add_child(hbox)
    
    var save_button = Button.new()
    save_button.text = "保存游戏"
    save_button.pressed.connect(_on_save_pressed)
    hbox.add_child(save_button)
    
    var load_button = Button.new()
    load_button.text = "加载游戏"
    load_button.pressed.connect(_on_load_pressed)
    hbox.add_child(load_button)
    
    _update_slots()

func _update_slots():
    var slots_container = get_node("SlotsContainer")
    if not slots_container:
        return
    
    # 清空
    for child in slots_container.get_children():
        child.queue_free()
    
    # 添加存档槽位
    for i in range(5):
        var hbox = HBoxContainer.new()
        slots_container.add_child(hbox)
        
        var label = Label.new()
        var has_save = save_system.has_save(i)
        if has_save:
            var info = save_system.get_save_info(i)
            var timestamp = info.get("timestamp", 0)
            var building_count = info.get("building_count", 0)
            label.text = "槽位%d: %d个建筑" % [i, building_count]
        else:
            label.text = "槽位%d: 空" % i
        hbox.add_child(label)
        
        var delete_button = Button.new()
        delete_button.text = "删除"
        delete_button.pressed.connect(_on_delete_pressed.bind(i))
        hbox.add_child(delete_button)

func _on_save_pressed():
    save_system.save_game(0, game_state)
    _update_slots()
    print("游戏已保存")

func _on_load_pressed():
    var result = save_system.load_game(0, game_state)
    if result:
        print("游戏已加载")
    else:
        print("加载失败")

func _on_delete_pressed(slot: int):
    save_system.delete_save(slot)
    _update_slots()
    print("存档已删除: ", slot)
