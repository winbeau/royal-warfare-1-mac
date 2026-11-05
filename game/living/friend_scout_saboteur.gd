# 移植自 S/gameCore/living/friendScoutSaboteur.as
class_name FriendScoutSaboteur
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 0

static func cache(param1: int = 15) -> void:
	cached_unit_data = SimpleCache.new(FriendScoutSaboteur, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("sabotStandAni")
	local_bmp_walk = BmpFrames.from_symbol("sabotMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("sabotAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("sabotDeadAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendScoutSaboteur, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_SABOTEUR
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
	var node: RWXml = GameUniverse.inst.unit_xml.child("saboteur")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func before_updating_active_unit() -> void:
	check_break_arrows()
	super.before_updating_active_unit()

func check_break_arrows() -> bool:
	if special_one != null:
		if cur_stanse != FIGHTING:
			var spec: SpecBreakArrows = special_one as SpecBreakArrows
			return spec.check_break_arrows(_instance)
		return false
	return false

func killed_enemy() -> void:
	GlobalData.inst.a8_killed_by_rogues += 1

# 原版此处不调用 super.specialBeforeDamagingEnemyHandler()
func special_before_damaging_enemy_handler() -> void:
	if special_two != null:
		var spec: SpecHide = special_two as SpecHide
		spec.disable_hide()

func after_adding_new_unit_handler() -> void:
	is_rogue = true
	special_one = SpecBreakArrows.new(friendly)
	special_two = SpecHide.new(true, _instance)
