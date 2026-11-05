# 移植自 S/gameCore/living/undeadGhost.as
class_name UndeadGhost
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var _cached_unit_data: SimpleCache = null
## 懒加载：首次读取时按 Main.loadResources 中对应 case 的对象池数量创建
static var cached_unit_data: SimpleCache:
	get:
		if _cached_unit_data == null:
			init_resources()
		return _cached_unit_data
	set(value):
		_cached_unit_data = value
static var upgrade_cost: int
static var unit_cost: int = 250
static var _frames_loaded: bool = false
var back_stab_from_new_battle: bool = false  # private，原版未使用

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("undeadGhostStayAni")
	local_bmp_walk = BmpFrames.from_symbol("undeadGhostWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("undeadGhostAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("undeadGhostDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(30)
static func init_resources() -> void:
	load_frames()
	cache(30)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadGhost, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("ghost")
	set_stats_from_xml(loc1)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_GHOST
	friendly = false
	basic_unit = false
	sens_class = "undeadGhostSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func special_being_hit_melee_handler(param1: int, param2: LivingObject) -> int:
	return use_miss_ability(param1)

# private
func use_miss_ability(param1: int) -> int:
	var loc2: int = param1
	if special_two != null:
		var loc3: SpecMissGhost = special_two as SpecMissGhost
		if loc3.is_missed(_instance) == true:
			loc2 = 0
	return loc2

func special_being_hit_ranged_handler(param1: int, param2: LivingObject) -> int:
	if param2 != null:
		if param2.is_mage == true:
			return param1
		return use_miss_ability(param1)
	return param1

func after_adding_new_unit_handler() -> void:
	special_two = SpecMissGhost.new(friendly)
