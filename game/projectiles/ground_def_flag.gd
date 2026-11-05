# 移植自 S/gameCore/projectiles/groundDefFlag.as
class_name GroundDefFlag
extends VisualsTemplate

static var bmp_data: BmpFrames
static var _cached_data: SimpleCache
# 原版在 Main.loadResources 中预建；此处首次访问时懒加载（等效）。
static var cached_data: SimpleCache:
	get:
		if _cached_data == null:
			init_resources()
		return _cached_data
	set(v):
		_cached_data = v

var just_added: bool
var anim_finished: bool
var counter: int
var self_: GroundDefFlag  # 原版 private var self；与 GDScript 内置 self 冲突，加后缀 _

## 对应 Main.as loadResources：groundDefFlag.bmpData = BmpFrames.createBmpFramesFromMC(defendFlagAni); groundDefFlag.cache();
static func init_resources() -> void:
	bmp_data = BmpFrames.from_symbol("defendFlagAni")
	cache()

static func cache(param1: int = 10) -> void:
	_cached_data = SimpleCache.new(GroundDefFlag, param1, true)

func _init() -> void:
	self_ = self
	is_map_flag = true

# 注意：原版此处不调用 super，也不回池，仅标记动画结束（淡出后由 alpha_and_remove 回池）。
func on_play_head_end() -> void:
	anim_finished = true

func after_added_to_stage() -> void:
	play_head_stance = STOPPED
	visible = false
	modulate.a = 1.0  # alpha = 1
	just_added = true
	anim_finished = false
	counter = 0

# 原版疑点（照原样保留）：just_added 在 after_added_to_stage 之外从不复位，因此每帧都消耗一次 RNG；
# anim_finished 且 counter > 60 后每帧都新建一个 0.3 秒 alpha 补间，依赖 TweenMax 的 AUTO 覆盖（RWTween 已实现）。
func update() -> void:
	if just_added == true:
		if RWRandom.rand() > 0.4:
			visible = true
			play_head_stance = PLAYING
	if anim_finished == true:
		counter += 1
		if counter > 60:
			RWTween.to(self_, 0.3, {"alpha": 0, "onComplete": func() -> void: alpha_and_remove()})
	super.update()

func alpha_and_remove() -> void:
	cached_data.set_data(_instance)
	remove_elements()

func init() -> void:
	bmp_list = bmp_data
	super.init()
