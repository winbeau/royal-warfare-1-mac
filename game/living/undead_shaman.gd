# 移植自 S/gameCore/living/undeadShaman.as
class_name UndeadShaman
extends PriestClass

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
	local_bmp_stay = BmpFrames.from_symbol("undeadShamanStayAni")
	local_bmp_walk = BmpFrames.from_symbol("undeadShamanWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("undeadShamanAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("undeadShamanDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("undeadShamanShootAni")
	local_bmp_cast = BmpFrames.from_symbol("undeadShamanCastAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(40)
static func init_resources() -> void:
	load_frames()
	cache(40)

static func cache(param1: int = 40) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadShaman, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("shaman")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_SHAMAN
	friendly = false
	basic_unit = true
	is_resurrecter = true
	sens_class = "undeadShamanSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

# private
func raise_friend_checker() -> bool:
	var loc1: bool = false
	if special_two != null:
		var loc2: SpecSmallRessurect = special_two as SpecSmallRessurect
		loc1 = loc2.check_ressurect(a_dead_units, _instance as PriestClass)
	return loc1

func after_adding_new_unit_handler() -> void:
	special_one = SpecStrongHeal.new(friendly)
	special_two = SpecSmallRessurect.new(friendly)

func check_abilities_priest_class() -> bool:
	var loc1: bool = check_strong_heal()
	if loc1 == false:
		loc1 = raise_friend_checker()
	return loc1

# private
func check_strong_heal() -> bool:
	var loc1: bool = false
	if special_one != null:
		if a_friends.size() > 0:
			# aFriends.sortOn("curHealth", Array.NUMERIC)：升序。AS3 的 sortOn 不保证稳定，
			# 此处用 GDScript 的 sort_custom（同样不保证稳定），血量相同的单位次序可能与原版不同。
			a_friends.sort_custom(func(a, b): return a.cur_health < b.cur_health)
			var loc2: LivingObject = a_friends[0] as LivingObject
			var loc3: SpecStrongHeal = special_one as SpecStrongHeal
			loc1 = loc3.check_strong_heal(loc2, _instance as PriestClass, cur_ranged_damage)
			if loc1 == true:
				got_experience(1)
	return loc1
