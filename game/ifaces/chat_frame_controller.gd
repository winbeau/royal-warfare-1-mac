# 移植自 S/gameCore/ifaces/chatFrameController.as
# 关卡对话框（chatFrame）：打开时 GameUniverse.pause()，点击翻页，最后一句点完关闭并 unpause()。
# 点击区域是 clickSens（透明热区）。
class_name ChatFrameController
extends RefCounted

static var game_chat_box: FlashClip  # chatFrame
static var text_array: Array = []
static var e_fader: FlashClip  # fader
static var hide_fader: bool = false
static var on_stage: bool = false

static func init(param1: FlashClip, param2: FlashClip) -> void:
	on_stage = false
	e_fader = param2
	game_chat_box = param1
	# Rasterizer.rasterize(gameChatBox.eBg)：位图缓存提示，剪辑场景已是位图，无需处理
	IfaceUtil.goto_and_stop(game_chat_box.get_node("eIco"), 2)
	_t_text().text = ""
	game_chat_box.modulate.a = 1.0
	game_chat_box.visible = false

static func _t_text() -> FlashText:
	return game_chat_box.get_node("tText")

static func reset() -> void:
	_t_text().text = ""
	game_chat_box.modulate.a = 1.0
	game_chat_box.visible = false

static func init_chat(param1: Array, param2: bool = false) -> void:
	on_stage = true
	hide_fader = param2
	text_array = param1.duplicate()
	reset()
	GameUniverse.inst.pause()
	IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0.1, 0.18)
	game_chat_box.visible = true
	game_chat_box.modulate.a = 0.0
	RWTween.to(game_chat_box, 0.25, {"alpha": 1})
	var e_black: FlashClip = game_chat_box.get_node("eBlack")
	e_black.modulate.a = 0.0
	RWTween.to(e_black, 0.25, {"alpha": 1, "delay": 0.2})
	var click_sens: FlashClip = game_chat_box.get_node("clickSens")
	ButtonClass.add_event_listener(click_sens, ButtonClass.CLICK, clicked)
	click_sens.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # buttonMode
	show_text(text_array.pop_front())
	if param2 == false:
		e_fader.visible = true
		e_fader.get_node("eTop").position.y = 0
		e_fader.get_node("eBottom").position.y = 608
		RWTween.from(e_fader.get_node("eTop"), 0.4, {"y": "-100"})
		RWTween.from(e_fader.get_node("eBottom"), 0.4, {"y": "100"})

static func show_text(param1: Dictionary) -> void:
	_t_text().text = param1["txt"]
	var e_ico: FlashClip = game_chat_box.get_node("eIco")
	IfaceUtil.goto_and_stop(e_ico, int(param1["unitNumberInPanel"] + 1))
	RWTween.from_to(e_ico, 0.4, {"colorMatrixFilter": {"brightness": 2}}, {"colorMatrixFilter": {"brightness": 1}})
	RWTween.from_to(_t_text(), 0.4, {"colorMatrixFilter": {"brightness": 2}}, {"colorMatrixFilter": {"brightness": 1}})
	GameUniverse.inst.level_info.got_text(param1["txt"])

static func clicked(_param1: Variant = null) -> void:
	if text_array.size() > 0:
		show_text(text_array.pop_front())
		IfaceUtil.play_sound(SoundLibrary.CLICK1, 0, 0.4)
	else:
		close_chat()

static func close_chat() -> void:
	IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0.1, 0.18)
	RWTween.to(game_chat_box, 0.2, {"autoAlpha": 0})
	GameUniverse.inst.unpause()
	GameUniverse.inst.level_info.chat_closed()
	ButtonClass.remove_event_listener(game_chat_box.get_node("clickSens"), ButtonClass.CLICK, clicked)
	if hide_fader == false:
		RWTween.to(e_fader.get_node("eTop"), 0.3, {"y": "-100"})
		RWTween.to(e_fader.get_node("eBottom"), 0.3, {"y": "100", "onComplete": fader_hider})
	on_stage = false

static func fader_hider() -> void:
	e_fader.visible = false
