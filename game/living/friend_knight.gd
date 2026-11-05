# 移植自 S/gameCore/living/friendKnight.as
class_name FriendKnight
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var cached_unit_data: SimpleCache
static var upgrade_cost: int = 0
static var unit_cost: int = 320

static func cache(param1: int = 50) -> void:
	cached_unit_data = SimpleCache.new(FriendKnight, param1, true)

# 对应 Main.loadResources 中该类的部分：烘焙各套 BmpFrames，并建对象池 cache(30)
static func init_resources() -> void:
	_load_bitmaps()
	cache(30)

static func _load_bitmaps() -> void:
	local_bmp_stay = BmpFrames.from_symbol("knightStayAni")
	local_bmp_walk = BmpFrames.from_symbol("knightWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("knightAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("knightDeadAni")

# 首次实例化时懒加载：仅当 init_resources 尚未被调用时，加载位图并建一个空对象池（按需增长）
static func _ensure_resources() -> void:
	if local_bmp_stay == null:
		_load_bitmaps()
	if cached_unit_data == null:
		cached_unit_data = SimpleCache.new(FriendKnight, 0, true)

func init() -> void:
	_ensure_resources()
	kind = FR_KNIGHT
	class_kind = CLASS_WARRIOR
	money_cost = unit_cost
	friendly = true
	sens_class = "knightSens"
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	super.init()

func update_stats() -> void:
	var node: RWXml = GameUniverse.inst.unit_xml.child("knight")
	set_stats_from_xml(node)
	money_cost = unit_cost
	upgr_cost = upgrade_cost

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func special_play_head_start_playing_handler() -> void:
	if special_two != null:
		var spec: SpecMassStun = special_two as SpecMassStun
		spec.check_wave(_instance)

func special_before_damaging_enemy_handler() -> void:
	var taunted: bool = check_taunt()
	if taunted == false:
		check_mass_stun()

func check_taunt() -> bool:
	var result: bool = false
	if special_one != null:
		var spec: SpecTaunt = special_one as SpecTaunt
		result = spec.check_taunt(_instance)
	return result

func check_mass_stun() -> bool:
	var result: bool = false
	if special_two != null:
		var spec: SpecMassStun = special_two as SpecMassStun
		result = spec.check_stun(cur_target, _instance)
	return result

func on_play_head_action() -> void:
	if friendly:
		if RWRandom.rand() > 0.9:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_VOICE), false, 0, 0.55, position.x, SoundLibrary.HEAVY_SWORD)
		else:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.HEAVY_SWORD), false, 0, 0.55, position.x, SoundLibrary.HEAVY_SWORD)
	else:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.HEAVY_SWORD), false, 0, 0.55, position.x, SoundLibrary.HEAVY_SWORD)

func after_adding_new_unit_handler() -> void:
	special_one = SpecTaunt.new(friendly)
	special_two = SpecMassStun.new(friendly)
