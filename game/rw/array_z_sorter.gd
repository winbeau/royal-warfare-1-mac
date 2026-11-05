# 移植自 S/org/webr3/util3d/ArrayZSorter.as
class_name ArrayZSorter
extends RefCounted

## sortClips(unitArray, container)：按 y 升序排序，y 相等按 uid；然后依序 setChildIndex。
## 单位需有 uid 属性（int），位置取 position.y。只在顺序变化时 move_child。
## 原版 compare 声明返回 int，Number 差值会被截断：|dy| < 1 且不为 0 时视为相等（不回退到 uid）。
## 这里照此保留（int(dy)），Flash 的 Array.sort 对相等元素的次序未定义，GDScript 同样不保证稳定。
static func sort_clips(unit_array: Array, container: Node) -> void:
	assert(unit_array != null, "No MovieClip was passed as an argument")
	if unit_array.size() <= 1:
		return
	var sort_vector := unit_array.duplicate()
	sort_vector.sort_custom(_compare)
	var index := 0
	for vo: Node in sort_vector:
		if vo.get_parent() == container and vo.get_index() != index:
			container.move_child(vo, index)
		index += 1

static func _compare(a: Node2D, b: Node2D) -> bool:
	var d: float = a.position.y - b.position.y
	if d == 0.0:
		d = float(a.uid - b.uid)
	return int(d) < 0
