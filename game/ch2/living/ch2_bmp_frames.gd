## WP-D1：第二章纸娃娃动画帧。由 assets/ch2/units/<body_id>/body.json 的某个动作（action）
## 加上一份帧停留表构造；不使用 Content 的 symbol/SpriteFrames 体系（身体贴图是单独的 2x atlas）。
## apply_frame 不给 sprite 本身设纹理，而是在 sprite 下维护 ch2_body/ch2_weapon/ch2_offhand 三个子节点，
## 按 body.json 的 rod/disc 把当前武器（从 sprite 的 meta "ch2_weapon"/"ch2_offhand" 读取）贴上去。
class_name Ch2BmpFrames
extends BmpFrames

const BODY_DIR := "res://assets/ch2/units/"

## 起测停留表（逻辑帧，见规格 D1.2）。键为动作名；未命中按 [3]*8 兜底。
const HOLD_TABLES: Dictionary = {
	"idle": [3, 3, 3, 3, 3, 3, 3, 3],
	"walk": [3, 3, 3, 3, 3, 3, 3, 3],
	"attack": [3, 3, 3, 2, 4, 3, 3, 3],
	"reload": [4, 4, 4, 4, 4, 4, 4, 4],
	"skill": [3, 3, 3, 3, 6, 3, 3, 3],
	"brace": [3, 3, 3, 3, 6, 3, 3, 3],
	"death": [3, 3, 3, 3, 3, 3, 4, 30],
	"charge": [2, 2, 2, 2, 2, 2, 2, 2],
	"form": [3, 3, 3, 3, 3, 3, 3, 3],
	"fight": [3, 3, 3, 2, 4, 3, 3, 3],
}
## 火铳的 attack 行是射击动作，停留表与近战 attack 不同（规格 D1.2）。
const MUSKET_SHOOT_HOLD := [2, 2, 3, 3, 4, 3, 3, 2]

static var _body_json_cache: Dictionary = {}  # body_id -> Dictionary
static var _atlas_cache: Dictionary = {}  # body_id -> Texture2D
static var _by_key: Dictionary = {}  # "body_id:action" -> Ch2BmpFrames

var frame_textures: Array = []
var frame_origins: Array = []  # Array[Vector2]
var frame_rods: Array = []  # Dictionary{butt,tip} 或 null，每项
var frame_discs: Array = []  # Dictionary{center,axes,angle} 或 null
var frame_hips: Array = []  # Vector2，相对原点、2 倍像素（达思重骑马身的骑乘接点，无此字段的身体恒为 ZERO）
var body_id_: String = ""
var action_name: String = ""

static func _load_body_json(body_id: String) -> Dictionary:
	if _body_json_cache.has(body_id):
		return _body_json_cache[body_id]
	var path := BODY_DIR + body_id + "/body.json"
	var f := FileAccess.open(path, FileAccess.READ)
	var result: Dictionary = {}
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			result = parsed
	else:
		push_error("Ch2BmpFrames: missing %s" % path)
	_body_json_cache[body_id] = result
	return result

static func _load_atlas(body_id: String) -> Texture2D:
	if _atlas_cache.has(body_id):
		return _atlas_cache[body_id]
	var path := BODY_DIR + body_id + "/atlas.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_error("Ch2BmpFrames: missing %s" % path)
	_atlas_cache[body_id] = tex
	return tex

## body.json 的 rod/disc 字段是 JSON 解析出的 Dictionary{Array}；这里转成 Dictionary{Vector2} 方便使用。
static func _to_rod(v: Variant) -> Variant:
	if not (v is Dictionary):
		return null
	var d: Dictionary = v
	var butt: Array = d.get("butt", [0, 0])
	var tip: Array = d.get("tip", [0, 0])
	return {"butt": Vector2(float(butt[0]), float(butt[1])), "tip": Vector2(float(tip[0]), float(tip[1]))}

static func _to_disc(v: Variant) -> Variant:
	if not (v is Dictionary):
		return null
	var d: Dictionary = v
	var center: Array = d.get("center", [0, 0])
	return {"center": Vector2(float(center[0]), float(center[1]))}

static func _hold_table(body_id: String, action: String) -> Array:
	if action == "attack" and body_id == "musketeer_gun":
		return MUSKET_SHOOT_HOLD
	return HOLD_TABLES.get(action, [3, 3, 3, 3, 3, 3, 3, 3])

## 由 body_id + action 构造（带缓存）。body.json 里没有这个 action 时返回 null（调用方按需兜底）。
static func from_body(body_id: String, action: String) -> Ch2BmpFrames:
	var key := "%s:%s" % [body_id, action]
	if _by_key.has(key):
		return _by_key[key]
	var body_json := _load_body_json(body_id)
	var actions: Dictionary = body_json.get("actions", {})
	if not actions.has(action):
		return null
	var act: Dictionary = actions[action]
	var frames_meta: Array = act.get("frames", [])
	var atlas := _load_atlas(body_id)
	var hold: Array = _hold_table(body_id, action)
	var done_raw: Variant = act.get("done", null)
	var result := Ch2BmpFrames.new()
	result.body_id_ = body_id
	result.action_name = action
	var logical_index := 0
	var num_logical := 0
	for h in hold:
		num_logical += int(h)
	result.num_frames = num_logical
	result.frame_commands.resize(num_logical)
	for raw_i in range(frames_meta.size()):
		var fm: Dictionary = frames_meta[raw_i]
		var region: Array = fm.get("region", [0, 0, 1, 1])
		var tex := AtlasTexture.new()
		tex.atlas = atlas
		tex.region = Rect2(region[0], region[1], region[2], region[3])
		var origin_arr: Array = fm.get("origin", [0, 0])
		var origin := Vector2(float(origin_arr[0]), float(origin_arr[1]))
		var rod: Variant = _to_rod(fm.get("rod", null))
		var disc: Variant = _to_disc(fm.get("disc", null))
		var hip_arr: Array = fm.get("hip", [0, 0])
		var hip := Vector2(float(hip_arr[0]), float(hip_arr[1])) if hip_arr is Array and hip_arr.size() >= 2 else Vector2.ZERO
		var run_len: int = int(hold[raw_i]) if raw_i < hold.size() else 3
		for _k in run_len:
			result.frame_textures.append(tex)
			result.frame_origins.append(origin)
			result.frame_rods.append(rod)
			result.frame_discs.append(disc)
			result.frame_hips.append(hip)
			if done_raw != null and int(done_raw) == raw_i and _k == 0:
				result.frame_commands[logical_index] = DONE
			logical_index += 1
	if done_raw != null:
		result.frame_commands[num_logical - 1] = STOP
	_by_key[key] = result
	return result

## 取或创建 ch2_body/ch2_weapon/ch2_offhand 三个子节点（centered=false，缩放 0.5：atlas 与武器图都是 2 倍分辨率）。
static func _child(sprite: Sprite2D, name: String) -> Sprite2D:
	var n: Node = sprite.get_node_or_null(name)
	if n != null:
		return n as Sprite2D
	var s := Sprite2D.new()
	s.name = name
	s.centered = false
	s.scale = Vector2(0.5, 0.5)
	sprite.add_child(s)
	return s

func apply_frame(sprite: Sprite2D, i: int) -> void:
	var idx: int = clampi(i, 0, frame_textures.size() - 1)
	if frame_textures.is_empty():
		return
	var origin: Vector2 = frame_origins[idx]
	var body_node := _child(sprite, "ch2_body")
	body_node.texture = frame_textures[idx]
	body_node.offset = -origin
	body_node.visible = true

	# 注意：get_meta 的 default 若传字面量 null，Godot 会把它当成“没给默认值”，键不存在时照样报错；
	# 必须先 has_meta 判断。
	var weapon_meta: Variant = sprite.get_meta("ch2_weapon") if sprite.has_meta("ch2_weapon") else null
	var weapon_node := _child(sprite, "ch2_weapon")
	var rod: Variant = frame_rods[idx]
	if rod != null and weapon_meta is Dictionary and (weapon_meta as Dictionary).get("texture") != null:
		var wm: Dictionary = weapon_meta
		var butt: Vector2 = rod["butt"]
		var tip: Vector2 = rod["tip"]
		var w_tex: Texture2D = wm["texture"]
		var w_butt: Vector2 = wm.get("butt", Vector2.ZERO)
		var w_tip: Vector2 = wm.get("tip", w_butt)
		# 锚点比例（武器 x 动作，见 data/ch2/weapons.json 的 anchor_along）：rod.butt 不一定对准武器图自己的
		# butt 点，而是对准 butt->tip 方向上这个比例处的点——例如枪托贴肩时，握持点要沿枪身往后移。
		var anchor_map: Dictionary = wm.get("anchor_along", {})
		var anchor_t: float = float(anchor_map.get(action_name, 0.0))
		var anchor_point: Vector2 = w_butt.lerp(w_tip, anchor_t)
		weapon_node.texture = w_tex
		weapon_node.offset = -anchor_point
		weapon_node.position = butt * 0.5
		weapon_node.rotation = (tip - butt).angle()
		weapon_node.visible = true
	else:
		weapon_node.visible = false

	var offhand_meta: Variant = sprite.get_meta("ch2_offhand") if sprite.has_meta("ch2_offhand") else null
	var offhand_node := _child(sprite, "ch2_offhand")
	var disc: Variant = frame_discs[idx]
	if disc != null and offhand_meta is Dictionary and (offhand_meta as Dictionary).get("texture") != null:
		var om: Dictionary = offhand_meta
		var o_tex: Texture2D = om["texture"]
		var o_center: Vector2 = om.get("center", Vector2.ZERO)
		var center: Vector2 = disc["center"]
		offhand_node.texture = o_tex
		offhand_node.offset = -o_center
		offhand_node.position = center * 0.5
		offhand_node.rotation = 0.0
		offhand_node.visible = true
	else:
		offhand_node.visible = false

	# 火铳的枪口位置：rod.tip 换算到 sprite 本地坐标（0.5 缩放），供 Ch2Musketeer.throw_ranged 取用。
	# 同时存 butt->tip 的本地方向向量（未缩放，仅方向）：枪口火光要按该帧杆的真实角度旋转，
	# 不能用"枪口到落点"近似——落点在目标身上，和枪口朝向经常对不上（尤其目标在侧后方时）。
	if rod != null:
		var butt2: Vector2 = rod["butt"]
		var tip2: Vector2 = rod["tip"]
		sprite.set_meta("ch2_muzzle", tip2 * 0.5)
		sprite.set_meta("ch2_muzzle_dir", tip2 - butt2)
	else:
		sprite.set_meta("ch2_muzzle", Vector2.ZERO)
		sprite.set_meta("ch2_muzzle_dir", Vector2.RIGHT)

	# 达思重骑马身的骑乘接点（hip），换算到 sprite 本地坐标，供 Ch2DarthLancer 贴骑手用。
	sprite.set_meta("ch2_hip", frame_hips[idx] * 0.5)
