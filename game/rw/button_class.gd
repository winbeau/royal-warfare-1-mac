# 移植自 S/utils/buttonClass.as
# 原版是纯静态工具类，给 MovieClip 挂 MouseEvent 监听。这里作用对象是 FlashClip，保持静态。
#
# 事件模型：每个 FlashClip 懒建一个 _Hub（存在节点 meta "_button_class_hub"），把 Control 的
# mouse_entered / mouse_exited / gui_input 转成 ROLL_OVER / ROLL_OUT / MOUSE_DOWN / MOUSE_UP / CLICK，
# 各事件对应一个 Callable 列表。与 AS3 一致：同一个函数重复 addEventListener 只算一次。
# 回调签名等同 `function(e:MouseEvent)`，参数是 ButtonClass.ButtonEvent（继承 RWMouseEvent，多一个 target）；
# 回调声明 0 个参数也可以（按 get_argument_count 判断，对应 AS3 里省略参数的写法）。
#
# 用到的接口（保持原版名字）：
#   init / initSounds
#   addButtonFull / removeButtonFull
#   addButtonLite / removeButtonLite
#   addButtonOnFrames / addButtonOnFramesRD / removeButtonOnFrames
#   addButtonScale / removeButtonScale
#   addButtonAlpha / removeButtonAlpha
#   addBrightness / removeBrightnes（原版拼写）
#   addButtonLiteRD / removeButtonLiteRD
#   playClickSound / playRover
class_name ButtonClass
extends RefCounted

const HUB_META := &"_button_class_hub"

# 事件类型（对应 MouseEvent.*）
const ROLL_OVER := &"rollOver"
const ROLL_OUT := &"rollOut"
const CLICK := &"click"
const MOUSE_DOWN := &"mouseDown"
const MOUSE_UP := &"mouseUp"

static var s: SoundLibrary = null
static var o_buttons_params: Dictionary = {}


## 对应 flash.events.MouseEvent：target 就是挂监听的 FlashClip（mouseChildren=false 时与 AS3 一致）。
class ButtonEvent extends RWMouseEvent:
	var target: FlashClip = null
	var type: StringName = &""


## 每个 FlashClip 一个：持有各事件的监听列表，并连接 Control 信号。
class _Hub extends RefCounted:
	var clip: FlashClip = null
	var listeners: Dictionary = {}
	var pressed := false

	func _init(c: FlashClip) -> void:
		clip = c
		c.mouse_entered.connect(_on_entered)
		c.mouse_exited.connect(_on_exited)
		c.gui_input.connect(_on_gui_input)

	func add(type: StringName, cb: Callable) -> void:
		var arr: Array = listeners.get(type, [])
		if arr.has(cb):
			return
		arr.append(cb)
		listeners[type] = arr

	func remove(type: StringName, cb: Callable) -> void:
		if not listeners.has(type):
			return
		var arr: Array = listeners[type]
		arr.erase(cb)

	func has_any(type: StringName) -> bool:
		return listeners.has(type) and (listeners[type] as Array).size() > 0

	func dispatch(type: StringName, from_event: InputEvent = null) -> void:
		if not has_any(type) or not is_instance_valid(clip):
			return
		var e := ButtonEvent.new()
		e.target = clip
		e.type = type
		var gp := clip.get_global_mouse_position()
		e.stage_x = gp.x
		e.stage_y = gp.y
		if from_event is InputEventWithModifiers:
			var m := from_event as InputEventWithModifiers
			e.shift_key = m.shift_pressed
			e.ctrl_key = m.ctrl_pressed
			e.alt_key = m.alt_pressed
		# 回调里可能增删监听，遍历副本
		for cb: Callable in (listeners[type] as Array).duplicate():
			if not cb.is_valid():
				continue
			AS3.begin_entry()  # 每个监听是独立入口：一个监听抛错不影响其余监听（见 as3.gd）
			if cb.get_argument_count() == 0:
				cb.call()
			else:
				cb.call(e)
			AS3.end_entry()

	func _on_entered() -> void:
		dispatch(ROLL_OVER)

	func _on_exited() -> void:
		pressed = false
		dispatch(ROLL_OUT)

	func _on_gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			pressed = true
			dispatch(MOUSE_DOWN, event)
			clip.accept_event()
		else:
			var was_pressed := pressed
			pressed = false
			dispatch(MOUSE_UP, event)
			# CLICK：在同一对象上按下并抬起。用事件自带的 position（Godot 派发 _gui_input 时已经转换到
			# 这个 Control 的局部坐标系）判断，不要用 get_local_mouse_position()——后者另外读取
			# Viewport 自己缓存的"当前鼠标位置"，这个缓存在一些场景下（合成输入、多显示器、焦点切换、
			# 舞台 700x600 与窗口缩放之间的换算时机）可能与刚处理的这个事件本身对不上，导致明明点在按钮
			# 上却因为取到的坐标是别处而判定为没点中、CLICK 发不出去。
			if was_pressed and clip._has_point(mb.position):
				dispatch(CLICK, event)
			clip.accept_event()


# ---------------------------------------------------------------- 事件挂接（AS3 addEventListener 的对应）

static func _hub(mc: FlashClip) -> _Hub:
	if mc.has_meta(HUB_META):
		return mc.get_meta(HUB_META)
	var h := _Hub.new(mc)
	mc.set_meta(HUB_META, h)
	return h


## 对应 mc.addEventListener(type, cb)。
static func add_event_listener(mc: FlashClip, type: StringName, cb: Callable) -> void:
	_hub(mc).add(type, cb)


## 对应 mc.removeEventListener(type, cb)。
static func remove_event_listener(mc: FlashClip, type: StringName, cb: Callable) -> void:
	if mc.has_meta(HUB_META):
		(mc.get_meta(HUB_META) as _Hub).remove(type, cb)


static func _set_button_mode(mc: FlashClip, on: bool) -> void:
	var shape := Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	# Control.set_default_cursor_shape 内部取 get_global_rect()；祖先链的行列式为负（镜像，Flash 矩阵 a*d-b*c < 0）时
	# 其 size 为负，Rect2.has_point 会报 "Rect2 size is negative"。设置期间临时翻回符号，再还原。
	if mc.is_inside_tree() and mc.get_global_transform().determinant() < 0.0:
		var sc := mc.scale
		mc.scale = Vector2(sc.x, -sc.y)
		mc.mouse_default_cursor_shape = shape
		mc.scale = sc
	else:
		mc.mouse_default_cursor_shape = shape


static func _target_of(e: ButtonEvent) -> FlashClip:
	return e.target


# ---------------------------------------------------------------- 公开接口

static func init() -> void:
	o_buttons_params = {}


static func init_sounds() -> void:
	s = SoundLibrary.inst


static func _lib() -> SoundLibrary:
	if s == null:
		s = SoundLibrary.inst
	return s


static func add_button_full(param1: FlashClip, param2: Callable, param3: Callable, param4: Callable) -> void:
	param1.stop()
	param1.mouse_children = false
	_set_button_mode(param1, true)
	add_event_listener(param1, ROLL_OVER, param2)
	add_event_listener(param1, ROLL_OUT, param3)
	add_event_listener(param1, CLICK, param4)


static func remove_button_full(param1: FlashClip, param2: Callable, param3: Callable, param4: Callable) -> void:
	remove_event_listener(param1, ROLL_OVER, param2)
	remove_event_listener(param1, ROLL_OUT, param3)
	remove_event_listener(param1, CLICK, param4)


static func add_button_lite(param1: FlashClip, param2: Callable) -> void:
	param1.stop()
	param1.mouse_children = false
	param1.mouse_enabled = true
	_set_button_mode(param1, true)
	add_event_listener(param1, CLICK, param2)


static func remove_button_lite(param1: FlashClip, param2: Callable) -> void:
	remove_event_listener(param1, CLICK, param2)


static func add_button_on_frames(param1: FlashClip, param2: Callable) -> void:
	param1.goto_and_stop(1)
	param1.mouse_children = false
	_set_button_mode(param1, true)
	add_event_listener(param1, ROLL_OVER, _rover_goto_and_stop)
	add_event_listener(param1, ROLL_OUT, _rout_goto_and_stop)
	add_event_listener(param1, MOUSE_DOWN, _mdown_on_frames)
	add_event_listener(param1, MOUSE_UP, _mup_on_frames)
	add_event_listener(param1, CLICK, param2)


# 原版的 do{...}while(false) + break 是编译器对 if/else 的展开，语义如下：
#   eLight.alpha = 0；若 int(oButtonsParams[mc]) != 0 则（param3 为真时）把缩放还原成存档值，
#   否则存下当前 scaleX。注意 int() 截断：缩放小于 1 的按钮每次都会重新存档（照原版保留）。
static func add_button_on_frames_rd(param1: FlashClip, param2: Callable, param3: bool = true) -> void:
	param1.goto_and_stop(1)
	param1.mouse_children = false
	_set_button_mode(param1, true)
	_set_alpha(param1.child_clip("eLight"), 0.0)
	if int(o_buttons_params.get(param1, 0.0)) != 0:
		if param3 == true:
			var sc: float = o_buttons_params[param1]
			param1.scale = Vector2(sc, sc)
	else:
		o_buttons_params[param1] = param1.scale.x
	add_event_listener(param1, ROLL_OVER, _rover_goto_and_stop_rd)
	add_event_listener(param1, ROLL_OUT, _rout_goto_and_stop_rd)
	add_event_listener(param1, MOUSE_DOWN, _mdown_on_frames)
	add_event_listener(param1, MOUSE_UP, _mup_on_frames)
	add_event_listener(param1, CLICK, param2)
	add_event_listener(param1, CLICK, play_click_sound)


static func play_click_sound(_param1: ButtonEvent = null) -> void:
	var l := _lib()
	if Sounds.inst != null and l != null:
		Sounds.inst.play(l.get_sound(l.CLICK1), false, 0, 0.4)


static func _mup_on_frames(param1: ButtonEvent) -> void:
	_target_of(param1).goto_and_stop(2)


static func _mdown_on_frames(param1: ButtonEvent) -> void:
	_target_of(param1).goto_and_stop(3)


static func add_button_scale(param1: FlashClip, param2: Callable) -> void:
	param1.stop()
	param1.mouse_children = false
	_set_button_mode(param1, true)
	_set_alpha(param1, 1.0)
	add_event_listener(param1, ROLL_OVER, _rover_scale)
	add_event_listener(param1, ROLL_OUT, _rout_scale)
	add_event_listener(param1, CLICK, param2)


static func remove_button_scale(param1: FlashClip, param2: Callable) -> void:
	remove_button_on_frames(param1, param2)


static func add_button_alpha(param1: FlashClip, param2: Callable) -> void:
	param1.stop()
	param1.mouse_children = false
	_set_button_mode(param1, true)
	_set_alpha(param1, 0.7)
	add_event_listener(param1, ROLL_OVER, _rover_tween_max)
	add_event_listener(param1, ROLL_OUT, _rout_tween_max)
	add_event_listener(param1, CLICK, param2)


static func remove_button_alpha(param1: FlashClip, param2: Callable) -> void:
	remove_button_on_frames(param1, param2)


static func remove_button_on_frames(param1: FlashClip, param2: Callable) -> void:
	_set_alpha(param1, 1.0)
	param1.goto_and_stop(1)
	_set_button_mode(param1, false)
	RWTween.kill_tweens_of(param1)
	remove_event_listener(param1, ROLL_OVER, _rover_tween_max)
	remove_event_listener(param1, ROLL_OUT, _rout_tween_max)
	remove_event_listener(param1, ROLL_OVER, _rover_goto_and_stop)
	remove_event_listener(param1, ROLL_OVER, _rover_goto_and_stop_rd)
	remove_event_listener(param1, ROLL_OUT, _rout_goto_and_stop)
	remove_event_listener(param1, ROLL_OUT, _rout_goto_and_stop_rd)
	remove_event_listener(param1, CLICK, param2)
	remove_event_listener(param1, ROLL_OVER, _rover_scale)
	remove_event_listener(param1, ROLL_OUT, _rout_scale)
	remove_event_listener(param1, MOUSE_DOWN, _mdown_on_frames)
	remove_event_listener(param1, MOUSE_UP, _mup_on_frames)
	remove_event_listener(param1, CLICK, play_click_sound)


static func _rout_goto_and_stop(param1: ButtonEvent) -> void:
	_target_of(param1).goto_and_stop(1)


static func _rover_goto_and_stop(param1: ButtonEvent) -> void:
	_target_of(param1).goto_and_stop(2)


static func _rout_goto_and_stop_rd(param1: ButtonEvent) -> void:
	var mc := _target_of(param1)
	mc.goto_and_stop(1)
	RWTween.to(mc.child_clip("eLight"), 0.3, {"alpha": 0})
	var sc: float = o_buttons_params.get(mc, 0.0)
	RWTween.to(mc, 0.1, {"scaleX": sc, "scaleY": sc})


static func _rover_goto_and_stop_rd(param1: ButtonEvent) -> void:
	var mc := _target_of(param1)
	play_rover(mc)
	mc.goto_and_stop(2)
	RWTween.to(mc.child_clip("eLight"), 0.3, {"alpha": 1})
	var sc: float = float(o_buttons_params.get(mc, 0.0)) * 1.05
	RWTween.to(mc, 0.1, {"scaleX": sc, "scaleY": sc})


static func _rout_scale(param1: ButtonEvent) -> void:
	RWTween.to(_target_of(param1), 0.2, {"scaleX": 1, "scaleY": 1})


static func _rover_scale(param1: ButtonEvent) -> void:
	var mc := _target_of(param1)
	RWTween.to(mc, 0.1, {"scaleX": 1.1, "scaleY": 1.1})
	play_rover(mc)


static func _rout_tween_max(param1: ButtonEvent) -> void:
	RWTween.to(_target_of(param1), 0.1, {"alpha": 0.7})


static func _rover_tween_max(param1: ButtonEvent) -> void:
	RWTween.to(_target_of(param1), 0.3, {"alpha": 1})


static func add_brightness(param1: FlashClip, param2: Callable) -> void:
	param1.stop()
	param1.mouse_children = false
	_set_button_mode(param1, true)
	add_event_listener(param1, ROLL_OVER, _rover_tween_max_brightness)
	add_event_listener(param1, ROLL_OUT, _rout_tween_max_brightness)
	add_event_listener(param1, CLICK, param2)
	RWTween.to(param1, 0.1, {"colorTransform": {"brightness": 1}})


static func _rout_tween_max_brightness(param1: ButtonEvent) -> void:
	RWTween.to(_target_of(param1), 0.3, {"colorTransform": {"brightness": 1}})


static func _rover_tween_max_brightness(param1: ButtonEvent) -> void:
	RWTween.to(_target_of(param1), 0.3, {"colorTransform": {"brightness": 1.3}})


## 原版拼写 removeBrightnes。
static func remove_brightnes(param1: FlashClip, param2: Callable) -> void:
	remove_event_listener(param1, ROLL_OVER, _rover_tween_max_brightness)
	remove_event_listener(param1, ROLL_OUT, _rout_tween_max_brightness)
	remove_event_listener(param1, CLICK, param2)


static func add_button_lite_rd(param1: FlashClip, param2: Callable) -> void:
	param1.stop()
	param1.mouse_children = false
	_set_button_mode(param1, true)
	add_event_listener(param1, ROLL_OVER, _button_rover_rd)
	add_event_listener(param1, ROLL_OUT, _button_rout_rd)
	add_event_listener(param1, CLICK, param2)
	add_event_listener(param1, CLICK, play_click_sound)


static func remove_button_lite_rd(param1: FlashClip, param2: Callable) -> void:
	remove_event_listener(param1, CLICK, play_click_sound)
	remove_event_listener(param1, ROLL_OVER, _button_rover_rd)
	remove_event_listener(param1, ROLL_OUT, _button_rout_rd)
	remove_event_listener(param1, CLICK, param2)
	_set_button_mode(param1, false)


static func _button_rout_rd(param1: ButtonEvent) -> void:
	RWTween.to(_target_of(param1), 1, {"colorMatrixFilter": {"contrast": 1}})


static func _button_rover_rd(param1: ButtonEvent) -> void:
	var mc := _target_of(param1)
	play_rover(mc)
	RWTween.to(mc, 1, {"colorMatrixFilter": {"contrast": 1.6}})


static func play_rover(param1: FlashClip) -> void:
	var l := _lib()
	if Sounds.inst != null and l != null:
		Sounds.inst.play_rover(l.get_sound(l.ROVER), 0, 0.3, param1)


static func _set_alpha(mc: FlashClip, a: float) -> void:
	if mc != null:
		mc.modulate.a = a
