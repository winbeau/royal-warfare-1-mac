# 移植自 S/gameCore/living/friendBlueMage.as
class_name FriendBlueMage
extends MageClass

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_bmp_ranged: BmpFrames
static var local_bmp_cast: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 220

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendBlueMage, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("wizardStayAni")
	local_bmp_walk = BmpFrames.from_symbol("wizardWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("wizardAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("wizardDeadAni")
	local_bmp_ranged = BmpFrames.from_symbol("wizardShootAni")
	local_bmp_cast = BmpFrames.from_symbol("wizardCastAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendBlueMage, 0, true)

func init() -> void:
	_ensure_resources()
	class_kind = CLASS_MAGE
	kind = FR_BLUEMAGE
	friendly = true
	basic_unit = true
	money_cost = unit_cost
	sens_class = "blueWizardSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	bmp_ranged = local_bmp_ranged
	bmp_casting = local_bmp_cast
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("bluemage")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAGE_BLUE_STRIKE), false, 0, 0.4, position.x, SoundLibrary.MAGE_STRIKE)

func check_abilities() -> bool:
	var result: bool = false
	if cur_stanse == STAND or cur_stanse == RANGED_SHOOT:
		if special_one != null:
			if special_one.can_use_special():
				if cur_target != null:
					var spec_ice: SpecIce = special_one as SpecIce
					result = spec_ice.check_ice(_instance as MageClass, cur_target)
					# 原版 while(result == true){...; break;} 即 if
					if result == true:
						got_experience(1)
						cur_spell = 1
		if result == false and special_two != null:
			if special_two.can_use_special():
				var spec_flash: SpecFlash = special_two as SpecFlash
				result = spec_flash.check_flash(_instance as MageClass)
				if result == true:
					got_experience(1)
					cur_spell = 2
	return result

func casting_done() -> void:
	if cur_spell == 2:
		if special_two != null:
			var spec_flash: SpecFlash = special_two as SpecFlash
			spec_flash.set_flash()
	elif cur_spell == 1:
		if cur_target != null:
			var spec_ice: SpecIce = special_one as SpecIce
			spec_ice.set_ice()

func after_adding_new_unit_handler() -> void:
	special_one = SpecIce.new(friendly)
	special_two = SpecFlash.new(friendly)
