# scenes/ui/MainUI.gd
extends CanvasLayer

@onready var building_panel: PanelContainer = $BuildingPanel
@onready var technology_panel: PanelContainer = $TechnologyPanel
@onready var station_panel: PanelContainer = $StationPanel
@onready var save_panel: PanelContainer = $SavePanel
@onready var statistics_panel: PanelContainer = $StatisticsPanel

func _ready():
    # 连接信号
    EventBus.card_selected.connect(_on_card_selected)
    
    # 设置面板位置
    _setup_panel_positions()

func _setup_panel_positions():
    # 右侧建筑面板
    building_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 250, 10)
    building_panel.size = Vector2(240, 600)
    
    # 左侧科技面板
    technology_panel.position = Vector2(10, 10)
    technology_panel.size = Vector2(240, 300)
    
    # 左侧物流站面板
    station_panel.position = Vector2(10, 320)
    station_panel.size = Vector2(240, 200)
    
    # 底部存档面板
    save_panel.position = Vector2(10, get_viewport().get_visible_rect().size.y - 210)
    save_panel.size = Vector2(240, 200)
    
    # 底部统计面板
    statistics_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 250, get_viewport().get_visible_rect().size.y - 210)
    statistics_panel.size = Vector2(240, 200)

func _on_card_selected(card_id: String):
    building_panel.update_building_info(card_id)
