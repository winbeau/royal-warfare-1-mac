# 移植自 S/gameCore/living/friendRedMage.as
class_name FriendRedMage
extends MageClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 500

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendRedMage, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("redWizardStayAni")
	local_bmp_walk = BmpFrames.from_symbol("redWizardWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("redWizardAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("redWizardDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("redWizardShootAni")
	local_bmp_cast = BmpFrames.from_symbol("redWizardCastAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendRedMage, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_REDMAGE
	class_kind = CLASS_MAGE
	friendly = true
	sens_class = "redWizardSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("redmage")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAGE_RED_STRIKE), false, 0.1, 0.4, position.x, SoundLibrary.MAGE_STRIKE)

func check_abilities() -> bool:
	var result: bool = false
	if cur_stanse != FIGHTING:
		result = check_metheor()
	return result

# 原版：无论 checkMetheor 是否施放，都 return false（反编译代码末尾 return false，保留）
func check_metheor() -> bool:
	if special_one != null:
		if cur_target != null:
			var spec: SpecMetheor = special_one as SpecMetheor
			var result: bool = spec.check_metheor(_instance as MageClass, cur_target)
			# 原版 while(result == true){...; break;} 即 if
			if result == true:
				cur_spell = 1
				got_experience(1)
	return false

func before_damaging_enemy(param1: LivingObject) -> void:
	if special_two != null:
		var spec: SpecFireHitSplash = special_two as SpecFireHitSplash
		spec.check_fire_splash(Vector2(param1.position.x, param1.position.y), _instance, param1, cur_ranged_damage)

func after_adding_new_unit_handler() -> void:
	special_one = SpecMetheor.new(friendly)
	special_two = SpecFireHitSplash.new(friendly)
