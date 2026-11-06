# 移植自 S/gameCore/ifaces/victoryPanel_ex.as
# 胜利面板：按已损失生命数评 1~3 星（eStars 里 eOneStar / eTwoStars / eThreeStars 三选一并 gotoAndPlay(1)），
# 写入存档（COM_VICTORY 与剧情漫画解锁），统计文字，成就进度（VinDefPanelAchivesController），
# 以及 Next（升级面板）/ Retry / Menu / More 四个按钮。
# 偏离：GlobalTracker.trackPage、Kongregate 统计提交不移植（站点分析脚本）。
class_name VictoryPanelEx
extends FlashClip

const SCENE := "res://scenes/ifaces/victory_panel_ex.tscn"

var on_stage: bool = false
var self_: VictoryPanelEx  # 原版 private var self
var g: GlobalData
var counter: float = 0.0

var e_stars: FlashClip
var e_stars_hint: FlashClip
var e_achives_hint: FlashClip
var e_max_games: FlashClip
var b_restart: FlashClip
var b_more: FlashClip
var b_menu: FlashClip
var b_next: FlashClip
var _more_games_cb: Callable
var _listening: bool = false

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "victoryPanel")
	_construct()

static func create() -> VictoryPanelEx:
	var n := IfaceUtil.instantiate(SCENE) as VictoryPanelEx
	n._construct()
	return n

func _construct() -> void:
	e_stars = get_node("eStars")
	e_stars_hint = get_node("eStarsHint")
	e_achives_hint = get_node("eAchivesHint")
	e_max_games = get_node("eMaxGames")
	b_restart = get_node("bRestart")
	b_more = get_node("bMore")
	b_menu = get_node("bMenu")
	b_next = get_node("bNext")
	# Rasterizer.rasterize(eBg, "eBg")：无需处理
	var e_delete := e_stars.get_node_or_null("eDelete")
	if e_delete != null:
		e_stars.remove_child(e_delete)
		e_delete.free()
	b_restart.stop()
	b_more.stop()
	b_menu.stop()
	b_next.stop()

func init(param1: int, param2: int) -> void:
	var s: SoundLibrary
	var num_stars: int
	var max_lifes: float
	var lifes_spent: float
	var mid: float
	var dif_num: float
	var saved_data: Dictionary
	var a_numbers: Array
	var num_lifes := param1
	var cur_level_num := param2
	var show_hint := func() -> void:
		if cur_level_num == 0:
			e_stars_hint.visible = true
			e_achives_hint.visible = true
			e_stars_hint.modulate.a = 1.0
			e_achives_hint.modulate.a = 1.0
			RWTween.from(e_stars_hint, 1, {"alpha": 0, "x": "-80", "delay": 1})
			RWTween.from(e_achives_hint, 1, {"alpha": 0, "x": "-80", "delay": 1.3})
			set_physics_process(true)  # addEventListener(ENTER_FRAME, closeHints)
			counter = 0
		else:
			e_stars_hint.visible = false
			e_achives_hint.visible = false
	_listening = true  # addEventListener(REMOVED_FROM_STAGE, removed)
	self_ = self
	on_stage = true
	_more_games_cb = Callable(IfaceUtil.main(), "load_more_games")
	ButtonClass.add_button_scale(e_max_games, _more_games_cb)
	IfaceUtil.main().stop_music_ingame()
	IfaceUtil.play_sound(SoundLibrary.WIN_MUSIC, 0, 0.6, 350, SoundLibrary.WIN_MUSIC)
	position.x = 350
	position.y = 250
	num_stars = 0
	# 二次开发：二章的星数由关卡对象的 compute_stars() 给出，不看生命数。
	var is_ch2: bool = GameUniverse.inst.get("chapter") == 2
	var ch2_stars_n := 1
	if is_ch2:
		var info: Variant = GameUniverse.inst.level_info
		if info != null and (info as Object).has_method("compute_stars"):
			ch2_stars_n = clampi(int(info.call("compute_stars")), 1, 3)
	max_lifes = GameUniverse.inst.num_max_lives
	lifes_spent = max_lifes - num_lifes
	mid = floorf((max_lifes - 2) / 2)
	var one: FlashClip = e_stars.get_node("eOneStar")
	var two: FlashClip = e_stars.get_node("eTwoStars")
	var three: FlashClip = e_stars.get_node("eThreeStars")
	var three_stars: bool = ch2_stars_n == 3 if is_ch2 else lifes_spent <= 2
	var two_stars: bool = ch2_stars_n == 2 if is_ch2 else lifes_spent <= mid
	if three_stars:
		num_stars = 3
		one.visible = false
		two.visible = false
		three.visible = true
		three.goto_and_play(1)
	elif two_stars:
		num_stars = 2
		one.visible = false
		two.visible = true
		three.visible = false
		two.goto_and_play(1)
	else:
		num_stars = 1
		one.visible = true
		two.visible = false
		three.visible = false
		one.goto_and_play(1)
	dif_num = float(StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY])
	saved_data = {"stars": num_stars, "level": cur_level_num, "dif": dif_num}
	if is_ch2:
		var info2: Variant = GameUniverse.inst.level_info
		var ch2_n: int = int(info2.get("level_number")) if info2 != null and info2.get("level_number") != null else cur_level_num + 1
		StoredData.ch2_record_victory(ch2_n, num_stars, int(dif_num))
	else:
		StoredData.save_data(StoredData.COM_VICTORY, saved_data)
	e_stars_hint.visible = false
	e_achives_hint.visible = false
	RWTween.from(self_, 0.6, {"scaleX": 0.4, "scaleY": 0.4, "alpha": 0.3, "onComplete": show_hint})
	if is_ch2:
		pass  # 二章没有一代的漫画解锁与通关标志
	elif cur_level_num == 5:
		StoredData.save_data(StoredData.COMIX_SET_TO_WATCH, {"comixNumber": 2})
	elif cur_level_num == 11:
		StoredData.save_data(StoredData.COMIX_SET_TO_WATCH, {"comixNumber": 3})
	elif cur_level_num == 17:
		StoredData.save_data(StoredData.COMIX_SET_TO_WATCH, {"comixNumber": 4})
	elif cur_level_num == 20:
		StoredData.save_data(StoredData.COMIX_SET_TO_WATCH, {"comixNumber": 5})
	elif cur_level_num == 23:
		StoredData.save_data(StoredData.COMIX_SET_TO_WATCH, {"comixNumber": 6})
		StoredData.set_end_game_completed()
	ButtonClass.add_button_on_frames_rd(b_restart, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_menu, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_next, button_clicked)
	set_statistics()
	a_numbers = [] if is_ch2 else g.check_achievements(cur_level_num)
	if a_numbers.size() == 0:
		e_achives_hint.visible = false
	VinDefPanelAchivesController.init(self_, a_numbers, get_node("eNoNewAchives"), get_node("bLeft"),
			get_node("bRight"), get_node("eCont"), get_node("eHint"))
	# GlobalTracker.trackPage("Victory/Level" + curLevelNum)：站点分析，不移植
	GameUniverse.inst.update_revealed_units()
	StoredData.save_shared_data()
	# Main.isExternalApiEnabled / isKong 的 Kongregate 统计提交：不移植

func _ready() -> void:
	super._ready()  # GDScript 不会自动调用基类的 _ready
	set_physics_process(false)  # 只在 show_hint 里开启

# ENTER_FRAME 监听 closeHints（物理帧 30 tps 对应 Flash 30 fps）。仅在 show_hint 里开启。
func _physics_process(_delta: float) -> void:
	close_hints()

func close_hints(_param1: Variant = null) -> void:
	counter += 1
	if counter == 250:
		set_physics_process(false)
		RWTween.to(e_stars_hint, 1, {"alpha": 0})
		RWTween.to(e_achives_hint, 1, {"alpha": 0})

func set_statistics() -> void:
	g = GlobalData.inst
	_set_html("tNumKills", "Enemies killed:  ", g.num_killed)
	_set_html("tNumLost", "Soldiers lost:  ", g.num_soldiers_dead)
	_set_html("tDamageDealt", "Damage dealt:  ", g.damage_dealt)
	_set_html("tDamageReceived", "Damage received:  ", g.damage_received)
	_set_html("tNumUpgrades", "Damage healed:  ", g.num_healed)
	_set_html("tHired", "Soldiers hired:  ", g.num_hired)
	_set_html("tUpgraded", "Soldiers promoted:  ", g.num_upgrades)
	_set_html("tGotGold", "Gold gained:  ", g.gold_gained)
	_set_html("tSpentGold", "Gold spent:  ", int(-1 * g.gold_spent))
	var _loc1_: float = Time.get_unix_time_from_system() * 1000.0  # new Date().getTime()
	var _loc2_: float = g.start_time * 1000.0
	var _loc3_: float = _loc1_ - _loc2_
	var _loc4_: float = floorf(_loc3_ / 1000)
	_set_html("tTimeSpent", "Time spent:  ", seconds_to_timecode(_loc4_))

func _set_html(field: String, label: String, value: Variant) -> void:
	(get_node(field) as FlashText).html_text = label + "<font color='#F6F581'>" + str(value) + "</font>"

# 原版 removed(Event.REMOVED_FROM_STAGE)
func _exit_tree() -> void:
	if not _listening:
		return
	_listening = false
	set_physics_process(false)
	ButtonClass.remove_button_scale(e_max_games, _more_games_cb)
	VinDefPanelAchivesController.remove_events()
	ButtonClass.remove_button_on_frames(b_restart, button_clicked)
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_on_frames(b_menu, button_clicked)
	ButtonClass.remove_button_on_frames(b_next, button_clicked)
	on_stage = false

func seconds_to_timecode(param1: float) -> String:
	var _loc2_: float = floorf(param1 / 60)
	var _loc3_: float = fmod(param1, 60)
	var _loc4_: float = fmod(_loc2_, 60)
	var _loc5_: float = floorf(_loc2_ / 60)
	_loc3_ = floorf(_loc3_)
	return get_two_digits(_loc5_) + ":" + get_two_digits(_loc4_) + ":" + get_two_digits(_loc3_)

func get_two_digits(param1: float) -> String:
	if param1 < 10:
		return "0" + IfaceUtil.num_to_str(param1)
	return IfaceUtil.num_to_str(param1)

func _remove_self() -> void:
	if self_.get_parent() != null:
		self_.get_parent().remove_child(self_)

func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var _loc2_: FlashClip = param1.target
	match _loc2_:
		b_next:
			_remove_self()
			IfaceUtil.main().load_upgrade_panel()
		b_restart:
			_remove_self()
			IfaceUtil.main().load_game()
		b_menu:
			_remove_self()
			IfaceUtil.main().load_main_menu()
		b_more:
			IfaceUtil.main().load_more_games()
