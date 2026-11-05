# 移植自 S/gameCore/projectiles/arrow_ex.as
# 箭：RWTween 的 bezierThrough + orientToBezier + Linear.easeNone，按墙钟时间飞行（不受 2x 速度与 pause 影响）。
# 伤害由 call_final_funcs 里的命中回调结算；未命中的箭停在地上，4 秒后淡出。
# 原版 theArrow 是两帧的 MovieClip "arrow"（1 飞行、2 插地），这里用 Sprite2D + BmpFrames 显示。
class_name ArrowEx
extends DisObject

static var _cached_data: SimpleCache
# 原版在 Main.loadResources 中预建；此处首次访问时懒加载（等效）。
static var cached_data: SimpleCache:
	get:
		if _cached_data == null:
			init_resources()
		return _cached_data
	set(v):
		_cached_data = v

var _instance: ArrowEx = null  # private
var missile_hit_handler: Callable = Callable()  # private
var is_hit: bool = false  # private
var is_external: bool = false  # private
var s: SoundLibrary = null  # private
var cur_target: LivingObject = null  # private
var the_arrow: Sprite2D = null  # private
var _arrow_bm: BmpFrames = null

## 对应 Main.as loadResources：arrow_ex.cache();
static func init_resources() -> void:
	cache()

static func cache(param1: int = 150) -> void:
	_cached_data = SimpleCache.new(ArrowEx, param1)

func _init() -> void:
	_arrow_bm = BmpFrames.from_symbol("arrow")
	the_arrow = Sprite2D.new()
	add_child(the_arrow)
	_goto_and_stop(1)

## theArrow.gotoAndStop(n)，n 从 1 起
func _goto_and_stop(n: int) -> void:
	if _arrow_bm != null:
		_arrow_bm.apply_frame(the_arrow, n - 1)

## param7 对应 isExternal：命中后由外部（技能）处理，不自行淡出。param6 为 true 时是弩箭（中点抬高更小）。
func init(param1: LivingObject, param2: Vector2, param3: Vector2, param4: Callable, param5: bool, param6: bool, param7: bool = false) -> void:
	cur_target = param1
	is_external = param7
	is_hit = param5
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)
	missile_hit_handler = param4
	_instance = self
	position = Vector2(param2.x, param2.y - 2)
	var loc8: float = param2.distance_to(param3)
	var loc9: float = loc8 / 450.0
	var loc10: Vector2 = AS3.point_interpolate(param2, param3, 0.5)
	s = SoundLibrary.inst
	_goto_and_stop(1)
	if param6 == false:
		RWTween.to(_instance, loc9, {
			"bezierThrough": [
				{"x": loc10.x, "y": loc10.y - loc8 / (3.0 + 5.0 * RWRandom.rand())},
				{"x": param3.x, "y": param3.y},
			],
			"orientToBezier": true,
			"ease": RWEase.linear_ease_none,
			"onComplete": call_final_funcs,
		})
	else:
		RWTween.to(_instance, loc9, {
			"bezierThrough": [
				{"x": loc10.x, "y": loc10.y - loc8 / (8.0 + 2.0 * RWRandom.rand())},
				{"x": param3.x, "y": param3.y},
			],
			"orientToBezier": true,
			"ease": RWEase.linear_ease_none,
			"onComplete": call_final_funcs,
		})

func call_final_funcs() -> void:
	if is_hit == true:
		missile_hit_handler.call(_instance, cur_target)
		if is_external == false:
			RWTween.to(_instance, 0.1, {"alpha": 0, "onComplete": remove_arrow})
	else:
		_goto_and_stop(2)
		RWTween.to(_instance, 0.1, {"alpha": 0, "delay": 4, "onComplete": remove_arrow})
		sound_miss()

func sound_miss() -> void:
	Sounds.inst.play(s.get_sound_from_stack(s.ARROW_GROUND), false, 0, 0.4, position.x, s.ARROW_GROUND)

func set_missed() -> void:
	_goto_and_stop(2)
	sound_miss()
	RWTween.to(_instance, 0.1, {"alpha": 0, "delay": 4, "onComplete": remove_arrow})

func set_hit() -> void:
	RWTween.to(_instance, 0.1, {"alpha": 0, "onComplete": remove_arrow})

## REMOVED_FROM_STAGE 监听（tree_exiting）：此时节点已在被移出，不再 remove_child。
func _on_tree_exiting() -> void:
	remove_arrow(null, true)

func remove_arrow(_e: Variant = null, _from_exit: bool = false) -> void:
	GameUniverse.inst.remove_arrow_from_display_array(_instance)
	if tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.disconnect(_on_tree_exiting)
	RWTween.kill_tweens_of(_instance)
	if not _from_exit:
		var p: Node = _instance.get_parent()
		if p != null:
			p.remove_child(_instance)
	cached_data.set_data(_instance)
