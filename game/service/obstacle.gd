# 移植自 S/gameCore/serviceUtils/obstacle.as
class_name Obstacle
extends RefCounted

var radius: float = 0.0
var coord: Vector2 = Vector2.ZERO

func _init(param1: RWLayoutClip = null) -> void:
	if param1 != null:
		coord = Vector2(param1.x, param1.y)
		radius = param1.width / 2.0
