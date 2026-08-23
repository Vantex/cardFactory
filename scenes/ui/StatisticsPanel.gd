# scenes/ui/StatisticsPanel.gd
extends PanelContainer

var stats_system: StatisticsSystem
var game_state: GameState

func _ready():
    game_state = GameManager.get_game_state()
    var stats_script = load("res://scripts/game/StatisticsSystem.gd")
    stats_system = stats_script.new(game_state)
    _create_ui()

func _create_ui():
    # 创建主容器
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 标题
    var title = Label.new()
    title.text = "生产统计"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # 统计信息
    var stats_label = RichTextLabel.new()
    stats_label.name = "StatsLabel"
    stats_label.bbcode_enabled = true
    stats_label.fit_content = true
    vbox.add_child(stats_label)
    
    _update_stats()

func _process(_delta):
    _update_stats()

func _update_stats():
    var stats_label = get_node("StatsLabel")
    if not stats_label:
        return
    
    stats_system.update(1.0)
    var summary = stats_system.get_statistics_summary()
    
    var text = ""
    text += "[b]建筑数量:[/b] %d\n" % summary.get("total_buildings", 0)
    text += "[b]连接数量:[/b] %d\n" % summary.get("total_connections", 0)
    text += "[b]游戏时间:[/b] %.1f秒\n\n" % summary.get("elapsed_time", 0.0)
    
    # 生产统计
    var production = summary.get("production", {})
    if production.size() > 0:
        text += "[b]生产:[/b]\n"
        for item_id in production:
            var amount = production[item_id]
            text += "  %s: %.1f\n" % [item_id, amount]
    
    # 消耗统计
    var consumption = summary.get("consumption", {})
    if consumption.size() > 0:
        text += "\n[b]消耗:[/b]\n"
        for item_id in consumption:
            var amount = consumption[item_id]
            text += "  %s: %.1f\n" % [item_id, amount]
    
    stats_label.text = text
