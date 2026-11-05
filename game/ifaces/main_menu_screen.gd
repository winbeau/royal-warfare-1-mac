# 移植自 S/gameCore/ifaces/mainMenuScreen.as（mainMenuScreen extends mainMenuClass）
# 主菜单：bPlay/bAchieves/bMore/bCredits/bHowTo 五个按钮、声音/音乐开关、策略指南/HostIt/更多游戏的
# 侧边推广位，以及背景里的动画士兵（MmAnimSoldiersEx，addChildAt 到索引 1，叠在 eBg 之上、其余按钮之下）。
#
# 反编译破损：soundClicked 含 §§push/§§pop 的链式赋值 `a.music = b.music_on = c`，按
# docs/port-plan.md 的规则重建为 `t = c; b.music_on = t; a.music = t`，随后的 while+breakloop2 等价于
# if/else（见下方 sound_clicked 注释）。
class_name MainMenuScreen
extends FlashClip

const SCENE := "res://scenes/ifaces/main_menu_screen.tscn"

var mm_anim: MmAnimSoldiersEx
var sound_scale: float = 1.0
var music_scale: float = 1.0

var b_play: FlashClip
var b_achieves: FlashClip
var b_more: FlashClip
var b_credits: FlashClip
var b_how_to: FlashClip
var b_sound: FlashClip
var b_music: FlashClip
var e_strategy_guide: FlashClip
var e_host_it: FlashClip
var e_max_games: FlashClip
var e_bg: FlashClip
var e_logo: FlashClip

var _bound: bool = false
var _attached: bool = false
var _first_ready_done: bool = false
var _inited_once: bool = false


func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "mainMenuClass")
	_bind()


static func create() -> MainMenuScreen:
	var n := IfaceUtil.instantiate(SCENE) as MainMenuScreen
	n._bind()
	return n


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bind()


func _bind() -> void:
	if _bound:
		return
	b_play = get_node("bPlay")
	b_achieves = get_node("bAchieves")
	b_more = get_node("bMore")
	b_credits = get_node("bCredits")
	b_how_to = get_node("bHowTo")
	b_sound = get_node("bSound")
	b_music = get_node("bMusic")
	e_strategy_guide = get_node("eStrategyGuide")
	e_host_it = get_node("eHostIt")
	e_max_games = get_node("eMaxGames")
	e_bg = get_node("eBg")
	e_logo = get_node("eLogo")
	_bound = b_play != null


## 原版构造函数：bPlay/bAchieves/bMore/bCredits/bHowTo 停帧，记下 bSound/bMusic 的初始缩放。
func _construct() -> void:
	b_play.stop()
	b_achieves.stop()
	b_more.stop()
	b_credits.stop()
	b_how_to.stop()
	sound_scale = b_sound.scale.x
	music_scale = b_music.scale.x


func _ready() -> void:
	super._ready()
	if data == null or not _bound:
		return
	_construct()
	_first_ready_done = true
	_added()


func _enter_tree() -> void:
	if _first_ready_done and not _attached:
		_added()


func _exit_tree() -> void:
	if _attached:
		_removed()


## 原版 initOnce()：预建一次动画士兵并停在初始状态；这里懒加载，首次 added() 时自动调用一次。
func init_once() -> void:
	if _inited_once:
		return
	_inited_once = true
	mm_anim = MmAnimSoldiersEx.create()
	mm_anim.stop_anim()


func init() -> void:
	pass


func _added() -> void:
	_attached = true
	init_once()
	ButtonClass.add_button_on_frames_rd(b_play, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_achieves, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_credits, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_how_to, button_clicked)
	add_child(mm_anim)
	move_child(mm_anim, 1)
	mm_anim.init()
	draw_main_buttons()
	ButtonClass.add_button_scale(e_strategy_guide, button_clicked)
	ButtonClass.add_button_scale(e_host_it, button_clicked)
	ButtonClass.add_button_scale(e_max_games, button_clicked)
	e_strategy_guide.modulate.a = 0.0
	e_strategy_guide.scale = Vector2(1.4, 1.4)
	RWTween.to(e_strategy_guide, 0.6, {"scaleX": 1, "scaleY": 1, "alpha": 1, "delay": 0.5})
	ButtonClass.add_button_full(b_sound, sound_rover, sound_rout, sound_clicked)
	ButtonClass.add_button_full(b_music, sound_rover, sound_rout, sound_clicked)


func draw_main_buttons() -> void:
	var p: Dictionary = StoredData.main_params
	IfaceUtil.goto_and_stop(b_sound, 1 if p.get("sound", false) == true else 2)
	IfaceUtil.goto_and_stop(b_music, 1 if p.get("music", false) == true else 2)


## 原版 soundClicked。bMusic 分支的 §§push/§§pop 按链式赋值的求值顺序重建：
## `t = !mainParams.music; Sounds.inst.music_on = t; mainParams.music = t`，随后的
## `while(!Sounds.self.music_on){...; break loop2;} Main.self.unpauseMusic("menu");`
## 等价于 if(!music_on) pauseMusic else unpauseMusic。
func sound_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var p: Dictionary
	if target == b_sound:
		p = StoredData.main_params
		var t: bool = not bool(p.get("sound", false))
		if Sounds.inst != null:
			Sounds.inst.sound_on = t
		p["sound"] = t
		StoredData.main_params = p
		draw_main_buttons()
	elif target == b_music:
		p = StoredData.main_params
		var t2: bool = not bool(p.get("music", false))
		if Sounds.inst != null:
			Sounds.inst.music_on = t2
		p["music"] = t2
		StoredData.main_params = p
		draw_main_buttons()
		if Sounds.inst == null or not Sounds.inst.music_on:
			_main_call("pause_music", ["menu"])
		else:
			_main_call("unpause_music", ["menu"])
	ButtonClass.play_click_sound(null)


func sound_rout(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var s: float = sound_scale if target == b_sound else music_scale
	target.scale = Vector2(s, s)


func sound_rover(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var s: float = (sound_scale if target == b_sound else music_scale) * 1.1
	target.scale = Vector2(s, s)
	ButtonClass.play_rover(target)


func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	if target == b_play:
		_main_call("load_map")
	elif target == b_achieves:
		_main_call("load_achievements")
	elif target == b_more or target == e_max_games:
		_main_call("load_more_games")
	elif target == e_strategy_guide:
		_main_call("load_strategy_games")
	elif target == e_host_it:
		_main_call("load_host_it_page")
	elif target == b_credits:
		_main_call("load_credits")
	elif target == b_how_to:
		_main_call("load_how_to")


func _removed() -> void:
	_attached = false
	mm_anim.stop_anim()
	if mm_anim.get_parent() == self:
		remove_child(mm_anim)
	ButtonClass.remove_button_scale(e_strategy_guide, button_clicked)
	ButtonClass.remove_button_scale(e_host_it, button_clicked)
	ButtonClass.remove_button_scale(e_max_games, button_clicked)
	ButtonClass.remove_button_full(b_sound, sound_rover, sound_rout, sound_clicked)
	ButtonClass.remove_button_full(b_music, sound_rover, sound_rout, sound_clicked)
	ButtonClass.remove_button_on_frames(b_play, button_clicked)
	ButtonClass.remove_button_on_frames(b_achieves, button_clicked)
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_on_frames(b_credits, button_clicked)
	ButtonClass.remove_button_on_frames(b_how_to, button_clicked)


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)
