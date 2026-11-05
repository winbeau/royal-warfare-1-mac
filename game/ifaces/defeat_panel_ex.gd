# 移植自 S/gameCore/ifaces/defeatPanel_ex.as
# 失败面板：统计文字、成就进度，以及 Retry / Menu / More / Map 四个按钮。
# 偏离：GlobalTracker.trackPage、Kongregate 统计提交不移植（站点分析脚本）。
class_name DefeatPanelEx
extends FlashClip

const SCENE := "res://scenes/ifaces/defeat_panel_ex.tscn"

var self_: DefeatPanelEx  # 原版 private var self
var g: GlobalData
var on_stage: bool = false

var e_max_games: FlashClip
var b_restart: FlashClip
var b_more: FlashClip
var b_menu: FlashClip
var b_map: FlashClip
var _more_games_cb: Callable
var _listening: bool = false

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "defeatPanel")
	_construct()

static func create() -> DefeatPanelEx:
	var n := IfaceUtil.instantiate(SCENE) as DefeatPanelEx
	n._construct()
	return n

func _construct() -> void:
	e_max_games = get_node("eMaxGames")
	b_restart = get_node("bRestart")
	b_more = get_node("bMore")
	b_menu = get_node("bMenu")
	b_map = get_node("bMap")
	# Rasterizer.rasterize(eBg)：无需处理
	b_restart.stop()
	b_more.stop()
	b_menu.stop()
	b_map.stop()

func init() -> void:
	_more_games_cb = Callable(IfaceUtil.main(), "load_more_games")
	ButtonClass.add_button_scale(e_max_games, _more_games_cb)
	_listening = true  # addEventListener(REMOVED_FROM_STAGE, removed)
	self_ = self
	IfaceUtil.main().stop_music_ingame()
	IfaceUtil.play_sound(SoundLibrary.LOSS_MUSIC, 0, 0.55)
	position.x = 350
	position.y = 250
	RWTween.from(self_, 0.4, {"scaleX": 0.4, "scaleY": 0.4, "alpha": 0.3})
	ButtonClass.add_button_on_frames_rd(b_restart, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_menu, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_map, button_clicked)
	on_stage = true
	set_statistics()
	# GlobalTracker.trackPage("Defeat/Level_" + curLevelNum)：站点分析，不移植
	var _loc3_: Array = g.check_achievements(-1)
	VinDefPanelAchivesController.init(self_, _loc3_, get_node("eNoNewAchives"), get_node("bLeft"),
			get_node("bRight"), get_node("eCont"), get_node("eHint"))
	GameUniverse.inst.update_revealed_units()
	StoredData.save_shared_data()
	# Main.isExternalApiEnabled / isKong 的 Kongregate 统计提交：不移植

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
	VinDefPanelAchivesController.remove_events()
	on_stage = false
	ButtonClass.remove_button_on_frames(b_restart, button_clicked)
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_on_frames(b_menu, button_clicked)
	ButtonClass.remove_button_on_frames(b_map, button_clicked)
	ButtonClass.remove_button_scale(e_max_games, _more_games_cb)

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
		b_restart:
			_remove_self()
			IfaceUtil.main().load_game()
		b_menu:
			_remove_self()
			IfaceUtil.main().load_main_menu()
		b_more:
			IfaceUtil.main().load_more_games()
		b_map:
			_remove_self()
			IfaceUtil.main().load_map()
