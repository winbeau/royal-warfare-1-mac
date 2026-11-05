# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/ifaces/healthBar_ex.as，仅声明 LivingObject 实际调用的成员。
class_name HealthBarEx
extends Node2D

## 原版 top 是 MovieClip（stop / gotoAndStop），此处用最小替身。
class TopClip extends RefCounted:
	var current_frame: int = 1
	func stop() -> void:
		pass
	func goto_and_stop(frame: int) -> void:
		current_frame = frame

var friendly: bool = false
var top: TopClip = TopClip.new()

func _init(_param1: int = 0) -> void:
	pass

func update(_cur_health: int, _cur_level: int, _can_upgrade: bool = false, _selected: bool = false) -> void:
	pass

func reset_health(_cur_health: int, _health: int) -> void:
	pass

func reset_level_bar() -> void:
	pass

func set_group(_group: float) -> void:
	pass

func remove_icon(_icon: int) -> void:
	pass

func add_icon(_icon: int, _param2: bool = false) -> void:
	pass

func reset_icons() -> void:
	pass
