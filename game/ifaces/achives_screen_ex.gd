# 移植自 S/gameCore/ifaces/achivesScreen_ex.as（achivesScreen_ex extends achivesScreen）
# 成就页：48 项成就分 4 页（每页 12 个），bLeft/bRight 循环翻页，bDot1..4 标记当前页，
# 已完成的成就显示奖章（随机轻微旋转），未完成的悬停显示进度条（eAchives.eHint），
# bMenu 按 isMap 回地图或主菜单，bMore 跳转更多游戏。
#
# HUD-2（VinDefPanelAchivesController）通过 IfaceUtil.global_script("AchivesScreenEx") 动态取
# 静态字段 a_achives_description，这里原样保留该字段名与顺序；另按任务要求提供静态 inst。
class_name AchivesScreenEx
extends FlashClip

const SCENE := "res://scenes/ifaces/achives_screen_ex.tscn"

static var inst: AchivesScreenEx  # 原版 private var self（这里改为静态单例，供其他界面动态引用）
static var a_achives_description: Array = []
static var a_achives_ng: Array = []
static var a_achives_kong: Array = []
static var cached_unit_data: SimpleCache  # 原版声明但未使用，仅保持 API 对齐

const TOTAL_UNDEAD_KILLED := "totalUndeadKilled"
const TOTAL_VICTORIES := "totalVictories"
const TOTAL_VICTORIES_NORMAL := "totalVictoriesNormal"
const TOTAL_VICTORIES_HARD := "totalVictoriesHard"
const TOTAL_VICTORIES_IMPOSSIBLE := "totalVictoriesImpossible"
const FULL_STARS_ACHIEVED := "fullStarsAchieved"

var is_map: bool = false

var current_list: int = 0
var a_lists: Array = []
var a_dots: Array = []
var a_achives: Array = []
var a_medals: Array = []
var a_texts: Array = []
var a_text_coords: Array = []
var a_sensors: Array = []
var o_achives_buffer: Dictionary = {}

var b_more: FlashClip
var b_menu: FlashClip
var b_left: FlashClip
var b_right: FlashClip
var e_achives: FlashClip
var e_logo: FlashClip

var _bound: bool = false
var _attached: bool = false
var _first_ready_done: bool = false
var _inited_once: bool = false


func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "achivesScreen")
	_bind()


static func create() -> AchivesScreenEx:
	var n := IfaceUtil.instantiate(SCENE) as AchivesScreenEx
	n._bind()
	return n


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bind()


func _bind() -> void:
	if _bound:
		return
	b_more = get_node("bMore")
	b_menu = get_node("bMenu")
	b_left = get_node("bLeft")
	b_right = get_node("bRight")
	e_achives = get_node("eAchives")
	e_logo = get_node_or_null("eLogo")
	_bound = b_more != null


## 原版构造函数：停帧四个按钮。
func _construct() -> void:
	inst = self
	b_more.stop()
	b_menu.stop()
	b_left.stop()
	b_right.stop()


func _ready() -> void:
	super._ready()
	if data == null or not _bound:
		return
	_construct()
	init_once()
	_first_ready_done = true
	_added()


func _enter_tree() -> void:
	if _first_ready_done and not _attached:
		_added()


func _exit_tree() -> void:
	if _attached:
		_removed()


## 原版 initOnce()：建数组缓存、成就文案、12 个感应区初始透明。Rasterizer 栅格化调用不移植（纯缓存优化）。
func init_once() -> void:
	if _inited_once:
		return
	_inited_once = true
	a_lists = [e_achives.get_node("l1"), e_achives.get_node("l2"), e_achives.get_node("l3"), e_achives.get_node("l4")]
	a_dots = [get_node("bDot1"), get_node("bDot2"), get_node("bDot3"), get_node("bDot4")]
	a_medals = []
	a_texts = []
	for i in range(1, 13):
		a_medals.append(e_achives.get_node("m%d" % i))
		a_texts.append(e_achives.get_node("t%d" % i))
	for t: FlashText in a_texts:
		t.auto_size = "center"
	a_text_coords = []
	for t2: FlashText in a_texts:
		a_text_coords.append(t2.position.y)
	a_achives_description = [
		"Kill 100 Darth Knights", "Kill 50 Vampires", "Kill 30 Witches", "Kill 25 Ogres", "Kill 150 archers",
		"Kill 1500 skeletons", "Kill 15 enemies with single shot", "Kill 100 enemies using rogue class fighters",
		"Use poison 100 times", "Cast Ice 400 times", "Kill 10 enemies detonating bomberman", "Kill 500 Zombies",
		"Use Mind Control on 100 enemies", "Kill Ogre and receive no damage from him", "Kill 300 enemies using Meteor",
		"Kill 120 enemies using Flash strike", "Upgrade soldier's class to maximum", "Deal 50,000 damage",
		"Heal 5,000 damage", "Suffer 10,000 damage from enemies", "Complete 6 missions with 3 stars in each",
		"Complete 12 missions with 3 stars in each", "Complete 18 missions with 3 stars in each",
		"Complete the game with 3 stars in each mission", "Kill 100 enemies", "Kill 3,000 enemies",
		"Kill 6,000 enemies", "Kill 10,000 enemies", "Complete 1st mission", "Half game passed",
		"Destroy the Undead machine", "Complete the game and kill the Undead King", "Get 119 stars",
		"Lose the battle", "10 soldiers killed", "50 soldiers killed", "15 soldiers resurrected",
		"Protection cast 180 times ", "Receive 100,000 in gold", "Steal 10,000 gold ", "Stun 200 enemies",
		"Check Credits and write author a few words", "Upgrade 300 units to tier2", "Hire 250 units",
		"Curse 400 enemies", "Break armor 150 times", "No soldier killed in the final mission", "Get 50 elite units",
	]
	a_achives_kong = ["DarthKnightsKilled", "VampiresKilled", "WitchesKilled", "OgresKilled", "ArchersKilled",
		"SkeletonsKilled", "killedWithSingleShot", "killedByAssassins", "enemiesPoisoned", "enemiesFrozen",
		"bombermanDetonated", "ZombiesKilled", "setMindControl", "shootTheOgre", "metheorStriked",
		"LightningStriked", "upgradeToTheMax", "damageDealed", "damageHealed", "damageSuffered", "beginner",
		"Experienced", "Veteran", "Master", "killed100", "killed3000", "killed6000", "killed10000",
		"firstMissonCompleted", "halfGameCompleted", "destroyedPortal", "gameCompleted", "gotAllStars",
		"battleLost", "lost10soldiers", "lost50soldiers", "ressurectedAllies", "protectedAllies",
		"gotTonsOfGold", "stealedTonsOfGold", "stunnedEnemies", "watchedCredits", "gotTierTwoUnits",
		"hiredLegions", "cursedEnemies", "breakEnemyArmor", "allUnitsSurvived", "gotEliteUnits"]
	a_achives_ng = ["Darth knights", "Vampires", "Witches", "Ogres", "Archers", "Skeletons", "Massacre",
		"Fast blades", "Poisoned", "Frozen", "Detonated", "Zombies", "Control", "Shoot the Ogre", "Strike",
		"Lightning", "Total upgrade", "Damage bringer", "Healer", "Suffer", "Beginner", "Experienced",
		"Veteran", "Master", "100", "3,000", "6,000", "10,000", "First done", "Half way", "The Machine",
		"Game completed", "All stars", "Battle lost", "10 lost", "50 lost", "Resurrection", "Protection",
		"Farmer", "Stealer", "Stunner", "Credits", "Upgraded", "HR", "Cursed", "Broken", "Survived", "Elite"]
	e_achives.get_node("eHint").mouse_enabled = false
	e_achives.get_node("eHint").mouse_children = false
	a_sensors = []
	for i in range(1, 13):
		a_sensors.append(e_achives.get_node("s%d" % i))
	for s: FlashClip in a_sensors:
		s.modulate.a = 0.0


func _added() -> void:
	_attached = true
	(e_achives.get_node("eHint") as FlashClip).visible = false
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_menu, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_left, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_right, button_clicked)
	a_achives = StoredData.local_game_data[StoredData.NUMPAN_ACHIVES].duplicate()
	current_list = 0
	hide_all_lists()
	set_cur_list_visible()
	for s: FlashClip in a_sensors:
		ButtonClass.add_event_listener(s, ButtonClass.ROLL_OVER, rover)
		ButtonClass.add_event_listener(s, ButtonClass.ROLL_OUT, rout)
	o_achives_buffer = StoredData.local_game_data[StoredData.NUMPAN_ACHIVE_COUNTER]


func rout(_param1: Variant = null) -> void:
	(e_achives.get_node("eHint") as FlashClip).visible = false


## 原版 rover()：按 currentList 与感应区下标查进度计数器/上限，写入 eHint。悬停进度条宽度按百分比缩放。
func rover(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var e_hint: FlashClip = e_achives.get_node("eHint")
	e_hint.visible = true
	var idx := a_sensors.find(target)
	e_hint.position = Vector2(target.position.x + 35, target.position.y + 58)
	var medal: FlashClip = a_medals[idx]
	var cur := 0
	var total := 1
	if medal.visible:
		e_hint.visible = false
	else:
		var r := _progress(idx)
		cur = r[0]
		total = r[1]
		if r[2] == false:
			e_hint.visible = false
	var t_text: FlashText = e_hint.get_node("tText")
	t_text.text = "%d / %d" % [cur, total]
	# Math.round(x) -> floor(x + 0.5)（docs/port-plan.md 第 3.2 条）
	var pct: float = floorf(cur * 100.0 / total + 0.5)
	(e_hint.get_node("eBar") as FlashClip).scale.x = pct / 100.0


func _ctr(key: String) -> int:
	return int(o_achives_buffer.get(key, 0))


## 返回 [当前进度, 上限, 是否显示进度条]，按 current_list 与感应区下标（0 基）对应原版四个 switch 分支。
func _progress(idx: int) -> Array:
	match current_list:
		0:
			match idx:
				0: return [_ctr("a1_darkKnitedKilled"), 100, true]
				1: return [_ctr("a2_vampiresKilled"), 50, true]
				2: return [_ctr("a3_witchesKilled"), 30, true]
				3: return [_ctr("a4_ogresKilled"), 25, true]
				4: return [_ctr("a5_archersKilled"), 150, true]
				5: return [_ctr("a6_skeletonsKilled"), 1500, true]
				6: return [0, 1, false]
				7: return [_ctr("a8_killedByRogues"), 100, true]
				8: return [_ctr("a9_poisoned"), 100, true]
				9: return [_ctr("a10_frozen"), 400, true]
				10: return [0, 1, false]
				11: return [_ctr("a12_zombieKilled"), 500, true]
		1:
			var completed3 := _count_levels_equal(3)
			match idx:
				0: return [_ctr("a13_mindControl"), 100, true]
				1: return [0, 1, false]
				2: return [_ctr("a15_killByMetheor"), 300, true]
				3: return [_ctr("a16_killFlash"), 120, true]
				4: return [0, 1, false]
				5: return [_ctr("a18_makeDamage"), 50000, true]
				6: return [_ctr("a19_healDamage"), 5000, true]
				7: return [_ctr("a20_tankDamage"), 10000, true]
				8: return [completed3, 6, true]
				9: return [completed3, 12, true]
				10: return [completed3, 18, true]
				11: return [completed3, 24, true]
		2:
			var visited := _count_levels_not_equal(0)
			var stars := StoredData.get_num_gained_stars()
			match idx:
				0: return [_ctr("a25_28_totalKilled"), 100, true]
				1: return [_ctr("a25_28_totalKilled"), 3000, true]
				2: return [_ctr("a25_28_totalKilled"), 6000, true]
				3: return [_ctr("a25_28_totalKilled"), 10000, true]
				4: return [visited, 1, true]
				5: return [visited, 12, true]
				6: return [visited, 21, true]
				7: return [visited, 24, true]
				8: return [stars, 119, true]
				9: return [0, 1, true]  # 原版此分支没有把 eHint.visible 设为 false，始终显示 "0 / 1"
				10: return [_ctr("a35_36_lostSoldiers"), 10, true]
				11: return [_ctr("a35_36_lostSoldiers"), 50, true]
		3:
			match idx:
				0: return [_ctr("a37_ressurect"), 15, true]
				1: return [_ctr("a38_protection"), 180, true]
				2: return [_ctr("a39_farmGold"), 100000, true]
				3: return [_ctr("a40_stealGold"), 10000, true]
				4: return [_ctr("a41_stunEnemies"), 200, true]
				5: return [0, 1, false]
				6: return [_ctr("a43_tier2upgrade"), 300, true]
				7: return [_ctr("a44_hireUnits"), 250, true]
				8: return [_ctr("a45_curseEnemies"), 400, true]
				9: return [_ctr("a46_breakArmor"), 150, true]
				10: return [0, 1, false]
				11: return [_ctr("a48_getElite"), 50, true]
	return [0, 1, false]


func _count_levels_equal(v: int) -> int:
	var n := 0
	for x in StoredData.local_game_data[StoredData.NUMPAN_LEVELS]:
		if int(x) == v:
			n += 1
	return n


func _count_levels_not_equal(v: int) -> int:
	var n := 0
	for x in StoredData.local_game_data[StoredData.NUMPAN_LEVELS]:
		if int(x) != v:
			n += 1
	return n


func set_cur_list_visible() -> void:
	a_lists[current_list].visible = true
	a_dots[current_list].modulate.a = 1.0
	RWTween.from_to(e_achives, 0.4, {"colorMatrixFilter": {"brightness": 2}}, {"colorMatrixFilter": {"brightness": 1}})
	var offset := current_list * 12
	for i in range(offset, offset + 12):
		var achived: int = int(a_achives[i])
		var li := i - offset
		var medal: FlashClip = a_medals[li]
		if achived == 0:
			medal.visible = false
		else:
			medal.visible = true
			medal.rotation_degrees = floorf(15.0 * RWRandom.rand())
			if RWRandom.rand() > 0.5:
				medal.rotation_degrees *= -1.0
		var text: FlashText = a_texts[li]
		text.text = str(a_achives_description[i])
		text.position.y = a_text_coords[li]
		match IfaceUtil.num_lines(text):
			3: text.position.y += 11
			2: text.position.y += 18
			1: text.position.y += 25


func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	if target == b_menu:
		if is_map:
			_main_call(&"load_map")
		else:
			_main_call(&"load_main_menu")
	elif target == b_more:
		_main_call(&"load_more_games")
	elif target == b_left:
		current_list -= 1
		if current_list < 0:
			current_list = 3
		hide_all_lists()
		set_cur_list_visible()
	elif target == b_right:
		current_list += 1
		if current_list > 3:
			current_list = 0
		hide_all_lists()
		set_cur_list_visible()


func hide_all_lists() -> void:
	for l: FlashClip in a_lists:
		l.visible = false
	for d: FlashClip in a_dots:
		d.modulate.a = 0.3


## 原版疑点：removed() 只摘掉了 bMore/bMenu 的监听，没有摘 bLeft/bRight（addButtonOnFramesRD 加过的监听），
## 按规则原样保留，不补上。
func _removed() -> void:
	_attached = false
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_on_frames(b_menu, button_clicked)
	for s: FlashClip in a_sensors:
		ButtonClass.remove_event_listener(s, ButtonClass.ROLL_OVER, rover)
		ButtonClass.remove_event_listener(s, ButtonClass.ROLL_OUT, rout)


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)
