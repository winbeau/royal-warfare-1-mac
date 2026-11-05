# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/ifaces/chatController.as
class_name ChatController
extends RefCounted

static var inst: ChatController = null

func _init() -> void:
	inst = self

func message(_text: String) -> void:
	pass
