# 原版 flash.events.MouseEvent 的替身：只含移植代码读取的字段。
class_name RWMouseEvent
extends RefCounted

var stage_x: float = 0.0
var stage_y: float = 0.0
var shift_key: bool = false
var ctrl_key: bool = false
var alt_key: bool = false

func _init(sx: float = 0.0, sy: float = 0.0, shift: bool = false, ctrl: bool = false, alt: bool = false) -> void:
	stage_x = sx
	stage_y = sy
	shift_key = shift
	ctrl_key = ctrl
	alt_key = alt
