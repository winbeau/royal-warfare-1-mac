# 移植自 S/gameCore/ifaces/upgrPanel_ex.as（升级面板：兵种解锁、技能/奖励加点、星数计算）
#
# 与原版的对应方式：
# - 原版 `upgrPanel_ex extends upgrPanel`；符号类 upgrPanel 的实例字段在这里是通过 _bind() 取得的成员变量，
#   做法与 game/ifaces/main_game_ui_ex.gd 一致：`new upgrPanel_ex()` 走 IfaceUtil.adopt + _bind；从继承场景
#   scenes/ifaces/upgr_panel_ex.tscn 实例化时由 NOTIFICATION_SCENE_INSTANTIATED 触发 _bind。
# - 原版构造函数体 → _construct()；ADDED_TO_STAGE 的 added() → _added()；REMOVED_FROM_STAGE 的 removed() → _removed()，
#   分别由 _ready/_enter_tree 和 _exit_tree 驱动（同 MainGameUIEx）。
# - gameUniverse.aSpecials 直接用 GameUniverse.a_specials[idx]（静态数组，下标即 StoredData.A_*；A_WEAKNESS=33 为 null，同原版）。
# - Rasterizer.rasterize / cacheAsBitmap（initOnce 里的位图缓存）不移植：纯渲染优化，不影响行为。
# - zanavesUpgr 的 getChildAt(0).mask = msk：zanavesUpgr（607）里 getChildAt(0) 是没有实例名的子剪辑 604，
#   管线（ClipExporter.INDEXED_CHILD_IDS 含 607）把它导出为可寻址节点 e0（按显示列表下标命名）。init_once() 用
#   FlashClip.set_mask(e0, msk) 接上遮罩（e0 改挂到 msk 下，msk 裁剪），幕布动画移动 e0 自身的 y（见 zanaves_child）。
# - 站点统计、Kongregate 相关：原版这个类没有，不涉及。
class_name UpgrPanelEx
extends FlashClip

const SCENE := "res://scenes/ifaces/upgr_panel_ex.tscn"

const C_WARRIORS := "cWarriors"
const C_ARCHERS := "cArchers"
const C_THIEVES := "cThieves"
const C_MAGES := "cMages"
const C_PRIESTS := "cPriests"

static var class_instance: UpgrPanelEx  # 原版 classInstance（全工程未见引用，照样保留）

# ---- 私有字段（原版 private var）----
var num_free_stars: int = 0
var a_all_locked_buttons: Array = []
var self_: UpgrPanelEx
var default_text: String = "Spend your stars to get new abilities and to improve already gained. Hold SHIFT and click ability to downgrade it. Click \"Reset\" button to reset all your stars and reassign in a different way."
var a_hint_coords: Array = []
var element_to_blink: FlashClip
var s: SoundLibrary

var _attached: bool = false
var _first_ready_done: bool = false
var _bound: bool = false

# ---- 符号类 upgrPanel 的实例字段 ----
var b_next: FlashClip
var b_more: FlashClip
var b_menu: FlashClip
var b_reset: FlashClip
var b_help: FlashClip
var e_hint: FlashClip
var e_achievement: FlashClip
var e_achievement_final: FlashClip
var e_unit_unlocked_bar: FlashClip
var t_free_stars: FlashText
var t_hint_text: FlashText
var zanaves_warriors: FlashClip
var zanaves_archers: FlashClip
var zanaves_thieves: FlashClip
var zanaves_mages: FlashClip
var zanaves_priests: FlashClip

var u_war_sword_unit: FlashClip
var u_war_sword_a: FlashClip
var u_war_sword_b: FlashClip
var u_war_warrior_a: FlashClip
var u_war_warrior_b: FlashClip
var u_war_knight_unit: FlashClip
var u_war_knight_a: FlashClip
var u_war_knight_b: FlashClip
var u_warrior_icon: FlashClip
var u_warriors_attack: FlashClip
var u_warriors_defend: FlashClip

var u_arch_crossb_unit: FlashClip
var u_arch_crossb_a: FlashClip
var u_arch_crossb_b: FlashClip
var u_arch_archer_a: FlashClip
var u_arch_archer_b: FlashClip
var u_arch_sniper_unit: FlashClip
var u_arch_sniper_a: FlashClip
var u_arch_sniper_b: FlashClip
var u_archer_icon: FlashClip
var u_archers_attack: FlashClip
var u_archers_defend: FlashClip

var u_mage_red_unit: FlashClip
var u_mage_red_a: FlashClip
var u_mage_red_b: FlashClip
var u_mage_black_unit: FlashClip
var u_mage_black_a: FlashClip
var u_mage_black_b: FlashClip
var u_mage_blue_a: FlashClip
var u_mage_blue_b: FlashClip
var u_blue_mage_icon: FlashClip
var u_mages_attack: FlashClip
var u_mages_defend: FlashClip

var u_priest_healer_unit: FlashClip
var u_priest_healer_a: FlashClip
var u_priest_healer_b: FlashClip
var u_priest_blesser_unit: FlashClip
var u_priest_blesser_a: FlashClip
var u_priest_blesser_b: FlashClip
var u_priest_priest_a: FlashClip
var u_priest_priest_b: FlashClip
var u_priest_icon: FlashClip
var u_priests_attack: FlashClip
var u_priests_defend: FlashClip

var u_thief_assasin_unit: FlashClip
var u_thief_assasin_a: FlashClip
var u_thief_assasin_b: FlashClip
var u_thief_sabot_unit: FlashClip
var u_thief_sabot_a: FlashClip
var u_thief_sabot_b: FlashClip
var u_thief_thief_a: FlashClip
var u_thief_thief_b: FlashClip
var u_thief_icon: FlashClip
var u_rogues_attack: FlashClip
var u_roguess_defend: FlashClip  # 原版拼写（少一个 s 用在别处、这里多一个 s），保留原拼写


static func create() -> UpgrPanelEx:
	return IfaceUtil.instantiate(SCENE) as UpgrPanelEx


func _init() -> void:
	class_instance = self
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "upgrPanel")
	_bind()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bind()
	elif what == NOTIFICATION_PREDELETE:
		if class_instance == self:
			class_instance = null


func _c(path: String) -> FlashClip:
	return get_node_or_null(NodePath(path)) as FlashClip


func _t(path: String) -> FlashText:
	return get_node_or_null(NodePath(path)) as FlashText


func _bind() -> void:
	if _bound:
		return
	b_next = _c("bNext")
	b_more = _c("bMore")
	b_menu = _c("bMenu")
	b_reset = _c("bReset")
	b_help = _c("bHelp")
	e_hint = _c("eHint")
	e_achievement = _c("eAchievement")
	e_achievement_final = _c("eAchievementFinal")
	e_unit_unlocked_bar = _c("eUnitUnlockedBar")
	t_free_stars = _t("tFreeStars")
	t_hint_text = _t("tHintText")
	zanaves_warriors = _c("zanavesWarriors")
	zanaves_archers = _c("zanavesArchers")
	zanaves_thieves = _c("zanavesThieves")
	zanaves_mages = _c("zanavesMages")
	zanaves_priests = _c("zanavesPriests")

	u_war_sword_unit = _c("uWarSwordUnit")
	u_war_sword_a = _c("uWarSwordA")
	u_war_sword_b = _c("uWarSwordB")
	u_war_warrior_a = _c("uWarWarriorA")
	u_war_warrior_b = _c("uWarWarriorB")
	u_war_knight_unit = _c("uWarKnightUnit")
	u_war_knight_a = _c("uWarKnightA")
	u_war_knight_b = _c("uWarKnightB")
	u_warrior_icon = _c("uWarriorIcon")
	u_warriors_attack = _c("uWarriorsAttack")
	u_warriors_defend = _c("uWarriorsDefend")

	u_arch_crossb_unit = _c("uArchCrossbUnit")
	u_arch_crossb_a = _c("uArchCrossbA")
	u_arch_crossb_b = _c("uArchCrossbB")
	u_arch_archer_a = _c("uArchArcherA")
	u_arch_archer_b = _c("uArchArcherB")
	u_arch_sniper_unit = _c("uArchSniperUnit")
	u_arch_sniper_a = _c("uArchSniperA")
	u_arch_sniper_b = _c("uArchSniperB")
	u_archer_icon = _c("uArcherIcon")
	u_archers_attack = _c("uArchersAttack")
	u_archers_defend = _c("uArchersDefend")

	u_mage_red_unit = _c("uMageRedUnit")
	u_mage_red_a = _c("uMageRedA")
	u_mage_red_b = _c("uMageRedB")
	u_mage_black_unit = _c("uMageBlackUnit")
	u_mage_black_a = _c("uMageBlackA")
	u_mage_black_b = _c("uMageBlackB")
	u_mage_blue_a = _c("uMageBlueA")
	u_mage_blue_b = _c("uMageBlueB")
	u_blue_mage_icon = _c("uBlueMageIcon")
	u_mages_attack = _c("uMagesAttack")
	u_mages_defend = _c("uMagesDefend")

	u_priest_healer_unit = _c("uPriestHealerUnit")
	u_priest_healer_a = _c("uPriestHealerA")
	u_priest_healer_b = _c("uPriestHealerB")
	u_priest_blesser_unit = _c("uPriestBlesserUnit")
	u_priest_blesser_a = _c("uPriestBlesserA")
	u_priest_blesser_b = _c("uPriestBlesserB")
	u_priest_priest_a = _c("uPriestPriestA")
	u_priest_priest_b = _c("uPriestPriestB")
	u_priest_icon = _c("uPriestIcon")
	u_priests_attack = _c("uPriestsAttack")
	u_priests_defend = _c("uPriestsDefend")

	u_thief_assasin_unit = _c("uThiefAssasinUnit")
	u_thief_assasin_a = _c("uThiefAssasinA")
	u_thief_assasin_b = _c("uThiefAssasinB")
	u_thief_sabot_unit = _c("uThiefSabotUnit")
	u_thief_sabot_a = _c("uThiefSabotA")
	u_thief_sabot_b = _c("uThiefSabotB")
	u_thief_thief_a = _c("uThiefThiefA")
	u_thief_thief_b = _c("uThiefThiefB")
	u_thief_icon = _c("uThiefIcon")
	u_rogues_attack = _c("uRoguesAttack")
	u_roguess_defend = _c("uRoguessDefend")

	_bound = b_next != null


func _ready() -> void:
	super._ready()
	if data == null or not _bound:
		return
	_construct()
	_first_ready_done = true
	_added()


func _enter_tree() -> void:
	# 首次进入时 _ready 尚未执行（FlashClip 还没建好图层），由 _ready 调用 _added()
	if _first_ready_done and not _attached:
		_added()


func _exit_tree() -> void:
	if _attached:
		_removed()


## 原版构造函数体。
func _construct() -> void:
	self_ = self
	a_hint_coords = []
	for c in e_hint.get_children():
		if c is FlashClip and c.name != "eBg":
			a_hint_coords.append([c, c.position])
	# 原版 eHint 自身没有任何自带位图，点击命中完全靠点到某个说明面板（614/618/620/622，导出成 e0..e3，
	# 见 pipeline/ClipExporter.java 的 INDEXED_CHILD_IDS 625 注释）；FlashClip._has_point 对只有子节点、
	# 自己没有位图的容器永远判 false（见该方法注释），所以 eHint 本身收不到 CLICK。按原版"点哪个面板都能
	# 关闭"的效果，直接在每个面板上也挂 hide_hint，不依赖 eHint 容器自身的命中测试。
	for pair in a_hint_coords:
		ButtonClass.add_button_lite(pair[0], _hint_element_clicked)
	var e_bg := e_hint.get_node_or_null("eBg") as FlashClip
	if e_bg != null:
		ButtonClass.add_button_lite(e_bg, _hint_element_clicked)
	a_all_locked_buttons = [
		u_arch_archer_a, u_arch_archer_b, u_arch_crossb_a, u_arch_crossb_b, u_arch_crossb_unit,
		u_arch_sniper_a, u_arch_sniper_b, u_arch_sniper_unit, u_mage_black_a, u_mage_black_b,
		u_mage_black_unit, u_mage_blue_a, u_mage_blue_b, u_mage_red_a, u_mage_red_b, u_mage_red_unit,
		u_priest_blesser_a, u_priest_blesser_b, u_priest_blesser_unit, u_priest_healer_a,
		u_priest_healer_b, u_priest_healer_unit, u_priest_priest_a, u_priest_priest_b,
		u_thief_assasin_a, u_thief_assasin_b, u_thief_assasin_unit, u_thief_sabot_a, u_thief_sabot_b,
		u_thief_sabot_unit, u_thief_thief_a, u_thief_thief_b, u_war_knight_a, u_war_knight_b,
		u_war_knight_unit, u_war_sword_a, u_war_sword_b, u_war_sword_unit, u_war_warrior_a,
		u_war_warrior_b, u_warriors_attack, u_warriors_defend, u_archers_attack, u_archers_defend,
		u_mages_attack, u_mages_defend, u_rogues_attack, u_roguess_defend, u_priests_attack,
		u_priests_defend,
	]
	b_next.stop()
	b_more.stop()
	b_menu.stop()
	b_reset.stop()
	b_help.stop()
	var e_ico := e_unit_unlocked_bar.child_clip("eIco")
	if e_ico != null:
		e_ico.stop()
	e_unit_unlocked_bar.mouse_enabled = false
	e_unit_unlocked_bar.mouse_children = false


## 原版 added()（Event.ADDED_TO_STAGE）。
func _added() -> void:
	if _attached:
		return
	_attached = true
	s = SoundLibrary.inst
	e_achievement.visible = false
	e_achievement.modulate.a = 1.0
	e_achievement.scale = Vector2.ONE
	e_achievement_final.visible = false
	e_achievement_final.modulate.a = 1.0
	e_achievement_final.scale = Vector2.ONE
	for btn: FlashClip in a_all_locked_buttons:
		var lock := btn.child_clip("eLock")
		if lock != null:
			lock.goto_and_stop(1)
	ButtonClass.add_button_on_frames_rd(b_next, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_menu, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_reset, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_help, button_clicked)
	var e_ico := e_unit_unlocked_bar.child_clip("eIco")
	if e_ico != null:
		e_ico.stop()
	e_unit_unlocked_bar.visible = false
	e_hint.visible = false
	ButtonClass.add_button_lite(e_hint, button_clicked)
	# buttonClass.addButtonLite 会把 e_hint.mouseChildren 设为 false（原版意图：没有子节点各自可点，
	# 整个 eHint 当一个按钮）。但现在 eHint 的说明面板（e0..e3/eBg）已导出成独立节点并各自挂了点击
	# 监听（见 _construct），需要改回 true 才能收到点击；e_hint 容器自身仍然没有自己的位图，不接收
	# 点击，靠这些子节点各自命中测试关闭提示，等效于原版"点到 eHint 范围内任意一处都能关闭"。
	e_hint.mouse_children = true
	num_free_stars = StoredData.get_num_free_stars()
	t_free_stars.text = str(num_free_stars)

	var a_units: Array = (StoredData.local_game_data[StoredData.NUMPAN_UNITS] as Array).duplicate()
	var unit_pairs := [
		[StoredData.U_ASSASIN, u_thief_assasin_unit], [StoredData.U_SABOT, u_thief_sabot_unit],
		[StoredData.U_KNIGHT, u_war_knight_unit], [StoredData.U_SWORDMASTER, u_war_sword_unit],
		[StoredData.U_CROSSBOW, u_arch_crossb_unit], [StoredData.U_SNIPER, u_arch_sniper_unit],
		[StoredData.U_HEAL, u_priest_healer_unit], [StoredData.U_BLESS, u_priest_blesser_unit],
		[StoredData.U_RED, u_mage_red_unit], [StoredData.U_BLACK, u_mage_black_unit],
	]
	for pair in unit_pairs:
		var idx: int = pair[0]
		var clip: FlashClip = pair[1]
		if int(StoredData._geti(a_units, idx)) == 1:
			unlock_unit(clip)
		else:
			lock_unit(clip)
		icon_rover_rout_init(clip)
	icon_rover_rout_init(u_warrior_icon)
	icon_rover_rout_init(u_priest_icon)
	icon_rover_rout_init(u_blue_mage_icon)
	icon_rover_rout_init(u_archer_icon)
	icon_rover_rout_init(u_thief_icon)

	var a_abils: Array = (StoredData.local_game_data[StoredData.NUMPAN_ABILS] as Array).duplicate()
	var abil_pairs := [
		[StoredData.A_BACKSTAB, u_thief_assasin_a], [StoredData.A_MISS_ASSASIN, u_thief_assasin_b],
		[StoredData.A_POISON_THIEF, u_thief_thief_b], [StoredData.A_COLLECTMONEY, u_thief_thief_a],
		[StoredData.A_HIDE, u_thief_sabot_a], [StoredData.A_BREAKARROW, u_thief_sabot_b],
		[StoredData.A_BLOCK, u_war_warrior_a], [StoredData.A_STUN, u_war_warrior_b],
		[StoredData.A_ROUNDATTACK, u_war_sword_a], [StoredData.A_PARRY, u_war_sword_b],
		[StoredData.A_TAUNT, u_war_knight_a], [StoredData.A_MASSSTUN, u_war_knight_b],
		[StoredData.A_SLOW, u_arch_archer_a], [StoredData.A_SUPPRESS, u_arch_archer_b],
		[StoredData.A_CRITRANGED, u_arch_crossb_a], [StoredData.A_CORRUPT, u_arch_crossb_b],
		[StoredData.A_HEADSHOT, u_arch_sniper_a], [StoredData.A_WEAKSPOT, u_arch_sniper_b],
		[StoredData.A_ICE, u_mage_blue_a], [StoredData.A_FLASH, u_mage_blue_b],
		[StoredData.A_METHEOR, u_mage_red_b], [StoredData.A_FIREHITSPLASH, u_mage_red_a],
		[StoredData.A_BETRAY, u_mage_black_a], [StoredData.A_CURSE_BLACK, u_mage_black_b],
		[StoredData.A_STRONGHEAL, u_priest_priest_a], [StoredData.A_ENCHANT, u_priest_priest_b],
		[StoredData.A_MASSHEAL, u_priest_healer_a], [StoredData.A_RESURRECT, u_priest_healer_b],
		[StoredData.A_CURSEBLESS, u_priest_blesser_a], [StoredData.A_HARMRESIST, u_priest_blesser_b],
	]
	for pair in abil_pairs:
		var idx2: int = pair[0]
		var clip2: FlashClip = pair[1]
		var lvl := int(StoredData._geti(a_abils, idx2))
		if lvl == 0:
			lock_ability(clip2)
		else:
			unlock_ability(clip2, lvl)
		icon_rover_rout_init(clip2)

	var a_bonus: Array = (StoredData.local_game_data[StoredData.NUMPAN_UNIT_BONUSES] as Array).duplicate()
	var bonus_pairs := [
		[0, u_warriors_attack], [1, u_warriors_defend], [2, u_archers_attack], [3, u_archers_defend],
		[4, u_mages_attack], [5, u_mages_defend], [6, u_rogues_attack], [7, u_roguess_defend],
		[8, u_priests_attack], [9, u_priests_defend],
	]
	for pair in bonus_pairs:
		var idx3: int = pair[0]
		var clip3: FlashClip = pair[1]
		var lvl3 := int(StoredData._geti(a_bonus, idx3))
		if lvl3 == 0:
			lock_ability(clip3)
		else:
			unlock_ability(clip3, lvl3)
		icon_rover_rout_init(clip3)

	# 原版 self.zanavesX.getChildAt(0).y = 0（getChildAt(0) 即导出节点 e0）
	for z: FlashClip in [zanaves_warriors, zanaves_thieves, zanaves_priests, zanaves_mages, zanaves_archers]:
		var zc := zanaves_child(z)
		if zc != null:
			zc.position.y = 0.0
	check_zanaves_and_tier_three()


## 原版 checkZanavesAndTierThree()。内层闭包 showWarrior 等改写成本函数的局部函数（Callable）。
## 原版 showWarrior 里未加限定的 showHint 引用的是外层方法 this.showHint()（本类"? 按钮"的帮助提示），
## 即五类幕布里只有"战士"类第一次升起时会在 1 秒后自动弹出一次帮助提示。
func check_zanaves_and_tier_three() -> void:
	var o_zanaves: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_ZANAVES]

	# clip 即 zanavesX；动画对象是 getChildAt(0)（zanaves_child）
	var reveal := func(zanaves_num: int, clip: FlashClip, watched: bool, auto_hint: bool) -> void:
		var zc := zanaves_child(clip)
		var h := IfaceUtil.clip_bounds(zc).size.y  # 原版 getChildAt(0).height
		if not watched:
			StoredData.save_data(StoredData.ZANAVES_WATCHED, {"zanavesNumber": zanaves_num})
			RWTween.to(zc, 1, {"y": -h, "delay": 0.6, "ease": RWEase.linear_ease_in})
			if auto_hint:
				RWTween.delayed_call(1, show_hint)
		else:
			zc.position.y = -h

	var show_warrior := func() -> void:
		reveal.call(1, zanaves_warriors, int(o_zanaves.get("zWarriors", 0)) != 0, true)
	var show_archer := func() -> void:
		reveal.call(2, zanaves_archers, int(o_zanaves.get("zArchers", 0)) != 0, false)
	var show_priest := func() -> void:
		reveal.call(3, zanaves_priests, int(o_zanaves.get("zPriests", 0)) != 0, false)
	var show_mages := func() -> void:
		reveal.call(4, zanaves_mages, int(o_zanaves.get("zMages", 0)) != 0, false)
	var show_thieves := func() -> void:
		reveal.call(5, zanaves_thieves, int(o_zanaves.get("zThieves", 0)) != 0, false)

	var a_levels_info: Array = (StoredData.local_game_data[StoredData.NUMPAN_LEVELS] as Array).duplicate()
	var num_passed := 0
	for v in a_levels_info:
		if int(v) > 0:
			num_passed += 1

	if num_passed < 2:
		show_warrior.call()
	elif num_passed < 3:
		show_warrior.call()
		show_archer.call()
	elif num_passed < 4:
		show_warrior.call()
		show_archer.call()
		show_priest.call()
	elif num_passed < 5:
		show_warrior.call()
		show_archer.call()
		show_priest.call()
		show_mages.call()
	else:
		show_warrior.call()
		show_archer.call()
		show_priest.call()
		show_mages.call()
		show_thieves.call()

	var opened_soldiers: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_OPENED_TIER3]
	if num_passed >= 7 and int(opened_soldiers.get("zKnight", 0)) == 0:
		locked_unit_unlocked(u_war_knight_unit)
		StoredData.save_data(StoredData.TIER3_SHOWN, {"unitNumber": 1})
	if num_passed >= 8 and int(opened_soldiers.get("zCrossbow", 0)) == 0:
		locked_unit_unlocked(u_arch_crossb_unit)
		StoredData.save_data(StoredData.TIER3_SHOWN, {"unitNumber": 2})
	if num_passed >= 9 and int(opened_soldiers.get("zBlack", 0)) == 0:
		locked_unit_unlocked(u_mage_black_unit)
		StoredData.save_data(StoredData.TIER3_SHOWN, {"unitNumber": 4})
	if num_passed >= 10 and int(opened_soldiers.get("zMonk", 0)) == 0:
		locked_unit_unlocked(u_priest_blesser_unit)
		StoredData.save_data(StoredData.TIER3_SHOWN, {"unitNumber": 3})
	if num_passed >= 11 and int(opened_soldiers.get("zSpy", 0)) == 0:
		locked_unit_unlocked(u_thief_sabot_unit)
		StoredData.save_data(StoredData.TIER3_SHOWN, {"unitNumber": 5})


func icon_rover_rout_init(c: FlashClip) -> void:
	ButtonClass.add_event_listener(c, ButtonClass.ROLL_OVER, icon_rovered)
	ButtonClass.add_event_listener(c, ButtonClass.ROLL_OUT, icon_routed)


func icon_rover_rout_remove(c: FlashClip) -> void:
	ButtonClass.remove_event_listener(c, ButtonClass.ROLL_OVER, icon_rovered)
	ButtonClass.remove_event_listener(c, ButtonClass.ROLL_OUT, icon_routed)


func icon_routed(e: ButtonClass.ButtonEvent = null) -> void:
	RWTween.delayed_call(1, show_default_text)
	var target: FlashClip = e.target if e != null else null
	if target != null:
		RWTween.to(target, 0.2, {"glowFilter": {"color": 16777215, "alpha": 0, "remove": true}})


func show_default_text() -> void:
	t_hint_text.text = default_text


## param2 对应原版 iconRovered 的重载第二参数（直接传 MovieClip 而不是事件，用于点击后刷新描述）。
func icon_rovered(e: Variant, forced: FlashClip = null) -> void:
	RWTween.kill_delayed_calls_to(show_default_text)
	var target: FlashClip = forced if forced != null else (e.target if e != null else null)
	if target == null:
		return
	IfaceUtil.play_sound(SoundLibrary.ROVER, 0, 0.2, 350, SoundLibrary.ROVER)
	ButtonClass.play_rover(target)
	var html := ""
	var spec: SpecialTemplate = null
	var abil_const := _abil_pad_const(target)
	if abil_const >= 0:
		spec = GameUniverse.a_specials[abil_const]
	elif _bonus_pads().has(target):
		html = _bonus_html(target)
		set_icon_glow(target)
	else:
		html = _unit_icon_html(target)
	if spec == null:
		if html != "":
			t_hint_text.html_text = html
		else:
			t_hint_text.text = default_text
	else:
		t_hint_text.html_text = spec.special_description + "<font size='4'><br></font>" + spec.cur_level_params()
		set_icon_glow(target)


func set_icon_glow(c: FlashClip) -> void:
	RWTween.to(c, 0.2, {"glowFilter": {"color": 16777215, "alpha": 1, "blurX": 4, "blurY": 4, "strength": 3}})


func button_clicked(e: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = e.target
	match target:
		b_next:
			IfaceUtil.main().load_map()
		b_menu:
			IfaceUtil.main().load_main_menu()
		b_more:
			IfaceUtil.main().load_more_games()
		b_reset:
			StoredData.save_data(StoredData.COM_RESET_ABILITIES, null)
			IfaceUtil.main().load_upgrade_panel()
		b_help:
			show_hint()
		e_hint:
			hide_hint()


## 非原版符号：挂在每个说明面板上的点击监听（见 _construct 注释），效果等同原版点 eHint 关闭提示。
func _hint_element_clicked(_e: ButtonClass.ButtonEvent) -> void:
	hide_hint()


func hide_hint() -> void:
	for pair in a_hint_coords:
		var el: FlashClip = pair[0]
		var pnt: Vector2 = pair[1]
		el.modulate.a = 1.0
		el.position = pnt
		RWTween.to(el, 0.3, {
			"alpha": 0, "x": Main.GAME_WIDTH * RWRandom.rand(), "y": Main.GAME_HEIGHT * RWRandom.rand(),
			"onComplete": func() -> void: e_hint.visible = false,
		})


func show_hint() -> void:
	e_hint.visible = true
	for pair in a_hint_coords:
		var el: FlashClip = pair[0]
		var pnt: Vector2 = pair[1]
		el.modulate.a = 1.0
		el.position = pnt
		RWTween.from(el, 0.3, {"alpha": 0, "x": Main.GAME_WIDTH * RWRandom.rand(), "y": Main.GAME_HEIGHT * RWRandom.rand()})


func unlock_ability(c: FlashClip, lvl: int) -> void:
	var lock := c.child_clip("eLock")
	if lock != null:
		lock.goto_and_stop(lvl + 2)
	ButtonClass.add_button_lite(c, ability_clicked)


## 原版 abilityClicked。tier3 兵种未解锁时点加点按钮算作点了"锁住的兵种"（lockedUnitClicked）。
func ability_clicked(e: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = e.target
	var lock := target.child_clip("eLock")
	if lock == null:
		return
	var cur_frame := lock.current_frame
	if not e.shift_key:
		if cur_frame == 5:
			ability_maxed()
			return
		if num_free_stars > 0:
			var gated := [
				[u_war_knight_a, u_war_knight_b, u_war_knight_unit],
				[u_arch_crossb_a, u_arch_crossb_b, u_arch_crossb_unit],
				[u_mage_black_a, u_mage_black_b, u_mage_black_unit],
				[u_priest_blesser_a, u_priest_blesser_b, u_priest_blesser_unit],
				[u_thief_sabot_a, u_thief_sabot_b, u_thief_sabot_unit],
			]
			for g in gated:
				if (target == g[0] or target == g[1]) and (g[2] as FlashClip).child_clip("eLock").current_frame == 1:
					locked_unit_clicked()
					return
			num_free_stars -= 1
			t_free_stars.text = str(num_free_stars)
			if cur_frame == 1:
				lock.goto_and_stop(3)
				IfaceUtil.play_sound(SoundLibrary.UPG_CLICK1, 0, 0.25)
			else:
				lock.goto_and_stop(cur_frame + 1)
				IfaceUtil.play_sound(SoundLibrary.UPG_CLICK3 if cur_frame == 4 else SoundLibrary.UPG_CLICK2, 0, 0.25)
			RWTween.from_to(target, 0.8,
				{"colorMatrixFilter": {"contrast": 1.5, "saturation": 1.5, "brightness": 2}},
				{"colorMatrixFilter": {"contrast": 1, "saturation": 1, "brightness": 1}})
			var category := _save_ability_or_bonus_click(target, false)
			if category == "":
				return
			var fully_upgraded := true
			for pad: FlashClip in _category_pads(category):
				var pl := pad.child_clip("eLock")
				if pl == null or pl.current_frame != 5:
					fully_upgraded = false
			if StoredData.check_if_achievement_not_done(StoredData.AB_17_FULL_UPGRADE) and fully_upgraded:
				StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": StoredData.AB_17_FULL_UPGRADE})
				e_achievement.visible = true
				e_achievement.modulate.a = 1.0
				e_achievement.scale = Vector2.ONE
				RWTween.from(e_achievement, 0.4, {
					"scaleX": 1.3, "scaleY": 1.3, "alpha": 0.3,
					"onComplete": remove_adhievement, "onCompleteParams": [e_achievement],
				})
				if StoredData.check_last_star():
					StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": StoredData.AB_33_GET_119_STARS})
					e_achievement_final.visible = true
					e_achievement_final.modulate.a = 1.0
					e_achievement_final.scale = Vector2.ONE
					RWTween.from(e_achievement_final, 0.4, {
						"scaleX": 1.3, "scaleY": 1.3, "alpha": 0.3,
						"onComplete": remove_adhievement, "onCompleteParams": [e_achievement_final],
					})
				StoredData.save_shared_data()
				num_free_stars = StoredData.get_num_free_stars()
				t_free_stars.text = str(num_free_stars)
		else:
			not_enough_stars()
	elif cur_frame > 1:
		num_free_stars += 1
		t_free_stars.text = str(num_free_stars)
		if cur_frame == 3:
			IfaceUtil.play_sound(SoundLibrary.UPG_CLICK1, 0, 0.25)
			lock_ability(target)
		else:
			lock.goto_and_stop(cur_frame - 1)
			IfaceUtil.play_sound(SoundLibrary.UPG_CLICK3 if cur_frame == 4 else SoundLibrary.UPG_CLICK2, 0, 0.25)
		RWTween.from_to(target, 0.8,
			{"colorMatrixFilter": {"contrast": 1.5, "saturation": 1.5, "brightness": 2}},
			{"colorMatrixFilter": {"contrast": 1, "saturation": 1, "brightness": 1}})
		_save_ability_or_bonus_click(target, true)
	else:
		ability_disabled()


## 原版 abilityClicked 两处 switch 共用的存档与分类逻辑：按 target 存对应技能/奖励加点，
## 刷新提示文本（iconRovered(null, target)），返回所属类别（C_WARRIORS 等），非加点按钮返回 ""。
func _save_ability_or_bonus_click(target: FlashClip, downgrade: bool) -> String:
	var abil_const := _abil_pad_const(target)
	if abil_const >= 0:
		StoredData.save_data(
			StoredData.COM_SAVE_ABIL_DOWNGRADE if downgrade else StoredData.COM_SAVE_ABIL,
			{"abilNumber": abil_const})
		icon_rovered(null, target)
		return _category_of(target)
	var bonus_idx := _bonus_index(target)
	if bonus_idx >= 0:
		StoredData.save_data(
			StoredData.COM_SAVE_BONUS_DOWNGRADE if downgrade else StoredData.COM_SAVE_BONUS,
			{"abilNumber": bonus_idx})
		icon_rovered(null, target)
		return _category_of(target)
	return ""


## 原版 removeAdhievement（原版拼写，保留）。
func remove_adhievement(c: FlashClip) -> void:
	RWTween.to(c, 0.3, {"alpha": 0, "delay": 3})


func lock_ability(c: FlashClip) -> void:
	var lock := c.child_clip("eLock")
	if lock != null:
		lock.goto_and_stop(1)
	RWTween.to(c, 0.1, {"colorMatrixFilter": {"amount": 1, "contrast": 0.5, "brightness": 0.5, "saturation": 0}})
	ButtonClass.add_button_lite(c, ability_clicked)


func lock_unit(c: FlashClip) -> void:
	var lock := c.child_clip("eLock")
	if lock != null:
		lock.goto_and_stop(1)
	RWTween.to(c, 0.1, {"colorMatrixFilter": {"amount": 1, "contrast": 0.5, "brightness": 0.5, "saturation": 0}})
	ButtonClass.add_button_lite(c, locked_unit_clicked)


func locked_unit_clicked(_e: Variant = null) -> void:
	IfaceUtil.play_sound(SoundLibrary.BTN_DENY, 0, 0.35)
	t_hint_text.text = "This soldier is not avaliable right now"


## 第三级兵种的解锁提示条（eUnitUnlockedBar.eIco 帧号 1..5，顺序照原版 switch）。
func locked_unit_unlocked(c: FlashClip) -> void:
	var e_ico := e_unit_unlocked_bar.child_clip("eIco")
	match c:
		u_war_knight_unit:
			StoredData.save_data(StoredData.COM_SAVE_UNIT, {"unitNumber": StoredData.U_KNIGHT})
			if e_ico != null: e_ico.goto_and_stop(1)
		u_arch_crossb_unit:
			StoredData.save_data(StoredData.COM_SAVE_UNIT, {"unitNumber": StoredData.U_CROSSBOW})
			if e_ico != null: e_ico.goto_and_stop(2)
		u_priest_blesser_unit:
			StoredData.save_data(StoredData.COM_SAVE_UNIT, {"unitNumber": StoredData.U_BLESS})
			if e_ico != null: e_ico.goto_and_stop(5)
		u_thief_sabot_unit:
			StoredData.save_data(StoredData.COM_SAVE_UNIT, {"unitNumber": StoredData.U_SABOT})
			if e_ico != null: e_ico.goto_and_stop(4)
		u_mage_black_unit:
			StoredData.save_data(StoredData.COM_SAVE_UNIT, {"unitNumber": StoredData.U_BLACK})
			if e_ico != null: e_ico.goto_and_stop(3)
		_:
			return
	unlock_unit(c)
	RWTween.to(c, 0.1, {"colorMatrixFilter": {"amount": 1, "contrast": 0.5, "brightness": 0.5, "saturation": 0}})
	element_to_blink = c
	RWTween.delayed_call(1.2, show_blink)


func show_blink() -> void:
	RWTween.from_to(element_to_blink, 1,
		{"colorMatrixFilter": {"contrast": 0.5, "saturation": 0, "brightness": 4}},
		{"colorMatrixFilter": {"contrast": 1, "saturation": 1, "brightness": 1}})
	e_unit_unlocked_bar.visible = true
	e_unit_unlocked_bar.modulate.a = 0.0
	RWTween.to(e_unit_unlocked_bar, 0.3, {"alpha": 1, "onComplete": delay_unlocked_unit_remover})


func delay_unlocked_unit_remover() -> void:
	RWTween.delayed_call(2.5, unit_locked_panel_remover)


func unit_locked_panel_remover() -> void:
	RWTween.to(e_unit_unlocked_bar, 0.3, {"autoAlpha": 0})


func not_enough_stars() -> void:
	IfaceUtil.play_sound(SoundLibrary.BTN_DENY, 0, 0.4)
	t_hint_text.text = "Can't upgrage ability. You need more stars. Get more by passing new levels, replaying levels with less than three stars, or gaining achievements."


func ability_disabled() -> void:
	IfaceUtil.play_sound(SoundLibrary.BTN_DENY, 0, 0.4)
	t_hint_text.text = "Can't downgrade the ability. It is already disabled."


func ability_maxed() -> void:
	IfaceUtil.play_sound(SoundLibrary.BTN_DENY, 0, 0.4)
	t_hint_text.text = "Can't upgrade the ability. It is already at maximum."


func unlock_unit(c: FlashClip) -> void:
	var lock := c.child_clip("eLock")
	if lock != null:
		lock.goto_and_stop(2)
	ButtonClass.remove_button_lite(c, locked_unit_clicked)


## 原版 removed()（Event.REMOVED_FROM_STAGE）。
func _removed() -> void:
	if not _attached:
		return
	StoredData.save_shared_data()
	_attached = false
	e_unit_unlocked_bar.visible = false
	for u in [
		u_thief_assasin_unit, u_thief_sabot_unit, u_war_knight_unit, u_war_sword_unit, u_arch_crossb_unit,
		u_arch_sniper_unit, u_priest_healer_unit, u_priest_blesser_unit, u_mage_red_unit, u_mage_black_unit,
		u_warrior_icon, u_priest_icon, u_blue_mage_icon, u_archer_icon, u_thief_icon,
	]:
		icon_rover_rout_remove(u)
	for btn: FlashClip in a_all_locked_buttons:
		ButtonClass.remove_button_lite(btn, ability_clicked)
		ButtonClass.remove_button_lite(btn, locked_unit_clicked)
	ButtonClass.remove_button_on_frames(b_next, button_clicked)
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_on_frames(b_menu, button_clicked)
	ButtonClass.remove_button_on_frames(b_reset, button_clicked)
	ButtonClass.remove_button_on_frames(b_help, button_clicked)
	ButtonClass.remove_button_lite(e_hint, button_clicked)
	for pair in a_hint_coords:
		ButtonClass.remove_button_lite(pair[0], _hint_element_clicked)
	var e_bg2 := e_hint.get_node_or_null("eBg") as FlashClip
	if e_bg2 != null:
		ButtonClass.remove_button_lite(e_bg2, _hint_element_clicked)


## 原版 initOnce()：Rasterizer.rasterize（纯渲染优化，不移植）+ 五个幕布 getChildAt(0).mask = msk。
func init_once() -> void:
	for z: FlashClip in [zanaves_warriors, zanaves_thieves, zanaves_priests, zanaves_mages, zanaves_archers]:
		var zc := zanaves_child(z)
		var msk := z.get_node_or_null("msk") as Control
		if zc != null and msk != null:
			FlashClip.set_mask(zc, msk)


## 原版 zanavesX.getChildAt(0)：导出节点 e0（接遮罩前挂在幕布下，接遮罩后挂在 msk 下）。
static func zanaves_child(z: FlashClip) -> FlashClip:
	var n := z.get_node_or_null("msk/e0")
	if n == null:
		n = z.get_node_or_null("e0")
	return n as FlashClip


# ================================================================ 内部辅助（原版没有对应符号，供本文件复用）

## 原版 iconRovered switch 里技能加点按钮的分支：按钮 -> StoredData.A_* 常量；非技能按钮返回 -1。
func _abil_pad_const(c: FlashClip) -> int:
	match c:
		u_thief_assasin_a: return StoredData.A_BACKSTAB
		u_thief_assasin_b: return StoredData.A_MISS_ASSASIN
		u_thief_thief_a: return StoredData.A_COLLECTMONEY
		u_thief_thief_b: return StoredData.A_POISON_THIEF
		u_thief_sabot_a: return StoredData.A_HIDE
		u_thief_sabot_b: return StoredData.A_BREAKARROW
		u_war_warrior_a: return StoredData.A_BLOCK
		u_war_warrior_b: return StoredData.A_STUN
		u_war_sword_a: return StoredData.A_ROUNDATTACK
		u_war_sword_b: return StoredData.A_PARRY
		u_war_knight_a: return StoredData.A_TAUNT
		u_war_knight_b: return StoredData.A_MASSSTUN
		u_arch_archer_a: return StoredData.A_SLOW
		u_arch_archer_b: return StoredData.A_SUPPRESS
		u_arch_crossb_a: return StoredData.A_CRITRANGED
		u_arch_crossb_b: return StoredData.A_CORRUPT
		u_arch_sniper_a: return StoredData.A_HEADSHOT
		u_arch_sniper_b: return StoredData.A_WEAKSPOT
		u_mage_blue_a: return StoredData.A_ICE
		u_mage_blue_b: return StoredData.A_FLASH
		u_mage_red_a: return StoredData.A_FIREHITSPLASH
		u_mage_red_b: return StoredData.A_METHEOR
		u_mage_black_a: return StoredData.A_BETRAY
		u_mage_black_b: return StoredData.A_CURSE_BLACK
		u_priest_priest_a: return StoredData.A_STRONGHEAL
		u_priest_priest_b: return StoredData.A_ENCHANT
		u_priest_healer_a: return StoredData.A_MASSHEAL
		u_priest_healer_b: return StoredData.A_RESURRECT
		u_priest_blesser_a: return StoredData.A_CURSEBLESS
		u_priest_blesser_b: return StoredData.A_HARMRESIST
	return -1


## 原版 iconRovered switch 里的奖励加点按钮（uWarriorsAttack 等 10 个）。
func _bonus_pads() -> Dictionary:
	return {
		u_warriors_attack: 1, u_warriors_defend: 1, u_archers_attack: 1, u_archers_defend: 1,
		u_mages_attack: 1, u_mages_defend: 1, u_rogues_attack: 1, u_roguess_defend: 1,
		u_priests_attack: 1, u_priests_defend: 1,
	}


## storedData.NUMPAN_UNIT_BONUSES 的下标（原版 abilityClicked 里 switch 的 0..9，与奖励加点面板顺序一致）。
func _bonus_index(c: FlashClip) -> int:
	match c:
		u_warriors_attack: return 0
		u_warriors_defend: return 1
		u_archers_attack: return 2
		u_archers_defend: return 3
		u_mages_attack: return 4
		u_mages_defend: return 5
		u_rogues_attack: return 6
		u_roguess_defend: return 7
		u_priests_attack: return 8
		u_priests_defend: return 9
	return -1


## 原版 abilityClicked 里按钮所属类别（用于判满级成就检查时的 switch(_loc2_) 分支）。
func _category_of(c: FlashClip) -> String:
	match c:
		u_war_sword_a, u_war_sword_b, u_war_warrior_a, u_war_warrior_b, u_war_knight_a, u_war_knight_b, \
		u_warriors_attack, u_warriors_defend:
			return C_WARRIORS
		u_arch_archer_a, u_arch_archer_b, u_arch_sniper_a, u_arch_sniper_b, u_arch_crossb_a, u_arch_crossb_b, \
		u_archers_attack, u_archers_defend:
			return C_ARCHERS
		u_mage_black_a, u_mage_black_b, u_mage_blue_a, u_mage_blue_b, u_mage_red_a, u_mage_red_b, \
		u_mages_attack, u_mages_defend:
			return C_MAGES
		u_thief_assasin_a, u_thief_assasin_b, u_thief_sabot_a, u_thief_sabot_b, u_thief_thief_a, u_thief_thief_b, \
		u_rogues_attack, u_roguess_defend:
			return C_THIEVES
		u_priest_blesser_a, u_priest_blesser_b, u_priest_healer_a, u_priest_healer_b, u_priest_priest_a, \
		u_priest_priest_b, u_priests_attack, u_priests_defend:
			return C_PRIESTS
	return ""


## 原版 abilityClicked 结尾满级检查用的 aLoc6 数组（按类别的 8 个加点按钮，顺序照原版）。
func _category_pads(category: String) -> Array:
	match category:
		C_WARRIORS:
			return [u_war_sword_a, u_war_sword_b, u_war_knight_a, u_war_knight_b, u_war_warrior_a, u_war_warrior_b, u_warriors_attack, u_warriors_defend]
		C_ARCHERS:
			return [u_arch_archer_a, u_arch_archer_b, u_arch_crossb_a, u_arch_crossb_b, u_arch_sniper_a, u_arch_sniper_b, u_archers_attack, u_archers_defend]
		C_MAGES:
			return [u_mage_black_a, u_mage_black_b, u_mage_blue_a, u_mage_blue_b, u_mage_red_a, u_mage_red_b, u_mages_attack, u_mages_defend]
		C_THIEVES:
			return [u_thief_assasin_a, u_thief_assasin_b, u_thief_sabot_a, u_thief_sabot_b, u_thief_thief_a, u_thief_thief_b, u_rogues_attack, u_roguess_defend]
		C_PRIESTS:
			return [u_priest_blesser_a, u_priest_blesser_b, u_priest_healer_a, u_priest_healer_b, u_priest_priest_a, u_priest_priest_b, u_priests_attack, u_priests_defend]
	return []


## 奖励加点按钮的提示文本：三个同系兵种（基础/二级/三级）当前的加成数值。数值来自 BonusCalculator，
## 与原版 bonusCalculator.calculateBonus 调用一一对应（含调用顺序，便于以后核对）。
func _bonus_html(c: FlashClip) -> String:
	var dmg := func(kind: int) -> Dictionary: return BonusCalculator.calculate_bonus(kind)
	match c:
		u_warriors_attack:
			var a: Dictionary = dmg.call(LivingObject.FR_WARRIOR)
			var b: Dictionary = dmg.call(LivingObject.FR_SWORDMASTER)
			var cc: Dictionary = dmg.call(LivingObject.FR_KNIGHT)
			return ("<p><font size='18' color='#F6F581'>Attack upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Swordsman: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(a.bonus_damage), SpecFmt.n(a.bonus_armor_pierce)]
				+ "<p>Swordmaster: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(b.bonus_damage), SpecFmt.n(b.bonus_armor_pierce)]
				+ "<p>Knight: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(cc.bonus_damage), SpecFmt.n(cc.bonus_armor_pierce)])
		u_warriors_defend:
			var a: Dictionary = dmg.call(LivingObject.FR_WARRIOR)
			var b: Dictionary = dmg.call(LivingObject.FR_SWORDMASTER)
			var cc: Dictionary = dmg.call(LivingObject.FR_KNIGHT)
			return ("<p><font size='18' color='#F6F581'>Defence upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Swordsman: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Armor</p>" % [SpecFmt.n(a.bonus_hp), SpecFmt.n(a.bonus_armor)]
				+ "<p>Swordmaster: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Armor</p>" % [SpecFmt.n(b.bonus_hp), SpecFmt.n(b.bonus_armor)]
				+ "<p>Knight: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Armor</p>" % [SpecFmt.n(cc.bonus_hp), SpecFmt.n(cc.bonus_armor)])
		u_archers_attack:
			var a: Dictionary = dmg.call(LivingObject.FR_ARCHER)
			var b: Dictionary = dmg.call(LivingObject.FR_SNIPER)
			var cc: Dictionary = dmg.call(LivingObject.FR_CROSSBOW)
			return ("<p><font size='18' color='#F6F581'>Attack upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Archer: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(a.bonus_damage), SpecFmt.n(a.bonus_armor_pierce)]
				+ "<p>Sniper: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(b.bonus_damage), SpecFmt.n(b.bonus_armor_pierce)]
				+ "<p>Crossbowman: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(cc.bonus_damage), SpecFmt.n(cc.bonus_armor_pierce)])
		u_archers_defend:
			var a: Dictionary = dmg.call(LivingObject.FR_ARCHER)
			var cc: Dictionary = dmg.call(LivingObject.FR_CROSSBOW)
			var b: Dictionary = dmg.call(LivingObject.FR_SNIPER)
			return ("<p><font size='18' color='#F6F581'>Defence upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Archer: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(a.bonus_hp), SpecFmt.n(a.bonus_move_speed)]
				+ "<p>Crossbowman: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Armor</p>" % [SpecFmt.n(cc.bonus_hp), SpecFmt.n(cc.bonus_armor)]
				+ "<p>Sniper: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(b.bonus_hp), SpecFmt.n(b.bonus_move_speed)])
		u_mages_attack:
			var a: Dictionary = dmg.call(LivingObject.FR_BLUEMAGE)
			var b: Dictionary = dmg.call(LivingObject.FR_REDMAGE)
			var cc: Dictionary = dmg.call(LivingObject.FR_BLACKMAGE)
			return ("<p><font size='18' color='#F6F581'>Attack upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Blue mage: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> MP</p>" % [SpecFmt.n(a.bonus_damage), SpecFmt.n(a.bonus_magic_pierce)]
				+ "<p>Red mage: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> MP</p>" % [SpecFmt.n(b.bonus_damage), SpecFmt.n(b.bonus_magic_pierce)]
				+ "<p>Black mage: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> MP</p>" % [SpecFmt.n(cc.bonus_damage), SpecFmt.n(cc.bonus_magic_pierce)])
		u_mages_defend:
			var a: Dictionary = dmg.call(LivingObject.FR_BLUEMAGE)
			var b: Dictionary = dmg.call(LivingObject.FR_REDMAGE)
			var cc: Dictionary = dmg.call(LivingObject.FR_BLACKMAGE)
			return ("<p><font size='18' color='#F6F581'>Defence upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Blue mage: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Resist</p>" % [SpecFmt.n(a.bonus_hp), SpecFmt.n(a.bonus_resist)]
				+ "<p>Red mage: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Resist</p>" % [SpecFmt.n(b.bonus_hp), SpecFmt.n(b.bonus_resist)]
				+ "<p>Black mage: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Resist</p>" % [SpecFmt.n(cc.bonus_hp), SpecFmt.n(cc.bonus_resist)])
		u_rogues_attack:
			var a: Dictionary = dmg.call(LivingObject.FR_ROGUE)
			var b: Dictionary = dmg.call(LivingObject.FR_ASSASIN)
			var cc: Dictionary = dmg.call(LivingObject.FR_SABOTEUR)
			return ("<p><font size='18' color='#F6F581'>Attack upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Rogue: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(a.bonus_damage), SpecFmt.n(a.bonus_armor_pierce)]
				+ "<p>Assassin: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(b.bonus_damage), SpecFmt.n(b.bonus_armor_pierce)]
				+ "<p>Spy: <font color='#F6F581'>+%s</font> Dmg, <font color='#F6F581'>+%s</font> AP</p>" % [SpecFmt.n(cc.bonus_damage), SpecFmt.n(cc.bonus_armor_pierce)])
		u_roguess_defend:
			var a: Dictionary = dmg.call(LivingObject.FR_ROGUE)
			var b: Dictionary = dmg.call(LivingObject.FR_ASSASIN)
			var cc: Dictionary = dmg.call(LivingObject.FR_SABOTEUR)
			return ("<p><font size='18' color='#F6F581'>Defence upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Rogue: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(a.bonus_hp), SpecFmt.n(a.bonus_move_speed)]
				+ "<p>Assassin: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(b.bonus_hp), SpecFmt.n(b.bonus_move_speed)]
				+ "<p>Spy: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(cc.bonus_hp), SpecFmt.n(cc.bonus_move_speed)])
		u_priests_attack:
			var a: Dictionary = dmg.call(LivingObject.FR_PRIEST)
			var b: Dictionary = dmg.call(LivingObject.FR_HEALER)
			var cc: Dictionary = dmg.call(LivingObject.FR_BLESSER)
			return ("<p><font size='18' color='#F6F581'>Healing upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Priest: <font color='#F6F581'>+%s</font> Heal, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(a.bonus_damage), SpecFmt.n(a.bonus_move_speed)]
				+ "<p>Cleric: <font color='#F6F581'>+%s</font> Heal, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(b.bonus_damage), SpecFmt.n(b.bonus_move_speed)]
				+ "<p>Monk: <font color='#F6F581'>+%s</font> Heal, <font color='#F6F581'>+%s</font> Speed</p>" % [SpecFmt.n(cc.bonus_damage), SpecFmt.n(cc.bonus_move_speed)])
		u_priests_defend:
			var a: Dictionary = dmg.call(LivingObject.FR_PRIEST)
			var b: Dictionary = dmg.call(LivingObject.FR_HEALER)
			var cc: Dictionary = dmg.call(LivingObject.FR_BLESSER)
			return ("<p><font size='18' color='#F6F581'>Defence upgrade</font></p><font size='4'><br></font><p>Current level:</p>"
				+ "<p>Priest: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Resist</p>" % [SpecFmt.n(a.bonus_hp), SpecFmt.n(a.bonus_resist)]
				+ "<p>Cleric: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Resist</p>" % [SpecFmt.n(b.bonus_hp), SpecFmt.n(b.bonus_resist)]
				+ "<p>Monk: <font color='#F6F581'>+%s</font> HP, <font color='#F6F581'>+%s</font> Resist</p>" % [SpecFmt.n(cc.bonus_hp), SpecFmt.n(cc.bonus_resist)])
	return ""


## 原版 iconRovered switch 里的兵种图标说明文本（固定文案，不随存档变化）。
func _unit_icon_html(c: FlashClip) -> String:
	match c:
		u_warrior_icon:
			return "<p><font size='18' color='#F6F581'>Swordsman</font></p><font size='4'><br></font><p>Backbone of any army, regular soldier, equipped with sword and shield</p>"
		u_war_sword_unit:
			return "<p><font size='18' color='#F6F581'>Swordmaster</font></p><font size='4'><br></font><p>Equipped with two swords, these soldiers deal a great amount of damage in close combat, but they wear only light armor and are vulnerable to archers.</p>"
		u_war_knight_unit:
			return "<p><font size='18' color='#F6F581'>Knight</font></p><font size='4'><br></font><p>Slow, heavily armored unit. Can handle huge amounts of damage, stun all enemies in range, and taunt them to attack.</p>"
		u_arch_crossb_unit:
			return "<p><font size='18' color='#F6F581'>Crossbowman</font></p><font size='4'><br></font><p>This ranged unit turns armor like a paper, and can defend himself in close combat.</p>"
		u_archer_icon:
			return "<p><font size='18' color='#F6F581'>Archer</font></p><font size='4'><br></font><p>Regular ranged warrior, shoots fast, but precision and shot power are not his strength.</p>"
		u_arch_sniper_unit:
			return "<p><font size='18' color='#F6F581'>Sniper</font></p><font size='4'><br></font><p>Elite marksman, shoots fast, hits hard, and can even kill a unit with one arrow</p>"
		u_mage_red_unit:
			return "<p><font size='18' color='#F6F581'>Red Mage</font></p><font size='4'><br></font><p>This mage has studied the most destructive spells and can call a meteor, or hit groups of enemies with his powerful splash attack</p>"
		u_mage_black_unit:
			return "<p><font size='18' color='#F6F581'>Black Mage</font></p><font size='4'><br></font><p>Dark magic adept, this mage can weaken enemies and even take control over someone's mind</p>"
		u_blue_mage_icon:
			return "<p><font size='18' color='#F6F581'>Blue Mage</font></p><font size='4'><br></font><p>Blue mage's attacks are weak, but he can use extremely useful spells, such as Freeze and Lightning strike</p>"
		u_thief_icon:
			return "<p><font size='18' color='#F6F581'>Rogue</font></p><font size='4'><br></font><p>Regular rogue. Evades backstabs, can poison enemies and steal their money.</p>"
		u_thief_sabot_unit:
			return "<p><font size='18' color='#F6F581'>Spy</font></p><font size='4'><br></font><p>Spies have unique abilities to hide themselves in the shadows and sabotage enemy archers and casters</p>"
		u_thief_assasin_unit:
			return "<p><font size='18' color='#F6F581'>Assassin</font></p><font size='4'><br></font><p>Hits fast and painfully. Assassin can kill with a single hit and easily evade both arrows and swords</p>"
		u_priest_icon:
			return "<p><font size='18' color='#F6F581'>Priest</font></p><font size='4'><br></font><p>Regular priest, heals wounds and blesses his friends. Can't stand in close combat.</p>"
		u_priest_healer_unit:
			return "<p><font size='18' color='#F6F581'>Cleric</font></p><font size='4'><br></font><p>Slow and weak, but has great healing abilities and an ultimate ability to resurrect fallen friends.</p>"
		u_priest_blesser_unit:
			return "<p><font size='18' color='#F6F581'>Monk</font></p><font size='4'><br></font><p>Monks are not as good at healing as Clerics, but can protect allies from any damage and bless them</p>"
	return ""
