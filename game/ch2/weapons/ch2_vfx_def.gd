## WP-D1：特效贴图/元数据的只读访问层（assets/ch2/vfx/<name>.png + vfx.json，见 docs/ch2-art-pipeline.md）。
class_name Ch2VfxDef
extends RefCounted

const VFX_JSON_PATH := "res://assets/ch2/vfx/vfx.json"
const VFX_DIR := "res://assets/ch2/vfx/"

static var _meta: Dictionary = {}
static var _textures: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(VFX_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Ch2VfxDef: missing %s" % VFX_JSON_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_meta = parsed

static func meta(name: String) -> Dictionary:
	_ensure_loaded()
	return _meta.get(name, {})

static func texture(name: String) -> Texture2D:
	_ensure_loaded()
	if _textures.has(name):
		return _textures[name]
	var path := VFX_DIR + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_error("Ch2VfxDef: missing %s" % path)
	_textures[name] = tex
	return tex
