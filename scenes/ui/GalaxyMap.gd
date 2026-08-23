# scenes/ui/GalaxyMap.gd
extends Control

var planet_system: PlanetSystem
var galaxy_system: GalaxySystem
var game_state: GameState

func _ready():
    game_state = GameManager.get_game_state()
    var planet_script = load("res://scripts/game/PlanetSystem.gd")
    var galaxy_script = load("res://scripts/game/GalaxySystem.gd")
    planet_system = planet_script.new(game_state)
    galaxy_system = galaxy_script.new(game_state)
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "星图"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 星系列表
    var system_list = VBoxContainer.new()
    system_list.name = "SystemList"
    vbox.add_child(system_list)
    
    # 行星详情
    var planet_label = Label.new()
    planet_label.name = "PlanetLabel"
    planet_label.text = "选择行星查看详情"
    vbox.add_child(planet_label)
    
    _update_system_list()

func _update_system_list():
    var system_list = get_node("SystemList")
    if not system_list:
        return
    
    # 清空
    for child in system_list.get_children():
        child.queue_free()
    
    # 添加星系
    var systems = galaxy_system.get_all_system_ids()
    for system_id in systems:
        var system = galaxy_system.get_star_system(system_id)
        var button = Button.new()
        button.text = "%s (%s)" % [system.get("name", ""), system.get("star_type", "")]
        button.pressed.connect(_on_system_selected.bind(system_id))
        system_list.add_child(button)

func _on_system_selected(system_id: String):
    var planets = galaxy_system.get_system_planets(system_id)
    var planet_label = get_node("PlanetLabel")
    if planet_label:
        var info = "星系: %s\n行星: " % galaxy_system.get_system_name(system_id)
        for planet_id in planets:
            info += planet_system.get_planet_name(planet_id) + " "
        planet_label.text = info
