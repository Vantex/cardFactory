# scenes/ui/TechnologyPanel.gd
extends PanelContainer

var tech_system: TechnologySystem
var game_state: GameState

func _ready():
    game_state = GameManager.get_game_state()
    var tech_script = load("res://scripts/game/TechnologySystem.gd")
    tech_system = tech_script.new(game_state)
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "科技研究"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 当前研究
    var current_label = Label.new()
    current_label.name = "CurrentLabel"
    current_label.text = "当前研究: 无"
    vbox.add_child(current_label)
    
    # 研究进度
    var progress_bar = ProgressBar.new()
    progress_bar.name = "ProgressBar"
    progress_bar.max_value = 100
    progress_bar.value = 0
    vbox.add_child(progress_bar)
    
    # 分隔线
    var separator = HSeparator.new()
    vbox.add_child(separator)
    
    # 科技列表
    var tech_list = VBoxContainer.new()
    tech_list.name = "TechList"
    vbox.add_child(tech_list)
    
    _update_tech_list()

func _process(_delta):
    _update_progress()

func _update_progress():
    var current_label = get_node("CurrentLabel")
    var progress_bar = get_node("ProgressBar")
    
    if current_label and progress_bar:
        var progress = tech_system.get_research_progress()
        if progress.get("tech_id", "").is_empty():
            current_label.text = "当前研究: 无"
            progress_bar.value = 0
        else:
            var tech_name = tech_system.get_technology_name(progress.tech_id)
            var percent = tech_system.get_research_progress_percent() * 100
            current_label.text = "当前研究: %s" % tech_name
            progress_bar.value = percent

func _update_tech_list():
    var tech_list = get_node("TechList")
    if not tech_list:
        return
    
    # 清空列表
    for child in tech_list.get_children():
        child.queue_free()
    
    # 添加可用科技
    var available = tech_system.get_available_technologies()
    for tech_id in available:
        var tech = tech_system.get_technology(tech_id)
        var button = Button.new()
        button.text = tech.get("name", tech_id)
        button.pressed.connect(_on_tech_selected.bind(tech_id))
        tech_list.add_child(button)

func _on_tech_selected(tech_id: String):
    var result = tech_system.start_research(tech_id)
    if result:
        print("开始研究: ", tech_id)
        _update_tech_list()
    else:
        print("无法研究: ", tech_id)
