# 移植自 S/gameCore/living/undeadVampireKing.as
class_name UndeadVampireKing
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var _cached_unit_data: SimpleCache = null
## 懒加载：首次读取时按 Main.loadResources 中对应 case 的对象池数量创建
static var cached_unit_data: SimpleCache:
	get:
		if _cached_unit_data == null:
			init_resources()
		return _cached_unit_data
	set(value):
		_cached_unit_data = value
static var unit_cost: int = 0
static var _frames_loaded: bool = false
var can_call_support: bool  # private；原版 Boolean 默认 false，afterAddingNewUnitHandler 置 true

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("VampireKingStayAni")
	local_bmp_walk = BmpFrames.from_symbol("VampireKingWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("VampireKingAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("VampireKingDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(15)
static func init_resources() -> void:
	load_frames()
	cache(15)

static func cache(param1: int = 10) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadVampireKing, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("vampire_king")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_VAMPIRE_KING
	class_name_ = "Undead King"
	friendly = false
	sens_class = "VampireSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func on_play_head_action() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.HEAVY_SWORD), false, 0, 0.6, position.x, s.HEAVY_SWORD)

func special_before_damaging_enemy_handler() -> void:
	if special_one != null:
		var loc1: SpecVampirizm = special_one as SpecVampirizm
		loc1.check_vampirizm(cur_target, _instance)
	if special_two != null:
		var loc2: SpecOgreStun = special_two as SpecOgreStun
		loc2.check_stun(cur_target, _instance)
	super.special_before_damaging_enemy_handler()

# 血量低于 650 时召唤援军（每次 after_adding_new_unit_handler 重置 can_call_support，最多触发到 Level24.support_counter==3）
func after_being_hit_handler() -> void:
	if cur_health < 650:
		if can_call_support == true:
			can_call_support = false
			call_support()

# private
func call_support() -> void:
	Level24.support_counter += 1
	if Level24.support_counter == 1:
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 2)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 2)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 2)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 2)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 3)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 3)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 3)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 3)
	elif Level24.support_counter == 2:
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 4)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 4)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 4)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 4)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 5)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 5)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 5)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 5)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 6)
		GameUniverse.inst.call_summoned_enemy(LivingObject.UNDEAD_DARTH_KNIGHT, 1, 1)
		GameUniverse.inst.call_summoned_enemy(LivingObject.UNDEAD_DARTH_KNIGHT, 1, 2)
	elif Level24.support_counter == 3:
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 4)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 8)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_CAPITAN, 1, 7)
		GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 6)

func unit_removed_from_death_array() -> void:
	GameUniverse.inst.level_info.external_data_inserted()

func after_adding_new_unit_handler() -> void:
	can_call_support = true
	special_one = SpecVampirizm.new(friendly)
	special_two = SpecOgreStun.new(friendly)

func update_dead() -> void:
	if get_death_time + 90 == GameUniverse.inst.global_counter:
		if Level24.support_counter < 3:
			var loc1: SimpleCache = SummonKingVisual.cached_data
			var loc2: SummonKingVisual = loc1.get_data() as SummonKingVisual
			loc2.added_to_stage(position.x, position.y, remover_animation_completed, null, true)
			RWTween.to(_instance, 2, {"alpha": 0})

# private
func remover_animation_completed() -> void:
	can_call_support = true
	visible = false
