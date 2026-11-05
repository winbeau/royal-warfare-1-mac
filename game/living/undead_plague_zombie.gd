# 移植自 S/gameCore/living/undeadPlagueZombie.as
class_name UndeadPlagueZombie
extends MeleeFighter

static var local_bmp_stay: BmpFrames
static var local_bmp_walk: BmpFrames
static var local_bmp_attack: BmpFrames
static var local_bmp_dead: BmpFrames
static var local_special_animation_one: BmpFrames
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
var spec_anim_bitmap: Sprite2D  # private Bitmap
## 原版 private curFrame（与 livingObject 的 private curFrame 是两个独立字段）；GDScript 同名会与父类 cur_frame 冲突，故改名
var spec_cur_frame: int

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("plagueZombieStayAni")
	local_bmp_walk = BmpFrames.from_symbol("plagueZombieWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("plagueZombieAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("plagueZombieDeadAni")
	local_special_animation_one = BmpFrames.from_symbol("zombieSmellAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(50)
static func init_resources() -> void:
	load_frames()
	cache(50)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(UndeadPlagueZombie, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("plague_zombie")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = UNDEAD_PLAGUE_ZOMBIE
	friendly = false
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	sens_class = "zombieSens"
	spec_cur_frame = 0
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func enemy_hit_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.IMPACT_HANDS), false, 0, 0.45, position.x, s.IMPACT)

func after_health_below_zero_handler() -> void:
	spec_anim_bitmap.visible = false
	GlobalData.inst.a12_zombie_killed += 1
	super.after_health_below_zero_handler()

func after_init() -> void:
	spec_anim_bitmap = Sprite2D.new()
	spec_anim_bitmap.centered = false
	sprite.add_child(spec_anim_bitmap)
	sprite.move_child(spec_anim_bitmap, 0)  # addChildAt(bitmap, 0)

func main_alg_update_sprite() -> void:
	if spec_cur_frame != local_special_animation_one.num_frames - 1:
		spec_cur_frame += 1
	else:
		spec_cur_frame = 0
	# bitmapData = frames[curFrame]; x/y = frameXs/frameYs[curFrame]（BmpFrames.apply_frame 同时设纹理与偏移）
	local_special_animation_one.apply_frame(spec_anim_bitmap, spec_cur_frame)
	super.main_alg_update_sprite()

func after_adding_new_unit_handler() -> void:
	spec_anim_bitmap.visible = true
	special_one = SpecWeakness.new(friendly)

func special_before_damaging_enemy_handler() -> void:
	check_weak()
	super.special_before_damaging_enemy_handler()

# private
func check_weak() -> void:
	if special_one != null:
		var loc1: SpecWeakness = special_one as SpecWeakness
		loc1.check_weak(cur_target)
