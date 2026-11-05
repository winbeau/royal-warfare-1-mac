# 移植自 S/gameCore/living/friendPriest.as
class_name FriendPriest
extends PriestClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 200

static func cache(param1: int = 40) -> void:
	cached_unit_data = SimpleCache.new(FriendPriest, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("priestStayAni")
	local_bmp_walk = BmpFrames.from_symbol("priestWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("priestAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("priestDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("priestShootAni")
	local_bmp_cast = BmpFrames.from_symbol("priestCastAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendPriest, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_PRIEST
	class_name_ = "Priest"
	friendly = true
	class_kind = CLASS_PRIEST
	basic_unit = true
	sens_class = "priestSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("priest")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_adding_new_unit_handler() -> void:
	special_one = SpecStrongHeal.new(friendly)
	special_two = SpecEnchantWeapon.new(friendly)

func check_abilities_priest_class() -> bool:
	var result: bool = check_strong_heal()
	if result == false:
		result = check_enchant_weapon()
	return result

func check_enchant_weapon() -> bool:
	var result: bool = false
	if special_two != null:
		var spec: SpecEnchantWeapon = special_two as SpecEnchantWeapon
		result = spec.check_enchant(_instance as PriestClass, last_target, float(search_radius * search_radius_ranged_modifier))
		if result == true:
			got_experience(1)
	return result

func check_strong_heal() -> bool:
	var result: bool = false
	if special_one != null:
		if a_friends.size() > 0:
			# 原版 aFriends.sortOn("curHealth", Array.NUMERIC)；AS3 sortOn 不保证稳定，同血量顺序原版也不确定
			a_friends.sort_custom(func(a, b): return a.cur_health < b.cur_health)
			var weakest: LivingObject = a_friends[0] as LivingObject
			var spec: SpecStrongHeal = special_one as SpecStrongHeal
			result = spec.check_strong_heal(weakest, _instance as PriestClass, cur_ranged_damage)
			if result == true:
				got_experience(1)
	return result
