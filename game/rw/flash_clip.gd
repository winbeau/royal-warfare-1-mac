class_name FlashClip
extends Control
## Runtime counterpart of a Flash MovieClip exported by pipeline/clips.py.
## Named child instances are real child nodes (named like the AS3 instance, e.g. eUnitPanel/sSensPanel/sArmor);
## everything unnamed is drawn from per-frame rasters ("back" below, "front" above the named children).

signal done

const FPS := 30.0
const MAX_SCRIPT_DEPTH := 8

@export var character_id := 0
@export var total_frames := 1
@export var data: FlashClipData

## 1-based like AS3 `currentFrame`.
var current_frame := 1
var playing := false
## When false every child Control ignores the mouse (AS3 `mouseChildren = false`).
var mouse_children := true:
	set(value):
		mouse_children = value
		_apply_mouse_children()
## AS3 `mouseEnabled`.
var mouse_enabled := true:
	set(value):
		mouse_enabled = value
		mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE

## 相当于 AS3 把剪辑时间轴上的无名图形（Shape）从显示列表移除：自身 back/front 光栅层始终隐藏，
## 具名子节点不受影响。例如 showPage 的 while(eCont.numChildren) removeChildAt(0)。
var hide_own_layers := false:
	set(value):
		hide_own_layers = value
		for layer in [_back, _front]:
			if layer != null and value:
				layer.visible = false

var _back: Sprite2D
var _front: Sprite2D
var _acc := 0.0
var _child_state := {}   # name -> index of the active state
var _child_vis := {}
var _script_depth := 0
var _ready_done := false
## goto_and_* / play / stop called before _ready (图层尚未建好，例如挂在未入树节点下的选择环)：记下，ready 时套用。
var _pending_frame := -1
var _pending_play := -1  # -1 未指定，0 停，1 播

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	if data == null:
		return
	character_id = data.character_id
	total_frames = data.total_frames
	size = data.rect.size
	# Added as plain (non-internal) children on purpose: Node.INTERNAL_MODE_BACK/FRONT only guarantees
	# draw order among children present when the node entered the tree, and here _back/_front are
	# created in _ready() *after* the scene's own named children (already instanced by the loader) —
	# so an internal "back" sprite can still end up drawn on top of a later sibling. move_child() does
	# reorder correctly regardless of when a child was added, so use that instead.
	_back = Sprite2D.new()
	_back.centered = false
	_back.name = "_back"
	add_child(_back)
	move_child(_back, 0)
	_front = Sprite2D.new()
	_front.centered = false
	_front.name = "_front"
	add_child(_front)
	move_child(_front, get_child_count() - 1)
	if data.reuse_frames != null:
		_back.scale = Vector2.ONE
	else:
		_back.scale = Vector2(0.5, 0.5)
		_front.scale = Vector2(0.5, 0.5)
	for cname in data.children:
		_child_state[cname] = -1
	playing = total_frames > 1
	if _pending_play >= 0:
		playing = _pending_play == 1 and total_frames > 1
	set_process(playing)
	_ready_done = true
	_apply_mouse_children()
	var first := _pending_frame if _pending_frame >= 1 else 1
	_pending_frame = -1
	_enter_frame(first, true)

func goto_and_stop(frame: int) -> void:
	if not _ready_done:
		_pending_frame = frame
		current_frame = clampi(frame, 1, maxi(total_frames, 1))
		_pending_play = 0
		return
	playing = false
	set_process(false)
	_enter_frame(frame)

func goto_and_play(frame: int) -> void:
	if not _ready_done:
		_pending_frame = frame
		current_frame = clampi(frame, 1, maxi(total_frames, 1))
		_pending_play = 1
		return
	playing = total_frames > 1
	set_process(playing)
	_enter_frame(frame)

func play() -> void:
	if not _ready_done:
		_pending_play = 1
		return
	playing = total_frames > 1
	set_process(playing)

func stop() -> void:
	if not _ready_done:
		_pending_play = 0
		return
	playing = false
	set_process(false)

func next_frame() -> void:
	goto_and_stop(mini(current_frame + 1, total_frames))

func prev_frame() -> void:
	goto_and_stop(maxi(current_frame - 1, 1))

func child_clip(instance_name: String) -> FlashClip:
	return get_node_or_null(NodePath(instance_name)) as FlashClip

func child_text(instance_name: String) -> FlashText:
	return get_node_or_null(NodePath(instance_name)) as FlashText

## Texture currently shown by the back / front layer (null when empty).
func back_texture() -> Texture2D:
	return _back.texture if _back else null

func front_texture() -> Texture2D:
	return _front.texture if _front else null

## Flash 的 `target.mask = mask`：mask 本身在舞台上不可见，只用它的形状裁切 target。被遮住的部分
## 既不显示，也收不到鼠标事件（升级面板的幕布升起后整块移到遮罩外，压在上方兵种的加点按钮上；
## 原版这些按钮照样能点）。已知用例（popupMission 的 eTextMask / eMapSymbol.eMask / 升级面板五块幕布
## 的 msk）都是矩形遮罩，绘制用 Control.clip_contents（按 mask.size 的矩形裁切）实现；鼠标命中的裁切
## 由 _has_point 按祖先遮罩矩形另外判定（clip_contents 只裁绘制，不裁 GUI 拾取）。
## 把 target 重新挂到 mask 下面，并按两者当前的全局变换换算 target 的新局部变换，保证视觉位置不变；
## mask 自己的图层（_back/_front）隐藏掉（否则会被当成普通可见内容画出来，且默认 mouse_filter=PASS
## 还会拦截点击——这正是当前界面上遮罩被画成实心矩形、同时吞掉点击的根因）。
static func set_mask(target: Control, mask: Control) -> void:
	if not is_instance_valid(target) or not is_instance_valid(mask):
		return
	if target.get_parent() != mask:
		var g := mask.get_global_transform().affine_inverse() * target.get_global_transform()
		var old := target.get_parent()
		if old != null:
			old.remove_child(target)
		_clear_owner_recursive(target)  # 场景实例化后 target 子树的 owner 仍指向旧场景根；IfaceUtil.adopt() 同类问题
		mask.add_child(target)
		target.position = g.get_origin()
		target.rotation = g.get_rotation()
		target.scale = g.get_scale()
	mask.move_child(target, mask.get_child_count() - 1)  # target 画在 mask 自己的图层之上
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mask is FlashClip:
		var mc := mask as FlashClip
		if mc._back != null:
			mc._back.visible = false
		if mc._front != null:
			mc._front.visible = false

## 同 IfaceUtil._clear_owner_recursive：跨场景搬家的子树要递归清 owner，否则后续 add_child 会报
## "owner inconsistent"。
static func _clear_owner_recursive(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_clear_owner_recursive(c)

func _process(delta: float) -> void:
	_acc += delta
	var step := 1.0 / FPS
	var guard := 0
	while _acc >= step and playing and guard < 8:
		_acc -= step
		guard += 1
		var next := current_frame + 1
		if next > total_frames:
			next = 1
		_enter_frame(next)
	if guard >= 8:
		_acc = 0.0

func _enter_frame(frame: int, initial := false) -> void:
	if data == null:
		return
	current_frame = clampi(frame, 1, total_frames)
	_update_layers()
	_update_children(initial)
	_run_scripts()

func _update_layers() -> void:
	var i := current_frame - 1
	if data.reuse_frames != null:
		var count := data.reuse_frames.get_frame_count(&"default")
		_back.texture = data.reuse_frames.get_frame_texture(&"default", mini(i, count - 1))
		_back.position = data.reuse_offset
		_back.visible = not hide_own_layers
		_front.visible = false
		return
	_set_layer(_back, data.back_textures, data.back_offsets, data.back_index, i)
	_set_layer(_front, data.front_textures, data.front_offsets, data.front_index, i)

func _set_layer(sprite: Sprite2D, textures: Array, offsets: PackedVector2Array, index: PackedInt32Array, i: int) -> void:
	var k := index[i] if i < index.size() else -1
	if k < 0:
		sprite.visible = false
		sprite.texture = null
	else:
		sprite.texture = textures[k]
		sprite.position = offsets[k]
		sprite.visible = not hide_own_layers

func _update_children(initial: bool) -> void:
	var stride := FlashClipData.STATE_STRIDE
	for cname in data.children:
		var info: Dictionary = data.children[cname]
		var frames: PackedInt32Array = info.frames
		# last state whose frame <= current_frame
		var lo := 0
		var hi := frames.size() - 1
		while lo < hi:
			var mid := (lo + hi + 1) >> 1
			if frames[mid] <= current_frame:
				lo = mid
			else:
				hi = mid - 1
		if _child_state[cname] == lo:
			continue
		_child_state[cname] = lo
		var node := get_node_or_null(NodePath(cname))
		if node == null or not node is Control:
			continue
		var s: PackedFloat32Array = info.states
		var b := lo * stride
		var shown := s[b] > 0.5
		var was_shown: bool = _child_vis.get(cname, false)
		_child_vis[cname] = shown
		var c := node as Control
		c.visible = shown
		var a := s[b + 1]
		var bb := s[b + 2]
		var cc := s[b + 3]
		var d := s[b + 4]
		var sx := sqrt(a * a + bb * bb)
		c.position = Vector2(s[b + 5], s[b + 6])
		if sx > 0.0:
			c.rotation = atan2(bb, a)
			c.scale = Vector2(sx, (a * d - bb * cc) / sx)
		else:
			c.rotation = 0.0
			c.scale = Vector2(0.0, sqrt(cc * cc + d * d))
		c.modulate = Color(s[b + 7], s[b + 8], s[b + 9], s[b + 10])
		if shown and not was_shown and not initial and node is FlashClip:
			# a timeline instance that re-enters the stage is a fresh instance: it starts at frame 1
			(node as FlashClip).goto_and_play(1)

func _run_scripts() -> void:
	if not data.scripts.has(current_frame) or _script_depth >= MAX_SCRIPT_DEPTH:
		return
	_script_depth += 1
	var ops: Array = data.scripts[current_frame]
	var entered := current_frame
	for op in ops:
		match op[0]:
			"stop":
				stop()
			"done":
				done.emit()
			"goto_play":
				goto_and_play(int(op[1]))
				break
		if current_frame != entered:
			break
	_script_depth -= 1

func _apply_mouse_children() -> void:
	if not _ready_done and data != null:
		return
	for child in get_children():
		if child is Control:
			if not mouse_children:
				if not child.has_meta("_fc_filter"):
					child.set_meta("_fc_filter", child.mouse_filter)
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			elif child.has_meta("_fc_filter"):
				child.mouse_filter = child.get_meta("_fc_filter")
				child.remove_meta("_fc_filter")

func _has_point(point: Vector2) -> bool:
	if data == null or _outside_ancestor_mask(point):
		return false
	return _hit_local(point)

## 点落在某一层祖先遮罩（set_mask 设了 clip_contents 的节点）的矩形之外：Flash 里这部分被遮住，
## 收不到鼠标事件。Godot 的 clip_contents 只裁绘制，GUI 拾取照样命中，且脚本无法覆盖 clips_input，
## 所以在命中测试里自己判。
func _outside_ancestor_mask(point: Vector2) -> bool:
	var a := get_parent()
	var global_pt := Vector2.ZERO
	var computed := false
	while a != null:
		var ac := a as Control
		if ac != null and ac.clip_contents:
			if not computed:
				global_pt = get_global_transform() * point
				computed = true
			if not Rect2(Vector2.ZERO, ac.size).has_point(ac.get_global_transform().affine_inverse() * global_pt):
				return true
		a = a.get_parent()
	return false

## 本剪辑（含子树）在 point（本地坐标）处有没有可点的内容，不看祖先遮罩。
func _hit_local(point: Vector2) -> bool:
	if data == null:
		return false
	var any_texture := false
	for sprite: Sprite2D in [_front, _back]:
		if sprite == null or not sprite.visible or sprite.texture == null:
			continue
		any_texture = true
		var local := (point - sprite.position) / sprite.scale
		var tex := sprite.texture
		var w := tex.get_width()
		var h := tex.get_height()
		if local.x < 0 or local.y < 0 or local.x >= w or local.y >= h:
			continue
		if tex is AtlasTexture:
			var at := tex as AtlasTexture
			var img := data.hit_image(at.atlas)
			if img == null:
				return true
			var p := Vector2i(local) + Vector2i(at.region.position)
			if img.get_pixelv(p).a > 0.05:
				return true
		else:
			var img2 := data.hit_image(tex)
			if img2 == null or img2.get_pixelv(Vector2i(local)).a > 0.05:
				return true
	# 组合符号常见做法：可见图形来自具名子剪辑（例如 eNewHint 的徽标画在子剪辑 d3 里），不是直接烘进
	# 本剪辑自己的 back/front 栅格。mouseChildren=false 只表示子节点不单独派发事件（见 button_class.gd
	# 顶部注释），Flash 的 hitTestPoint 对这类容器仍按整个显示对象（含子树）合并后的可见像素判定——
	# 不下探子节点会让点击只在"父剪辑自己恰好也有不透明像素"的地方生效，肉眼看来明明点在按钮画出来的
	# 图案上（其实画在子剪辑里）却落空，这正是 NEW HINT 这类徽标点不开的根因。按 clip_bounds 同样的
	# 仿射换算（position + scale，不含旋转，和既有写法一致）递归下探。
	for raw_c in get_children():
		if raw_c == _back or raw_c == _front or not (raw_c is FlashClip):
			continue
		var c: FlashClip = raw_c
		if not c.visible:
			continue
		var sx: float = c.scale.x
		var sy: float = c.scale.y
		if sx == 0.0 or sy == 0.0:
			continue
		var local_pt: Vector2 = (point - c.position) / Vector2(sx, sy)
		if c.clip_contents and not Rect2(Vector2.ZERO, c.size).has_point(local_pt):
			continue  # 子树里的遮罩：遮罩外的部分同样不算命中
		if c._hit_local(local_pt):
			return true
	if not any_texture and data.children.is_empty() and not _has_content_children() and data.rect.size != Vector2.ZERO:
		# 纯"命中形状"符号（Flash 里常见做法：填充 alpha=0 的矢量形状专门用来当点击热区，例如地图旗帜/
		# 单位的 sens：Symbol_5595 这类，总帧数 1、没有子对象、back/front 纹理都是空的，只有一个非零
		# rect）。栅格化管线不会为完全透明的填充导出任何位图，所以上面的纹理检测永远找不到东西，点击
		# 因此永远落空。Flash 的 hitTestPoint 对这种形状本来就是按矢量几何判定，不看渲染出的像素
		# alpha；这里退化为按符号的声明包围盒（data.rect，导出时就是该矢量形状的包围盒）做矩形命中，
		# 是能从已导出数据里拿到的最接近的等价物。只在完全没有子节点/子图层时才这样做，避免把正常的
		# 容器剪辑（自己没有位图、但靠子节点显示内容）也误判成热区。
		return data.rect.has_point(point)
	return false

## get_child_count() 总是至少数到 _back/_front（_ready() 无条件创建的两个图层 Sprite2D），
## 这里只看除它们之外还有没有别的子节点（具名子剪辑/文本）。
func _has_content_children() -> bool:
	for c in get_children():
		if c != _back and c != _front:
			return true
	return false
