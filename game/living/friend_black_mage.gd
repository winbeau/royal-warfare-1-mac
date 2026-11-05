# 移植自 S/gameCore/living/friendBlackMage.as
class_name FriendBlackMage
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

static func cache(param1: int = 40) -> void:
	cached_unit_data = SimpleCache.new(FriendBlackMage, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("blackWizardStayAni")
	local_bmp_walk = BmpFrames.from_symbol("blackWizardWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("blackWizardAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("blackWizardDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("blackWizardShootAni")
	local_bmp_cast = BmpFrames.from_symbol("blackWizardCastAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendBlackMage, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_BLACKMAGE
	class_name_ = "Black Mage"
	friendly = true
	class_kind = CLASS_MAGE
	sens_class = "blackWizardSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("blackmage")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAGE_BLACK_STRIKE), false, 0, 0.33, position.x, SoundLibrary.MAGE_STRIKE)

func check_abilities() -> bool:
	var result: bool = false
	if cur_stanse != FIGHTING:
		result = check_betray()
		if result == false:
			result = check_curse()
	return result

func check_curse() -> bool:
	var result: bool = false
	if special_two != null:
		if cur_target != null:
			var spec: SpecCurse = special_two as SpecCurse
			result = spec.check_curse_bless(_instance as MageClass, cur_target)
			# 原版 while(result == true){...; break;} 即 if
			if result == true:
				cur_spell = 2
				got_experience(1)
	return result

func casting_done() -> void:
	if cur_spell == 1:
		if special_one != null:
			if cur_target != null:
				var spec_betray: SpecBetray = special_one as SpecBetray
				spec_betray.set_betray()
	elif cur_spell == 2:
		var spec_curse: SpecCurse = special_two as SpecCurse
		spec_curse.set_curse(_instance)

func check_betray() -> bool:
	var result: bool = false
	if special_one != null:
		if cur_target != null:
			var spec: SpecBetray = special_one as SpecBetray
			result = spec.check_betray(_instance as MageClass, cur_target)
			# 原版 while(result == true){...; break;} 即 if
			if result == true:
				cur_spell = 1
				got_experience(1)
	return result

func after_adding_new_unit_handler() -> void:
	special_one = SpecBetray.new(friendly)
	special_two = SpecCurse.new(friendly)
