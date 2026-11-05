# 移植自 S/gameCore/projectiles/groundFlagAttack.as
class_name GroundFlagAttack
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

## 对应 Main.as loadResources：groundFlagAttack.bmpData = BmpFrames.createBmpFramesFromMC(gotoFlagPlaced); groundFlagAttack.cache();
static func init_resources() -> void:
	bmp_data = BmpFrames.from_symbol("gotoFlagPlaced")
	cache()

static func cache(param1: int = 50) -> void:
	_cached_data = SimpleCache.new(GroundFlagAttack, param1, true)

func _init() -> void:
	is_map_flag = true

func on_play_head_end() -> void:
	cached_data.set_data(_instance)
	super.on_play_head_end()

func after_added_to_stage() -> void:
	play_head_stance = STOPPED
	visible = false

func update() -> void:
	if play_head_stance == STOPPED:
		if RWRandom.rand() > 0.4:
			visible = true
			play_head_stance = PLAYING
	super.update()

func init() -> void:
	bmp_list = bmp_data
	super.init()
