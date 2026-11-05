# 移植自 S/gameCore/projectiles/smallFireball_ex.as
# 小火球：基类 smallFireball 是 13 帧 MovieClip（帧脚本：第 6 帧 gotoAndPlay(1)，第 13 帧派发 "done"）。
# 原版 MovieClip 由 Flash 按 30 fps 自行播放，不经 gameUniverse；这里在 _physics_process（30 fps）里手动推进，
# 帧序与帧脚本语义相同（clip_frame 从 1 起）。
# 飞行同样走 RWTween 的 bezierThrough + orientToBezier，按墙钟时间，飞行时间 dist/600，中点抬高 dist/(6+3*rand)。
class_name SmallFireballEx
extends Node2D

const CLIP_TOTAL_FRAMES := 13

static var _cached_data: SimpleCache
# 原版在 Main.loadResources 中预建；此处首次访问时懒加载（等效）。
static var cached_data: SimpleCache:
	get:
		if _cached_data == null:
			init_resources()
		return _cached_data
	set(v):
		_cached_data = v

var uid: int = 0  # GameUniverse 以外的代码依赖（占位期成员，保留）
var _instance: SmallFireballEx = null  # private
var missile_hit_handler: Callable = Callable()  # private
var is_hit: bool = false  # private
var cnt: int = 0  # private
var unit_cache: SimpleCache = null  # private
var smoke_eff: FbSmokeVisual = null  # private
var smoke_coords: Vector2 = Vector2.ZERO  # private
var got_target: LivingObject = null  # private
var game_uni: GameUniverse = null  # private
var is_paused: bool = false  # private
var clip_frame: int = 1
var clip_playing: bool = false
var _clip_bm: BmpFrames = null
var _clip_sprite: Sprite2D = null

## 对应 Main.as loadResources：smallFireball_ex.cache();
static func init_resources() -> void:
	cache()

static func cache() -> void:
	_cached_data = SimpleCache.new(SmallFireballEx, 60)

func _init() -> void:
	_clip_bm = BmpFrames.from_symbol("smallFireball")
	_clip_sprite = Sprite2D.new()
	add_child(_clip_sprite)
	_clip_goto(1)
	clip_playing = false  # stop()

## 手动推进 MovieClip：每个 30 fps 帧一次
func _physics_process(_delta: float) -> void:
	advance_clip()

func _clip_goto(n: int) -> void:
	clip_frame = n
	if _clip_bm != null:
		_clip_bm.apply_frame(_clip_sprite, n - 1)

func goto_and_play(n: int) -> void:
	_clip_goto(n)
	clip_playing = true

## 一次 ENTER_FRAME：播放头前进一帧并执行该帧的帧脚本
func advance_clip() -> void:
	if not clip_playing:
		return
	var n: int = clip_frame + 1
	if n > CLIP_TOTAL_FRAMES:
		n = 1
	_clip_goto(n)
	if n == 6:
		goto_and_play(1)  # frame6：gotoAndPlay(1)
	elif n == 13:
		remove_small_fireball(null)  # frame13：dispatchEvent("done")，监听者即 removeSmallFireball

func init(param1: LivingObject, param2: Vector2, param3: Vector2, param4: Callable, param5: bool) -> void:
	game_uni = GameUniverse.inst
	is_paused = false
	got_target = param1
	goto_and_play(1)
	is_hit = param5
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)
	missile_hit_handler = param4
	_instance = self
	position = Vector2(param2.x, param2.y - 7)
	cnt = 0
	scale.x = 0.55
	scale.y = 0.55
	RWTween.from(_instance, 0.1, {"scaleX": 0.1, "scaleY": 0.1})
	var loc6: float = param2.distance_to(param3)
	var loc7: float = loc6 / 600.0
	var loc8: Vector2 = AS3.point_interpolate(param2, param3, 0.5)
	RWTween.to(_instance, loc7, {
		"bezierThrough": [
			{"x": loc8.x, "y": loc8.y - loc6 / (6.0 + 3.0 * RWRandom.rand())},
			{"x": param3.x, "y": param3.y},
		],
		"orientToBezier": true,
		"ease": RWEase.linear_ease_none,
		"onComplete": call_final_funcs,
	})
	unit_cache = FbSmokeVisual.cached_data
	smoke_coords = Vector2(position.x, position.y)

## 由 GameUniverse.update_effects 每逻辑帧调用
func smoke_generator() -> void:
	smoke_eff = unit_cache.get_data() as FbSmokeVisual
	smoke_eff.added_to_stage(smoke_coords.x, smoke_coords.y)
	smoke_eff.rotation_degrees = float(RWRandom.rand_range(-180, 180))
	smoke_coords.x = position.x
	smoke_coords.y = position.y

func call_final_funcs() -> void:
	if is_hit == true:
		missile_hit_handler.call(got_target)
	goto_and_play(7)

## REMOVED_FROM_STAGE 监听（tree_exiting）：节点已在被移出，不再 remove_child。
func _on_tree_exiting() -> void:
	remove_small_fireball(null, true)

func remove_small_fireball(_e: Variant = null, _from_exit: bool = false) -> void:
	game_uni.remove_small_fireball(_instance)
	if tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.disconnect(_on_tree_exiting)
	clip_playing = false
	RWTween.kill_tweens_of(_instance)
	if not _from_exit:
		var p: Node = _instance.get_parent()
		if p != null:
			p.remove_child(_instance)
	cached_data.set_data(_instance)
