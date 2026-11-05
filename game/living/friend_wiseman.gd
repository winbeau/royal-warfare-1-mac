# 移植自 S/gameCore/living/friendWiseman.as
class_name FriendWiseman
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

static func cache(param1: int = 1) -> void:
	cached_unit_data = SimpleCache.new(FriendWiseman, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(1)
static func init_resources() -> void:
	_load_bitmaps()
	cache(1)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("wisemanStayAni")
	local_bmp_walk = BmpFrames.from_symbol("wisemanWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("wisemanAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("wisemanDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("wisemanShootAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendWiseman, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_WISEMAN
	friendly = true
	class_kind = CLASS_PRIEST
	basic_unit = false
	sens_class = "wisemanSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("wiseman")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_health_below_zero_handler() -> void:
	GameUniverse.inst.minus_health(20)
