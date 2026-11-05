# 移植自 S/gameCore/living/friendSwordMaster.as
class_name FriendSwordMaster
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 260

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendSwordMaster, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("swordMasterStayAni")
	local_bmp_walk = BmpFrames.from_symbol("swordMasterWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("swordMasterAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("swordMasterDeadAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendSwordMaster, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_SWORDMASTER
	class_kind = CLASS_WARRIOR
	friendly = true
	sens_class = "swordMasterSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("swordmaster")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func special_play_head_start_playing_handler() -> void:
	if special_two != null:
		var spec: SpecRoundAttack = special_two as SpecRoundAttack
		spec.check_wave(_instance)

func special_before_damaging_enemy_handler() -> void:
	if special_two != null:
		var spec: SpecRoundAttack = special_two as SpecRoundAttack
		spec.check_round_attack(cur_target, _instance)

func special_being_hit_melee_handler(param1: int, param2: LivingObject) -> int:
	var result: int = param1
	if special_one != null:
		var spec: SpecParry = special_one as SpecParry
		if spec.check_parry(_instance, param1, param2) == true:
			result = 0
	return result

func after_adding_new_unit_handler() -> void:
	special_one = SpecParry.new(friendly)
	special_two = SpecRoundAttack.new(friendly)
