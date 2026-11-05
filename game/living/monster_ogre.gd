# 移植自 S/gameCore/living/monsterOgre.as
class_name MonsterOgre
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
var strike_hit: bool  # private

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("OgreStayAni")
	local_bmp_walk = BmpFrames.from_symbol("OgreWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("OgreAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("OgreDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(30)
static func init_resources() -> void:
	load_frames()
	cache(30)

static func cache(param1: int = 30) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(MonsterOgre, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("ogre")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = MONSTER_OGRE
	friendly = false
	sens_class = "OgreSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_health_below_zero_handler() -> void:
	GlobalData.inst.a4_ogres_killed += 1
	if strike_hit == false:
		GlobalData.inst.a14_ogre_killed_but_not_hit += 1
	# 原版疑点，原样保留：play(sound, false, x, 0.4) 把 x 传给了 startTime，volume 取默认 1
	Sounds.inst.play(s.get_sound(s.OGRE_DEAD), false, position.x, 0.4)
	super.after_health_below_zero_handler()

func enemy_hit_sound() -> void:
	# 同上：x 落在 startTime 参数位置
	Sounds.inst.play(s.get_sound(s.OGRE_PUNCH), false, position.x, 0.45)

func special_before_damaging_enemy_handler() -> void:
	if special_one != null:
		var loc1: SpecOgreStun = special_one as SpecOgreStun
		loc1.check_stun(cur_target, _instance)
	strike_hit = true

func after_adding_new_unit_handler() -> void:
	strike_hit = false
	special_one = SpecOgreStun.new(friendly)
