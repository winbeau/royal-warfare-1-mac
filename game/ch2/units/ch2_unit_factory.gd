## WP-D1：第二章新 kind（>=100）的单位工厂。GameUniverse._new_unit 在 kind>=100 时转交本类。
## 与一代各 FriendXxx/UndeadXxx 类一样走 SimpleCache 对象池——池直接存在各单位类自己的静态
## cached_unit_data 里（Ch2Warden/Ch2Musketeer/Ch2DarthLancer 的 return_to_cache() 都读写这个字段），
## 本类不另建一份影子缓存，否则 return_to_cache 写回的池和这里取用的池对不上。
## init_resources() 由 D2 加入 Main 的预热队列。
class_name Ch2UnitFactory
extends RefCounted

static func _script_for(kind: int) -> Script:
	match kind:
		Ch2Kinds.CH2_WARDEN:
			return Ch2Warden
		Ch2Kinds.CH2_MUSKETEER:
			return Ch2Musketeer
		Ch2Kinds.CH2_DARTH_LANCER:
			return Ch2DarthLancer
	return null

## 对应一代 Main.loadResources 里各兵种的预热：建对象池。D2 负责把本函数加进 Main 的预热队列。
static func init_resources(pool_size: int = 20) -> void:
	for kind in [Ch2Kinds.CH2_WARDEN, Ch2Kinds.CH2_MUSKETEER, Ch2Kinds.CH2_DARTH_LANCER]:
		var scr := _script_for(kind)
		scr.call("cache", pool_size)

static func new_unit(kind: int) -> LivingObject:
	var scr := _script_for(kind)
	if scr == null:
		push_error("Ch2UnitFactory: unknown ch2 kind %d" % kind)
		return null
	# 与 GameUniverse._new_unit 对一代类的处理一致：池尚未建立（未走预热）时按 cache(0) 懒建。
	var cache: Variant = scr.get("cached_unit_data")
	if not (cache is SimpleCache):
		scr.call("cache", 0)
		cache = scr.get("cached_unit_data")
	return (cache as SimpleCache).get_data() as LivingObject
