# 移植自 S/gameCore/projectiles/fleeVisual.as
class_name FleeVisual
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

## 原版 Main.as 从未为本类赋 bmpData 或调用 cache()（全工程无引用）；保持原样，不加载资源。
static func init_resources() -> void:
	pass

static func cache(param1: int = 20) -> void:
	_cached_data = SimpleCache.new(FleeVisual, param1, true)

func on_play_head_end() -> void:
	cached_data.set_data(_instance)
	super.on_play_head_end()

func init() -> void:
	bmp_list = bmp_data
	super.init()
