# 移植自 S/gameCore/living/monsterShieldKamikaze.as
class_name MonsterShieldKamikaze
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
static var unit_cost: int = 0
static var _frames_loaded: bool = false

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("sKamikazeStayAni")
	local_bmp_walk = BmpFrames.from_symbol("sKamikazeWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("sKamikazeAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("sKamikazeDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(50)
static func init_resources() -> void:
	load_frames()
	cache(50)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(MonsterShieldKamikaze, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("shieldKamikaze")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = MONSTER_KAMI_SHIELD
	friendly = false
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	sens_class = "sKamikazeSens"
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func special_before_damaging_enemy_handler() -> void:
	cur_target = null
	bring_damage(1000, _instance, false, false)

func after_health_below_zero_handler() -> void:
	var loc1: SpecSelfDestruct = special_zero as SpecSelfDestruct
	loc1.self_destruct(_instance, cur_damage)

func after_adding_new_unit_handler() -> void:
	special_zero = SpecSelfDestruct.new(friendly)
	special_zero.unlock_special()
	is_kamikaze = true
