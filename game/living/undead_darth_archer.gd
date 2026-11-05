# 移植自 S/gameCore/living/undeadDarthArcher.as
class_name UndeadDarthArcher
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
	local_bmp_stay = BmpFrames.from_symbol("darthStormArcherStandAni")
	local_bmp_walk = BmpFrames.from_symbol("darthStormArcherMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("darthStormArcherAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("darthStormArcherDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("darthStormArcherShootAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(40)
static func init_resources() -> void:
	load_frames()
	cache(40)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadDarthArcher, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("storm_archer")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_STORMARCHER
	friendly = false
	sens_class = "darthStormArcherSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_health_below_zero_handler() -> void:
	GlobalData.inst.a5_archers_killed += 1
	super.after_health_below_zero_handler()

func start_ranged_attack() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.ARCHER_PULL), false, 0, 0.16, position.x, s.ARCHER_PULL)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.ARCHER_SHOOT), false, 0, 0.45, position.x, s.ARCHER_SHOOT)

func unlock_specials() -> void:
	pass

func after_adding_new_unit_handler() -> void:
	search_radius_ranged_modifier = 4.2
	special_one = SpecPoison.new(friendly)

func special_missile_hit_target(param1: LivingObject) -> void:
	var loc2: bool = false
	if special_one != null:
		var loc3: SpecPoison = special_one as SpecPoison
		loc2 = loc3.check_poison(param1)
