## WP-D1：播完即收的位图动画特效，支持一代原版 BmpFrames 与第二章 Ch2BmpFrames（接口相同：
## apply_frame(sprite, i)）。给达思重骑“人马俱碎”“下马”两处纯视觉表现复用：
## 马身播一次 death 行，骑手播一次一代原版 undeadDarthKnightDeadAni。
class_name Ch2OneShotBmp
extends VisualsTemplate

var bmp: BmpFrames = null
var ticks_per_frame: int = 1
var _tick: int = 0
var _frame: int = 0

## 同 Ch2Vfx/Ch2Bullet：不走 VisualsTemplate 默认的 bmp_list.apply_frame 首帧显示（本类的 bmp 是外部
## 传入、在 spawn() 里单独贴第 0 帧），必须整份重写，不能调用 super（bmp_list 恒为 null）。
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

static func spawn(bmp_frames: BmpFrames, pos: Vector2, flip_x: bool = false) -> Ch2OneShotBmp:
	var v := Ch2OneShotBmp.new()
	v.init()
	v.bmp = bmp_frames
	v.added_to_stage(pos.x, pos.y)
	if flip_x:
		v.sprite_bm.scale.x = -1
	if v.bmp != null:
		v.bmp.apply_frame(v.sprite_bm, 0)
	else:
		v.on_play_head_end()
	return v

func update() -> void:
	if play_head_stance != PLAYING or bmp == null:
		return
	_tick += 1
	if _tick < ticks_per_frame:
		return
	_tick = 0
	_frame += 1
	if _frame >= bmp.num_frames:
		on_play_head_end()
		return
	bmp.apply_frame(sprite_bm, _frame)
