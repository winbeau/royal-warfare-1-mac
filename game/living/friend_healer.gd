# 移植自 S/gameCore/living/friendHealer.as
class_name FriendHealer
extends PriestClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 550

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendHealer, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("healerStayAni")
	local_bmp_walk = BmpFrames.from_symbol("healerWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("healerAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("healerDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("healerShootAni")
	local_bmp_cast = BmpFrames.from_symbol("healerCastAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendHealer, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_HEALER
	class_name_ = "Healer"
	friendly = true
	class_kind = CLASS_PRIEST
	money_cost = unit_cost
	is_resurrecter = true
	sens_class = "priestSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("healer")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_adding_new_unit_handler() -> void:
	special_one = SpecMassHeal.new(friendly)
	special_two = SpecRessurect.new(friendly)

func raise_friend_checker() -> bool:
	var result: bool = false
	if special_two != null:
		var spec: SpecRessurect = special_two as SpecRessurect
		result = spec.check_ressurect(a_dead_units, _instance as PriestClass)
	return result

func check_mass_heal() -> bool:
	var result: bool = false
	if special_one != null:
		var spec: SpecMassHeal = special_one as SpecMassHeal
		result = spec.check_mass_heal(a_friends, _instance as PriestClass, cur_ranged_damage)
		if result == true:
			got_experience(1)
	return result

func check_abilities_priest_class() -> bool:
	var result: bool = check_mass_heal()
	if result == false:
		result = raise_friend_checker()
	return result
