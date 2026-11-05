# 移植自 S/gameCore/projectiles/roundAttackEffectVisual.as
class_name RoundAttackEffectVisual
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

## 对应 Main.as loadResources：roundAttackEffectVisual.bmpData = BmpFrames.createBmpFramesFromMC(roundAttackedEffectVisual); roundAttackEffectVisual.cache();
static func init_resources() -> void:
	bmp_data = BmpFrames.from_symbol("roundAttackedEffectVisual")
	cache()

# 原版 cache() 里还创建 DropShadowFilter(2,45,0,1,4,4,0.2) 存入 private static shadow，但类内从未使用，故不移植。

static func cache(param1: int = 20) -> void:
	_cached_data = SimpleCache.new(RoundAttackEffectVisual, param1, true)

func on_play_head_end() -> void:
	cached_data.set_data(_instance)
	super.on_play_head_end()

func init() -> void:
	bmp_list = bmp_data
	super.init()
