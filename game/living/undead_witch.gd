# 移植自 S/gameCore/living/undeadWitch.as
class_name UndeadWitch
extends MageClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var _cached_unit_data: SimpleCache = null
## 懒加载：首次读取时按 Main.loadResources 中对应 case 的对象池数量创建
static var cached_unit_data: SimpleCache:
	get:
		if _cached_unit_data == null:
			init_resources()
		return _cached_unit_data
	set(value):
		_cached_unit_data = value
static var unit_cost: int = 0
static var _frames_loaded: bool = false

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("undeadWitchStayAni")
	local_bmp_walk = BmpFrames.from_symbol("undeadWitchWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("undeadWitchAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("undeadWitchDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("undeadWitchShootAni")
	local_bmp_cast = BmpFrames.from_symbol("undeadWitchCastAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(30)
static func init_resources() -> void:
	load_frames()
	cache(30)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadWitch, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("witch")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_WITCH
	friendly = false
	sens_class = "undeadWitchSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_health_below_zero_handler() -> void:
	GlobalData.inst.a3_witches_killed += 1
	super.after_health_below_zero_handler()

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.MAGE_BLUE_STRIKE), false, 0, 0.4, position.x, s.MAGE_STRIKE)

func check_abilities() -> bool:
	var loc1: bool = false
	if cur_stanse != FIGHTING:
		loc1 = check_ice()
		if loc1 == false:
			loc1 = check_curse()
	return loc1

# private
func check_ice() -> bool:
	var loc1: bool = false
	if cur_stanse == STAND or cur_stanse == RANGED_SHOOT:
		if special_one != null:
			if special_one.can_use_special():
				if cur_target != null:
					var loc2: SpecIce = special_one as SpecIce
					loc1 = loc2.check_ice(_instance as MageClass, cur_target)
					# 原版 `while(loc1 == true) { ...; break; }` 等价于 if
					if loc1 == true:
						got_experience(1)
						cur_spell = 1
	return loc1

func casting_done() -> void:
	if cur_spell == 1:
		if cur_target != null:
			var loc1: SpecIce = special_one as SpecIce
			loc1.set_ice()
	elif cur_spell == 2:
		var loc2: SpecCurse = special_two as SpecCurse
		loc2.set_curse(_instance)

# private
func check_curse() -> bool:
	var loc1: bool = false
	if special_two != null:
		if cur_target != null:
			var loc2: SpecCurse = special_two as SpecCurse
			loc1 = loc2.check_curse_bless(_instance as MageClass, cur_target)
			# 原版 `while(loc1 == true) { ...; break; }` 等价于 if
			if loc1 == true:
				cur_spell = 2
				got_experience(1)
	return loc1

func after_adding_new_unit_handler() -> void:
	special_one = SpecIce.new(friendly)
	special_two = SpecCurse.new(friendly)
