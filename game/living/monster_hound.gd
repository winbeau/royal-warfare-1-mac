# 移植自 S/gameCore/living/monsterHound.as
class_name MonsterHound
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
	local_bmp_stay = BmpFrames.from_symbol("mosterHoundStandAni")
	local_bmp_walk = BmpFrames.from_symbol("mosterHoundMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("mosterHoundAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("mosterHoundDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(70)
static func init_resources() -> void:
	load_frames()
	cache(70)

static func cache(param1: int = 80) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(MonsterHound, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("hound")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = MONSTER_HOUND
	friendly = false
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	sens_class = "mosterHoundSens"
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func enemy_hit_sound() -> void:
	if RWRandom.rand() > 0.7:
		Sounds.inst.play(s.get_sound_from_stack(s.BIG_CREATURE_ATTACK), false, 0, 0.33, position.x, s.BIG_CREATURE_ATTACK)
	else:
		Sounds.inst.play(s.get_sound_from_stack(s.CREATURE_ATTACK), false, 0, 0.37, position.x, s.CREATURE_ATTACK)
