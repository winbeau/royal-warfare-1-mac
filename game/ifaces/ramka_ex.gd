# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/ifaces/ramka_ex.as（选择框）。几何与 destroy 的延迟回调按原版保留，视觉（淡入淡出）待 P5。
class_name RamkaEx
extends Node2D

var rect: Rect2 = Rect2()

## setCoordsAndSize(p1, p2)：p1 为按下点，p2 为当前鼠标点；x/y 取较小者，宽高为绝对差。
func set_coords_and_size(param1: Vector2, param2: Vector2) -> void:
	position = param1
	var dx := param1.x - param2.x
	var dy := param1.y - param2.y
	rect = Rect2(param1.x, param1.y, absf(dx), absf(dy))
	if dx > 0:
		position.x = param2.x
		rect.position.x = param2.x
	if dy > 0:
		position.y = param2.y
		rect.position.y = param2.y
	queue_redraw()

func destroy() -> void:
	# 原版：TweenMax.delayedCall(0.05, gameUniverse.self.addClickHandler)；alpha 0.2s 淡出后从父节点移除
	RWTween.delayed_call(0.05, GameUniverse.inst.add_click_handler)
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(1, 1, 1, 0.2), true)
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(1, 1, 1, 0.8), false)
