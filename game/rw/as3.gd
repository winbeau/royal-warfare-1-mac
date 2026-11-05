# 移植自 AS3 内建语义（docs/port-plan.md 第 3 节）与 S/gameCore/serviceUtils/miscUtils.as
class_name AS3
extends RefCounted

## Math.round：-2.5 -> -2（GDScript 的 round 会得 -3）
static func round(x: float) -> int:
	return int(floor(x + 0.5))

## uint(x)：int 先按 32 位回绕，再按无符号取值；浮点先向零截断。
static func uint(x: float) -> int:
	return int(x) & 0xFFFFFFFF

## Point.interpolate(p1, p2, f) = p1*f + p2*(1-f)；f=1 时返回 p1。
static func point_interpolate(p1: Vector2, p2: Vector2, f: float) -> Vector2:
	return p1 * f + p2 * (1.0 - f)

## miscUtils.getDistance(a, b)：两个带 x/y 的对象的距离。
## Node2D 取 position（与 AS3 的 x/y 一致，移植的单位都挂在同一父节点下）。
static func get_distance(a: Node2D, b: Node2D) -> float:
	return a.position.distance_to(b.position)

## miscUtils.getVector(len, angle)：|len| 为模，angle 为弧度。
static func get_vector(length: float, angle: float) -> Vector2:
	var m := absf(length)
	return Vector2(m * cos(angle), m * sin(angle))
