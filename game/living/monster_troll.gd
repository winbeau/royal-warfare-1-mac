# 移植自 S/gameCore/living/monsterTroll.as
class_name MonsterTroll
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
var spec_anim_bitmap: Sprite2D  # private Bitmap，原版未使用
## 原版 private curFrame（与父类 private curFrame 独立，且未被使用）；改名以避开 GDScript 同名冲突
var spec_cur_frame: int

## 加载 BmpFrames（Main.loadResources 的前半部分）。首次实例化时自动调用。
static func load_frames() -> void:
	if _frames_loaded:
		return
	_frames_loaded = true
	local_bmp_stay = BmpFrames.from_symbol("monsterTrollStayAni")
	local_bmp_walk = BmpFrames.from_symbol("monsterTrollWalkAni")
	local_bmp_attack = BmpFrames.from_symbol("monsterTrollAttackAni")
	local_bmp_dead = BmpFrames.from_symbol("monsterTrollDeadAni")

## 对应 Main.loadResources 中该类的全部工作：BmpFrames + cache(40)
static func init_resources() -> void:
	load_frames()
	cache(40)

static func cache(param1: int = 50) -> void:
	load_frames()
	_cached_unit_data = SimpleCache.new(MonsterTroll, param1, true)

func update_stats() -> void:
	var loc1: RWXml = GameUniverse.inst.unit_xml.child("troll")
	set_stats_from_xml(loc1)
	money_cost = unit_cost

func init() -> void:
	load_frames()
	kind = MONSTER_TROLL
	friendly = false
	bmp_stay = local_bmp_stay
	bmp_walk = local_bmp_walk
	bmp_attack = local_bmp_attack
	bmp_dead = local_bmp_dead
	sens_class = "monsterTrollSens"
	spec_cur_frame = 0
	super.init()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func on_play_head_action() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.AXE), false, 0, 0.5, position.x, s.AXE)

func after_init() -> void:
	pass

func after_adding_new_unit_handler() -> void:
	special_one = SpecRegen.new(friendly)
	special_one.unlock_special()

func before_updating_active_unit() -> void:
	check_regen()

# private
func check_regen() -> void:
	if special_one != null:
		var loc1: SpecRegen = special_one as SpecRegen
		loc1.check_regen(_instance)
