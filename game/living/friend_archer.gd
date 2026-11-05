# 移植自 S/gameCore/living/friendArcher.as
class_name FriendArcher
extends RangedFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 120
static var unit_cost: int = 120

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendArcher, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("archerStandAni")
	local_bmp_walk = BmpFrames.from_symbol("archerMoveAni")
	local_bmp_attack = BmpFrames.from_symbol("archerAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("archerDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("archerShootAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendArcher, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_ARCHER
	class_kind = CLASS_ARCHER
	sens_class = "archerSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	friendly = true
	basic_unit = true
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("archer")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func start_ranged_attack() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.ARCHER_PULL), false, 0, 0.2, position.x, SoundLibrary.ARCHER_PULL)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.ARCHER_SHOOT), false, 0, 0.4, position.x, SoundLibrary.ARCHER_SHOOT)

func after_adding_new_unit_handler() -> void:
	special_one = SpecSlow.new(friendly)
	special_two = SpecSuppress.new(friendly)

func special_missile_hit_target(param1: LivingObject) -> void:
	var slowed: bool = false
	if special_one != null:
		var spec_slow: SpecSlow = special_one as SpecSlow
		slowed = spec_slow.check_slow(param1)
	if slowed == false:
		if special_two != null:
			if param1 != null:
				var spec_suppress: SpecSuppress = special_two as SpecSuppress
				spec_suppress.check_suppress(param1)
