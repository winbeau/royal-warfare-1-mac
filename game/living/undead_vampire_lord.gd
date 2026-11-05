# 移植自 S/gameCore/living/undeadVampireLord.as
class_name UndeadVampireLord
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
	local_bmp_stay = BmpFrames.from_symbol("VampireLordStayAni")
	local_bmp_walk = BmpFrames.from_symbol("VampireLordWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("VampireLordAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("VampireLordDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(15)
static func init_resources() -> void:
	load_frames()
	cache(15)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadVampireLord, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("vampire_lord")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_VAMPIRE_LORD
	friendly = false
	sens_class = "VampireSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func on_play_head_action() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.HEAVY_SWORD), false, 0, 0.6, position.x, s.HEAVY_SWORD)

# private
func check_weak() -> void:
	var loc1: SpecWeakness = special_two as SpecWeakness
	loc1.check_weak(cur_target)

func special_before_damaging_enemy_handler() -> void:
	var loc1: SpecVampirizm = special_one as SpecVampirizm
	loc1.check_vampirizm(cur_target, _instance)
	check_weak()
	super.special_before_damaging_enemy_handler()

func after_adding_new_unit_handler() -> void:
	special_one = SpecVampirizm.new(friendly)
	special_two = SpecWeakness.new(friendly)
