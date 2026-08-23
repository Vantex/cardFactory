# autoload/EventBus.gd
extends Node

# 卡牌相关信号
signal card_placed(card_id: String, position: Vector2)
signal card_removed(card_id: String)
signal card_selected(card_id: String)

# 连接相关信号
signal connection_created(connection_id: String, source_id: String, target_id: String)
signal connection_removed(connection_id: String)

# 实体移动信号
signal entity_moved(entity_id: String, new_position: Vector2)

# 科技相关信号
signal technology_research_started(tech_id: String)
signal technology_research_completed(tech_id: String)
signal technology_unlocked(tech_id: String)

# 模拟相关信号
signal simulation_updated()
signal production_completed(card_id: String, item_id: String, amount: int)
