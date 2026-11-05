# 移植自 S/gameCore/living/friendCrossBowMan.as
class_name FriendCrossBowMan
extends RangedFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 340

static func cache(param1: int = 30) -> void:
	cached_unit_data = SimpleCache.new(FriendCrossBowMan, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("crossbowStandAni")
	local_bmp_walk = BmpFrames.from_symbol("crossbowMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("crossbowAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("crossbowDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("crossbowShootAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendCrossBowMan, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_CROSSBOW
	is_cross_bow_man = true
	class_kind = CLASS_ARCHER
	friendly = true
	sens_class = "crossbowSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("crossbowman")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.CROSSB_SHOOT), false, 0, 0.35, position.x, SoundLibrary.ARCHER_SHOOT)

func after_adding_new_unit_handler() -> void:
	special_one = SpecCritRanged.new(friendly)
	special_two = SpecCorrupt.new(friendly)

func special_missile_hit_target(param1: LivingObject) -> void:
	var crit: bool = false
	if special_one != null:
		var spec_crit: SpecCritRanged = special_one as SpecCritRanged
		crit = spec_crit.check_crit(param1, cur_ranged_damage, _instance)
	if crit == false:
		if special_two != null:
			var spec_corrupt: SpecCorrupt = special_two as SpecCorrupt
			spec_corrupt.check_corrupt(param1)
