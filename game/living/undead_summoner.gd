# 移植自 S/gameCore/living/undeadSummoner.as
class_name UndeadSummoner
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
	local_bmp_stay = BmpFrames.from_symbol("summonerStayAni")
	local_bmp_walk = BmpFrames.from_symbol("summonerWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("summonerAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("summonerDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("summonerShootAni")
	local_bmp_cast = BmpFrames.from_symbol("summonerCastAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(20)
static func init_resources() -> void:
	load_frames()
	cache(20)

static func cache(param1: int = 25) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadSummoner, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("Summoner")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_SUMMONER
	friendly = false
	sens_class = "summonerSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.MAGE_BLACK_STRIKE), false, 0, 0.33, position.x, s.MAGE_STRIKE)

func check_abilities() -> bool:
	var loc1: bool = false
	if special_one != null:
		if cur_stanse != FIGHTING:
			var loc2: SpecSummonSkeletons = special_one as SpecSummonSkeletons
			loc2.check_summon(_instance as MageClass)
	return loc1

func after_adding_new_unit_handler() -> void:
	special_one = SpecSummonSkeletons.new()
