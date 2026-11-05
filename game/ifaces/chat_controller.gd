# 移植自 S/gameCore/ifaces/chatController.as
# 左下角的战斗消息栏：五行（t1 最新），每行显示 200 帧，最后 100 帧淡出。update() 由 mainGameUI_ex 每帧调用。
class_name ChatController
extends RefCounted

static var inst: ChatController  # 原版 self

var e_chat: FlashClip  # chatBox
var c1: int = 0
var c2: int = 0
var c3: int = 0
var c4: int = 0
var c5: int = 0

func init(param1: FlashClip) -> void:
	inst = self
	e_chat = param1
	for n in ["t1", "t2", "t3", "t4", "t5"]:
		var row: FlashClip = e_chat.get_node(n)
		row.mouse_enabled = false
		row.mouse_children = false
	for n in ["t1", "t2", "t3", "t4", "t5"]:
		var row2: FlashClip = e_chat.get_node(n)
		row2.modulate.a = 0.0
		row2.get_node("tText").text = ""
	e_chat.mouse_children = false
	e_chat.mouse_enabled = false
	c1 = 0
	c2 = 0
	c3 = 0
	c4 = 0
	c5 = 0

func _row(n: int) -> FlashClip:
	return e_chat.get_node("t%d" % n)

func _text(n: int) -> FlashText:
	return e_chat.get_node("t%d/tText" % n)

func message(param1: String) -> void:
	_text(5).html_text = _text(4).html_text
	_text(4).html_text = _text(3).html_text
	_text(3).html_text = _text(2).html_text
	_text(2).html_text = _text(1).html_text
	_row(5).modulate.a = _row(4).modulate.a
	_row(4).modulate.a = _row(3).modulate.a
	_row(3).modulate.a = _row(2).modulate.a
	_row(2).modulate.a = _row(1).modulate.a
	c5 = c4
	c4 = c3
	c3 = c2
	c2 = c1
	_row(1).modulate.a = 1.0
	c1 = 200
	_text(1).html_text = param1

func update() -> void:
	if c1 > 0:
		c1 -= 1
		c2 -= 1
		c3 -= 1
		c4 -= 1
		c5 -= 1
		if c1 < 100:
			_row(1).modulate.a = c1 / 100.0
		if c2 < 100 and c2 > 0:
			_row(2).modulate.a = c2 / 100.0
		if c3 < 100 and c3 > 0:
			_row(3).modulate.a = c3 / 100.0
		if c4 < 100 and c4 > 0:
			_row(4).modulate.a = c4 / 100.0
		if c5 < 100 and c5 > 0:
			_row(5).modulate.a = c5 / 100.0
