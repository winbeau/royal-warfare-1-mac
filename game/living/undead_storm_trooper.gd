# 移植自 S/gameCore/living/undeadStormTrooper.as
class_name UndeadStormTrooper
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
	local_bmp_stay = BmpFrames.from_symbol("darthStormTrooperStandAni")
	local_bmp_walk = BmpFrames.from_symbol("darthStormTrooperMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("darthStormTrooperAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("darthStormTrooperDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(40)
static func init_resources() -> void:
	load_frames()
	cache(40)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadStormTrooper, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("darth_trooper")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_STORMTROOPER
	friendly = false
	sens_class = "darthStormTrooperSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	money_cost = unit_cost
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func special_play_head_start_playing_handler() -> void:
	if special_two != null:
		var loc1: SpecRoundAttack = special_two as SpecRoundAttack
		loc1.check_wave(_instance)

func special_before_damaging_enemy_handler() -> void:
	var loc1: bool = false

func special_being_hit_melee_handler(param1: int, param2: LivingObject) -> int:
	var loc3: int = param1
	if special_one != null:
		var loc4: SpecParry = special_one as SpecParry
		if loc4.check_parry(_instance, param1, param2) == true:
			loc3 = 0
	return loc3

func after_adding_new_unit_handler() -> void:
	special_one = SpecParry.new(friendly)
