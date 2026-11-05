# 移植自 S/utils/SimpleCache.as（对象池）。target_class 为 GDScript 类（如 GroundFlagAttack），实例需为 Node2D 或带 init() 的对象。
class_name SimpleCache
extends RefCounted

var initing: bool = false
var _target_class: Script
var _current_index: int = 0
var _instances: Array = []

func _init(param1: Script, param2: int, param3: bool = false) -> void:
	initing = param3
	_target_class = param1
	_current_index = param2 - 1
	_instances = []
	for i in param2:
		var inst := get_new_instance()
		_instances.append(inst)
		if param3 and inst.has_method("init"):
			inst.init()

func get_new_instance() -> Object:
	return _target_class.new()

func get_data() -> Object:
	if _current_index >= 0:
		_current_index -= 1
		return _instances[_current_index + 1]
	var inst := get_new_instance()
	if initing and inst.has_method("init"):
		inst.init()
	return inst

func set_data(param1: Object) -> void:
	param1.scale = Vector2.ONE
	param1.rotation = 0.0
	param1.position = Vector2.ZERO
	param1.modulate.a = 1.0
	param1.visible = true
	# 防御性去重：部分 VisualsTemplate 子类（如 GroundDefFlag.update()，见其文件头注释"原版疑点"）在动画
	# 结束后没有自己的"正在回收"标记，会在同一实例彻底处理完之前的连续多帧里反复新建淡出补间，每个补间
	# 各自的 onComplete 都调用一次 set_data(同一个实例)；原版 TweenMax 的 AUTO 覆盖本意是让同一目标同一
	# 属性的补间互斥，但调用处仍可能出现同一实例被 set_data 两次、中间没有 get_data() 取出过。不去重的话
	# _instances 里会出现同一引用的重复槽位：这个对象一旦被别处释放（例如关卡切换时容器整体 free()），
	# 其余槽位就变成悬挂引用，get_data() 迟早把它当"可用实例"交出去，报 "Trying to return a previously
	# freed instance"。这里按引用去重，已经在"可用"区间里的实例不重复插入。
	for i in range(_current_index + 1):
		if _instances[i] == param1:
			return
	_current_index += 1
	if _current_index == _instances.size():
		_instances.append(param1)
	else:
		_instances[_current_index] = param1

func get_amount() -> String:
	return "%s has %d/%d" % [_target_class, _current_index + 1, _instances.size()]
