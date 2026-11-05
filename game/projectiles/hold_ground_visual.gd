# 移植自 S/gameCore/projectiles/holdGroundVisual.as
class_name HoldGroundVisual
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

## 对应 Main.as loadResources：holdGroundVisual.bmpData = BmpFrames.createBmpFramesFromMC(holdGroundAni); holdGroundVisual.cache();
static func init_resources() -> void:
	bmp_data = BmpFrames.from_symbol("holdGroundAni")
	cache()

static func cache(param1: int = 40) -> void:
	_cached_data = SimpleCache.new(HoldGroundVisual, param1, true)

func on_play_head_end() -> void:
	cached_data.set_data(_instance)
	super.on_play_head_end()

func init() -> void:
	bmp_list = bmp_data
	super.init()
