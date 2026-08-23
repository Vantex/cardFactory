# scenes/ui/HUD.gd
extends CanvasLayer

var power_label: Label
var building_count_label: Label
var time_label: Label
var status_label: Label
var stats_label: Label

func _ready():
    _create_ui_elements()

func _create_ui_elements():
    # 创建电源信息标签
    power_label = Label.new()
    power_label.position = Vector2(10, 10)
    power_label.text = "电力: 0 / 0"
    add_child(power_label)
    
    # 创建建筑数量标签
    building_count_label = Label.new()
    building_count_label.position = Vector2(10, 30)
    building_count_label.text = "建筑: 0"
    add_child(building_count_label)
    
    # 创建时间标签
    time_label = Label.new()
    time_label.position = Vector2(10, 50)
    time_label.text = "时间: 00:00"
    add_child(time_label)
    
    # 创建状态标签
    status_label = Label.new()
    status_label.position = Vector2(10, 70)
    status_label.text = "状态: 运行中"
    add_child(status_label)
    
    # 创建统计标签
    stats_label = Label.new()
    stats_label.position = Vector2(10, 90)
    stats_label.text = "统计: -"
    add_child(stats_label)

func _process(_delta):
    _update_power_info()
    _update_building_count()
    _update_time()
    _update_statistics()

func _update_power_info():
    var power_info = GameManager.get_simulation_engine().get_power_info()
    power_label.text = "电力: %d / %d (余额: %d)" % [
        power_info.generation,
        power_info.consumption,
        power_info.balance
    ]

func _update_building_count():
    var building_count = GameManager.get_game_state().buildings.size()
    building_count_label.text = "建筑: %d" % building_count

func _update_time():
    var elapsed = GameManager.get_game_state().elapsed_time
    var total_seconds = int(elapsed)
    var minutes = int(total_seconds / 60.0)
    var seconds = total_seconds % 60
    time_label.text = "时间: %02d:%02d" % [minutes, seconds]

func _update_statistics():
    var stats = GameManager.get_simulation_engine().get_statistics()
    if stats.has("item_totals"):
        var totals = stats["item_totals"]
        var stats_text = "生产: "
        for item_id in totals:
            stats_text += item_id + ":" + str(snapped(totals[item_id], 0.1)) + " "
        stats_label.text = stats_text
