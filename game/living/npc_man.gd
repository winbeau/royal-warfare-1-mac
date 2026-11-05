# 移植自 S/gameCore/living/npcMan.as
class_name NpcMan
extends NpcClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int
static var unit_cost: int = 200

static func cache(param1: int = 40) -> void:
	cached_unit_data = SimpleCache.new(NpcMan, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache()
static func init_resources() -> void:
	_load_bitmaps()
	cache()

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("npcYoungStayAni")
	local_bmp_walk = BmpFrames.from_symbol("npcYoungWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("npcYoungAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("npcYoungDeadAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(NpcMan, 0, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("npc_man")
	set_stats_from_xml(loc1)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func init() -> void:
	_ensure_resources()
	kind = NPC_MAN
	friendly = true
	class_kind = CLASS_WARRIOR
	basic_unit = false
	sens_class = "npcSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)
