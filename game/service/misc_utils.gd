# 移植自 S/gameCore/serviceUtils/miscUtils.as；两个函数已在 AS3 中实现，直接复用。
class_name MiscUtils
extends RefCounted

static func get_distance(param1: Node2D, param2: Node2D) -> float:
	return AS3.get_distance(param1, param2)

static func get_vector(param1: float, param2: float) -> Vector2:
	return AS3.get_vector(param1, param2)
