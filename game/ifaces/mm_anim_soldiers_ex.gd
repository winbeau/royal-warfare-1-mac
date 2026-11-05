# 移植自 S/gameCore/ifaces/mmAnimSoldiers_ex.as
# 主菜单背景里的动画士兵：进场时把每个士兵子动画（以及它们各自嵌套的更小动画）都
# 从随机起始帧开始播放，离场时全部停止。
#
# 原版用 Math.random 取随机起始帧（纯装饰性，不消耗 Utility.rand/RWRandom 的调用序列），
# 按 docs/port-plan.md 第 3.9 条这里用 randf()。
# 原版 getChildAt(0) 取"第一个子显示对象"（这些单位动画内部是 anim 容器 -> 位置标记 -> 具体士兵剪辑
# 的三层嵌套）；FlashClip 自己的栅格层是内部节点 _back/_front，不是具名子节点，所以
# _first_clip_child 跳过它们直接取第一个具名 FlashClip 子节点，效果等价。
class_name MmAnimSoldiersEx
extends FlashClip

const SCENE := "res://scenes/ifaces/mm_anim_soldiers_ex.tscn"

var anim: FlashClip
var a_inviz: Array = []
var a_frames: Array = []

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "mmAnimSoldiers")
	_construct()


static func create() -> MmAnimSoldiersEx:
	var n := IfaceUtil.instantiate(SCENE) as MmAnimSoldiersEx
	n._construct()
	return n


func _construct() -> void:
	anim = get_node("anim")
	a_inviz = [anim.get_node("a2"), anim.get_node("a3"), anim.get_node("a4"), anim.get_node("a5"),
			anim.get_node("b6"), anim.get_node("b7"), anim.get_node("b8")]
	a_frames = []
	for n in ["a1", "a6", "a7", "a8", "a9", "a10", "b1", "b2", "b3", "b4", "b5", "c1", "c2", "c3", "c4", "c5",
			"d1", "d2", "d3", "d4", "d5", "e1", "e2", "e3", "e4", "e5"]:
		a_frames.append(anim.get_node(n))


func _first_clip_child(c: FlashClip) -> FlashClip:
	for child in c.get_children():
		if child is FlashClip:
			return child
	return null


func _random_start_frame(c: FlashClip) -> int:
	return maxi(1, int(floorf(randf() * c.total_frames)))


func init() -> void:
	for c: FlashClip in a_inviz:
		c.stop()
		c.visible = false
	for c2: FlashClip in a_frames:
		var c3 := _first_clip_child(c2)
		if c3 != null:
			var c4 := _first_clip_child(c3)
			if c4 != null:
				c4.goto_and_play(_random_start_frame(c4))
			c3.goto_and_play(_random_start_frame(c3))
		c2.goto_and_play(_random_start_frame(c2))
	var brd1 := anim.get_node("brd1") as FlashClip
	var brd2 := anim.get_node("brd2") as FlashClip
	brd1.goto_and_play(_random_start_frame(brd1))
	brd2.goto_and_play(_random_start_frame(brd2))


func stop_anim() -> void:
	for c2: FlashClip in a_frames:
		var c3 := _first_clip_child(c2)
		if c3 != null:
			c3.stop()
			var c4 := _first_clip_child(c3)
			if c4 != null:
				c4.stop()
		c2.stop()
	(anim.get_node("brd1") as FlashClip).stop()
	(anim.get_node("brd2") as FlashClip).stop()
