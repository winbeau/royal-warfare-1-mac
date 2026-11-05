# 原版 MovieClip 布局节点的只读替身：来自 data/level_layout.json（P0 导出的原始布局）。
# 原版的 numChildren / getChildAt(i) / name / x / y 直接映射到 children.size() / children[i] / name / x / y。
# x、y 为该 clip 摆放矩阵的 tx/ty；route 的 node 坐标是相对其父 route 的本地 x/y（不叠加 route 自身矩阵）。
# width/height 为额外字段：按摆放矩阵变换后的包围盒尺寸（原版 MovieClip.width/height，用于 eDefFlagPlace、obstacle）。
class_name RWLayoutClip
extends RefCounted

var name: String = ""
var x: float = 0.0
var y: float = 0.0
var width: float = 0.0
var height: float = 0.0
var children: Array[RWLayoutClip] = []

func get_num_children() -> int:
	return children.size()

func get_child_at(i: int) -> RWLayoutClip:
	return children[i]

func get_child_by_name(n: String) -> RWLayoutClip:
	for c in children:
		if c.name == n:
			return c
	return null

## 由 level_layout.json 的 item 字典构建（matrix=[a,b,c,d,tx,ty]，bounds=[x,y,w,h]）。
static func from_item(item: Dictionary) -> RWLayoutClip:
	var c := RWLayoutClip.new()
	c.name = str(item.get("name", ""))
	var m: Array = item.get("matrix", [1, 0, 0, 1, 0, 0])
	c.x = float(item["x"]) if item.has("x") else float(m[4])
	c.y = float(item["y"]) if item.has("y") else float(m[5])
	var b: Variant = item.get("bounds", null)
	if b is Array and b.size() >= 4:
		var a_ := float(m[0])
		var b_ := float(m[1])
		var c_ := float(m[2])
		var d_ := float(m[3])
		var xs: Array[float] = []
		var ys: Array[float] = []
		for corner in [[b[0], b[1]], [b[0] + b[2], b[1]], [b[0], b[1] + b[3]], [b[0] + b[2], b[1] + b[3]]]:
			xs.append(a_ * corner[0] + c_ * corner[1])
			ys.append(b_ * corner[0] + d_ * corner[1])
		c.width = xs.max() - xs.min()
		c.height = ys.max() - ys.min()
	for ch: Dictionary in item.get("children", []):
		c.children.append(RWLayoutClip.from_item(ch))
	return c
