# 移植自 S/gameCore/living/friendScoutRogue.as
class_name FriendScoutRogue
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 150

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendScoutRogue, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("rogueStandAni")
	local_bmp_walk = BmpFrames.from_symbol("rogueMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("rogueAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("rogueDeadAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendScoutRogue, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_ROGUE
	friendly = true
	basic_unit = true
	class_kind = CLASS_THIEF
	sens_class = "rogueSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("rogue")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func special_before_damaging_enemy_handler() -> void:
	if not check_poison():
		check_theft()
	super.special_before_damaging_enemy_handler()

func check_poison() -> bool:
	var result: bool = false
	if special_one != null:
		var spec: SpecPoisonRogue = special_one as SpecPoisonRogue
		result = spec.check_poison(cur_target)
	return result

func check_theft() -> void:
	if special_two != null:
		var spec: SpecCollectMoney = special_two as SpecCollectMoney
		spec.get_money_from_enemy(cur_target)

func killed_enemy() -> void:
	GlobalData.inst.a8_killed_by_rogues += 1

func after_adding_new_unit_handler() -> void:
	is_rogue = true
	special_one = SpecPoisonRogue.new(friendly)
	special_two = SpecCollectMoney.new(friendly)
