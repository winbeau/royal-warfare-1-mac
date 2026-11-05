# 移植自 S/gameCore/living/undeadSkeletionArcher.as
class_name UndeadSkeletionArcher
extends RangedFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
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
	local_bmp_stay = BmpFrames.from_symbol("skeletonArcherStandAni")
	local_bmp_walk = BmpFrames.from_symbol("skeletonArcherMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("skeletonArcherAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("skeletonArcherDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("skeletonArcherShootAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(50)
static func init_resources() -> void:
	load_frames()
	cache(50)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadSkeletionArcher, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("skeleton_archer")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_SKELETON_ARCHER
	friendly = false
	sens_class = "undeadSkeletonSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_health_below_zero_handler() -> void:
	var loc1: GlobalData = GlobalData.inst
	var loc2: float = loc1.a5_archers_killed + 1
	loc1.a5_archers_killed = int(loc2)
	GlobalData.inst.a6_skeletons_killed += 1
	super.after_health_below_zero_handler()

func after_adding_new_unit_handler() -> void:
	special_two = SpecMissSkeleton.new(friendly)
	search_radius_ranged_modifier = 3

# private
func use_miss_ability(param1: int) -> int:
	var loc2: int = param1
	if special_two != null:
		var loc3: SpecMissSkeleton = special_two as SpecMissSkeleton
		if loc3.is_missed(_instance) == true:
			loc2 = 0
	return loc2

func special_being_hit_ranged_handler(param1: int, param2: LivingObject) -> int:
	if param2 != null:
		if param2.is_mage == true:
			return param1
		return use_miss_ability(param1)
	return param1
