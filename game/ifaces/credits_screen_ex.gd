# 移植自 S/gameCore/ifaces/creditsScreen_ex.as（creditsScreen_ex extends creditsScreenMC）
# 制作名单：bMenu 返回主菜单，eText 里的 Facebook 群组链接、邮件反馈链接（点击解锁 AB_42_WRITE_LETTER，
# 若因此集齐 119 颗星则再解锁 AB_33_GET_119_STARS，两枚成就图标各自弹出后延时淡出），eMaxGames 跳转更多游戏。
class_name CreditsScreenEx
extends FlashClip

const SCENE := "res://scenes/ifaces/credits_screen_ex.tscn"

var b_menu: FlashClip
var e_logo: FlashClip
var e_bg: FlashClip
var e_text: FlashClip
var e_achievement: FlashClip
var e_achievement_final: FlashClip

var _bound: bool = false
var _attached: bool = false
var _first_ready_done: bool = false


func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "creditsScreenMC")
	_bind()


static func create() -> CreditsScreenEx:
	var n := IfaceUtil.instantiate(SCENE) as CreditsScreenEx
	n._bind()
	return n


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bind()


func _bind() -> void:
	if _bound:
		return
	b_menu = get_node("bMenu")
	e_logo = get_node("eLogo")
	e_bg = get_node("eBg")
	e_text = get_node("eText")
	e_achievement = get_node("eAchievement")
	e_achievement_final = get_node("eAchievementFinal")
	_bound = b_menu != null


func _ready() -> void:
	super._ready()
	if data == null or not _bound:
		return
	init_once()
	_first_ready_done = true
	_added()


func _enter_tree() -> void:
	if _first_ready_done and not _attached:
		_added()


func _exit_tree() -> void:
	if _attached:
		_removed()


## 原版 initOnce()：Rasterizer.bgRaster(eBg) 不移植（纯缓存优化）；bMenu 停帧。
func init_once() -> void:
	b_menu.stop()


func _added() -> void:
	_attached = true
	ButtonClass.add_button_on_frames_rd(b_menu, clicked)
	show_text()
	e_achievement.visible = false
	e_achievement_final.visible = false
	var e_fb: FlashClip = e_text.get_node("eFb")
	var e_message: FlashClip = e_text.get_node("eMessage")
	var e_max_games: FlashClip = e_text.get_node("eMaxGames")
	ButtonClass.add_button_lite(e_fb, goto_fb)
	ButtonClass.add_event_listener(e_message, ButtonClass.CLICK, message_clicked)
	e_message.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ButtonClass.add_button_scale(e_max_games, _more_games_cb())


func goto_fb(_param1: Variant = null) -> void:
	OS.shell_open("https://www.facebook.com/groups/idengames")


func message_clicked(_param1: Variant = null) -> void:
	OS.shell_open("mailto:platon.sk@gmail.com")
	var unlocked: bool = StoredData.check_if_achievement_not_done(StoredData.AB_42_WRITE_LETTER)
	if unlocked:
		StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": StoredData.AB_42_WRITE_LETTER})
		e_achievement.visible = true
		e_achievement.modulate.a = 1.0
		e_achievement.scale = Vector2.ONE
		RWTween.from(e_achievement, 0.4, {"scaleX": 1.3, "scaleY": 1.3, "alpha": 0.3,
				"onComplete": remove_adhievement, "onCompleteParams": [e_achievement]})
		var last_star: bool = StoredData.check_last_star()
		if last_star:
			StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": StoredData.AB_33_GET_119_STARS})
			e_achievement_final.visible = true
			e_achievement_final.modulate.a = 1.0
			e_achievement_final.scale = Vector2.ONE
			RWTween.from(e_achievement_final, 0.4, {"scaleX": 1.3, "scaleY": 1.3, "alpha": 0.3,
					"onComplete": remove_adhievement, "onCompleteParams": [e_achievement_final]})
		StoredData.save_shared_data()


## 原版拼写 removeAdhievement。
func remove_adhievement(param1: FlashClip) -> void:
	RWTween.to(param1, 0.3, {"alpha": 0, "delay": 3})


func show_text() -> void:
	RWTween.from_to(e_text, 0.4, {"colorMatrixFilter": {"brightness": 2}}, {"colorMatrixFilter": {"brightness": 1}})


func clicked(_param1: Variant = null) -> void:
	_main_call(&"load_main_menu")


func _removed() -> void:
	_attached = false
	var e_message: FlashClip = e_text.get_node("eMessage")
	var e_fb: FlashClip = e_text.get_node("eFb")
	var e_max_games: FlashClip = e_text.get_node("eMaxGames")
	ButtonClass.remove_event_listener(e_message, ButtonClass.CLICK, message_clicked)
	ButtonClass.remove_button_on_frames(b_menu, clicked)
	ButtonClass.remove_button_lite(e_fb, goto_fb)
	ButtonClass.remove_button_scale(e_max_games, _more_games_cb())


func _more_games_cb() -> Callable:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method("load_more_games"):
		return Callable(m, "load_more_games")
	return Callable(self, "_noop")


func _noop(_e: Variant = null) -> void:
	pass


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)
