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

# ---------------------------------------------------------------------------------------------
# AS3 未捕获异常语义（Flash 发行版播放器）
#
# 事件监听函数里未捕获的错误（TypeError #1009 等）会中止"这一次"监听调用：异常沿调用栈一路穿透，
# 中间所有函数里剩余的语句都不执行；其余监听和后续帧照常运行（发行版播放器不弹窗、不暂停）。
# 战斗主循环是 gameUniverse 的单个 ENTER_FRAME 监听 globalUpdate，所以单位 update() 里一抛错，
# 本帧剩下的内容（后面所有单位的更新、z 排序、尸体处理、UI、updateEffects、2x 速度的第二遍）全部跳过。
#
# GDScript 没有异常，用静态标志模拟：
# - 原版会抛错的位置调用 AS3.throw_error(msg)，随后立即 return，并沿调用链每一层在调用之后
#   `if AS3.aborted: return` 逐层返回（返回值无意义，随便给）。
# - 入口（GameUniverse.global_update、鼠标/键盘处理、Tween 回调、关卡加载等）在开始处调用 AS3.begin_entry()
#   清除标志——一个入口里抛的错只中止该入口本身，不影响下一个入口。
# - global_update / main_update_function 在每个单位 update() 之后检查标志，置位则中止本帧剩余内容。
# ---------------------------------------------------------------------------------------------

## 当前入口（一次监听调用）是否已被未捕获异常中止。
static var aborted: bool = false
## 累计抛错次数与最近一次的描述（日志/测试用；不随 begin_entry 清除）。
static var error_count: int = 0
static var last_error: String = ""
## 是否打印日志（测试可关闭）。
static var log_errors: bool = true

## 模拟 AS3 抛出未捕获异常：置位中止标志并打印日志。调用后调用者应立即 return。
static func throw_error(msg: String) -> void:
	aborted = true
	error_count += 1
	last_error = msg
	if log_errors:
		print("[AS3 未捕获异常] ", msg)

## 一个新的入口（事件监听调用）开始：清除中止标志。
static func begin_entry() -> void:
	aborted = false

## 入口结束：异常已被"播放器"吞掉，清除标志，避免残留到下一个不清除标志的调用链里。
static func end_entry() -> void:
	aborted = false
