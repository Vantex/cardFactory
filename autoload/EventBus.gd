# autoload/EventBus.gd
extends Node

# 卡牌相关信号
signal card_placed(card_id: String, position: Vector2)
signal card_removed(card_id: String)
signal card_selected(card_id: String)

# 连接相关信号
signal connection_created(connection_id: String, source_id: String, target_id: String)
signal connection_removed(connection_id: String)
signal connection_configuration_changed(connection_id: String, configuration: Dictionary)

# 实体移动信号
signal entity_moved(entity_id: String, new_position: Vector2)

# 工厂工作区交互信号
signal placement_requested(building_type: String)
signal start_connection_requested(building_id: String)
signal delete_building_requested(building_id: String)
signal pause_toggled_requested()
signal speed_requested(speed: float)
signal notice_requested(message: String, tone: String)
signal progression_updated(result: Dictionary)
signal active_planet_changed(planet_id: String)

# 科技相关信号
signal technology_research_started(tech_id: String)
signal technology_research_completed(tech_id: String)
signal technology_unlocked(tech_id: String)
signal technology_research_paused(tech_id: String)
signal technology_research_resumed(tech_id: String)
signal technology_research_cancelled(tech_id: String)
signal technology_research_progressed(tech_id: String, progress: float, duration: float)
signal technology_research_queue_changed(queue: Array)
signal technology_start_requested(tech_id: String)
signal technology_queue_requested(tech_id: String)
signal technology_pause_requested()
signal technology_resume_requested()
signal technology_cancel_requested()
signal technology_remove_queue_requested(tech_id: String)

# 模拟相关信号
signal simulation_updated()
signal production_completed(card_id: String, item_id: String, amount: int)
