# 移植自 S/gameCore/living/livingObject.as
#
# 命名约定见 docs/port-plan.md 第 2 节。本文件中与 GDScript/Node 冲突而必须偏离原名的只有：
#   free(Event)        -> free_(_e)         （Object.free 冲突）
#   getName            -> get_name_         （Node.get_name 冲突）
#   setVisible()       -> set_visible_()    （CanvasItem.set_visible 冲突）
#   className          -> class_name_       （GDScript 关键字）
#   BMPStay/Walk/...   -> bmp_stay/bmp_walk/bmp_attack/bmp_dead/bmp_ranged/bmp_casting；currentBM -> current_bm
#   sensClass(Class)   -> sens_class（String，symbols.json 中 *Sens 符号名，如 "warriorSens"）
#   oPursueCounter     -> o_pursue_counter，键为 pursue_key(unit)（见该函数注释）
#
# 显示：sprite 是 Sprite2D（原版 sprite_bm 位图与其容器合一；原版 sprite.alpha -> sprite.modulate.a，
# sprite_bm.alpha -> sprite.self_modulate.a，朝向 sprite.scale.x = ±1）。逻辑只由 GameUniverse 调用 update()，
# 本类没有 _process/_physics_process。
class_name LivingObject
extends DisObject

static var mass_center: Vector2 = Vector2.ZERO
static var v_untouchable_units: Array = []  # Vector.<livingObject>
static var v_untouchable_time_mark: Array = []  # Vector.<Number>
static var a_friend_warriors: Array = []  # Vector.<livingObject>
static var a_friend_ranged: Array = []  # Vector.<livingObject>

const NONE := -1
const BUTTON_WARRIORS := -10
const BUTTON_MAGES := -11
const BUTTON_ARCHERS := -12
const BUTTON_PRIESTS := -13
const BUTTON_THIEVES := -14
const FR_WARRIOR := 1
const FR_SWORDMASTER := 7
const FR_KNIGHT := 13
const FR_ARCHER := 2
const FR_CROSSBOW := 14
const FR_SNIPER := 12
const FR_BLUEMAGE := 5
const FR_REDMAGE := 8
const FR_BLACKMAGE := 9
const FR_PRIEST := 4
const FR_WISEMAN := 42
const NPC_OLDMAN := 43
const NPC_MAN := 44
const NPC_WOMAN := 45
const FR_HEALER := 10
const FR_BLESSER := 11
const FR_ROGUE := 18
const FR_ASSASIN := 19
const FR_SABOTEUR := 20
const FR_KING := 41
const CLASS_WARRIOR := 100
const CLASS_ARCHER := 200
const CLASS_MAGE := 300
const CLASS_PRIEST := 400
const CLASS_THIEF := 500
const UNDEAD_ZOMBIE := 6
const UNDEAD_SKELETON := 16
const UNDEAD_SKELETON_ARM := 15
const UNDEAD_SKELETON_CAPITAN := 17
const UNDEAD_SKELETON_ARCHER := 3
const UNDEAD_DARTH_KNIGHT := 0
const UNDEAD_GRAY_ZOMBIE := 21
const MONSTER_OGRE := 22
const UNDEAD_WITCH := 23
const UNDEAD_VAMPIRE := 24
const MONSTER_KAMIKAZE := 25
const UNDEAD_SHAMAN := 26
const UNDEAD_STORMGUARDIAN := 27
const UNDEAD_STORMTROOPER := 28
const UNDEAD_STORMARCHER := 29
const UNDEAD_SEEKER := 30
const MONSTER_HOUND := 32
const MONSTER_GREEN_HOUND := 31
const UNDEAD_PLAGUE_ZOMBIE := 33
const UNDEAD_RANGER := 34
const MONSTER_TROLL := 35
const UNDEAD_VAMPIRE_LORD := 36
const UNDEAD_VAMPIRE_KING := 37
const UNDEAD_SUMMONER := 38
const UNDEAD_GHOST := 39
const MONSTER_KAMI_SHIELD := 40
const STAND := 1
const WALKING := 2
const FIGHTING := 3
const ROOTED := 4
const DEAD := 5
const RANGED_SHOOT := 6
const CASTING := 7
const ARM_NONE := 1.0
const ARM_LIGHT := 0.9
const ARM_MEDIUM := 0.7
const ARM_HEAVY := 0.5
const ARM_SUPER := 0.3
const GLOBAL_SEARCH_COUNTER := 10
const C_DEATH_TIME_AVALIABLE := 300
const PLAYING := 0
const STOPPED := 1
const MAX_PURSUIT_DISTANCE := 150
const MAX_DISTANCE_BEFORE_MAKING_BATTLE := 40

static var unit_num_warriors: int = 0
static var unit_num_mages: int = 0
static var unit_num_archers: int = 0
static var unit_num_priests: int = 0
static var unit_num_rogues: int = 0

const A_WARRIOR_COOLDOWN_TAB := [8, 8, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33]
const A_MAGE_COOLDOWN_TAB := [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40]
const A_PRIEST_COOLDOWN_TAB := [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40]
# 原版疑点，原样保留：下标 16 的 2223（疑为 22、23 少一个逗号）
const A_ARCHER_COOLDOWN_TAB := [8, 8, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 2223, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33]
const A_ROGUE_COOLDOWN_TAB := [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33]

const BP_SLOW := "bpSlow"
const BP_CONFUSE := "bpConfuse"
const BP_SUPPRESS := "bpSuppress"
const BP_ENCHANT := "bpEnchant"
const BP_CORRUPT := "bpCorrupt"
const BP_WEAK := "bpWeak"
const BP_POSSESS := "bpPossess"
const BP_WEAKSPOT := "bpWeakspot"
const BP_POISONED := "bpPoisoned"
const BP_CURSE := "bpCurse"
const BP_BLESS := "bpBless"
const BP_ICED := "bpIced"
const BP_STUNNED := "bpStunned"
const BP_HARMRES := "bpHarmres"
const MAX_TIME_PURSUE := 280
const MAX_DIST_FROM_MASS_CENTER := 160

# Main.gameWidth / Main.gameHeight（checkObstacles 的屏幕矩形）
const GAME_WIDTH := 700
const GAME_HEIGHT := 600

static var direction: int = 1

var unit_description: String = ""
var can_be_selected: bool = false  # private
var last_click_time: int = 0  # private
var can_upgrade_is_shown: bool = false  # private
var selected: bool = false
var ring: RingSelectorEx = null
var a_soldier_main_route: Array = []
var last_external_point: Variant = null  # Point
var search_counter: int = 0
var search_radius: float = 0.0  # 原版 NaN，addToGame 中赋值
var _instance: LivingObject = null
var cur_battle: Battle = null
var attack_counter: int = 0
var sens: Sprite2D = null
## sens.height（MovieClip 高度 = 包围盒高，来自 data/bounds.json）。sens.y 初始为 -sens_height / 2。
var sens_height: float = 0.0
var sens_width: float = 0.0
## 原版 sens.mouseEnabled（setStance(DEAD) 置 false，addToGame/reanimateDead 置 true）
var sens_mouse_enabled: bool = true
var death_time: int = 0
var ui_health_bar: HealthBarEx = null
var battle_point: Vector2 = Vector2.ZERO  # 原版 null，由 Battle 设置
var _zero_point: Variant = null  # Point
var friendly: bool = false
var _x: float = 0.0
var _y: float = 0.0
var dest_point: Variant = null  # Point
var is_rogue: bool = false
var _health: int = 0
var _cur_health: int = 0
var _walk_speed: float = 0.0
var _max_walk_speed: float = 0.0
var kind: int = 0
var cur_stanse: int = 0
var cur_target: LivingObject = null
var attack_interval: int = 0
var ranged_attack_interval: int = 0
var _cur_damage: int = 0
var _damage: int = 0
var basic_unit: bool = false
var shoot_accuracy: float = 0.0
var _shoot_accuracy_max: float = 0.0
var is_defence_stance: bool = false
var _cur_ranged_damage: int = 0
var _ranged_damage: int = 0
var _cur_armor: float = 0.0
var _max_armor: float = 0.0
var _cur_magic_resist: float = 0.0
var _max_magic_resist: float = 0.0
var attacking_with_ranged_weapon: bool = false
var is_archer: bool = false
var is_npc: bool = false
var is_mage: bool = false
var is_priest: bool = false
var _armor_piercing_melee: float = 0.0
var _armor_piercing_ranged: float = 0.0
var _magic_piercing: float = 0.0
var unit_name: String = ""
var class_name_: String = ""
var _special_one: SpecialTemplate = null
var _special_two: SpecialTemplate = null
var _special_zero: SpecialTemplate = null
var cur_level: int = 0
var cur_experience: int = 0
var exp_to_next_level: int = 0
var a_exp_levels: Array = [20, 40, 60]
var a_health_levels: Array = [20, 40, 60]
var a_armor_levels: Array = [0, 0, 0]
var a_resist_levels: Array = [0, 0, 0]
var a_armor_piercing_melee_levels: Array = [0, 0, 0]
var a_armor_piercing_ranged_levels: Array = [0, 0, 0]
var a_magic_piercing_levels: Array = [0, 0, 0]
var a_attack_interval_levels: Array = [50, 40, 30]
var a_ranged_attack_interval_levels: Array = [60, 50, 40]
var a_ranged_shoot_accuracy: Array = [0.6, 0.8, 0.9]
var a_melee_damage_levels: Array = [5, 7, 9]
var a_ranged_damage_levels: Array = [8, 10, 12]
var a_walk_speed_levels: Array = [2, 2, 1.5]
var _money_cost: int = 0
var _upgr_cost: int = 0
## 原版 sprite（容器）与 sprite_bm（位图）在此合并为一个 Sprite2D，节点名 "sprite"
var sprite: Sprite2D = null
var sprite_bm: Sprite2D = null  # 与 sprite 同一节点
var current_bm: BmpFrames = null
var play_head_stance: int = 0
var play_flag: bool = false
var cur_frame: int = 0
var is_stunned: bool = false
var stun_counter: int = 0
var scounter: int = 0
var _is_slowed: bool = false
var slow_counter: int = 0
var _is_poisoned: bool = false
var poison_timer: int = 0
var poison_strength: int = 0
var is_cursed: bool = false
var curse_counter: int = 0
var max_attack_interval: int = 0
var max_ranged_attack_interval: int = 0
var max_damage: int = 0
var curse_modifier: float = 1.0
var max_ranged_damage: int = 0
var bless_modifier: float = 0.0
var bless_counter: int = 0
var is_blessed: bool = false
var is_trapped_in_ice: bool = false
var freeze_counter: int = 0
var cur_ice_damage: int = 0
var ice_effect: Variant = null  # iceVisual（未使用）
var in_action: bool = true
var _is_suppressed: bool = false
var suppress_counter: int = 0
var suppress_ratio: float = 0.0
var _is_corrupted: bool = false
var _is_weakened: bool = false
var weaken_counter: int = 0
var corrupt_counter: int = 0
var corrupt_ratio: float = 0.0
var max_harm_resist_time: int = 0
var _is_harm_resisted: bool = false
var next_stance: int = 0
var attack_stance_release_counter: int = 0
var num_killed: int = 0
var bmp_stay: BmpFrames = null
var bmp_walk: BmpFrames = null
var bmp_attack: BmpFrames = null
var bmp_dead: BmpFrames = null
var bmp_ranged: BmpFrames = null
var bmp_casting: BmpFrames = null
var stand_still: bool = false
# 二次开发（二章）：为 true 的单位不能被玩家选中（盟军、设施）；默认 false，一代不受影响
var ch2_uncontrollable: bool = false
var sens_class: String = ""
var can_remove_from_units_array: bool = false
var temp_dist_to_attacker: float = 0.0
var _in_hide: bool = false
var _is_broken_arrows: bool = false
var broken_arrows_counter: int = 0
var _is_silenced: bool = false  # isConfused 的存储字段
var confused_counter: int = 0
var direction_angle: float = 0.0
var rotation_counter: int = 0
var a_obstacle_route: Array = []
var cur_time_to_possess: int = 0
var is_possessed: bool = false
var old_route: Array = []
var cur_route_number: int = 0
var _cur_weak_mod: float = 0.0
var time_to_weak_spot: int = 0
var enchant_timer: int = 0
var enchant_ratio: float = 0.0
var max_armor_piercing_melee: float = 0.0
var max_armor_piercing_ranged: float = 0.0
var o_bp: Dictionary = {}  # 名称 -> Callable
var a_buffs_and_penalties: Array = []  # Vector.<String>
var s: SoundLibrary = null
var real_friendly: bool = false
var g: GlobalData = null
var archer_goto_target: bool = false
const BP_BREAKARROWS := "bpBreakArrows"
var money_upgrade: int = 0
var will_be_soon_possessed: bool = false
var has_weak_spot: bool = false
var sprioritized_healing_target: LivingObject = null
var is_kamikaze: bool = false
var is_enchanted: bool = false
var _cur_group: float = 0.0
var is_archer_shooting_its_target_while_is_needed_to_move: bool = false
var last_backstab: int = 0
## 原版是 Object，键为 curTarget 的字符串化（"[object friendWarrior]"），见 pursue_key
var o_pursue_counter: Dictionary = {}
var ext_unlock: bool = false
var class_kind: int = -1
var remove_after_move: bool = false
var search_radius_ranged_modifier: float = 0.0
var ranged_circle: Sprite2D = null

static var _sens_alpha_cache: Dictionary = {}  # symbol id -> {"image": Image|null, "has_alpha": bool}

## 原版 oPursueCounter 是 Object，`oPursueCounter[unit]` 把 unit 转成字符串作键，
## 即 "[object <类名>]"，同一兵种的所有单位共用一个计数（原版行为，保留）。
## GameUniverse.makeBattle、meleeFighter 等也必须通过本函数取键。
static func pursue_key(unit: Object) -> String:
	var scr: Script = unit.get_script()
	return "[object %s]" % scr.get_global_name()

## Number -> int 参数（getPixel(x:int, y:int)）：向零截断，NaN/Infinity 得 0。
static func _to_int(v: float) -> int:
	if is_nan(v) or is_inf(v):
		return 0
	return int(v)

static func _content() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Content")

## GlobalData.inst 统计字段累加（字段名 snake_case）。
func _g_add(field: String, delta: int) -> void:
	g.set(field, int(g.get(field)) + delta)

# ---------------------------------------------------------------------------------------------
# 生命周期
# ---------------------------------------------------------------------------------------------

func init() -> void:
	is_kamikaze = false
	sprite = Sprite2D.new()
	sprite.name = "sprite"
	sprite.centered = false
	sprite_bm = sprite
	add_child(sprite)
	if is_archer == true:
		# rangedCircleMC：3 帧 MovieClip（1=弓箭手 2=牧师 3=法师）
		var circle_bm := BmpFrames.from_symbol("rangedCircleMC")
		ranged_circle = Sprite2D.new()
		ranged_circle.name = "rangedCircle"
		ranged_circle.centered = false
		ranged_circle.show_behind_parent = true  # 原版先于位图加入，显示在位图之后
		sprite.add_child(ranged_circle)
		ranged_circle.position.y = -7
		var circle_frame := 0
		if is_mage:
			circle_frame = 2
		elif is_priest:
			circle_frame = 1
		if circle_bm != null:
			circle_bm.apply_frame(ranged_circle, circle_frame)
		_set_circle_size(100.0, 100.0)
		ranged_circle.modulate.a = 0.4
		ranged_circle.scale.y = 0.8
		ranged_circle.visible = false
	_instance = self
	# 原版 sens = new sensClass()，sens.y = -sens.height / 2；sens 是 this 的子节点而非 sprite 的，不随朝向翻转
	sens = Sprite2D.new()
	sens.name = "sens"
	sens.centered = false
	if sens_class != "":
		var sens_bm := BmpFrames.from_symbol(sens_class)
		if sens_bm != null:
			sens_bm.apply_frame(sens, 0)
			var b: Array = _content().bounds.get(str(sens_bm.id), [0, 0, 1, 1])
			sens_width = float(b[2])
			sens_height = float(b[3])
	sens.visible = false  # 原版是透明热区，不绘制
	add_child(sens)
	sens.position.y = -sens_height / 2
	ui_health_bar = HealthBarEx.new(health)
	add_child(ui_health_bar)
	ui_health_bar.visible = true
	ui_health_bar.top.stop()
	ui_health_bar.position.x = sens.position.x
	ui_health_bar.position.y = sens.position.y - sens_height / 2 - 8
	o_bp = {}
	o_bp[BP_SLOW] = bp_slow
	o_bp[BP_BREAKARROWS] = bp_break_arrows
	o_bp[BP_CONFUSE] = bp_confuse
	o_bp[BP_SUPPRESS] = bp_suppress
	o_bp[BP_ENCHANT] = bp_enchant
	o_bp[BP_CORRUPT] = bp_corrupt
	o_bp[BP_WEAK] = bp_weak
	o_bp[BP_POSSESS] = bp_possess
	o_bp[BP_WEAKSPOT] = bp_weak_spot
	o_bp[BP_POISONED] = bp_poisoned
	o_bp[BP_CURSE] = bp_curse
	o_bp[BP_BLESS] = bp_bless
	o_bp[BP_ICED] = bp_iced
	o_bp[BP_STUNNED] = bp_stunned
	o_bp[BP_HARMRES] = bp_harm_resisted
	after_init()

## rangedCircle.width/height = value（Sprite2D 以纹理尺寸 * scale 计）
func _set_circle_size(w: float, h: float) -> void:
	if ranged_circle == null or ranged_circle.texture == null:
		return
	ranged_circle.scale.x = w / ranged_circle.texture.get_width()
	ranged_circle.scale.y = h / ranged_circle.texture.get_height()

func after_init() -> void:
	pass

func add_to_game(param1: float, param2: float, param3: int = 1, param4: bool = false, param5: bool = false) -> void:
	remove_after_move = false
	o_pursue_counter = {}
	is_archer_shooting_its_target_while_is_needed_to_move = false
	stand_still = false
	ch2_uncontrollable = false  # 池化实例复用时复位
	ext_unlock = false
	cur_group = -1
	s = SoundLibrary.inst
	g = GlobalData.inst
	a_buffs_and_penalties = []
	enchant_timer = 0
	enchant_ratio = 0
	is_enchanted = false
	has_weak_spot = false
	will_be_soon_possessed = false
	a_obstacle_route = []
	is_confused = false
	confused_counter = 0
	is_broken_arrows = false
	broken_arrows_counter = 0
	in_action = true
	stun_counter = 0
	is_stunned = false
	is_slowed = false
	slow_counter = 0
	is_poisoned = false
	is_possessed = false
	cur_time_to_possess = 0
	poison_timer = 0
	poison_strength = 0
	is_cursed = false
	curse_counter = 0
	curse_modifier = 0
	archer_goto_target = false
	is_blessed = false
	bless_counter = 0
	bless_modifier = 0
	is_suppressed = false
	suppress_counter = 0
	is_trapped_in_ice = false
	freeze_counter = 0
	cur_ice_damage = 0
	is_corrupted = false
	corrupt_counter = 0
	corrupt_ratio = 0
	is_weakened = false
	weaken_counter = 0
	max_harm_resist_time = 0
	is_harm_resisted = false
	in_hide = false
	set_alpha(1)
	attack_stance_release_counter = 0
	next_stance = -1
	var friendly_kinds: Array = [FR_WARRIOR, FR_SWORDMASTER, FR_KNIGHT, FR_KING, FR_WISEMAN, NPC_OLDMAN, NPC_MAN, NPC_WOMAN, FR_ARCHER, FR_SNIPER, FR_CROSSBOW, FR_PRIEST, FR_HEALER, FR_BLESSER, FR_BLUEMAGE, FR_BLACKMAGE, FR_REDMAGE, FR_ROGUE, FR_ASSASIN, FR_SABOTEUR]
	if friendly_kinds.find(kind) < 0:
		friendly = false
	else:
		friendly = true
	real_friendly = friendly
	if friendly:
		if ui_health_bar.get_parent() != null:
			ui_health_bar.get_parent().remove_child(ui_health_bar)
		GameUniverse.inst.healt_bar_cont.add_child(ui_health_bar)
		if is_npc:
			ui_health_bar.visible = false
		if param4 == false:
			Sounds.inst.play(s.get_sound(SoundLibrary.HIRE), false, 0, 0.4)
			if param5 == false:
				var cost: float = 0
				match kind:
					FR_WARRIOR:
						cost = floor(money_cost + MainGameUIEx.inst.cost_multiplier * unit_num_warriors * money_cost)
					FR_ARCHER:
						cost = floor(money_cost + MainGameUIEx.inst.cost_multiplier * unit_num_archers * money_cost)
					FR_PRIEST:
						cost = floor(money_cost + MainGameUIEx.inst.cost_multiplier * unit_num_priests * money_cost)
					FR_BLUEMAGE:
						cost = floor(money_cost + MainGameUIEx.inst.cost_multiplier * unit_num_mages * money_cost)
					FR_ROGUE:
						cost = floor(money_cost + MainGameUIEx.inst.cost_multiplier * unit_num_rogues * money_cost)
				if cost == 0:
					cost = money_cost
				GameUniverse.inst.set_money(-1 * cost)
			else:
				GameUniverse.inst.set_money(-1 * upgr_cost)
		ui_health_bar.top.goto_and_stop(1)
	else:
		ui_health_bar.top.goto_and_stop(2)
	ui_health_bar.friendly = friendly
	ui_health_bar.reset_level_bar()
	sprioritized_healing_target = null
	num_killed = 0
	modulate.a = 1.0
	visible = true
	sprite.modulate.a = 1.0
	sprite.visible = true
	can_be_selected = false
	last_click_time = 0
	can_upgrade_is_shown = false
	selected = false
	kill_ring()
	a_soldier_main_route = []
	last_external_point = null
	search_counter = 0
	cur_battle = null
	attack_counter = 0
	death_time = 0
	zero_point = null
	dest_point = null
	_health = 1
	_cur_health = 1
	walk_speed = 1
	_max_walk_speed = 1
	cur_stanse = 0
	cur_target = null
	attack_interval = 1
	ranged_attack_interval = 1
	cur_damage = 1
	_damage = 1
	shoot_accuracy = 1
	_shoot_accuracy_max = 1
	cur_ranged_damage = 1
	_ranged_damage = 1
	_cur_armor = 1
	_max_armor = 1
	_cur_magic_resist = 1
	_max_magic_resist = 1
	attacking_with_ranged_weapon = false
	armor_piercing_melee = 0
	armor_piercing_ranged = 0
	magic_piercing = 0
	ui_health_bar.reset_icons()
	special_one = null
	special_two = null
	special_zero = null
	cur_level = 1
	cur_experience = 0
	exp_to_next_level = 0
	current_bm = null
	play_flag = false
	cur_frame = 0
	search_radius_ranged_modifier = 3.8
	search_radius = 70
	direction_angle = 0
	rotation_counter = 0
	play_head_stance = PLAYING
	can_remove_from_units_array = false
	sens_mouse_enabled = true
	if friendly == true:
		unit_name = NamesList.a_names[RWRandom.rand_range(0, NamesList.a_names.size() - 1)]
		is_defence_stance = true
		match kind:
			NPC_OLDMAN:
				a_friend_warriors.push_back(_instance)
			NPC_MAN:
				a_friend_warriors.push_back(_instance)
			NPC_WOMAN:
				a_friend_warriors.push_back(_instance)
			FR_WISEMAN:
				a_friend_ranged.push_back(_instance)
			FR_WARRIOR:
				unit_num_warriors += 1
				a_friend_warriors.push_back(_instance)
			FR_SWORDMASTER:
				unit_num_warriors += 1
				a_friend_warriors.push_back(_instance)
			FR_KNIGHT:
				unit_num_warriors += 1
				a_friend_warriors.push_back(_instance)
			FR_KING:
				unit_num_warriors += 1
				a_friend_warriors.push_back(_instance)
			FR_BLUEMAGE:
				unit_num_mages += 1
				a_friend_ranged.push_back(_instance)
			FR_REDMAGE:
				unit_num_mages += 1
				a_friend_ranged.push_back(_instance)
			FR_BLACKMAGE:
				unit_num_mages += 1
				a_friend_ranged.push_back(_instance)
			FR_ARCHER:
				unit_num_archers += 1
				a_friend_ranged.push_back(_instance)
			FR_SNIPER:
				unit_num_archers += 1
				a_friend_ranged.push_back(_instance)
			FR_CROSSBOW:
				unit_num_archers += 1
				a_friend_ranged.push_back(_instance)
			FR_PRIEST:
				unit_num_priests += 1
				a_friend_ranged.push_back(_instance)
			FR_HEALER:
				unit_num_priests += 1
				a_friend_ranged.push_back(_instance)
			FR_BLESSER:
				unit_num_priests += 1
				a_friend_ranged.push_back(_instance)
			FR_ROGUE:
				unit_num_rogues += 1
				a_friend_warriors.push_back(_instance)
			FR_ASSASIN:
				unit_num_rogues += 1
				a_friend_warriors.push_back(_instance)
			FR_SABOTEUR:
				unit_num_rogues += 1
				a_friend_warriors.push_back(_instance)
	else:
		is_defence_stance = false
	attack_counter = 0
	a_soldier_main_route = []
	set_coordinates(param1, param2)
	set_destination(Vector2(param1, param2))
	cur_stanse = NONE
	upgrade(param3)
	after_adding_new_unit_handler()
	update()

func after_adding_new_unit_handler() -> void:
	pass

func upgrade(param1: int = -1) -> void:
	can_upgrade_is_shown = false
	if cur_level != 3:
		if param1 == -1:
			cur_level += 1
		else:
			cur_level = param1
		cur_experience = 0
		exp_to_next_level = int(a_exp_levels[cur_level - 1])
		var bonus: Dictionary = BonusCalculator.calculate_bonus(kind)
		var bonus_damage: float = bonus["bonus_damage"]
		var bonus_hp: float = bonus["bonus_hp"]
		var bonus_armor_pierce: float = bonus["bonus_armor_pierce"]
		var bonus_armor: float = bonus["bonus_armor"]
		var bonus_resist: float = bonus["bonus_resist"]
		var bonus_move_speed: float = bonus["bonus_move_speed"]
		var bonus_magic_pierce: float = bonus["bonus_magic_pierce"]
		var old_cur_health: int = cur_health
		var old_health: int = _health
		health = int(a_health_levels[cur_level - 1] + bonus_hp)
		cur_health = proportional_reset_int(cur_health, old_cur_health, old_health, _health)
		var armor_level: float = float(a_armor_levels[cur_level - 1])
		var armor_sum: float = bonus_armor + armor_level
		armor_sum = AS3.round(armor_sum * 100) / 100.0
		armor = armor_sum
		if armor > 1:
			armor = 1
		max_magic_resist = a_resist_levels[cur_level - 1] + bonus_resist
		if max_magic_resist > 1:
			max_magic_resist = 1
		magic_piercing = a_magic_piercing_levels[cur_level - 1] + bonus_magic_pierce
		if magic_piercing > 1:
			magic_piercing = 1
		armor_piercing_melee = a_armor_piercing_melee_levels[cur_level - 1] + bonus_armor_pierce
		armor_piercing_ranged = a_armor_piercing_ranged_levels[cur_level - 1] + bonus_armor_pierce
		if armor_piercing_melee > 1:
			armor_piercing_melee = 1
		if armor_piercing_ranged > 1:
			armor_piercing_ranged = 1
		max_armor_piercing_melee = armor_piercing_melee
		max_armor_piercing_ranged = armor_piercing_ranged
		attack_interval = int(a_attack_interval_levels[cur_level - 1])
		max_attack_interval = int(a_attack_interval_levels[cur_level - 1])
		ranged_attack_interval = int(a_ranged_attack_interval_levels[cur_level - 1])
		max_ranged_attack_interval = int(a_ranged_attack_interval_levels[cur_level - 1])
		shoot_accuracy_max = a_ranged_shoot_accuracy[cur_level - 1]
		damage = int(a_melee_damage_levels[cur_level - 1] + bonus_damage)
		max_damage = damage
		ranged_damage = int(a_ranged_damage_levels[cur_level - 1] + bonus_damage)
		max_ranged_damage = ranged_damage
		max_walk_speed = a_walk_speed_levels[cur_level - 1] + bonus_move_speed
		if selected == true:
			MainGameUIEx.inst.show_unit_panel()
		ui_health_bar.reset_health(cur_health, health)
		# 反编译中的 if(false){goto} 为空操作；其余按 curLevel 分支
		if cur_level == 3:
			if special_one == null:
				cur_level = 2
				unlock_specials()
				cur_level = 3
				unlock_specials()
			else:
				unlock_specials()
		else:
			unlock_specials()

func proportional_reset_int(param1: int, param2: int, param3: int, param4: int) -> int:
	var result: int = AS3.round(param1 * (float(param2) / param3))
	if result <= 0:
		result = 1
	if result >= param4:
		result = param4
	return result

## Array.sortOn(prop, Array.NUMERIC [| Array.DESCENDING])：稳定插入排序（Flash 的排序对平局次序未公开）。prop 为 snake_case 属性名。
static func sort_on_prop(arr: Array, prop: String, descending: bool = false) -> void:
	for i in range(1, arr.size()):
		var item: Variant = arr[i]
		var key: float = float(item.get(prop))
		var j := i - 1
		while j >= 0:
			var other: float = float(arr[j].get(prop))
			var swap: bool = other < key if descending else other > key
			if not swap:
				break
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = item

func unlock_specials() -> void:
	pass

## 原版 sens.addEventListener(MouseEvent.CLICK, clicked) 的处理函数；由 GameUniverse 在 hit_test_sens 命中后调用。
func clicked(event: RWMouseEvent) -> void:
	if event.alt_key == true:
		pass
	if cur_stanse != DEAD:
		if friendly == true:
			if event.shift_key:
				if _instance.friendly:
					GameUniverse.inst.set_prioritized_healing_target(_instance)
					var cache: SimpleCache = GroundFlagHeal.cached_data
					var flag: GroundFlagHeal = cache.get_data() as GroundFlagHeal
					flag.added_to_stage(position.x, position.y)
					Sounds.inst.play(s.get_sound(SoundLibrary.FLAG_HEAL), false, 0, 0.4, position.x)
			elif event.ctrl_key:
				if _instance.friendly:
					if _instance.selected == false:
						GameUniverse.inst.select_unit(_instance)
					else:
						GameUniverse.inst.unselect_unit(_instance)
			else:
				var now: int = Time.get_ticks_msec()  # getTimer()
				if last_click_time + 400 > now:
					GameUniverse.inst.select_all_of_type(class_kind)
				else:
					GameUniverse.inst.friendly_unit_clicked(self)
				last_click_time = now
		else:
			GameUniverse.inst.enemy_unit_clicked(_instance)

## sens 的包围盒（舞台/全局坐标），对应 Flash 的 sens.hitTestObject 所用的显示对象边界。
func get_sens_rect() -> Rect2:
	if sens == null or sens.texture == null:
		return Rect2(global_position, Vector2.ZERO)
	return sens.get_global_transform() * sens.get_rect()

## 点击热区：用 sens 图像的 alpha（> 0）结合单位当前位置判定。stage_point 为舞台（全局）坐标。
## sens 是 this 的子节点而不是 sprite 的，原版不随 sprite.scaleX 翻转，这里同样不翻转。
## 单位被释放/不可点（mouseEnabled=false、DEAD、不可见）时返回 false。
func hit_test_sens(stage_point: Vector2) -> bool:
	if sens == null or sens.texture == null or not sens_mouse_enabled or not is_visible_in_tree():
		return false
	var local: Vector2 = to_local(stage_point) - sens.position - sens.offset
	var tex: Texture2D = sens.texture
	var w: int = int(tex.get_width())
	var h: int = int(tex.get_height())
	var px: int = int(floor(local.x))
	var py: int = int(floor(local.y))
	if px < 0 or py < 0 or px >= w or py >= h:
		return false
	var id: int = int(_content().symbols.get(sens_class, -1))
	var entry: Dictionary
	if _sens_alpha_cache.has(id):
		entry = _sens_alpha_cache[id]
	else:
		var img: Image = tex.get_image()
		var has_alpha := false
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			var data := img.get_data()
			for i in range(3, data.size(), 4):
				if data[i] > 0:
					has_alpha = true
					break
		entry = {"image": img, "has_alpha": has_alpha}
		_sens_alpha_cache[id] = entry
	if not entry["has_alpha"]:
		return true  # 热区图像无任何 alpha 像素：退化为包围盒
	var image: Image = entry["image"]
	return image.get_pixel(px, py).a > 0.0

func set_battle_destination(param1: Vector2) -> void:
	battle_point = param1

func set_destination(param1: Vector2, param2: bool = false) -> void:
	var loc3: Vector2 = param1
	var loc4: float = loc3.x
	var loc5: float = loc3.y
	if loc4 < 5:
		loc4 = 5
	if loc4 > 695:
		loc4 = 695
	if loc5 < 5:
		loc5 = 5
	if loc5 > 595:
		loc5 = 595
	loc3 = Vector2(loc4, loc5)
	var path_bd: RWBitmapData = GameUniverse.inst.path_bd
	if path_bd != null:
		if path_bd.get_pixel(_to_int(loc3.x), _to_int(loc3.y)) != 0:
			var loc7 := Vector2(_instance.position.x, _instance.position.y)
			var loc8: float = loc7.distance_to(loc3)
			var loc9: float = 1 - walk_speed / loc8  # loc8 == 0 时 AS3 得 -Infinity，GDScript 浮点除零同为 inf
			var loc10 := false
			var loc12: float = 0.01
			var loc13: int = 0
			while loc10 == false:
				var loc11: Vector2 = AS3.point_interpolate(loc7, loc3, 1 - loc9 + loc12)
				loc12 += 0.03
				loc13 += 1
				if path_bd.get_pixel(_to_int(loc11.x), _to_int(loc11.y)) == 0 or loc13 > 50:
					loc10 = true
					loc3 = loc11
	if cur_stanse != DEAD:
		if attacking_with_ranged_weapon == true:
			is_archer_shooting_its_target_while_is_needed_to_move = true
		elif is_defence_stance == true:
			check_flee_battle()
			if AS3.aborted:
				return
		if a_obstacle_route.size() == 0:
			zero_point = loc3
		dest_point = loc3
		if param2 == true:
			if last_external_point != null:
				var loc14: int = a_soldier_main_route.find(last_external_point)
				if loc14 >= 0:
					a_soldier_main_route.remove_at(loc14)
			if can_be_selected == true:
				a_soldier_main_route.insert(0, loc3)
			else:
				a_soldier_main_route.push_back(loc3)
			last_external_point = dest_point

# 反编译破损，按 P-code 重建
# 结论：第三个分支（自己是 defender）与反编译一致；第二个分支（自己是 attacker 且只有 1 个进攻者）中，
# showBackStabSigh 在 fleeBattle/showCantMoveSign 之后只由 strike 标志决定，与 curHealth 无关
# （P-code @00ce：curHealth<=0 时直接跳到 @00a0 的 if(strike) showBackStabSigh）。
func check_flee_battle() -> void:
	var strike := false
	if cur_battle == null:
		set_target(null)
	elif cur_battle.is_defender(_instance) == false:
		if cur_battle.get_num_attackers > 1:
			cur_battle.remove_from_battle(_instance)
			cur_target = null
			if cur_stanse == FIGHTING:
				cur_frame = 0
		else:
			var defender_unit: LivingObject = cur_battle.defender
			if defender_unit != null:
				if defender_unit.get_stance == FIGHTING:
					strike = defender_unit.strike_back_stab(_instance)
					if AS3.aborted:
						return
			if cur_health > 0:
				if defender_unit == null:
					flee_battle()
				elif defender_unit.walk_speed <= walk_speed:
					flee_battle()
				else:
					show_cant_move_sign()
			if strike:
				show_back_stab_sigh()
	else:
		strike = false
		var any_strike := false
		var num_attackers: int = cur_battle.a_melee_attackers.size()
		var max_speed: float = 0.0
		var i: int = 0
		while i < num_attackers:
			if cur_health > 0:
				# 原版 numAttackers 在循环前取一次；strikeBackStab 击杀攻击者会让 aMeleeAttackers 缩短，随后 aMeleeAttackers[i]
				# 为 undefined，原版在 getStance 处抛 TypeError #1009，异常穿透调用链，fleeBattle 不再执行。
				if i >= cur_battle.a_melee_attackers.size():
					AS3.throw_error("TypeError #1009: LivingObject.checkFleeBattle aMeleeAttackers[%d] is undefined" % i)
					return
				var attacker: LivingObject = cur_battle.a_melee_attackers[i]
				if attacker.get_stance == FIGHTING:
					if attacker.walk_speed > max_speed:
						max_speed = attacker.walk_speed
					strike = attacker.strike_back_stab(_instance)
					if AS3.aborted:
						return
					if strike:
						any_strike = true
			i += 1
		if cur_health > 0:
			if walk_speed >= max_speed:
				flee_battle()
			else:
				show_cant_move_sign()
		if any_strike:
			show_back_stab_sigh()

func show_cant_move_sign() -> void:
	Sounds.inst.play(s.get_sound(SoundLibrary.BTN_DENY), false, 0, 0.45, position.x, SoundLibrary.BTN_DENY)
	var cache: SimpleCache = CantMoveVisual.cached_data
	var visual: CantMoveVisual = cache.get_data() as CantMoveVisual
	visual.added_to_stage(sens.position.x, sens.position.y, Callable(), _instance)

func show_back_stab_sigh() -> void:
	Sounds.inst.play(s.get_sound(SoundLibrary.BACKSTAB), false, 0, 0.45, position.x)
	var cache: SimpleCache = BackstabVisual.cached_data
	var visual: BackstabVisual = cache.get_data() as BackstabVisual
	visual.added_to_stage(sens.position.x, sens.position.y, Callable(), _instance)

## 原版内部闭包 backstabbing：target.lastBackstab = tm；curTarget.bringDamage(curDamage * 3, _instance, true)
func strike_back_stab(targt: LivingObject) -> bool:
	var striked := false
	if targt.is_rogue == false and in_action == true:
		if targt.cur_health > 0:
			if kind != MONSTER_KAMIKAZE and kind != MONSTER_KAMI_SHIELD:
				var tm: int = GameUniverse.inst.get_game_time()
				if targt.last_backstab + 60 < tm:
					var do_stab := false
					if targt.walk_speed >= walk_speed:
						do_stab = true
					elif friendly == true:
						do_stab = true
					if do_stab:
						var cache: SimpleCache = StunnedSmallWaveVisual.cached_data
						var wave: StunnedSmallWaveVisual = cache.get_data() as StunnedSmallWaveVisual
						wave.added_to_stage(sens.position.x, sens.position.y + sens_height / 2, Callable(), _instance)
						wave.scale.x = _instance.get_view_direction
						targt.last_backstab = tm
						if cur_target == null:
							AS3.throw_error("TypeError #1009: LivingObject.strikeBackStab curTarget is null")
							return striked
						cur_target.bring_damage(cur_damage * 3, _instance, true)
						striked = true
	return striked

func flee_battle() -> void:
	if friendly == false:
		return
	v_untouchable_units.push_back(_instance)
	v_untouchable_time_mark.push_back(GameUniverse.inst.global_counter)
	if get_cur_battle != null:
		if get_cur_battle.defender != null:
			if get_cur_battle.is_defender(_instance):
				var distant: Array = get_cur_battle.v_distant_attackers.duplicate()
				var i: int = 0
				while i < distant.size():
					var unit: LivingObject = distant[i]
					unit.set_battle(null)
					i += 1
			else:
				var def_unit: LivingObject = get_cur_battle.defender
				def_unit.set_battle(null)
				if def_unit.is_archer:
					def_unit.attacking_with_ranged_weapon = true
				def_unit.is_defence_stance = false
	is_defence_stance = true
	cur_battle = null
	set_target(null)

# 反编译破损，按 P-code 重建
# 结论：反编译里的 while(true){push} 和 §§goto 都是控制流混淆；P-code 验证后的顺序为
#   非 DEAD：buffs -> [inAction：beforeUpdatingActiveUnit、searchTarget、弓箭手移动中射击复位、++attackCounter、
#   checkTargetExistence、checkBattleExistence、目标分支、specialOne/Two/Zero.update] -> mainAlgUpdateHealthBar；
#   DEAD：仅在尸体动画最后一帧置 canRemoveFromUnitsArray；
#   最后（两种情况都执行）：curHealth <= 0 则 inAction = true；mainAlgUpdateSprite。
# 抛错语义：update() 内任何一层抛出的未捕获异常（as3.gd）使本函数剩余语句都不执行，立即返回。
func update() -> void:
	if cur_stanse != DEAD:
		main_alg_check_all_buffs_and_penalties()
		if AS3.aborted:
			return
		if in_action == true:
			before_updating_active_unit()
			search_target()
			if AS3.aborted:
				return
			if is_archer_shooting_its_target_while_is_needed_to_move == true:
				if cur_frame == 0:
					is_archer_shooting_its_target_while_is_needed_to_move = false
					attacking_with_ranged_weapon = false
					set_target(null)
					cur_stanse = WALKING
					current_bm = bmp_walk
					play_head_stance = PLAYING
			attack_counter += 1
			main_alg_check_target_existence()
			main_alg_check_battle_existence()
			if cur_target == null:
				if cur_stanse != CASTING and cur_stanse != RANGED_SHOOT:
					manage_walk_normal()
					if AS3.aborted:
						return
				elif current_bm.num_frames - cur_frame < 2 or cur_frame < 2:
					manage_walk_normal()
					if AS3.aborted:
						return
				check_abilities()
				if AS3.aborted:
					return
			elif cur_target != null:
				if attacking_with_ranged_weapon == true:
					if archer_goto_target == false:
						if cur_stanse != CASTING:
							if cur_stanse != RANGED_SHOOT:
								set_stance(RANGED_SHOOT)
								is_defence_stance = false
								turn_to_attacker()
								manage_attack()
								if AS3.aborted:
									return
							else:
								manage_attack()
								if AS3.aborted:
									return
					else:
						var dist: float = MiscUtils.get_distance(_instance, cur_target)
						if dist > search_radius * search_radius_ranged_modifier:
							if a_obstacle_route.size() == 0:
								manage_walk_to_battle(dist, Vector2(_x, _y), Vector2(cur_target._x, cur_target._y))
								if AS3.aborted:
									return
							else:
								main_alg_move_soldier_to_route_way_point(a_obstacle_route[0])
								if AS3.aborted:
									return
						else:
							archer_goto_target = false
				else:
					var cur_pos := Vector2(_x, _y)
					if cur_battle == null:
						var dist2: float = MiscUtils.get_distance(_instance, cur_target)
						if dist2 > walk_speed + MAX_DISTANCE_BEFORE_MAKING_BATTLE:
							var may_walk := true
							var target_battle: Battle = cur_target.get_cur_battle
							if target_battle != null:
								if target_battle.is_defender(cur_target):
									if target_battle.get_num_attackers == 6:
										may_walk = false
									elif target_battle.get_num_distant_walkers == 6 and not target_battle.is_distant_attacker(_instance):
										may_walk = false
									if may_walk == true:
										if not target_battle.is_distant_attacker(_instance):
											target_battle.add_distant_attacker(_instance)
							if may_walk == true:
								if a_obstacle_route.size() == 0:
									manage_walk_to_battle(dist2, cur_pos, Vector2(cur_target._x, cur_target._y))
									if AS3.aborted:
										return
								else:
									main_alg_move_soldier_to_route_way_point(a_obstacle_route[0])
									if AS3.aborted:
										return
								if not friendly:
									if cur_target.class_kind == CLASS_WARRIOR or cur_target.class_kind == CLASS_THIEF:
										var pursue: int = int(o_pursue_counter.get(pursue_key(cur_target), 0))
										if pursue != 0:
											pursue += 1
											if cur_target.selected == true:
												var d_mass: float = mass_center.distance_to(Vector2(cur_target.position.x, cur_target.position.y))
												if d_mass > MAX_DIST_FROM_MASS_CENTER:
													pursue += 2
											if pursue > MAX_TIME_PURSUE:
												if RWRandom.rand() > 0.25:
													cur_target = null
												else:
													o_pursue_counter[pursue_key(cur_target)] = RWRandom.rand_range(1, MAX_TIME_PURSUE)
											else:
												o_pursue_counter[pursue_key(cur_target)] = pursue
							else:
								if v_untouchable_units.find(cur_target) < 0:
									v_untouchable_units.push_back(cur_target)
									v_untouchable_time_mark.push_back(GameUniverse.inst.global_counter)
								cur_target = null
						elif cur_target.get_cur_battle == null:
							if v_untouchable_units.find(cur_target) < 0 or get_walk_speed > cur_target.get_walk_speed:
								if cur_target.get_cur_target == _instance:
									if RWRandom.rand() > 0.5:
										GameUniverse.inst.make_battle(_instance, cur_target)
									else:
										GameUniverse.inst.make_battle(cur_target, _instance)
								else:
									GameUniverse.inst.make_battle(_instance, cur_target)
							else:
								turn_to_attacker()
								if cur_stanse != STAND:
									set_stance(STAND)
						else:
							var other_battle: Battle = cur_target.get_cur_battle
							if other_battle.is_defender(cur_target):
								if other_battle.get_num_attackers < 6:
									other_battle.add_melee_attacker(_instance)
								else:
									if v_untouchable_units.find(cur_target) < 0:
										v_untouchable_units.push_back(cur_target)
										v_untouchable_time_mark.push_back(GameUniverse.inst.global_counter)
									set_target(null)
							else:
								if other_battle.get_num_attackers == 1:
									other_battle.switch_defender_and_attacker()
									other_battle.add_melee_attacker(_instance)
								else:
									other_battle.remove_from_battle(cur_target)
									GameUniverse.inst.make_battle(_instance, cur_target)
								after_making_a_new_battle_from_old_one()
					elif cur_battle.is_defender(_instance):
						if not main_alg_move_to_point(battle_point, false):
							turn_to_attacker()
							if cur_stanse != FIGHTING:
								var idx: int = v_untouchable_units.find(_instance)
								if idx >= 0:
									v_untouchable_units.remove_at(idx)
									v_untouchable_time_mark.remove_at(idx)
								set_stance(FIGHTING)
								is_defence_stance = false
								manage_attack()
								if AS3.aborted:
									return
							else:
								manage_attack()
								if AS3.aborted:
									return
					elif not main_alg_move_to_point(battle_point, false):
						if cur_target.get_cur_battle == _instance.get_cur_battle:
							turn_to_attacker()
							if cur_stanse != FIGHTING:
								var idx2: int = v_untouchable_units.find(_instance)
								if idx2 >= 0:
									v_untouchable_units.remove_at(idx2)
									v_untouchable_time_mark.remove_at(idx2)
								set_stance(FIGHTING)
								is_defence_stance = false
								manage_attack()
								if AS3.aborted:
									return
							else:
								manage_attack()
								if AS3.aborted:
									return
						else:
							cur_battle = null
			if special_one != null:
				special_one.update()
				if AS3.aborted:
					return
			if special_two != null:
				special_two.update()
				if AS3.aborted:
					return
			if special_zero != null:
				special_zero.update()
				if AS3.aborted:
					return
		main_alg_update_health_bar()
	elif current_bm == bmp_dead:
		if current_bm.num_frames - 1 == cur_frame:
			can_remove_from_units_array = true
	if cur_health <= 0:
		in_action = true
	main_alg_update_sprite()

# 反编译破损，按 P-code 重建
# 结论：aSoldierMainRoute 非空且无绕障路点时，取离 (x, y)（节点的取整坐标）最近的路点下标（最小距离存为 int，
# P-code 在 loc6 赋值处有 convert_i），丢弃其前面的路点；有绕障路点则 destPoint = aObstacleRoute[0]；
# 最后 mainAlgMoveSoldierToRouteWayPoint(destPoint)。路线为空则 mainAlgDestinationReached。
func manage_walk_normal() -> void:
	if a_soldier_main_route.size() > 0:
		if a_obstacle_route.size() == 0:
			var first_point: Vector2 = a_soldier_main_route[0]
			if dest_point != first_point:
				dest_point = first_point
			var here := Vector2(position.x, position.y)
			var best_index: int = 0
			var best_dist: int = 9999
			var i: int = 0
			while i < a_soldier_main_route.size():
				var p: Vector2 = a_soldier_main_route[i]
				var d: float = p.distance_to(here)
				if d < best_dist:
					best_dist = int(d)
					best_index = i
				i += 1
			if best_index > 0:
				# splice(0, best_index)：原地删除（duplucatedRoute 会让多个单位共用同一数组）
				for _k in best_index:
					a_soldier_main_route.remove_at(0)
				dest_point = a_soldier_main_route[0]
		else:
			dest_point = a_obstacle_route[0]
		main_alg_move_soldier_to_route_way_point(dest_point)
	else:
		main_alg_destination_reached()

func after_making_a_new_battle_from_old_one() -> void:
	pass

func main_alg_check_battle_existence() -> void:
	if cur_battle != null:
		if cur_target == null:
			cur_battle.check_enemy_existence()
		else:
			var dist: float = MiscUtils.get_distance(_instance, cur_target)
			if dist > MAX_DISTANCE_BEFORE_MAKING_BATTLE * 1.5:
				if cur_battle.is_defender(_instance) == true:
					if cur_battle.a_melee_attackers.size() > 1:
						var cur_pos := Vector2(_x, _y)
						var i: int = 0
						while i < cur_battle.a_melee_attackers.size():
							var attacker: LivingObject = cur_battle.a_melee_attackers[i] as LivingObject
							attacker.temp_dist_to_attacker = cur_pos.distance_to(Vector2(attacker._x, attacker._y))
							i += 1
						sort_on_prop(cur_battle.a_melee_attackers, "temp_dist_to_attacker")
						cur_target = cur_battle.a_melee_attackers[0]
						dist = MiscUtils.get_distance(_instance, cur_target)
						if dist > MAX_DISTANCE_BEFORE_MAKING_BATTLE * 1.5:
							cur_battle.remove_from_battle(_instance)
					else:
						cur_battle.remove_from_battle(_instance)

# 反编译破损，按 P-code 重建
# 结论：非 STAND 时 setStance(STAND) 并 isDefenceStance = setDefenceStanceWhenStay()；之后（始终）
# 消耗一次 rand，> 0.995 则翻转朝向；最后若离 zeroPoint 超过 walkSpeed 则 setDestination(zeroPoint, true)。
func main_alg_destination_reached() -> void:
	if cur_stanse != STAND:
		set_stance(STAND)
		is_defence_stance = set_defence_stance_when_stay()
	if RWRandom.rand() > 0.995:
		sprite.scale.x *= -1
	var here := Vector2(_x, _y)
	var dist: float = here.distance_to(zero_point)
	if dist > walk_speed:
		set_destination(zero_point, true)

var set_view_direction: int:
	set(value):
		sprite.scale.x = value

var get_view_direction: float:
	get:
		return sprite.scale.x

func main_alg_check_target_existence() -> void:
	if cur_target != null:
		if cur_target.cur_health <= 0:
			set_target(null)
			return
		if cur_target.in_hide == true:
			if is_priest == false:
				set_target(null)
				return
		if cur_target.friendly == friendly:
			if is_priest == false:
				set_target(null)
				return
		if friendly == false:
			if is_rogue == false:
				if is_archer == false:
					if MiscUtils.get_distance(_instance, cur_target) > MAX_PURSUIT_DISTANCE:
						set_target(null)
						return
		if attacking_with_ranged_weapon == true:
			if cur_stanse != CASTING:
				if archer_goto_target == false:
					if MiscUtils.get_distance(_instance, cur_target) > search_radius * search_radius_ranged_modifier:
						set_target(null)
						return

func main_alg_move_to_point(param1: Vector2, param2: bool = true) -> bool:
	var cur_pos := Vector2(_x, _y)
	var dist: float = cur_pos.distance_to(param1)
	if dist > walk_speed:
		if cur_stanse != WALKING:
			set_stance(WALKING)
		if cur_stanse != FIGHTING:
			var ratio: float = 1 - walk_speed / dist
			var next_pos: Vector2 = AS3.point_interpolate(cur_pos, param1, ratio)
			var moved: Vector2
			if param2 == true:
				moved = check_obstacles(cur_pos, next_pos, param1)
				if AS3.aborted:
					return false
			else:
				moved = next_pos
			if moved.x < _x:
				sprite.scale.x = -1
			else:
				sprite.scale.x = 1
			set_coordinates(moved.x, moved.y)
		return true
	return false

func is_point_obstacle(param1: Vector2) -> bool:
	var result := false
	var path_bd: RWBitmapData = GameUniverse.inst.path_bd
	if path_bd != null:
		if path_bd.get_pixel(_to_int(param1.x), _to_int(param1.y)) != 0:
			result = true
	return result

# 反编译破损，按 P-code 重建
# 结论：反编译里的 while(_loc10_ != _loc9_) 实为 if（P-code @01dd：相等则直接 return param2）；
# 环号是路点名 pX_n 的 substr(1,1)，点号是 substr(3)。先找离 param1 最近的路点 loc9，再收集同环全部路点
# （按子节点顺序，下标即点号）并找离目标 param3 最近的 loc10；沿环正向（点号递增，到长度回 0）和反向
# （递减，到 -1 回长度-1）各生成一条路点序列，任何路点落在 700x600 屏幕外则该方向作废（清空）；
# 取较短的非空方向（长度相等取正向），去掉第一个点（起点自身）后存入 aObstacleRoute，返回值始终是 param2。
func check_obstacles(param1: Vector2, param2: Vector2, param3: Vector2 = Vector2.ZERO) -> Vector2:
	var path_bd: RWBitmapData = GameUniverse.inst.path_bd
	if path_bd != null:
		if a_obstacle_route.size() == 0:
			if path_bd.get_pixel(_to_int(param2.x), _to_int(param2.y)) != 0:
				var waypoints: RWLayoutClip = GameUniverse.inst.obstacle_way_points
				var best_dist_start: float = 9999
				var nearest_start: RWLayoutClip = null
				var best_dist_end: float = 9999
				var nearest_end: RWLayoutClip = null
				var ring_points: Array = []
				var i: int = 0
				while i < waypoints.children.size():
					var wp: RWLayoutClip = waypoints.children[i]
					var d: float = param1.distance_to(Vector2(wp.x, wp.y))
					if d < best_dist_start:
						nearest_start = wp
						best_dist_start = d
					i += 1
				var start_name: String = nearest_start.name
				var start_num: int = start_name.substr(3).to_int()
				var ring_no: int = start_name.substr(1, 1).to_int()
				i = 0
				while i < waypoints.children.size():
					var wp2: RWLayoutClip = waypoints.children[i]
					var wp_ring: int = wp2.name.substr(1, 1).to_int()
					if wp_ring == ring_no:
						var d2: float = param3.distance_to(Vector2(wp2.x, wp2.y))
						if d2 < best_dist_end:
							nearest_end = wp2
							best_dist_end = d2
						ring_points.push_back(wp2)
					i += 1
				var end_name: String = nearest_end.name
				var end_num: int = end_name.substr(3).to_int()
				if nearest_end != nearest_start:
					a_obstacle_route = []
					var forward: Array = []
					var backward: Array = []
					var idx: int = start_num
					var screen := Rect2(0, 0, GAME_WIDTH, GAME_HEIGHT)
					while idx != end_num:
						# 原版数据缺陷：level_23greenroad 的 ring 4 编号为 1..12 且只有 12 个点，ringPoints[12] 为 undefined，
						# 原版在 p.x 处抛 TypeError #1009，异常穿透 checkObstacles -> mainAlgMoveToPoint/manageWalkToBattle ->
						# update -> 单位更新循环 -> globalUpdate，本帧其余内容全部跳过（见 as3.gd；第 20 关会出现）。
						# 此时 aObstacleRoute 已被置为 []（抛错前的状态保留）。
						if idx >= ring_points.size():
							AS3.throw_error("TypeError #1009: LivingObject.checkObstacles ringPoints[%d] is undefined" % idx)
							return param2
						var p: RWLayoutClip = ring_points[idx]
						forward.push_back(Vector2(p.x, p.y))
						idx += 1
						if idx == ring_points.size():
							idx = 0
						if not screen.has_point(Vector2(p.x, p.y)):
							idx = end_num
							forward = []
							break
					idx = start_num
					while idx != end_num:
						if idx >= ring_points.size():
							AS3.throw_error("TypeError #1009: LivingObject.checkObstacles ringPoints[%d] is undefined (backward)" % idx)
							return param2  # 同上：原版此处 TypeError #1009
						var p2: RWLayoutClip = ring_points[idx]
						backward.push_back(Vector2(p2.x, p2.y))
						idx -= 1
						if idx == -1:
							idx = ring_points.size() - 1
						if not screen.has_point(Vector2(p2.x, p2.y)):
							idx = end_num
							backward = []
							break
					if forward.size() <= backward.size():
						if forward.size() != 0:
							a_obstacle_route = forward.duplicate()
						else:
							a_obstacle_route = backward.duplicate()
					elif backward.size() != 0:
						a_obstacle_route = backward.duplicate()
					else:
						a_obstacle_route = forward.duplicate()
					if a_obstacle_route.size() > 0:
						a_obstacle_route.remove_at(0)  # splice(0, 1)
	return param2

func get_direction() -> int:
	return direction

func main_alg_move_soldier_to_route_way_point(param1: Vector2) -> void:
	var moving: bool = main_alg_move_to_point(param1)
	if AS3.aborted:
		return
	if not moving:
		if a_obstacle_route.size() > 0:
			if cur_target == null:
				a_obstacle_route.remove_at(0)
				if a_obstacle_route.size() > 0:
					set_destination(a_obstacle_route[0] as Vector2)
			else:
				var dist: float = MiscUtils.get_distance(_instance, cur_target)
				if dist < 100:
					a_obstacle_route.clear()
					set_destination(Vector2(cur_target._x, cur_target._y))
				else:
					a_obstacle_route.remove_at(0)
					if a_obstacle_route.size() > 0:
						set_destination(a_obstacle_route[0] as Vector2)
		else:
			if a_soldier_main_route.size() > 0:
				a_soldier_main_route.remove_at(0)
			if a_soldier_main_route.size() > 0:
				set_destination(a_soldier_main_route[0] as Vector2)
			elif friendly == false:
				GameUniverse.inst.make_unit_dead(_instance)
				if cur_battle != null:
					cur_battle.set_unit_dead(_instance)
				set_stance(DEAD)
				GameUniverse.inst.enemy_escaped()
				ui_health_bar.update(0, cur_level)
				sprite.modulate.a = 0.05
			else:
				move_finished()
				can_be_selected = true

func move_finished() -> void:
	pass

# 反编译破损，按 P-code 重建
# 结论：仅当 playHeadStance == PLAYING 且 inAction 时处理帧命令 cmd = currentBM.frameCommands[curFrame]：
#   cmd == STOPPED 且 playFlag == false：playHeadStance = STOPPED，onPlayHeadStopped()，不推进帧、不换位图（直接进入收尾）；
#   否则：cmd == DONE(2) 调 onPlayHeadDone()；cmd == ACTION(3) 调 onPlayHeadAction()（cmd 为 STOPPED 但 playFlag 为 true
#   时两者都不调）；随后（DONE、ACTION、无命令、被 playFlag 放行的 STOP 都一样）playFlag = false，
#   curFrame 推进一帧（到 totalFrames-1 后回 0；注意用的是钩子执行后的 currentBM/curFrame），更新位图。
# 收尾（无论是否处理帧命令）：attackStanceReleaseCounter > 0 则减 1，减到 <= 0 时清零、curFrame = 0、setStance(nextStance)。
func main_alg_update_sprite() -> void:
	if play_head_stance == PLAYING and in_action == true:
		var cmd: int = current_bm.frame_commands[cur_frame]
		if cmd == STOPPED and play_flag == false:
			play_head_stance = STOPPED
			on_play_head_stopped()
		else:
			if cmd == 2:
				on_play_head_done()
			elif cmd == 3:
				on_play_head_action()
			if AS3.aborted:
				return  # 钩子里抛了错（例如 enemy_hit_sound）：原版异常穿透，帧推进与收尾都不执行
			play_flag = false
			if cur_frame != current_bm.num_frames - 1:
				cur_frame += 1
			else:
				cur_frame = 0
			_show_frame(cur_frame)
	if attack_stance_release_counter > 0:
		attack_stance_release_counter -= 1
		if attack_stance_release_counter <= 0:
			attack_stance_release_counter = 0
			cur_frame = 0
			set_stance(next_stance)

## sprite_bm.bitmapData = currentBM.frames[i]; x/y = frameXs/frameYs（BmpFrames.apply_frame）
func _show_frame(i: int) -> void:
	if sprite != null and current_bm != null:
		current_bm.apply_frame(sprite, i)

func on_play_head_action() -> void:
	pass

func main_alg_update_health_bar() -> void:
	ui_health_bar.update(cur_health, cur_level, can_upgrade_is_shown, selected)
	if ui_health_bar.friendly:
		ui_health_bar.position.x = _x + sens.position.x
		ui_health_bar.position.y = _y + sens.position.y - sens_height / 2 - 6

func remove_from_buff_pen(param1: String) -> void:
	var idx: int = a_buffs_and_penalties.find(param1)
	if idx >= 0:
		a_buffs_and_penalties.remove_at(idx)

func bp_slow() -> void:
	if is_slowed == true:
		slow_counter -= 1
		walk_speed = max_walk_speed / 2
		if slow_counter <= 0:
			is_slowed = false
			slow_counter = 0
			walk_speed = max_walk_speed
			remove_from_buff_pen(BP_SLOW)
			ui_health_bar.remove_icon(MiniIcons.cSLOW)

func bp_break_arrows() -> void:
	if is_broken_arrows == true:
		broken_arrows_counter -= 1
		if attacking_with_ranged_weapon == true:
			search_counter = 0
			attack_counter = 0
		if broken_arrows_counter <= 0:
			is_broken_arrows = false
			broken_arrows_counter = 0
			remove_from_buff_pen(BP_BREAKARROWS)
			ui_health_bar.remove_icon(MiniIcons.cBREAKARROW)

func bp_confuse() -> void:
	if is_confused == true:
		confused_counter -= 1
		if special_one != null:
			special_one.lock_special()
		if special_two != null:
			special_two.lock_special()
		if confused_counter <= 0:
			if special_one != null:
				special_one.unlock_special()
			if special_two != null:
				special_two.unlock_special()
			is_confused = false
			confused_counter = 0
			remove_from_buff_pen(BP_CONFUSE)

func bp_suppress() -> void:
	if is_suppressed == true:
		suppress_counter -= 1
		attack_interval = int(max_attack_interval * suppress_ratio)
		ranged_attack_interval = int(max_ranged_attack_interval * suppress_ratio)
		if suppress_counter <= 0:
			is_suppressed = false
			suppress_counter = 0
			attack_interval = max_attack_interval
			ranged_attack_interval = max_ranged_attack_interval
			remove_from_buff_pen(BP_SUPPRESS)
			ui_health_bar.remove_icon(MiniIcons.cWEAK)

func bp_enchant() -> void:
	if is_enchanted == true:
		enchant_timer -= 1
		cur_damage = int(floor(max_damage * enchant_ratio))
		if enchant_timer <= 0:
			is_enchanted = false
			enchant_timer = 0
			cur_damage = max_damage
			remove_from_buff_pen(BP_ENCHANT)
			ui_health_bar.remove_icon(MiniIcons.cWEAPONBUFF)

func bp_corrupt() -> void:
	if is_corrupted == true:
		corrupt_counter -= 1
		cur_armor = _max_armor - corrupt_ratio
		if cur_armor < 0:
			cur_armor = 0
		if corrupt_counter <= 0:
			is_corrupted = false
			corrupt_counter = 0
			cur_armor = _max_armor
			remove_from_buff_pen(BP_CORRUPT)
			ui_health_bar.remove_icon(MiniIcons.cCORRUPT)

func bp_weak() -> void:
	if is_weakened == true:
		weaken_counter -= 1
		attack_interval = int(max_attack_interval * 1.5)
		ranged_attack_interval = int(max_ranged_attack_interval * 1.5)
		if weaken_counter <= 0:
			is_weakened = false
			weaken_counter = 0
			attack_interval = max_attack_interval
			ranged_attack_interval = max_ranged_attack_interval
			remove_from_buff_pen(BP_WEAK)
			ui_health_bar.remove_icon(MiniIcons.cWEAK)

func bp_possess() -> void:
	if is_possessed == true:
		cur_time_to_possess -= 1
		if cur_time_to_possess <= 0:
			is_possessed = false
			if cur_health > 0:
				friendly = not friendly
				if friendly:
					ui_health_bar.top.goto_and_stop(1)
				else:
					ui_health_bar.top.goto_and_stop(2)
				if cur_battle != null:
					cur_battle.remove_from_battle(_instance)
					cur_battle = null
				set_target(null)
				set_stance_after_upgrade(LivingObject.STAND)
				clear_route()
				if AS3.aborted:
					return
				GameUniverse.inst.remove_from_selected_array(_instance)
				a_soldier_main_route = old_route.duplicate()
				old_route = []
				set_destination(Vector2(position.x, position.y))
				if AS3.aborted:
					return
				cur_stanse = NONE
			remove_from_buff_pen(BP_POSSESS)
			ui_health_bar.remove_icon(MiniIcons.cMINDCONTROL)

func bp_weak_spot() -> void:
	if has_weak_spot == true:
		time_to_weak_spot -= 1
		if time_to_weak_spot <= 0:
			has_weak_spot = false
			time_to_weak_spot = 0
			remove_from_buff_pen(BP_WEAKSPOT)
			ui_health_bar.remove_icon(MiniIcons.cFOCUSSHOOT)

func bp_poisoned() -> void:
	if is_poisoned == true:
		if float(poison_timer) / 15 == floor(float(poison_timer) / 15):
			bring_damage(poison_strength, null, false, false)
		poison_timer -= 1
		if poison_timer <= 0:
			is_poisoned = false
			poison_timer = 0
			remove_from_buff_pen(BP_POISONED)
			ui_health_bar.remove_icon(MiniIcons.cPOISON)

func bp_curse() -> void:
	if is_cursed == true:
		curse_counter -= 1
		if curse_counter <= 0:
			var old_cur_health: int = cur_health
			var old_health: int = _health
			health = int(a_health_levels[cur_level - 1])
			cur_health = proportional_reset_int(cur_health, old_cur_health, old_health, _health)
			is_cursed = false
			curse_counter = 0
			remove_from_buff_pen(BP_CURSE)
			ui_health_bar.remove_icon(MiniIcons.cCURSE)

func bp_bless() -> void:
	if is_blessed == true:
		bless_counter -= 1
		attack_interval = int(max_attack_interval * (1 - bless_modifier))
		ranged_attack_interval = int(max_ranged_attack_interval * (1 - bless_modifier))
		if bless_counter <= 0:
			attack_interval = max_attack_interval
			ranged_attack_interval = max_ranged_attack_interval
			is_blessed = false
			bless_counter = 0
			remove_from_buff_pen(BP_BLESS)
			ui_health_bar.remove_icon(MiniIcons.cBLESSBUFF)

func bp_iced() -> void:
	if is_trapped_in_ice == true:
		in_action = false
		freeze_counter -= 1
		if float(freeze_counter) / 15 == floor(float(freeze_counter) / 15):
			bring_damage(cur_ice_damage, null, false, false)
		if freeze_counter <= 0:
			freeze_counter = 0
			is_trapped_in_ice = false
			in_action = true
			remove_from_buff_pen(BP_ICED)

func bp_stunned() -> void:
	if is_stunned == true:
		stun_counter -= 1
		in_action = false
		if stun_counter <= 0:
			stun_counter = 0
			is_stunned = false
			in_action = true
			remove_from_buff_pen(BP_STUNNED)
			ui_health_bar.remove_icon(MiniIcons.cSTUN)

func bp_harm_resisted() -> void:
	if is_harm_resisted == true:
		max_harm_resist_time -= 1
		if max_harm_resist_time <= 0:
			is_harm_resisted = false
			max_harm_resist_time = 0
			remove_from_buff_pen(BP_HARMRES)
			ui_health_bar.remove_icon(MiniIcons.cRESIST)

## 按 aBuffsAndPenalties 的下标顺序逐个执行；执行中 removeFromBuffPen 会缩短数组，下标照常 +1（会跳过下一项，原版行为）。
func main_alg_check_all_buffs_and_penalties() -> void:
	if a_buffs_and_penalties.size() > 0:
		var i: int = 0
		while i < a_buffs_and_penalties.size():
			var bp_name: String = a_buffs_and_penalties[i]
			var fn: Callable = o_bp[bp_name]
			fn.call()
			if AS3.aborted:
				return
			i += 1

func rogue_close_to_target() -> void:
	pass

func manage_walk_to_battle(param1: float, param2: Vector2, param3: Vector2) -> void:
	if cur_stanse != WALKING:
		set_stance(WALKING)
	var ratio: float = 1 - walk_speed / param1
	var interpolated: Vector2 = AS3.point_interpolate(param2, param3, ratio)
	var moved: Vector2 = check_obstacles(param2, interpolated, param3)
	if AS3.aborted:
		return
	var target_point: Vector2 = param3
	if interpolated.length() != moved.length():
		if target_point.x < _x:
			sprite.scale.x = -1
		else:
			sprite.scale.x = 1
		if rotation_counter < 5:
			if sprite.scale.x * (moved.x - _x) < 0:
				rotation_counter += 1
		else:
			sprite.scale.x *= -1
	else:
		rotation_counter = 0
		if moved.x < _x:
			sprite.scale.x = -1
		else:
			sprite.scale.x = 1
	set_coordinates(moved.x, moved.y)

func set_defence_stance_when_stay() -> bool:
	return false

func before_updating_active_unit() -> void:
	pass

func on_play_head_done() -> void:
	if cur_stanse == FIGHTING:
		attack_done(null)
	elif cur_stanse == RANGED_SHOOT:
		throw_ranged(null)
	elif cur_stanse == CASTING:
		casting_done()

func casting_done() -> void:
	pass

func on_play_head_stopped() -> void:
	pass

func turn_to_attacker() -> void:
	if cur_target != null:
		if cur_target._x < _instance._x:
			sprite.scale.x = -1
		else:
			sprite.scale.x = 1

func turn_to_unit(param1: LivingObject) -> void:
	if param1._x < _instance._x:
		sprite.scale.x = -1
	else:
		sprite.scale.x = 1

func manage_attack() -> void:
	if check_abilities() == false:
		if cur_target.get_stance == DEAD:
			set_target(null)
			return
		if attacking_with_ranged_weapon == true:
			if attack_counter >= ranged_attack_interval:
				attack_counter = 0
				turn_to_attacker()
				play_head_start_play()
				start_ranged_attack()
		elif attack_counter >= attack_interval:
			var dist: float = MiscUtils.get_distance(_instance, cur_target)
			if dist < 35:
				if cur_target.in_hide == false:
					attack_counter = 0
					turn_to_attacker()
					play_head_start_play()
			elif cur_battle.is_defender(_instance) == true:
				if cur_battle.a_melee_attackers.size() > 1:
					scounter += 1
					if scounter > 5:
						scounter = 0
						var cur_pos := Vector2(_x, _y)
						var i: int = 0
						while i < cur_battle.a_melee_attackers.size():
							var attacker: LivingObject = cur_battle.a_melee_attackers[i] as LivingObject
							attacker.temp_dist_to_attacker = cur_pos.distance_to(Vector2(attacker.position.x, attacker.position.y))
							i += 1
						sort_on_prop(cur_battle.a_melee_attackers, "temp_dist_to_attacker")
						cur_target = cur_battle.a_melee_attackers[0]
						dist = cur_pos.distance_to(Vector2(cur_target.position.x, cur_target.position.y))
						if dist < 35:
							if cur_target.in_hide == false:
								attack_counter = 0
								turn_to_attacker()
								play_head_start_play()
				elif not can_unit_move(cur_target):
					cur_battle.switch_defender_and_attacker()
	else:
		turn_to_attacker()
		attack_counter = 0

func start_ranged_attack() -> void:
	pass

func can_unit_move(_param1: LivingObject) -> bool:
	if is_stunned == true or is_trapped_in_ice == true:
		return false
	return true

func play_head_start_play() -> void:
	play_flag = true
	play_head_stance = 0
	special_play_head_start_playing_handler()

func special_play_head_start_playing_handler() -> void:
	pass

func attack_done(_e: Variant = null) -> void:
	if cur_target != null:
		if cur_target.cur_health > 0:
			var target_armor: float = cur_target.cur_armor
			var effective_armor: float = target_armor - armor_piercing_melee
			if effective_armor < 0:
				effective_armor = 0
			var dmg: int = int(cur_damage * (1 - effective_armor))
			got_experience(1)
			special_before_damaging_enemy_handler()
			if cur_target == null:
				return
			cur_target.bring_damage(dmg, _instance, true)
			enemy_hit_sound()

func enemy_hit_sound() -> void:
	# 原版 enemyHitSound 在 curTarget 为 null 时抛 TypeError #1009（bringDamage 的副作用可能清空 curTarget，
	# 如 SpecMissAssasin 之类）。异常穿透 attackDone -> onPlayHeadDone -> mainAlgUpdateSprite -> update ->
	# 单位更新循环 -> globalUpdate：本帧其余内容全部跳过（见 as3.gd）。
	if cur_target == null:
		AS3.throw_error("TypeError #1009: LivingObject.enemyHitSound curTarget is null")
		return
	if cur_target.cur_armor > 0.5:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.IMPACT_ARMOR), false, RWRandom.rand_range(0, 12) / 100.0, 0.28, position.x, SoundLibrary.IMPACT)
	else:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.IMPACT_FLESH), false, RWRandom.rand_range(0, 10) / 100.0, 0.28, position.x, SoundLibrary.IMPACT)

func got_experience(_param1: float) -> void:
	cur_experience += 1
	if cur_experience >= exp_to_next_level:
		if basic_unit == true and cur_level == 3:
			if GameUniverse.inst.is_upgrade_allowed(kind):
				if can_upgrade_is_shown == false:
					can_upgrade_is_shown = true
					var can_upgrade := CanUpgradeEx.new()
					add_child(can_upgrade)
					can_upgrade.position.x = sens.position.x
					can_upgrade.position.y = sens.position.y - sens_height / 2 - 12
					MainGameUIEx.inst.show_has_upgrade_button(_instance)
					Sounds.inst.play(s.get_sound(SoundLibrary.HAS_UPGRADE), false, 0, 0.5, position.x)
		else:
			if ui_health_bar.friendly:
				if cur_level == 2:
					_g_add("a48_get_elite", 1)
			if basic_unit == true:
				upgrade_clicked()
			elif cur_level < 3:
				upgrade_clicked()

func special_before_damaging_enemy_handler() -> void:
	pass

func play_head_goto_and_stop(param1: float) -> void:
	play_flag = false
	play_head_stance = STOPPED
	cur_frame = int(param1)
	_show_frame(cur_frame)

func play_head_goto_and_play(param1: float) -> void:
	play_flag = true
	play_head_stance = PLAYING
	cur_frame = int(param1 - 1)

func reset_current_frame() -> void:
	cur_frame = 0

func throw_ranged(_e: Variant = null) -> void:
	pass

var get_walk_speed: float:
	get:
		return walk_speed

func get_cur_destination() -> Variant:
	var result: Variant = null
	if is_archer == true:
		result = dest_point
	elif cur_battle != null:
		result = battle_point
	else:
		result = dest_point
	return result

## 伤害结算（死亡分支经 P-code 核对：反编译的 while(true)/§§goto 只是混淆）。
# 反编译破损，按 P-code 重建
# 结论：顺序为 melee/ranged 受击处理 -> param1 == 0 时 rand > 0.66 记 1 -> weakSpot 乘数（floor 后转 int）->
# 免疫（>0 时记 1）-> curHealth -= param1 -> param1 > 0：血液特效（消耗 2 次 rand）、gotExperience(1)、统计；
# param1 < 0：治疗统计 -> curHealth > 0：超上限则截断，否则 afterBeingHitHandler；否则死亡流程
# （afterHealthBelowZeroHandler、友方/敌方音效统计与怪物音效 rand > 0.9、calculateDeathCost/giveFrag、
# removeDistantAttacker、makeUnitDead、setUnitDead、minusUnits、血条清零、setStance(DEAD)）。
func bring_damage(param1: int, param2: LivingObject, param3: bool = false, param4: bool = true) -> void:
	if param3 == true:
		param1 = special_being_hit_melee_handler(param1, param2)
	else:
		param1 = special_being_hit_ranged_handler(param1, param2)
	if param1 == 0:
		if RWRandom.rand() > 0.66:
			param1 = 1
	if has_weak_spot == true:
		param1 = int(floor(param1 * cur_weak_mod))
	if is_harm_resisted == true:
		if param1 > 0:
			param1 = 1
	cur_health -= param1
	if param1 > 0:
		if param4:
			var cache: SimpleCache = BloodEx.cached_data
			var blood: BloodEx = cache.get_data() as BloodEx
			blood.added_to_stage(sens.position.x - 2 + 4 * RWRandom.rand(), sens.position.y - 5 + 10 * RWRandom.rand(), Callable(), _instance)
		got_experience(1)
		if friendly:
			_g_add("damage_received", param1)
		else:
			_g_add("damage_dealt", param1)
	elif param1 < 0:
		if friendly:
			_g_add("num_healed", param1 * -1)
	if cur_health > 0:
		if cur_health > health:
			cur_health = health
		else:
			after_being_hit_handler()
		return
	after_health_below_zero_handler()
	can_remove_from_units_array = false
	if ui_health_bar.friendly:
		if is_npc == false:
			_g_add("num_soldiers_dead", 1)
			MainGameUIEx.inst.hide_has_upgrade_button(_instance)
		else:
			GameUniverse.inst.minus_health()
		if kind != NPC_WOMAN:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_DIED), false, 0, 0.4, position.x)
	else:
		if RWRandom.rand() > 0.9:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MONSTERS), false, 0, 0.4, position.x, SoundLibrary.MONSTERS)
		_g_add("num_killed", 1)
	if param2 != null:
		if param2.friendly == true:
			param2.calculate_death_cost(_instance)
		param2.give_frag()
	else:
		calculate_death_cost(_instance)
	remove_distant_attacker()
	GameUniverse.inst.make_unit_dead(_instance)
	if cur_battle != null:
		cur_battle.set_unit_dead(_instance)
	minus_units()
	ui_health_bar.update(0, cur_level)
	set_stance(DEAD)

func special_being_hit_ranged_handler(param1: int, _param2: LivingObject) -> int:
	return param1

func remove_distant_attacker() -> void:
	if cur_target != null:
		if cur_target.get_cur_battle != null:
			cur_target.get_cur_battle.remove_distant_attacker(_instance)

func after_health_below_zero_handler() -> void:
	if ui_health_bar.friendly == true:
		var cache: SimpleCache = UnitKilledVisual.cached_data
		var visual: UnitKilledVisual = cache.get_data() as UnitKilledVisual
		visual.added_to_stage(_instance.sens.position.x, _instance.sens.position.y, Callable(), _instance)
		if ChatController.inst != null:
			ChatController.inst.message(class_name_ + " was killed.")

func give_frag() -> void:
	num_killed += 1
	killed_enemy()

func killed_enemy() -> void:
	pass

# 反编译破损，按 P-code 重建
# 结论：反编译的 "FR_KNIGHT 出现两次、缺 FR_SWORDMASTER" 是反编译错误。P-code（@0037..@0056）依次比较
# kind == FR_WARRIOR、FR_SWORDMASTER、FR_KNIGHT、再 FR_KNIGHT（重复一次），即 FR_WARRIOR/FR_SWORDMASTER/FR_KNIGHT
# 会 --unit_numWarriors；FR_KING 在 addToGame 里 ++unit_numWarriors 但这里不减（原版不对称，保留）。
func minus_units() -> void:
	if friendly:
		if kind == FR_WARRIOR or kind == FR_SWORDMASTER or kind == FR_KNIGHT or kind == FR_KNIGHT:
			unit_num_warriors -= 1
		if kind == FR_ARCHER or kind == FR_CROSSBOW or kind == FR_SNIPER:
			unit_num_archers -= 1
		if kind == FR_BLUEMAGE or kind == FR_BLACKMAGE or kind == FR_REDMAGE:
			unit_num_mages -= 1
		if kind == FR_PRIEST or kind == FR_BLESSER or kind == FR_HEALER:
			unit_num_priests -= 1
		if kind == FR_ROGUE or kind == FR_ASSASIN or kind == FR_SABOTEUR:
			unit_num_rogues -= 1

func after_being_hit_handler() -> void:
	pass

func calculate_death_cost(param1: LivingObject) -> void:
	var cost: int = param1.money_cost
	GameUniverse.inst.set_money(cost)

func special_being_hit_melee_handler(param1: int, _param2: LivingObject) -> int:
	return param1

func check_abilities() -> bool:
	return false

func search_target(_param1: bool = false) -> void:
	pass

func unselect() -> void:
	if ring != null:
		ring.start_removing()
	selected = false

func set_route(param1: int, param2: Variant = null) -> void:
	cur_route_number = param1
	var path_route: MapRoute = GameUniverse.inst.a_path_map[param1] as MapRoute
	a_soldier_main_route = path_route.a_points.duplicate()
	var i: int = 0
	while i < a_soldier_main_route.size():
		var pt: Vector2 = a_soldier_main_route[i]
		var nx: float = pt.x - 20 + floor(RWRandom.rand() * 40)
		var ny: float = pt.y - 20 + floor(RWRandom.rand() * 40)
		a_soldier_main_route[i] = Vector2(nx, ny)  # splice(i, 1, new Point(nx, ny))
		i += 1
	if param2 == null:
		var first_point: Vector2 = a_soldier_main_route[0]
		set_coordinates(first_point.x, first_point.y)
		set_destination(first_point)
		if friendly == true and a_soldier_main_route.size() > 2:
			var pick: int = RWRandom.rand_range(1, a_soldier_main_route.size() - 1)
			var picked: Vector2 = a_soldier_main_route[pick]
			# splice(1, length, picked)：从下标 1 起全部替换为 picked
			while a_soldier_main_route.size() > 1:
				a_soldier_main_route.pop_back()
			a_soldier_main_route.push_back(picked)
	else:
		var start: Vector2 = param2
		set_coordinates(start.x, start.y)
		set_destination(start)
	cur_stanse = NONE
	update()

func in_field(param1: LivingObject) -> bool:
	var px: float = param1.position.x
	var py: float = param1.position.y
	if px < 30 or px > 670 or py < 30 or py > 595:
		return false
	return true

func set_target(param1: LivingObject, _param2: bool = true) -> void:
	remove_distant_attacker()
	cur_target = param1
	if param1 == null:
		main_alg_check_battle_existence()

func set_battle(param1: Battle, param2: Battle = null) -> void:
	if param2 != null:
		if param1 == null:
			if cur_battle == param2:
				cur_battle = null
	else:
		cur_battle = param1

func set_death_time(param1: int) -> void:
	death_time = param1

func set_self_destruct() -> void:
	var idx: int = a_friend_warriors.find(_instance)
	if idx >= 0:
		a_friend_warriors.remove_at(idx)
	idx = a_friend_ranged.find(_instance)
	if idx >= 0:
		a_friend_ranged.remove_at(idx)
	GameUniverse.inst.remove_from_death_array(_instance)
	unit_removed_from_death_array()
	RWTween.to(sprite, 0.3, {"alpha": 0, "onComplete": unit_remover})
	kill_ring()

func unit_removed_from_death_array() -> void:
	pass

func set_selected() -> void:
	Sounds.inst.play(s.get_sound(SoundLibrary.SELECTION), false, 0, 0.4, position.x, SoundLibrary.SELECTION)
	selected = true
	RWTween.from(sprite, 0.3, {"scaleY": 0.9})
	if ring == null:
		ring = RingSelectorEx.new(_instance)
		sprite.add_child(ring)
		sprite.move_child(ring, 0)
		ring.show_behind_parent = true  # sprite.addChildAt(ring, 0)：在位图之后
	else:
		ring.reset_ring()

func kill_ring() -> void:
	if ring != null:
		sprite.remove_child(ring)
		ring = null

func upgrade_clicked() -> void:
	var done := UpgradeCompleted.new(cur_level)
	add_child(done)
	done.position.x = sens.position.x
	done.position.y = sens.position.y - sens_height / 2 - 12
	upgrade()

func healed_effect() -> void:
	var cache: SimpleCache = HealEffectEx.cached_data
	var effect: HealEffectEx = cache.get_data() as HealEffectEx
	effect.added_to_stage(sens.position.x, sens.position.y, Callable(), _instance)

func get_route() -> Array:
	return a_soldier_main_route.duplicate()

func get_route_number() -> int:
	return cur_route_number

## 注意：原版直接令 aSoldierMainRoute = param1（共用同一数组引用），不拷贝。
func duplucated_route(param1: Array) -> void:
	a_soldier_main_route = param1

func update_stance_after_upgrade_to_pro(param1: int) -> void:
	set_stance(param1)

func stunned(param1: int) -> void:
	is_stunned = true
	stun_counter = param1
	add_to_buffs_pens(BP_STUNNED)
	ui_health_bar.add_icon(MiniIcons.cSTUN)

func slowed(param1: int) -> void:
	is_slowed = true
	slow_counter = param1
	add_to_buffs_pens(BP_SLOW)
	ui_health_bar.add_icon(MiniIcons.cSLOW)

func add_to_buffs_pens(param1: String) -> void:
	var idx: int = a_buffs_and_penalties.find(param1)
	if idx < 0:
		a_buffs_and_penalties.push_back(param1)

func broken_arrows(param1: int) -> void:
	is_broken_arrows = true
	broken_arrows_counter = param1
	add_to_buffs_pens(BP_BREAKARROWS)
	ui_health_bar.add_icon(MiniIcons.cBREAKARROW)

func weak_spotted(param1: float, param2: float) -> void:
	has_weak_spot = true
	cur_weak_mod = param1
	time_to_weak_spot = int(param2)
	add_to_buffs_pens(BP_WEAKSPOT)
	ui_health_bar.add_icon(MiniIcons.cFOCUSSHOOT)

func poisoned(param1: int, param2: int) -> void:
	if cur_health > 0:
		add_to_buffs_pens(BP_POISONED)
		is_poisoned = true
		poison_timer = param1
		poison_strength = param2
		ui_health_bar.add_icon(MiniIcons.cPOISON)

func set_battle_stance(param1: int) -> void:
	set_stance(FIGHTING)
	_show_frame(param1)

func get_cur_frame() -> int:
	return cur_frame

func set_stance_after_upgrade(param1: int) -> void:
	set_stance(param1)

func reanimate_dead() -> void:
	modulate.a = 1.0
	sens_mouse_enabled = true
	play_head_stance = PLAYING
	can_remove_from_units_array = false
	death_time = 0
	cur_health = health
	cur_stanse = WALKING
	reset_current_frame()
	if friendly:
		if is_npc == false:
			_g_add("num_soldiers_dead", -1)
		set_stance(STAND)
	else:
		set_stance(STAND)
		modify_first_point()
	o_pursue_counter = {}
	GameUniverse.inst.unit_resurrected(_instance)
	current_bm = bmp_stay
	cur_frame = 0
	_show_frame(cur_frame)
	if kind == UNDEAD_VAMPIRE_KING:
		stunned(15)
		reanimated()
	else:
		stunned(60)

func reanimated() -> void:
	pass

func clear_route() -> void:
	a_soldier_main_route.clear()  # splice(0)
	can_be_selected = true
	set_destination(Vector2(_x, _y), true)
	if AS3.aborted:
		return

func blessed(param1: int, param2: float) -> void:
	is_blessed = true
	bless_counter = param1
	bless_modifier = param2
	add_to_buffs_pens(BP_BLESS)
	ui_health_bar.add_icon(MiniIcons.cBLESSBUFF)

func cursed(param1: int, param2: float) -> void:
	is_cursed = true
	curse_counter = param1
	curse_modifier = param2
	var old_cur_health: int = cur_health
	var old_health: int = _health
	health = int(floor(old_health * (1 - curse_modifier)))
	cur_health = proportional_reset_int(cur_health, old_cur_health, old_health, _health)
	if cur_health <= 0:
		cur_health = 1
	add_to_buffs_pens(BP_CURSE)
	ui_health_bar.add_icon(MiniIcons.cCURSE)

func trapped_in_ice(param1: int, param2: int) -> void:
	is_trapped_in_ice = true
	freeze_counter = param1
	cur_ice_damage = param2
	add_to_buffs_pens(BP_ICED)

func suppressed(param1: int, param2: float) -> void:
	is_suppressed = true
	suppress_counter = param1
	suppress_ratio = param2
	add_to_buffs_pens(BP_SUPPRESS)
	ui_health_bar.add_icon(MiniIcons.cWEAK)

func enchant_weapon(param1: int, param2: float) -> void:
	add_to_buffs_pens(BP_ENCHANT)
	is_enchanted = true
	enchant_timer = param1
	enchant_ratio = param2
	ui_health_bar.add_icon(MiniIcons.cWEAPONBUFF)

func armor_corrupted(param1: int, param2: float) -> void:
	is_corrupted = true
	corrupt_counter = param1
	corrupt_ratio = param2
	add_to_buffs_pens(BP_CORRUPT)
	ui_health_bar.add_icon(MiniIcons.cCORRUPT)

func weakened(param1: int) -> void:
	add_to_buffs_pens(BP_WEAK)
	is_weakened = true
	weaken_counter = param1
	ui_health_bar.add_icon(MiniIcons.cWEAK)

func harm_resisted(param1: float) -> void:
	add_to_buffs_pens(BP_HARMRES)
	max_harm_resist_time = int(param1)
	is_harm_resisted = true
	ui_health_bar.add_icon(MiniIcons.cRESIST)

# 反编译破损，按 P-code 重建：if(false){goto} 为空操作，结构按反编译的 if/else 嵌套即可。
func can_attack_enemy(param1: LivingObject = null) -> bool:
	var can_attack := false
	if is_priest:
		can_attack = false
	elif in_action == true:
		if cur_target != param1:
			if param1 != null:
				if attacking_with_ranged_weapon == true:
					can_attack = true
				elif param1.get_cur_battle == cur_battle:
					can_attack = true
				else:
					check_flee_battle()
					if AS3.aborted:
						return false
					if cur_health > 0:
						can_attack = true
			else:
				check_flee_battle()
				if AS3.aborted:
					return false
				if cur_health > 0:
					can_attack = true
	if can_attack == true:
		if param1 != null:
			var other_battle: Battle = param1.get_cur_battle
			if other_battle != null:
				if other_battle.is_defender(param1) == true:
					if other_battle.get_num_attackers == 6:
						can_attack = false
	return can_attack

func confuse(param1: int) -> void:
	is_confused = true
	confused_counter = param1
	add_to_buffs_pens(BP_CONFUSE)

func pursuit_target() -> void:
	if is_archer == true:
		if cur_battle == null:
			archer_goto_target = true
			attacking_with_ranged_weapon = true

var get_attack_speed: int:
	get:
		return attack_interval

var get_ranged_attack_speed: int:
	get:
		return ranged_attack_interval

var get_kind: int:
	get:
		return kind

var get_xp: int:
	get:
		return cur_experience

var get_level: int:
	get:
		return cur_level

var get_xp_until_upgrade: int:
	get:
		return exp_to_next_level

var get_class_name: String:
	get:
		return class_name_

## getName（Node.get_name 冲突，加下划线）
var get_name_: String:
	get:
		return unit_name

var get_cur_target: LivingObject:
	get:
		return cur_target

## 反编译中 unitRemover 的 try/catch 块（§§push(err)）只是 catch 空体。
## 原版 getChildAt(2/3) 的子节点：VisualsTemplate 调 endGameRemover，其余 MovieClip 直接移除。
func unit_remover() -> void:
	GameUniverse.inst.remove_from_display_object(_instance)
	ui_health_bar.reset_icons()
	if ui_health_bar.friendly:
		if ui_health_bar.get_parent() != null:
			ui_health_bar.get_parent().remove_child(ui_health_bar)
		while get_child_count() > 2:
			var child: Node = get_child(2)
			if child is VisualsTemplate:
				(child as VisualsTemplate).end_game_remover()
			else:
				child.get_parent().remove_child(child)
	else:
		while get_child_count() > 3:
			var child2: Node = get_child(3)
			if child2 is VisualsTemplate:
				(child2 as VisualsTemplate).end_game_remover()
			else:
				child2.get_parent().remove_child(child2)
	if _instance.get_parent() != null:
		_instance.get_parent().remove_child(_instance)
	return_to_cache()

func add_betray_icon(param1: int) -> void:
	cur_time_to_possess = param1
	add_to_buffs_pens(BP_POSSESS)
	ui_health_bar.add_icon(MiniIcons.cMINDCONTROL)
	old_route = a_soldier_main_route.duplicate()
	clear_route()
	is_possessed = true
	will_be_soon_possessed = false
	ui_health_bar.add_icon(MiniIcons.cMINDCONTROL)
	if friendly:
		ui_health_bar.top.goto_and_stop(1)
	else:
		ui_health_bar.top.goto_and_stop(2)

func reset_obstacles() -> void:
	a_obstacle_route = []

func clear_data_after_game_end() -> void:
	GameUniverse.inst.make_unit_dead(_instance)
	GameUniverse.inst.remove_from_death_array(_instance)
	kill_ring()
	unit_remover()

## sprite_bm.alpha
func set_alpha(param1: float) -> void:
	if sprite_bm != null:
		sprite_bm.self_modulate.a = param1

func update_stats() -> void:
	pass

## param1 是 units.xml 中的单位节点（原版 unitXML.warrior 这类 XMLList），例如 RWXml 根 `data` 的 child("warrior")。
func set_stats_from_xml(param1: RWXml) -> void:
	class_name_ = param1.text("className")
	a_exp_levels = _xml_triple(param1, "Experience")
	a_health_levels = _xml_triple(param1, "Health")
	a_armor_levels = _xml_triple(param1, "Armor")
	a_resist_levels = _xml_triple(param1, "Resist")
	a_armor_piercing_melee_levels = _xml_triple(param1, "armorPierceMelee")
	a_armor_piercing_ranged_levels = _xml_triple(param1, "armorPierceRanged")
	a_magic_piercing_levels = _xml_triple(param1, "magicPierce")
	a_attack_interval_levels = _xml_triple(param1, "attackSpeedMelee")
	a_ranged_attack_interval_levels = _xml_triple(param1, "attackSpeedRanged")
	a_ranged_shoot_accuracy = _xml_triple(param1, "accuracy")
	a_melee_damage_levels = _xml_triple(param1, "damageMelee")
	a_ranged_damage_levels = _xml_triple(param1, "damageRanged")
	a_walk_speed_levels = _xml_triple(param1, "walkSpeed")

static func _xml_triple(node: RWXml, tag: String) -> Array:
	var sub := node.child(tag)
	return [sub.to_number("one"), sub.to_number("two"), sub.to_number("three")]

func return_to_cache() -> void:
	pass

var get_death_time: int:
	get:
		return death_time

var cur_armor: float:
	get:
		return _cur_armor
	set(value):
		_cur_armor = value

var get_cur_battle: Battle:
	get:
		return cur_battle

var has_target: bool:
	get:
		var result := false
		if cur_target != null:
			result = true
		return result

var cur_health: int:
	get:
		return _cur_health
	set(value):
		_cur_health = value

var damage: int:
	get:
		return _damage
	set(value):
		cur_damage = value
		_damage = value

var armor: float:
	get:
		return _max_armor
	set(value):
		_max_armor = value
		cur_armor = value

var health: int:
	get:
		return _health
	set(value):
		_cur_health = value
		_health = value

var ranged_damage: int:
	get:
		return _ranged_damage
	set(value):
		cur_ranged_damage = value
		_ranged_damage = value

# 反编译破损，按 P-code 重建
# 结论：当前不是 DEAD 时——目标 DEAD 以外、且当前处于 FIGHTING/CASTING/RANGED_SHOOT 而新姿态不是 CASTING、
# 且 curFrame != 0 时，不立即切换：attackStanceReleaseCounter = totalFrames - curFrame（FIGHTING 再 +10），
# nextStance = param1，直接返回（由 mainAlgUpdateSprite 的收尾倒数后真正切换）；否则 curStanse = param1，
# 按姿态换 currentBM（DEAD 同时关闭 sens 点击）；currentBM 变化时 curFrame = 0，STAND/WALKING 再取随机起始帧
# randRange(0, totalFrames-1)（消耗一次 rand），playHeadStance = PLAYING。已是 DEAD 时：currentBM 不是 BMPDead 则
# 换成 BMPDead、curFrame = 0、playHeadStance = PLAYING；两种情况都关闭 sens.mouseEnabled。
func set_stance(param1: int) -> void:
	if cur_stanse != DEAD:
		if param1 != DEAD:
			if (cur_stanse == FIGHTING or cur_stanse == CASTING or cur_stanse == RANGED_SHOOT) and param1 != CASTING:
				if cur_frame != 0:
					if cur_stanse == FIGHTING:
						attack_stance_release_counter = current_bm.num_frames - cur_frame + 10
					else:
						attack_stance_release_counter = current_bm.num_frames - cur_frame
					next_stance = param1
					return
		cur_stanse = param1
		var old_bm: BmpFrames = current_bm
		match param1:
			STAND:
				current_bm = bmp_stay
			WALKING:
				current_bm = bmp_walk
			FIGHTING:
				current_bm = bmp_attack
			CASTING:
				current_bm = bmp_casting
			DEAD:
				current_bm = bmp_dead
				sens_mouse_enabled = false  # removeEventListener(CLICK) + mouseEnabled = false
			RANGED_SHOOT:
				current_bm = bmp_ranged
		if current_bm != old_bm:
			cur_frame = 0
			if cur_stanse == STAND or cur_stanse == WALKING:
				cur_frame = RWRandom.rand_range(0, current_bm.num_frames - 1)
			play_head_stance = PLAYING
		return
	if current_bm != bmp_dead:
		current_bm = bmp_dead
		cur_frame = 0
		play_head_stance = PLAYING
	sens_mouse_enabled = false

var get_stance: int:
	get:
		return cur_stanse

var shoot_accuracy_max: float:
	get:
		return _shoot_accuracy_max
	set(value):
		_shoot_accuracy_max = value
		shoot_accuracy = value

var max_walk_speed: float:
	get:
		return _max_walk_speed
	set(value):
		walk_speed = value
		_max_walk_speed = value

var max_magic_resist: float:
	get:
		return _max_magic_resist
	set(value):
		_max_magic_resist = value
		cur_magic_resist = value

var cur_magic_resist: float:
	get:
		return _cur_magic_resist
	set(value):
		_cur_magic_resist = value

var armor_piercing_melee: float:
	get:
		return _armor_piercing_melee
	set(value):
		_armor_piercing_melee = value

var cur_damage: int:
	get:
		return _cur_damage
	set(value):
		_cur_damage = value

var cur_ranged_damage: int:
	get:
		return _cur_ranged_damage
	set(value):
		_cur_ranged_damage = value

var is_harm_resisted: bool:
	get:
		return _is_harm_resisted
	set(value):
		_is_harm_resisted = value

var in_hide: bool:
	get:
		return _in_hide
	set(value):
		_in_hide = value

var money_cost: int:
	get:
		return _money_cost
	set(value):
		_money_cost = value

var is_slowed: bool:
	get:
		return _is_slowed
	set(value):
		_is_slowed = value

var is_poisoned: bool:
	get:
		return _is_poisoned
	set(value):
		_is_poisoned = value

var is_corrupted: bool:
	get:
		return _is_corrupted
	set(value):
		_is_corrupted = value

var is_suppressed: bool:
	get:
		return _is_suppressed
	set(value):
		_is_suppressed = value

var is_broken_arrows: bool:
	get:
		return _is_broken_arrows
	set(value):
		_is_broken_arrows = value

## 原版 isConfused 的存取器读写的是 _isSilenced 字段
var is_confused: bool:
	get:
		return _is_silenced
	set(value):
		_is_silenced = value

var armor_piercing_ranged: float:
	get:
		return _armor_piercing_ranged
	set(value):
		_armor_piercing_ranged = value

var magic_piercing: float:
	get:
		return _magic_piercing
	set(value):
		_magic_piercing = value

var special_one: SpecialTemplate:
	get:
		return _special_one
	set(value):
		_special_one = value

var special_two: SpecialTemplate:
	get:
		return _special_two
	set(value):
		_special_two = value

var special_zero: SpecialTemplate:
	get:
		return _special_zero
	set(value):
		_special_zero = value

var zero_point: Variant:
	get:
		return _zero_point
	set(value):
		_zero_point = value

var is_weakened: bool:
	get:
		return _is_weakened
	set(value):
		_is_weakened = value

var upgr_cost: int:
	get:
		return _upgr_cost
	set(value):
		_upgr_cost = value

var cur_weak_mod: float:
	get:
		return _cur_weak_mod
	set(value):
		_cur_weak_mod = value

var cur_group: float:
	get:
		return _cur_group
	set(value):
		_cur_group = value
		ui_health_bar.set_group(cur_group)

var walk_speed: float:
	get:
		return _walk_speed
	set(value):
		_walk_speed = value

func set_coordinates(param1: float, param2: float) -> void:
	_x = param1
	_y = param2
	position = Vector2(AS3.round(param1), AS3.round(param2))

## 原版 free(Event)：只移除监听，节点已无监听可移，保留空实现（Object.free 冲突，加下划线）
func free_(_e: Variant = null) -> void:
	pass

func set_new_route(param1: Array) -> void:
	a_soldier_main_route = param1
	var first_point: Vector2 = a_soldier_main_route[0]
	set_destination(first_point)

func modify_first_point() -> void:
	if a_soldier_main_route.size() > 1:
		a_soldier_main_route.pop_front()  # shift()
		var first_point: Vector2 = a_soldier_main_route[0]
		set_destination(first_point)

func nullify_target() -> void:
	cur_target = null

func unlock_abils_set_max_level() -> void:
	if _special_one != null:
		_special_one.unlock_abil_set_max_level()
	if special_two != null:
		_special_two.unlock_abil_set_max_level()
	ext_unlock = true

func set_experience(param1: float) -> void:
	cur_experience = int(param1)

func set_external_position(param1: Vector2) -> void:
	set_coordinates(param1.x, param1.y)
	a_soldier_main_route = []
	set_destination(param1)
	if friendly:
		can_be_selected = true

## setVisible（CanvasItem.set_visible 冲突，加下划线）
func set_visible_() -> void:
	visible = true

func update_dead() -> void:
	pass

func set_random_abils_time() -> void:
	if _special_one != null:
		_special_one.set_random_time()
	if special_two != null:
		_special_two.set_random_time()

func set_ext_route(param1: Array) -> void:
	a_soldier_main_route = param1.duplicate()

func change_speed(param1: float) -> void:
	walk_speed = param1

func update_health_bar() -> void:
	main_alg_update_health_bar()

# 反编译破损，按 P-code 重建：§§push/while(true) 是对 `if(rangedCircle !== null)` 的混淆，
# 实际语义为 rangedCircle 非空时：杀掉其 tween，alpha = 0.6，scaleX = scaleY = 1，
# 尺寸 searchRadius * searchRadiusRangedModifier * 2，可见，TweenMax.from(0.2s, width/height 10, Elastic.easeOut)。
func show_circle() -> void:
	if ranged_circle != null:
		RWTween.kill_tweens_of(ranged_circle)
		ranged_circle.modulate.a = 0.6
		ranged_circle.scale = Vector2.ONE
		var diameter: float = search_radius * search_radius_ranged_modifier * 2
		ranged_circle.visible = true
		_set_circle_size(diameter, diameter)
		RWTween.from(ranged_circle, 0.2, {"width": 10, "height": 10, "ease": RWEase.elastic_ease_out})

func hide_circle() -> void:
	if ranged_circle != null:
		RWTween.kill_tweens_of(ranged_circle)
		ranged_circle.visible = true
		RWTween.to(ranged_circle, 0.2, {"width": 1, "height": 1, "autoAlpha": 0})

func set_free_move() -> void:
	if stand_still == true:
		var cache: SimpleCache = FreeMoveVisual.cached_data
		var visual: FreeMoveVisual = cache.get_data() as FreeMoveVisual
		visual.added_to_stage(sens.position.x, sens.position.y, Callable(), _instance)
	stand_still = false

func set_hold_ground_move() -> void:
	if stand_still == false:
		var cache: SimpleCache = HoldGroundVisual.cached_data
		var visual: HoldGroundVisual = cache.get_data() as HoldGroundVisual
		visual.added_to_stage(sens.position.x, sens.position.y, Callable(), _instance)
	stand_still = true
