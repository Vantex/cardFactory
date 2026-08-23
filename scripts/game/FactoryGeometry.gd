class_name FactoryGeometry
extends RefCounted

const CARD_SIZE := Vector2(232.0, 144.0)

static func card_rect(world_position: Vector2) -> Rect2:
	return Rect2(world_position, CARD_SIZE)
