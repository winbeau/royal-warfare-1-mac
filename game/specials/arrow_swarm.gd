# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/specials/arrowSwarm.as
class_name ArrowSwarm
extends RefCounted

static var inst: ArrowSwarm = null

func _init() -> void:
	inst = self

func reset() -> void:
	pass

# --- 由 P2-A2 追加（关卡类用到的成员） ---
var LEFT: String = "left"
var RIGHT: String = "right"

func add_swarm(_direction: String, _p2: int = 50, _p3: float = 0.0, _p4: int = 10, _p5: int = 9, _x: float = 350, _y: float = 300, _p8: int = 600, _p9: int = 500) -> void:
	pass

func set_cool_down(_cd: int) -> void:
	pass

func update_arrow_swarm() -> int:
	return 0

