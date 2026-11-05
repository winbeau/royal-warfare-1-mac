# 移植自 S/gameCore/living/friendBlesser.as
class_name FriendBlesser
extends PriestClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 480

static func cache(param1: int = 30) -> void:
	cached_unit_data = SimpleCache.new(FriendBlesser, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("blesserStayAni")
	local_bmp_walk = BmpFrames.from_symbol("blesserWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("blesserAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("blesserDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("blesserShootAni")
	local_bmp_cast = BmpFrames.from_symbol("blesserCastAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendBlesser, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_BLESSER
	class_name_ = "Blesser"
	friendly = true
	class_kind = CLASS_PRIEST
	sens_class = "priestSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("blesser")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func check_curse_bless() -> bool:
	var result: bool = false
	if special_one != null:
		var spec: SpecCurseBless = special_one as SpecCurseBless
		result = spec.check_curse_bless(_instance as PriestClass)
	return result

func after_adding_new_unit_handler() -> void:
	special_one = SpecCurseBless.new(friendly)
	special_two = SpecHarmResist.new(friendly)

func check_abilities_priest_class() -> bool:
	var result: bool = check_curse_bless()
	if result == false:
		result = check_harm_hesist()
	return result

func check_harm_hesist() -> bool:
	var result: bool = false
	if special_two != null:
		var spec: SpecHarmResist = special_two as SpecHarmResist
		result = spec.check_harm_resist(_instance as PriestClass)
	return result
