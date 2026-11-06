## WP-D1 D1.5：火铳弹丸。按逻辑帧直线推进（不用 RWTween），由 GameUniverse.update_effects 经
## VisualsTemplate 的 a_effects 列表每帧驱动一次——暂停时不调用、2 倍速时每逻辑帧调用两次，天然满足
## “暂停停住、2 倍速两次推进”的要求，不需要额外的速度/暂停判断。
## 命中判定、特殊弹效果都在命中/未命中到达时通过 on_arrive 回调交给 Ch2Musketeer 处理
## （伤害公式沿用 RangedFighter 的护甲减伤，在那边按 shooter 的当前破甲/伤害计算，这里只管飞行与特效）。
class_name Ch2Bullet
extends VisualsTemplate

const SPEED := 22.0

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var distance: float = 0.0
var traveled: float = 0.0
var hit: bool = false
var target: LivingObject = null
var on_arrive: Callable = Callable()

## 同 Ch2Vfx：不用 BmpFrames，必须整份重写 added_to_stage，不能调用 super（bmp_list 恒为 null）。
func added_to_stage(param1: float, param2: float, param3: Callable = Callable(), param4: Variant = null, param5: bool = false, param6: bool = false) -> void:
	visible = true
	play_head_stance = PLAYING
	cur_frame = -1
	after_added_to_stage()
	GameUniverse.inst.add_effect(_instance, param4, param5)
	position = Vector2(param1, param2)
	call_back_function = param3
	if param6 == true:
		visible = false
		play_head_stance = DELAYED

static func fire(from_pt: Vector2, to_pt: Vector2, is_hit: bool, target_unit: LivingObject, on_arrive_cb: Callable) -> Ch2Bullet:
	var b := Ch2Bullet.new()
	b.init()
	b.from = from_pt
	b.to = to_pt
	var delta: Vector2 = to_pt - from_pt
	b.distance = delta.length()
	b.dir = delta / b.distance if b.distance > 0.01 else Vector2.RIGHT
	b.hit = is_hit
	b.target = target_unit
	b.on_arrive = on_arrive_cb
	var meta: Dictionary = Ch2VfxDef.meta("ball_tracer")
	var frames: int = int(meta.get("frames", 6))
	b.sprite_bm.texture = Ch2VfxDef.texture("ball_tracer")
	b.sprite_bm.hframes = maxi(frames, 1)
	b.sprite_bm.vframes = 1
	b.sprite_bm.frame = 0
	b.sprite_bm.centered = false
	var anchor: Array = meta.get("anchor", [0, 0])
	b.sprite_bm.offset = Vector2(-float(anchor[0]), -float(anchor[1]))
	b.sprite_bm.scale = Vector2(0.5, 0.5)
	if str(meta.get("blend", "alpha")) == "add":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		b.sprite_bm.material = mat
	b.added_to_stage(from_pt.x, from_pt.y)
	b.rotation = b.dir.angle()
	return b

func update() -> void:
	if play_head_stance != PLAYING:
		return
	traveled += SPEED
	if traveled >= distance:
		position = to
		if on_arrive.is_valid():
			on_arrive.call(hit, target, to)
		on_play_head_end()
		return
	position = from + dir * traveled
