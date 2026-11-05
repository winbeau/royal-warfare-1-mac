# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/ifaces/hintsManager.as
class_name HintsManager
extends RefCounted

static func update() -> void:
	pass

static func need_to_show_units(_kind: int) -> void:
	pass

# --- 由 P2-A2 追加（关卡类用到的成员） ---
static func need_to_show_hint(_n: int) -> void:
	pass

static func show_temp_hint() -> void:
	pass

static func hide_temp_hint() -> void:
	pass

