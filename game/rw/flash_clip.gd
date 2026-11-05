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

var _back: Sprite2D
var _front: Sprite2D
var _acc := 0.0
var _child_state := {}   # name -> index of the active state
var _child_vis := {}
var _script_depth := 0
var _ready_done := false

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
	set_process(playing)
	_ready_done = true
	_apply_mouse_children()
	_enter_frame(1, true)

func goto_and_stop(frame: int) -> void:
	playing = false
	set_process(false)
	_enter_frame(frame)

func goto_and_play(frame: int) -> void:
	playing = total_frames > 1
	set_process(playing)
	_enter_frame(frame)

func play() -> void:
	playing = total_frames > 1
	set_process(playing)

func stop() -> void:
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
		_back.visible = true
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
		sprite.visible = true

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
	if data == null:
		return false
	for sprite: Sprite2D in [_front, _back]:
		if sprite == null or not sprite.visible or sprite.texture == null:
			continue
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
	return false
