# 移植自 S/com/greensock/plugins/{TweenPlugin,TintPlugin,ColorTransformPlugin,ColorMatrixFilterPlugin}.as 的数值部分，
# 以及 AS3 DisplayObject 属性（x/y/scaleX/rotation/alpha/width...）到 Godot 节点的映射。供 RWTween 使用。
class_name RWTweenUtil
extends RefCounted

static var _shader: Shader

const _SHADER_CODE := """
shader_type canvas_item;
uniform vec3 ct_mul = vec3(1.0);
uniform vec3 ct_add = vec3(0.0);
uniform vec4 r0 = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 r1 = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 r2 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 r3 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 cm_add = vec4(0.0);
void fragment() {
	vec4 c = COLOR;
	c.rgb = c.rgb * ct_mul + ct_add;
	COLOR = vec4(dot(r0, c), dot(r1, c), dot(r2, c), dot(r3, c)) + cm_add;
}
"""

# ---------------------------------------------------------------------------------------------
# 属性读写（AS3 DisplayObject 属性 -> Godot 节点）
# ---------------------------------------------------------------------------------------------

static func get_prop(t: Variant, p: String) -> Variant:
	if t is Dictionary:
		return t[p]
	if t is Object and t.has_method("rw_tween_get"):
		var hooked: Variant = t.rw_tween_get(p)
		if hooked != null:
			return hooked
	if t is CanvasItem:
		match p:
			"x": return t.position.x
			"y": return t.position.y
			"scaleX": return t.scale.x
			"scaleY": return t.scale.y
			"rotation": return t.rotation_degrees
			"alpha": return t.modulate.a
			"visible": return t.visible
			"width":
				if t is Control: return t.size.x
				if t is Sprite2D and t.texture: return t.texture.get_width() * t.scale.x
			"height":
				if t is Control: return t.size.y
				if t is Sprite2D and t.texture: return t.texture.get_height() * t.scale.y
	return t.get(p)

static func set_prop(t: Variant, p: String, v: Variant) -> void:
	if t is Dictionary:
		t[p] = v
		return
	if t is Object and t.has_method("rw_tween_set") and t.rw_tween_set(p, v):
		return
	if t is CanvasItem:
		match p:
			"x": t.position.x = v; return
			"y": t.position.y = v; return
			"scaleX": t.scale.x = v; return
			"scaleY": t.scale.y = v; return
			"rotation": t.rotation_degrees = v; return
			"alpha": t.modulate.a = v; return
			"visible": t.visible = bool(v); return
			"width":
				if t is Control: t.size.x = v; return
				if t is Sprite2D and t.texture: t.scale.x = v / t.texture.get_width(); return
			"height":
				if t is Control: t.size.y = v; return
				if t is Sprite2D and t.texture: t.scale.y = v / t.texture.get_height(); return
	t.set(p, v)

# ---------------------------------------------------------------------------------------------
# 颜色效果（colorTransform / colorMatrixFilter）-> 着色器
# ---------------------------------------------------------------------------------------------

const _CT_META := "rw_ct"   # [rMul, gMul, bMul, rOff, gOff, bOff]，偏移为 0..255
const _CM_META := "rw_cm"   # 20 个元素的 4x5 矩阵，偏移为 0..255

static func ct_state(node: Object) -> Array:
	return node.get_meta(_CT_META, [1.0, 1.0, 1.0, 0.0, 0.0, 0.0]).duplicate()

static func cm_state(node: Object) -> Array:
	return node.get_meta(_CM_META, [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]).duplicate()

static func apply_fx(node: CanvasItem) -> void:
	var ct := ct_state(node)
	var cm := cm_state(node)
	var mat: ShaderMaterial = node.material as ShaderMaterial
	if mat == null or mat.shader != _get_shader():
		mat = ShaderMaterial.new()
		mat.shader = _get_shader()
		node.material = mat
		for d in node.find_children("*", "CanvasItem", true, false):
			if d.material == null:
				d.use_parent_material = true
	mat.set_shader_parameter("ct_mul", Vector3(ct[0], ct[1], ct[2]))
	mat.set_shader_parameter("ct_add", Vector3(ct[3], ct[4], ct[5]) / 255.0)
	mat.set_shader_parameter("r0", Vector4(cm[0], cm[1], cm[2], cm[3]))
	mat.set_shader_parameter("r1", Vector4(cm[5], cm[6], cm[7], cm[8]))
	mat.set_shader_parameter("r2", Vector4(cm[10], cm[11], cm[12], cm[13]))
	mat.set_shader_parameter("r3", Vector4(cm[15], cm[16], cm[17], cm[18]))
	mat.set_shader_parameter("cm_add", Vector4(cm[4], cm[9], cm[14], cm[19]) / 255.0)

static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SHADER_CODE
	return _shader

# ColorMatrixFilterPlugin 的矩阵运算
const _ID_MATRIX := [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]
const _LUM_R := 0.212671
const _LUM_G := 0.71516
const _LUM_B := 0.072169

## applyMatrix(m1, m2) = m1 * m2（m2 先作用）；偏移项 m1[idx+4] 按 AS3 取 int()。
static func apply_matrix(m1: Array, m2: Array) -> Array:
	var out: Array = []
	out.resize(20)
	var idx := 0
	for _i in 4:
		for j in 5:
			var extra := 0
			if j == 4:
				extra = int(m1[idx + 4])
			out[idx + j] = m1[idx] * m2[j] + m1[idx + 1] * m2[j + 5] + m1[idx + 2] * m2[j + 10] \
					+ m1[idx + 3] * m2[j + 15] + extra
		idx += 5
	return out

static func set_brightness(m: Array, b: float) -> Array:
	var p := b * 100.0 - 100.0
	return apply_matrix([1.0, 0.0, 0.0, 0.0, p, 0.0, 1.0, 0.0, 0.0, p, 0.0, 0.0, 1.0, 0.0, p, 0.0, 0.0, 0.0, 1.0, 0.0], m)

static func set_contrast(m: Array, c: float) -> Array:
	c += 0.01
	var o := 128.0 * (1.0 - c)
	return apply_matrix([c, 0.0, 0.0, 0.0, o, 0.0, c, 0.0, 0.0, o, 0.0, 0.0, c, 0.0, o, 0.0, 0.0, 0.0, 1.0, 0.0], m)

static func set_saturation(m: Array, s: float) -> Array:
	var i := 1.0 - s
	var ir := i * _LUM_R
	var ig := i * _LUM_G
	var ib := i * _LUM_B
	return apply_matrix([ir + s, ig, ib, 0.0, 0.0, ir, ig + s, ib, 0.0, 0.0, ir, ig, ib + s, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0], m)


## AS3 Number(x)：空串 0，非法 NaN。
static func as_number(s: String) -> float:
	var t := s.strip_edges()
	if t == "":
		return 0.0
	if t.is_valid_float():
		return t.to_float()
	return NAN
