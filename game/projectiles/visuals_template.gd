# 移植自 S/gameCore/projectiles/visualsTemplate.as
# 特效基类：每逻辑帧由 GameUniverse.update_effects 调用 update() 推进 1 帧；位图经 BmpFrames.apply_frame 显示。
# 与原版的对应：callBAckFunction -> call_back_function；curFrame 的内部 getter/setter 直接用字段 cur_frame；
# internal 成员（bmpList、onPlayHeadDone、onPlayHeadEnd、removeElements、afterAddedToStage）在 GDScript 中同样公开。
class_name VisualsTemplate
extends Node2D

const DONE := 2
const PLAYING := 0
const STOPPED := 1
const DELAYED := 2

var bmp_list: BmpFrames = null
var cur_frame: int = 0
var sprite_bm: Sprite2D = null  # private
var call_back_function: Callable = Callable()
var _instance: VisualsTemplate = null
var is_map_flag: bool = false
var play_head_stance: int = 0

func init() -> void:
	cur_frame = -1
	sprite_bm = Sprite2D.new()
	add_child(sprite_bm)
	_instance = self

## param3 回调（DONE 帧触发）；param4 指定父节点（null 则放入 effects_cont / bottom_effects_cont）；
## param5 为 true 时放入 bottom_effects_cont；param6 为 true 时先隐藏并进入 DELAYED。
func added_to_stage(param1: float, param2: float, param3: Callable = Callable(), param4: Variant = null, param5: bool = false, param6: bool = false) -> void:
	visible = true
	play_head_stance = PLAYING
	cur_frame = -1
	after_added_to_stage()
	GameUniverse.inst.add_effect(_instance, param4, param5)
	position = Vector2(param1, param2)
	call_back_function = param3
	bmp_list.apply_frame(sprite_bm, 0)
	if param6 == true:
		visible = false
		play_head_stance = DELAYED

func after_added_to_stage() -> void:
	pass

func update() -> void:
	if play_head_stance == PLAYING:
		# 原版 frameCommands 是 Array：curFrame 为 -1 时取到 undefined，int() 得 0（GDScript 负下标会取末元素，必须显式处理）
		var loc1: int = 0
		if cur_frame >= 0:
			loc1 = bmp_list.get_command(cur_frame)
		if cur_frame != bmp_list.num_frames - 1:
			cur_frame += 1
			if loc1 == DONE:
				on_play_head_done()
				manage_call_back()
		else:
			on_play_head_end()
		bmp_list.apply_frame(sprite_bm, cur_frame)
	elif play_head_stance == DELAYED:
		if RWRandom.rand() > 0.85:
			play_head_stance = PLAYING
			visible = true

func end_game_remover() -> void:
	on_play_head_end()

func on_play_head_done() -> void:
	pass

func manage_call_back() -> void:
	if call_back_function.is_valid():
		call_back_function.call()

func on_play_head_end() -> void:
	remove_elements()

func remove_elements() -> void:
	var p: Node = _instance.get_parent()
	if p != null:
		p.remove_child(_instance)
	GameUniverse.inst.remove_effect(_instance)
