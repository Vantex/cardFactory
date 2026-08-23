# scenes/ui/DysonUI.gd
extends Control

var dyson_system: DysonSphereSystem
var game_state: GameState

func _ready():
    game_state = GameManager.get_game_state()
    var dyson_script = load("res://scripts/game/DysonSphereSystem.gd")
    dyson_system = dyson_script.new(game_state)
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "戴森球"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 戴森球信息
    var info_label = Label.new()
    info_label.name = "InfoLabel"
    info_label.text = "选择星系查看戴森球"
    vbox.add_child(info_label)
    
    # 操作按钮
    var hbox = HBoxContainer.new()
    vbox.add_child(hbox)
    
    var create_button = Button.new()
    create_button.text = "创建戴森层"
    create_button.pressed.connect(_on_create_layer)
    hbox.add_child(create_button)
    
    var add_node_button = Button.new()
    add_node_button.text = "添加节点"
    add_node_button.pressed.connect(_on_add_node)
    hbox.add_child(add_node_button)

func update_dyson_info(system_id: String):
    var info_label = get_node("InfoLabel")
    if info_label:
        var info = dyson_system.get_dyson_info_formatted(system_id)
        info_label.text = info

func _on_create_layer():
    dyson_system.create_dyson_layer("helios")
    update_dyson_info("helios")

func _on_add_node():
    var layers = dyson_system.get_layers_in_system("helios")
    if layers.size() > 0:
        dyson_system.add_dyson_node(layers[0], randf() * PI * 2)
        update_dyson_info("helios")
