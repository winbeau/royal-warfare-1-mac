## WP-D1：第二章特效的通用播放器（枪焰/硝烟/弹道曳光/命中扬尘/技能特效……），一次性播完自动回收。
## 继承 VisualsTemplate 只是为了复用 GameUniverse.add_effect/update_effects 的驱动（暂停与 2 倍速正确），
## 不使用 BmpFrames 的帧命令体系——贴图是 assets/ch2/vfx/<name>.png 的横排条带，按 vfx.json 的 frames 切片。
class_name Ch2Vfx
extends VisualsTemplate

var frame_count: int = 6
var ticks_per_frame: int = 2
var _tick: int = 0
var _vfx_frame: int = 0

## VisualsTemplate.added_to_stage 默认用 bmp_list.apply_frame(sprite_bm, 0) 显示首帧；本类不用
## BmpFrames（贴图是横排条带，已经在 spawn() 里直接设到 sprite_bm.texture/frame），bmp_list 恒为 null，
## 必须整份重写，不能调用 super（否则 bmp_list.apply_frame 会在 null 上报错）。
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

## pos：世界坐标；rot：弧度；flip_x：水平镜像（朝向翻转）；parent：挂载节点（默认 effects_cont）。
static func spawn(vfx_name: String, pos: Vector2, rot: float = 0.0, flip_x: bool = false, parent: Node = null) -> Ch2Vfx:
	var meta: Dictionary = Ch2VfxDef.meta(vfx_name)
	var v := Ch2Vfx.new()
	v.init()
	v.frame_count = int(meta.get("frames", 6))
	v.sprite_bm.texture = Ch2VfxDef.texture(vfx_name)
	v.sprite_bm.hframes = maxi(v.frame_count, 1)
	v.sprite_bm.vframes = 1
	v.sprite_bm.frame = 0
	v.sprite_bm.centered = false
	var anchor: Array = meta.get("anchor", [0, 0])
	v.sprite_bm.offset = Vector2(-float(anchor[0]), -float(anchor[1]))
	v.sprite_bm.scale = Vector2(0.5, 0.5)
	v.sprite_bm.flip_h = flip_x
	if str(meta.get("blend", "alpha")) == "add":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		v.sprite_bm.material = mat
	v.added_to_stage(pos.x, pos.y)
	v.rotation = rot
	return v

## 只播到前 n 帧就结束（例如命中目标身上只放 ball_impact 的前 4 帧）。
static func spawn_partial(vfx_name: String, pos: Vector2, play_frames: int, rot: float = 0.0, flip_x: bool = false) -> Ch2Vfx:
	var v := spawn(vfx_name, pos, rot, flip_x)
	v.frame_count = mini(v.frame_count, play_frames)
	return v

func update() -> void:
	if play_head_stance != PLAYING:
		return
	_tick += 1
	if _tick < ticks_per_frame:
		return
	_tick = 0
	_vfx_frame += 1
	if _vfx_frame >= frame_count:
		on_play_head_end()
		return
	sprite_bm.frame = _vfx_frame
