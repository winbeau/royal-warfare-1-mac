# 移植自 S/com/greensock/{TweenLite,TweenMax,OverwriteManager}.as、core/{TweenCore,SimpleTimeline,PropTween}.as、
# plugins/{TweenPlugin,BezierPlugin,BezierThroughPlugin,AutoAlphaPlugin,TintPlugin,ColorTransformPlugin,ColorMatrixFilterPlugin}.as
#
# class_name RWTween，API 全是静态函数，转发给 RWTween.inst（autoload RWTweenRunner 的实例）。props 的键沿用 TweenMax 原名，例如：
#   RWTween.to(node, 0.3, {"alpha": 0, "onComplete": Callable(self, "remove")})
#   RWTween.to(arrow, t, {"bezierThrough": [{"x": mx, "y": my}, {"x": tx, "y": ty}], "orientToBezier": true,
#                         "ease": RWEase.linear_ease_none, "onComplete": cb})
#
# 时间语义（与 TweenMax 相同）：
# - 只有一个根时间线，按墙钟时间推进，不是逻辑帧，不受 SceneTree.paused 影响（process_mode = ALWAYS）。
# - 新 tween 的起点 = 上一次根时间线渲染的时刻 + delay（不是调用瞬间的时钟）。
# - 默认缓动是 TweenLite.easeOut = 1-(1-t/d)^2；默认 overwrite 为 OverwriteManager.AUTO(2)，
#   delayedCall 为 overwrite 0。
# - 同一帧内按"后创建的先渲染"的顺序处理（SimpleTimeline 头插法）。
# - tween 被覆盖杀掉（killVars 后无剩余属性）时不调用 onComplete。
#
# 近似/差异：
# - brightness/contrast/saturation 通过 CanvasItem 着色器实现（见 _SHADER_CODE），公式与 Flash 的
#   ColorTransform / ColorMatrixFilter 一致（含 AS3 applyMatrix 的 int 截断），对容器节点会把无自带材质的
#   后代设为 use_parent_material；之后新增的子节点需自行处理。
# - glowFilter 只占用 overwrite 槽并按时间运行，不绘制任何效果。
# - 目标节点被释放后其 tween 静默丢弃（不调用 onComplete）。
# - width/height 对 Control 用 size，对 Sprite2D 用纹理尺寸*scale；其他对象可实现
#   rw_tween_get(prop) / rw_tween_set(prop, value) -> bool 接管任意属性。
class_name RWTween
extends Node

## 运行节点（autoload RWTweenRunner 的实例；--script 模式下若未实例化则首次调用时懒创建）。
static var inst: RWTween = null

const OVERWRITE_NONE := 0
const OVERWRITE_ALL_IMMEDIATE := 1
const OVERWRITE_AUTO := 2

const RAD2DEG := 180.0 / PI

# TweenLite._reservedProps
const _RESERVED := {
	"ease": 1, "delay": 1, "overwrite": 1, "onComplete": 1, "onCompleteParams": 1, "useFrames": 1,
	"runBackwards": 1, "startAt": 1, "onUpdate": 1, "onUpdateParams": 1, "roundProps": 1, "onStart": 1,
	"onStartParams": 1, "onReverseComplete": 1, "onReverseCompleteParams": 1, "onRepeat": 1,
	"onRepeatParams": 1, "proxiedEase": 1, "easeParams": 1, "yoyo": 1, "orientToBezier": 1,
	"timeScale": 1, "immediateRender": 1, "repeat": 1, "repeatDelay": 1, "timeline": 1, "data": 1, "paused": 1,
}

## 测试钩子：true 时 _process 不推进，由 step(dt) 手动推进时钟。
var manual_clock := false
## 上一次渲染的根时间（秒）；新 tween 的起点以它为基准。
var root_time := 0.0
var overwrite_mode := OVERWRITE_AUTO

var _t0_usec := 0
var _timeline: Array = []   # 旧 -> 新
var _master: Dictionary = {}  # target -> Array[Handle]

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if inst == null:
		inst = self

func _exit_tree() -> void:
	if inst == self:
		inst = null

func _ready() -> void:
	_t0_usec = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if manual_clock:
		return
	root_time = (Time.get_ticks_usec() - _t0_usec) * 1e-6
	_render_root()

## 手动推进时钟（测试用，需 manual_clock = true）。
func i_step(dt: float) -> void:
	root_time += dt
	_render_root()

## 清空全部并复位时钟（测试用）。
func i_reset() -> void:
	for h: Handle in _timeline.duplicate():
		h.set_enabled(false)
	_timeline.clear()
	_master.clear()
	root_time = 0.0

func _render_root() -> void:
	var snapshot := _timeline.duplicate()
	for i in range(snapshot.size() - 1, -1, -1):
		var h: Handle = snapshot[i]
		if h.gc:
			continue
		if not h.is_target_alive():
			h.set_enabled(false)
			continue
		if h.active or (root_time >= h.start_time and not h.paused and not h.gc):
			h.render_time(root_time - h.start_time)

# ---------------------------------------------------------------------------------------------
# 公共 API（对应 TweenMax 静态方法）
# ---------------------------------------------------------------------------------------------

func i_to(target: Variant, duration: float, props: Dictionary) -> Handle:
	return Handle.new(self, target, duration, props.duplicate())

func i_from(target: Variant, duration: float, props: Dictionary) -> Handle:
	var v := props.duplicate()
	v["runBackwards"] = true
	if not v.has("immediateRender"):
		v["immediateRender"] = true
	return Handle.new(self, target, duration, v)

func i_from_to(target: Variant, duration: float, from_props: Dictionary, to_props: Dictionary) -> Handle:
	var v := to_props.duplicate()
	v["startAt"] = from_props.duplicate()
	if from_props.get("immediateRender", false):
		v["immediateRender"] = true
	return Handle.new(self, target, duration, v)

func i_delayed_call(delay: float, callable: Callable, params: Array = []) -> Handle:
	return Handle.new(self, callable, 0.0, {
		"delay": delay, "onComplete": callable, "onCompleteParams": params,
		"immediateRender": false, "overwrite": 0,
	})

func i_all_to(targets: Array, duration: float, props: Dictionary, stagger: float = 0.0,
		on_complete_all: Callable = Callable(), on_complete_all_params: Array = []) -> Array:
	var out: Array = []
	var cur_delay: float = float(props.get("delay", 0.0))
	var proxy: Callable = props.get("onComplete", Callable())
	var proxy_params: Array = props.get("onCompleteParams", [])
	var last_index := 0 if stagger <= 0.0 else targets.size() - 1
	for i in targets.size():
		var v := props.duplicate()
		v["delay"] = cur_delay
		if i == last_index and on_complete_all.is_valid():
			v["onComplete"] = func() -> void:
				if proxy.is_valid():
					proxy.callv(proxy_params)
				on_complete_all.callv(on_complete_all_params)
			v["onCompleteParams"] = []
		out.append(Handle.new(self, targets[i], duration, v))
		cur_delay += stagger
	return out

func i_all_from(targets: Array, duration: float, props: Dictionary, stagger: float = 0.0,
		on_complete_all: Callable = Callable(), on_complete_all_params: Array = []) -> Array:
	var v := props.duplicate()
	v["runBackwards"] = true
	if not v.has("immediateRender"):
		v["immediateRender"] = true
	return all_to(targets, duration, v, stagger, on_complete_all, on_complete_all_params)

func i_kill_tweens_of(target: Variant, complete: bool = false) -> void:
	if not _master.has(target):
		return
	for h: Handle in _master[target].duplicate():
		if h.gc:
			continue
		if complete:
			h.complete_now()
		else:
			h.set_enabled(false)
	_master.erase(target)

func i_kill_delayed_calls_to(callable: Callable) -> void:
	kill_tweens_of(callable)

func i_get_tweens_of(target: Variant) -> Array:
	var out: Array = []
	for h: Handle in _master.get(target, []):
		if not h.gc:
			out.append(h)
	return out

func i_get_all_tweens() -> Array:
	var out: Array = []
	for h: Handle in _timeline:
		if not h.gc:
			out.append(h)
	return out

## TweenMax.killAll(complete, tweens, delayedCalls)：Main 切屏时调用的是 (false, false, true)，即只杀 delayedCall。
func i_kill_all(complete: bool = false, tweens: bool = true, delayed_calls: bool = true) -> void:
	var all := get_all_tweens()
	for i in range(all.size() - 1, -1, -1):
		var h: Handle = all[i]
		if h.is_delayed_call == delayed_calls or h.is_delayed_call != tweens:
			if complete:
				h.complete_now()
			else:
				h.set_enabled(false)

func i_pause_all(tweens: bool = true, delayed_calls: bool = true) -> void:
	_change_pause(true, tweens, delayed_calls)

func i_resume_all(tweens: bool = true, delayed_calls: bool = true) -> void:
	_change_pause(false, tweens, delayed_calls)

func _change_pause(p: bool, tweens: bool, delayed_calls: bool) -> void:
	var all := get_all_tweens()
	for i in range(all.size() - 1, -1, -1):
		var h: Handle = all[i]
		if h.is_delayed_call == delayed_calls or h.is_delayed_call != tweens:
			h.set_paused(p)


## 取运行节点；autoload 未实例化（--script 模式）时懒创建并挂到 SceneTree root。
static func inst_() -> RWTween:
	if inst == null or not is_instance_valid(inst):
		var n := RWTween.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(n)
		inst = n
	return inst

static func to(target: Variant, duration: float, props: Dictionary) -> Handle:
	return inst_().i_to(target, duration, props)

static func from(target: Variant, duration: float, props: Dictionary) -> Handle:
	return inst_().i_from(target, duration, props)

static func from_to(target: Variant, duration: float, from_props: Dictionary, to_props: Dictionary) -> Handle:
	return inst_().i_from_to(target, duration, from_props, to_props)

static func delayed_call(delay: float, callable: Callable, params: Array = []) -> Handle:
	return inst_().i_delayed_call(delay, callable, params)

static func all_to(targets: Array, duration: float, props: Dictionary, stagger: float = 0.0,
		on_complete_all: Callable = Callable(), on_complete_all_params: Array = []) -> Array:
	return inst_().i_all_to(targets, duration, props, stagger, on_complete_all, on_complete_all_params)

static func all_from(targets: Array, duration: float, props: Dictionary, stagger: float = 0.0,
		on_complete_all: Callable = Callable(), on_complete_all_params: Array = []) -> Array:
	return inst_().i_all_from(targets, duration, props, stagger, on_complete_all, on_complete_all_params)

static func kill_tweens_of(target: Variant, complete: bool = false) -> void:
	inst_().i_kill_tweens_of(target, complete)

static func kill_delayed_calls_to(callable: Callable) -> void:
	inst_().i_kill_delayed_calls_to(callable)

static func get_tweens_of(target: Variant) -> Array:
	return inst_().i_get_tweens_of(target)

static func get_all_tweens() -> Array:
	return inst_().i_get_all_tweens()

static func kill_all(complete: bool = false, tweens: bool = true, delayed_calls: bool = true) -> void:
	inst_().i_kill_all(complete, tweens, delayed_calls)

static func pause_all(tweens: bool = true, delayed_calls: bool = true) -> void:
	inst_().i_pause_all(tweens, delayed_calls)

static func resume_all(tweens: bool = true, delayed_calls: bool = true) -> void:
	inst_().i_resume_all(tweens, delayed_calls)

## 测试钩子（转发）
static func step(dt: float) -> void:
	inst_().i_step(dt)

static func reset() -> void:
	inst_().i_reset()

# ---------------------------------------------------------------------------------------------
# 插件
# ---------------------------------------------------------------------------------------------

class PT:
	var target: Variant
	var prop: String
	var start: float
	var change: float
	var name: String
	var plugin: Plugin = null  # 非 null 即 isPlugin：prop 固定为 changeFactor

class Plugin:
	var overwrite_props: Array = []
	func init(_target: Variant, _value: Variant, _tw: Handle) -> bool:
		return false
	func set_ratio(_f: float) -> void:
		pass
	func kill_props(d: Dictionary) -> void:
		for i in range(overwrite_props.size() - 1, -1, -1):
			if d.has(overwrite_props[i]):
				overwrite_props.remove_at(i)

class AutoAlphaPlugin extends Plugin:
	var _target: Variant
	var _ignore_visible := false
	var _tweens: Array = []
	func _init() -> void:
		overwrite_props = ["alpha", "visible"]
	func init(target: Variant, value: Variant, _tw: Handle) -> bool:
		_target = target
		var cur: float = RWTweenUtil.get_prop(target, "alpha")
		var change := float(value) - cur
		if change != 0.0:
			_tweens.append([cur, change, "alpha"])
		return true
	func kill_props(d: Dictionary) -> void:
		super.kill_props(d)
		_ignore_visible = d.has("visible")
		for i in range(_tweens.size() - 1, -1, -1):
			if d.has(_tweens[i][2]):
				_tweens.remove_at(i)
	func set_ratio(f: float) -> void:
		for t in _tweens:
			RWTweenUtil.set_prop(_target, "alpha", t[0] + t[1] * f)
		if not _ignore_visible:
			RWTweenUtil.set_prop(_target, "visible", RWTweenUtil.get_prop(_target, "alpha") != 0.0)

class BezierPlugin extends Plugin:
	var through := false
	var _target: Variant
	var _real_target: Variant
	var _orient := false
	var _orient_data: Array = []
	var _future: Dictionary = {}
	var _beziers: Dictionary = {}  # prop -> Array[[a, ctrl, b]]
	func _init(is_through: bool = false) -> void:
		through = is_through
	func init(target: Variant, value: Variant, tw: Handle) -> bool:
		if not (value is Array):
			return false
		_target = target
		_real_target = target
		var vars := tw.vars
		if vars.get("orientToBezier", false) == true:
			_orient_data = [["x", "y", "rotation", 0.0, 0.01]]
			_orient = true
		elif vars.get("orientToBezier") is Array:
			_orient_data = vars["orientToBezier"]
			_orient = true
		var points: Dictionary = {}
		for item: Dictionary in value:
			for k: String in item:
				if not points.has(k):
					points[k] = [RWTweenUtil.get_prop(target, k)]
				if typeof(item[k]) == TYPE_INT or typeof(item[k]) == TYPE_FLOAT:
					points[k].append(float(item[k]))
				else:
					points[k].append(float(RWTweenUtil.get_prop(target, k)) + RWTweenUtil.as_number(str(item[k])))
		for k: String in points:
			overwrite_props.append(k)
			if not vars.has(k):
				continue
			var end: Variant = vars[k]
			if typeof(end) == TYPE_INT or typeof(end) == TYPE_FLOAT:
				points[k].append(float(end))
			else:
				points[k].append(float(RWTweenUtil.get_prop(target, k)) + RWTweenUtil.as_number(str(end)))
			tw.kill_vars({k: true}, false)
			vars.erase(k)
		_beziers = parse_beziers(points, through)
		return true
	## BezierPlugin.parseBeziers
	static func parse_beziers(points: Dictionary, is_through: bool) -> Dictionary:
		var out: Dictionary = {}
		for k: String in points:
			var a: Array = points[k]
			var segs: Array = []
			out[k] = segs
			if is_through:
				if a.size() > 2:
					segs.append([a[0], a[1] - (a[2] - a[0]) / 4.0, a[1]])
					for i in range(1, a.size() - 1):
						segs.append([a[i], a[i] + (a[i] - segs[i - 1][1]), a[i + 1]])
				else:
					segs.append([a[0], (a[0] + a[1]) / 2.0, a[1]])
			else:
				if a.size() > 3:
					segs.append([a[0], a[1], (a[1] + a[2]) / 2.0])
					for i in range(2, a.size() - 2):
						segs.append([segs[i - 2][2], a[i], (a[i] + a[i + 1]) / 2.0])
					segs.append([segs[segs.size() - 1][2], a[a.size() - 2], a[a.size() - 1]])
				elif a.size() == 3:
					segs.append([a[0], a[1], a[2]])
				elif a.size() == 2:
					segs.append([a[0], (a[0] + a[1]) / 2.0, a[1]])
		return out
	func kill_props(d: Dictionary) -> void:
		for k in _beziers.keys():
			if d.has(k):
				_beziers.erase(k)
		super.kill_props(d)
	func _write(k: String, v: float) -> void:
		RWTweenUtil.set_prop(_target, k, v)
	func set_ratio(f: float) -> void:
		if f == 1.0:
			for k: String in _beziers:
				var segs: Array = _beziers[k]
				_write(k, segs[segs.size() - 1][2])
		else:
			for k: String in _beziers:
				var segs: Array = _beziers[k]
				var n := segs.size()
				var i: int
				if f < 0.0:
					i = 0
				elif f >= 1.0:
					i = n - 1
				else:
					i = int(n * f)
				var t := (f - i * (1.0 / n)) * n
				var s: Array = segs[i]
				_write(k, s[0] + t * (2.0 * (1.0 - t) * (s[1] - s[0]) + t * (s[2] - s[0])))
		if _orient:
			var cur: Dictionary = {}
			for od: Array in _orient_data:
				cur[od[0]] = RWTweenUtil.get_prop(_target, od[0])
				cur[od[1]] = RWTweenUtil.get_prop(_target, od[1])
			var real: Variant = _target
			_target = _future
			_orient = false
			for od: Array in _orient_data:
				set_ratio(f + (od[4] if od[4] else 0.01))
				var offs := float(od[3]) if od[3] else 0.0
				var dx: float = _future[od[0]] - cur[od[0]]
				var dy: float = _future[od[1]] - cur[od[1]]
				# 角度单位：度（Math.atan2 * 180/PI），与 Flash rotation 一致
				RWTweenUtil.set_prop(real, od[2], atan2(dy, dx) * RAD2DEG + offs)
			_target = real
			_orient = true

class ColorTransformPlugin extends Plugin:
	var _target: CanvasItem
	var _start: Array
	var _end: Array
	func _init() -> void:
		overwrite_props = ["tint"]
	func init(target: Variant, value: Variant, _tw: Handle) -> bool:
		if not (target is CanvasItem) or not (value is Dictionary):
			return false
		_target = target
		_start = RWTweenUtil.ct_state(target)
		_end = _start.duplicate()
		var v: Dictionary = value
		if v.has("brightness"):
			var b: float = v["brightness"]
			var o := maxf(0.0, (b - 1.0) * 255.0)
			var m := 1.0 - absf(b - 1.0)
			_end = [m, m, m, o, o, o]
		elif v.has("exposure"):
			var o2: float = 255.0 * (float(v["exposure"]) - 1.0)
			_end = [1.0, 1.0, 1.0, o2, o2, o2]
		return true
	func set_ratio(f: float) -> void:
		var cur: Array = []
		for i in 6:
			cur.append(_start[i] + (_end[i] - _start[i]) * f)
		_target.set_meta(RWTweenUtil._CT_META, cur)
		RWTweenUtil.apply_fx(_target)

class ColorMatrixFilterPlugin extends Plugin:
	var _target: CanvasItem
	var _start: Array
	var _end: Array
	func _init() -> void:
		overwrite_props = ["colorMatrixFilter"]
	func init(target: Variant, value: Variant, _tw: Handle) -> bool:
		if not (target is CanvasItem) or not (value is Dictionary):
			return false
		_target = target
		_start = RWTweenUtil.cm_state(target)
		var v: Dictionary = value
		var m: Array
		if v.get("matrix") is Array:
			m = v["matrix"]
		else:
			m = _start.duplicate() if v.get("relative", false) == true else RWTweenUtil._ID_MATRIX.duplicate()
			if v.has("brightness"): m = RWTweenUtil.set_brightness(m, float(v["brightness"]))
			if v.has("contrast"): m = RWTweenUtil.set_contrast(m, float(v["contrast"]))
			if v.has("saturation"): m = RWTweenUtil.set_saturation(m, float(v["saturation"]))
			# hue / threshold / colorize 原版未使用，未移植
		_end = m
		return true
	func set_ratio(f: float) -> void:
		var cur: Array = []
		for i in 20:
			cur.append(_start[i] + (_end[i] - _start[i]) * f)
		_target.set_meta(RWTweenUtil._CM_META, cur)
		RWTweenUtil.apply_fx(_target)

class GlowFilterPlugin extends Plugin:
	func _init() -> void:
		overwrite_props = ["glowFilter"]
	func init(_target: Variant, _value: Variant, _tw: Handle) -> bool:
		return true  # 近似：不绘制发光，只占 overwrite 槽并保持时序

static func _make_plugin(name: String) -> Plugin:
	match name:
		"autoAlpha": return AutoAlphaPlugin.new()
		"bezier": return BezierPlugin.new(false)
		"bezierThrough": return BezierPlugin.new(true)
		"colorTransform": return ColorTransformPlugin.new()
		"colorMatrixFilter": return ColorMatrixFilterPlugin.new()
		"glowFilter": return GlowFilterPlugin.new()
	return null

# ---------------------------------------------------------------------------------------------
# Handle = TweenLite/TweenMax 实例
# ---------------------------------------------------------------------------------------------

class Handle:
	var mgr
	var target: Variant
	var vars: Dictionary
	var duration: float
	var delay := 0.0
	var start_time := 0.0
	var cached_time := 0.0
	var ratio := 0.0
	var raw_prev_time := -1.0
	var pause_time := 0.0
	var active := false
	var gc := false
	var initted := false
	var paused := false
	var is_delayed_call := false
	var overwrite := 2
	var ease_fn: Callable = RWEase.default_ease_out
	var prop_tweens: Array = []   # 创建顺序；渲染时倒序（AS3 链表头插）
	var lookup: Dictionary = {}
	var _overwritten: Dictionary = {}

	func _init(manager, tgt: Variant, dur: float, v: Dictionary) -> void:
		mgr = manager
		target = tgt
		vars = v
		duration = maxf(dur, 0.0)
		delay = float(v.get("delay", 0.0))
		is_delayed_call = typeof(tgt) == TYPE_CALLABLE and v.get("onComplete") is Callable and v["onComplete"] == tgt
		active = duration == 0.0 and delay == 0.0 and v.get("immediateRender", true) != false
		start_time = mgr.root_time + delay
		mgr._timeline.append(self)
		if v.get("paused", false):
			set_paused(true)
		overwrite = int(v["overwrite"]) if v.has("overwrite") else mgr.overwrite_mode
		var siblings: Array = mgr._master.get(tgt, [])
		if siblings.is_empty():
			mgr._master[tgt] = [self]
		elif overwrite == 1:
			for s: Handle in siblings.duplicate():
				if not s.gc:
					s.set_enabled(false)
			mgr._master[tgt] = [self]
		else:
			siblings.append(self)
		if active or v.get("immediateRender", false):
			render_time(0.0, false, true)

	func is_target_alive() -> bool:
		if typeof(target) == TYPE_OBJECT:
			return is_instance_valid(target)
		if typeof(target) == TYPE_CALLABLE:
			return (target as Callable).is_valid()
		return true

	## 外部可调用：杀掉（不触发 onComplete）。
	func kill() -> void:
		set_enabled(false)

	func pause() -> void:
		set_paused(true)

	func resume() -> void:
		set_paused(false)

	func set_enabled(enable: bool) -> void:
		if enable:
			return  # 本移植不需要重新启用
		active = false
		mgr._timeline.erase(self)
		var l: Array = mgr._master.get(target, [])
		l.erase(self)
		if l.is_empty():
			mgr._master.erase(target)
		gc = true

	func set_paused(p: bool) -> void:
		if gc or p == paused:
			return
		if p:
			pause_time = mgr.root_time
		else:
			start_time += mgr.root_time - pause_time
		paused = p
		active = not paused and cached_time > 0.0 and cached_time < duration

	func complete_now() -> void:
		render_time(duration, false, false)

	## TweenCore.complete(true, suppress)
	func _complete(suppress: bool) -> void:
		set_enabled(false)
		if not suppress:
			var cb: Variant = vars.get("onComplete")
			if cb is Callable and (cb as Callable).is_valid() and cached_time == duration:
				(cb as Callable).callv(_params("onCompleteParams"))

	func _params(key: String) -> Array:
		var p: Variant = vars.get(key)
		return p if p is Array else []

	## TweenLite/TweenMax.renderTime
	func render_time(t: float, suppress: bool = false, force: bool = false) -> void:
		var prev := cached_time
		var is_complete := false
		var needs_ease := false
		if t >= duration:
			cached_time = duration
			ratio = 1.0
			is_complete = true
			if duration == 0.0:
				if (t == 0.0 or raw_prev_time < 0.0) and raw_prev_time != t:
					force = true
				raw_prev_time = t
		elif t <= 0.0:
			cached_time = 0.0
			ratio = 0.0
			if t < 0.0:
				active = false
				if duration == 0.0:
					if raw_prev_time > 0.0:
						force = true
						is_complete = true
					raw_prev_time = t
		else:
			cached_time = t
			needs_ease = true
		if cached_time == prev and not force:
			return
		if not initted:
			initted = true
			_init_props()
		if not active and not paused:
			active = true
		if needs_ease:
			ratio = ease_fn.call(cached_time, 0.0, 1.0, duration)
		for i in range(prop_tweens.size() - 1, -1, -1):
			var pt: PT = prop_tweens[i]
			var v := pt.start + ratio * pt.change
			if pt.plugin != null:
				pt.plugin.set_ratio(v)
			else:
				RWTweenUtil.set_prop(pt.target, pt.prop, v)
		if vars.get("onUpdate") is Callable and not suppress:
			(vars["onUpdate"] as Callable).callv(_params("onUpdateParams"))
		if is_complete:
			_complete(suppress)

	## TweenMax.init + TweenLite.init
	func _init_props() -> void:
		var sa: Variant = vars.get("startAt")
		if sa is Dictionary:
			var s: Dictionary = sa.duplicate()
			s["overwrite"] = 0
			s["immediateRender"] = true
			Handle.new(mgr, target, 0.0, s)
		var e: Variant = vars.get("ease")
		if e is Callable:
			ease_fn = e
		prop_tweens = []
		lookup = {}
		for key: String in vars.keys():
			if not vars.has(key) or mgr._RESERVED.has(key) or key == "ease":
				continue
			var plugin: Plugin = mgr._make_plugin(key)
			if plugin != null and plugin.init(target, vars[key], self):
				var pt := PT.new()
				pt.target = plugin
				pt.prop = "changeFactor"
				pt.start = 0.0
				pt.change = 1.0
				pt.plugin = plugin
				pt.name = plugin.overwrite_props[0] if plugin.overwrite_props.size() == 1 else "_MULTIPLE_"
				prop_tweens.append(pt)
				if pt.name == "_MULTIPLE_":
					for n in plugin.overwrite_props:
						lookup[n] = pt
				else:
					lookup[pt.name] = pt
			else:
				var pt2 := PT.new()
				pt2.target = target
				pt2.prop = key
				pt2.start = float(RWTweenUtil.get_prop(target, key))
				var val: Variant = vars[key]
				if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
					pt2.change = float(val) - pt2.start
				else:
					pt2.change = RWTweenUtil.as_number(str(val))  # 字符串 = 相对值
				pt2.name = key
				prop_tweens.append(pt2)
				lookup[key] = pt2
		if vars.get("runBackwards", false):
			for pt: PT in prop_tweens:
				pt.start += pt.change
				pt.change = -pt.change
		if not _overwritten.is_empty():
			kill_vars(_overwritten)
			if prop_tweens.is_empty():
				set_enabled(false)
		if overwrite > 1 and not prop_tweens.is_empty():
			var sibs: Array = mgr._master.get(target, [])
			if sibs.size() > 1:
				_manage_overwrites(sibs)

	## OverwriteManager.manageOverwrites，仅 AUTO(2) 模式、单一根时间线。
	func _manage_overwrites(sibs: Array) -> void:
		if overwrite >= 4:
			return
		var overlapping: Array = []
		for i in range(sibs.size() - 1, -1, -1):
			var s: Handle = sibs[i]
			if s == self or s.gc:
				continue
			if s.start_time <= start_time and s.start_time + s.duration > start_time and not s.paused:
				overlapping.append(s)
		for i in range(overlapping.size() - 1, -1, -1):
			var s: Handle = overlapping[i]
			if overwrite == 2:
				s.kill_vars(lookup)
				if s.prop_tweens.is_empty() and s.initted:
					s.set_enabled(false)
			else:
				s.set_enabled(false)

	## TweenLite.killVars
	func kill_vars(props: Dictionary, record: bool = true) -> void:
		for n: String in props:
			if lookup.has(n):
				var pt: PT = lookup[n]
				if pt.plugin != null and pt.name == "_MULTIPLE_":
					pt.plugin.kill_props(props)
					if pt.plugin.overwrite_props.is_empty():
						pt.name = ""
				if pt.name != "_MULTIPLE_":
					prop_tweens.erase(pt)
					lookup.erase(n)
			if record:
				_overwritten[n] = 1
