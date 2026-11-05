# 移植自 S/gameCore/ifaces/pauseMenu_ex.as
# 暂停菜单：重开、回地图、回主菜单、更多游戏、继续，以及声音/音乐/提示/自动暂停四个开关（图标 1=开 2=关）。
# init() 时 GameUniverse.pause()；"继续" 时移除自身并 unpause()。
# 反编译破损：buttonClicked 里 bMusic 分支的 while(!music_on){...break loop5} 加 §§goto，按 P-code 理解为
#   if (!music_on) pauseMusic("map") else unpauseMusic("map")。
class_name PauseMenuEx
extends FlashClip

const SCENE := "res://scenes/ifaces/pause_menu_ex.tscn"

var self_: PauseMenuEx  # 原版 private var self
var _inited: bool = false
var _more_games_cb: Callable

var e_max_games: FlashClip
var b_restart: FlashClip
var b_more: FlashClip
var b_menu: FlashClip
var b_close: FlashClip
var b_to_map: FlashClip
var b_sound: FlashClip
var b_music: FlashClip
var b_hints: FlashClip
var b_autopause: FlashClip

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "pauseMenu")
	_construct()

static func create() -> PauseMenuEx:
	var n := IfaceUtil.instantiate(SCENE) as PauseMenuEx
	n._construct()
	return n

func _construct() -> void:
	e_max_games = get_node("eMaxGames")
	b_restart = get_node("bRestart")
	b_more = get_node("bMore")
	b_menu = get_node("bMenu")
	b_close = get_node("bClose")
	b_to_map = get_node("bToMap")
	b_sound = get_node("bSound")
	b_music = get_node("bMusic")
	b_hints = get_node("bHints")
	b_autopause = get_node("bAutopause")
	# Rasterizer.rasterize(eBg)：无需处理
	for b: FlashClip in [b_restart, b_more, b_menu, b_close, b_to_map]:
		b.stop()
	for b: FlashClip in [b_sound, b_music, b_hints, b_autopause]:
		b.stop()
		(b.get_node("eIco") as FlashClip).stop()

func init() -> void:
	self_ = self
	_inited = true
	_more_games_cb = Callable(IfaceUtil.main(), "load_more_games")
	ButtonClass.add_button_scale(e_max_games, _more_games_cb)
	position.x = GameUniverse.MAX_SCREEN_WIDTH / 2.0
	position.y = GameUniverse.MAX_SCREEN_HEIGHT / 2.0
	RWTween.from(self_, 0.2, {"scaleX": 0.6, "scaleY": 0.6, "alpha": 0.3})
	ButtonClass.add_button_on_frames_rd(b_restart, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_to_map, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_menu, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_close, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_sound, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_music, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_hints, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_autopause, button_clicked)
	GameUniverse.inst.pause()
	draw_main_buttons()
	IfaceUtil.main().pause_music("gameplay")
	IfaceUtil.main().play_map_music()
	IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0, 0.16)

func draw_main_buttons() -> void:
	var _loc1_: Dictionary = StoredData.main_params
	_set_icon(b_sound, _loc1_.get("sound") == true)
	_set_icon(b_music, _loc1_.get("music") == true)
	_set_icon(b_hints, _loc1_.get("hints") == true)
	_set_icon(b_autopause, _loc1_.get("autop") == true)

func _set_icon(button: FlashClip, on: bool) -> void:
	IfaceUtil.goto_and_stop(button.get_node("eIco"), 1 if on else 2)

# 原版 removed(Event.REMOVED_FROM_STAGE)，监听在 init() 里挂上
func _exit_tree() -> void:
	if not _inited:
		return
	_inited = false
	ButtonClass.remove_button_on_frames(b_restart, button_clicked)
	ButtonClass.remove_button_on_frames(b_to_map, button_clicked)
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_scale(e_max_games, _more_games_cb)
	ButtonClass.remove_button_on_frames(b_menu, button_clicked)
	ButtonClass.remove_button_on_frames(b_close, button_clicked)
	ButtonClass.remove_button_on_frames(b_sound, button_clicked)
	ButtonClass.remove_button_on_frames(b_music, button_clicked)
	ButtonClass.remove_button_on_frames(b_hints, button_clicked)
	ButtonClass.remove_button_on_frames(b_autopause, button_clicked)

func _remove_self() -> void:
	if self_.get_parent() != null:
		self_.get_parent().remove_child(self_)

func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var _loc3_: Dictionary
	var _loc2_: FlashClip = param1.target
	match _loc2_:
		b_restart:
			_remove_self()
			IfaceUtil.main().load_game()
		b_to_map:
			_remove_self()
			IfaceUtil.main().load_map()
		b_menu:
			_remove_self()
			IfaceUtil.main().load_main_menu()
		b_more:
			IfaceUtil.main().load_more_games()
		b_close:
			IfaceUtil.main().stop_music_ingame()
			IfaceUtil.main().unpause_music("gameplay")
			_remove_self()
			GameUniverse.inst.unpause()
		b_sound:
			_loc3_ = StoredData.main_params
			var on: bool = not _loc3_.get("sound")
			_loc3_["sound"] = on
			Sounds.inst.sound_on = on
			StoredData.main_params = _loc3_
			draw_main_buttons()
		b_music:
			_loc3_ = StoredData.main_params
			var on2: bool = not _loc3_.get("music")
			_loc3_["music"] = on2
			Sounds.inst.music_on = on2
			StoredData.main_params = _loc3_
			draw_main_buttons()
			if not Sounds.inst.music_on:
				IfaceUtil.main().pause_music("map")
			else:
				IfaceUtil.main().unpause_music("map")
		b_hints:
			_loc3_ = StoredData.main_params
			_loc3_["hints"] = not _loc3_.get("hints")
			StoredData.main_params = _loc3_
			draw_main_buttons()
		b_autopause:
			_loc3_ = StoredData.main_params
			_loc3_["autop"] = not _loc3_.get("autop")
			StoredData.main_params = _loc3_
			draw_main_buttons()
