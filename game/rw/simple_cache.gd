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
	_current_index += 1
	if _current_index == _instances.size():
		_instances.append(param1)
	else:
		_instances[_current_index] = param1

func get_amount() -> String:
	return "%s has %d/%d" % [_target_class, _current_index + 1, _instances.size()]
