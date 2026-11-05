# 移植自 S/gameCore/living/friendScoutAssasin.as
class_name FriendScoutAssasin
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 250

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendScoutAssasin, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("assasinStandAni")
	local_bmp_walk = BmpFrames.from_symbol("assasinMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("assasinAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("assasinDeadAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendScoutAssasin, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_ASSASIN
	friendly = true
	basic_unit = false
	class_kind = CLASS_THIEF
	sens_class = "rogueSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("assassin")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

var back_stab_from_new_battle: bool = false

func killed_enemy() -> void:
	GlobalData.inst.a8_killed_by_rogues += 1

func special_before_damaging_enemy_handler() -> void:
	check_back_stab()
	back_stab_from_new_battle = false
	super.special_before_damaging_enemy_handler()

func special_play_head_start_playing_handler() -> void:
	if special_one != null:
		var spec: SpecBackStab = special_one as SpecBackStab
		spec.check_wave(_instance)

func check_back_stab() -> void:
	if special_one != null:
		var spec: SpecBackStab = special_one as SpecBackStab
		spec.check_back_stab(cur_target, cur_damage, _instance, back_stab_from_new_battle)

func after_making_a_new_battle_from_old_one() -> void:
	back_stab_from_new_battle = true

func special_being_hit_melee_handler(param1: int, _param2: LivingObject) -> int:
	return use_miss_ability(param1)

func use_miss_ability(param1: int) -> int:
	var result: int = param1
	if result > 0:
		if special_two != null:
			var spec: SpecMissAssasin = special_two as SpecMissAssasin
			if spec.is_missed(_instance) == true:
				result = 0
	else:
		result = param1
	return result

func special_being_hit_ranged_handler(param1: int, _param2: LivingObject) -> int:
	return use_miss_ability(param1)

func after_adding_new_unit_handler() -> void:
	is_rogue = true
	back_stab_from_new_battle = false
	special_one = SpecBackStab.new(friendly)
	special_two = SpecMissAssasin.new(friendly)
