## WP-D1：武器/职业数值表的只读访问层。数据来自 data/ch2/weapons.json、data/ch2/units.json
## 与 assets/ch2/weapons/weapons.json（武器贴图的 butt/tip/muzzle 像素坐标，见 docs/ch2-art-pipeline.md）。
## 全部按需加载一次并缓存；不在代码里重复抄数值。
class_name Ch2WeaponDef
extends RefCounted

const WEAPONS_DATA_PATH := "res://data/ch2/weapons.json"
const UNITS_DATA_PATH := "res://data/ch2/units.json"
const WEAPON_ART_JSON_PATH := "res://assets/ch2/weapons/weapons.json"
const WEAPON_ART_DIR := "res://assets/ch2/weapons/"

static var _weapons: Dictionary = {}
static var _units: Dictionary = {}
static var _weapon_art: Dictionary = {}
static var _weapon_textures: Dictionary = {}  # id -> Texture2D
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_weapons = _read_json(WEAPONS_DATA_PATH)
	_units = _read_json(UNITS_DATA_PATH)
	_weapon_art = _read_json(WEAPON_ART_JSON_PATH)

static func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Ch2WeaponDef: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

## 武器战斗数值（dao_shield / great_glaive / matchlock / five_thunders / heavy_musket / darth_lancer）。
static func weapon(id: String) -> Dictionary:
	_ensure_loaded()
	return _weapons.get(id, {})

## 职业静态数值（recruit/升级/互换价、武器列表）。class_id: "warden" | "musketeer"。
static func unit_class(class_id: String) -> Dictionary:
	_ensure_loaded()
	return _units.get("classes", {}).get(class_id, {})

## 技能冷却/效果起测表（data/ch2/units.json 的 skills 段）。
static func skill(id: String) -> Dictionary:
	_ensure_loaded()
	return _units.get("skills", {}).get(id, {})

## 武器贴图的 butt/tip（/muzzle/head）像素坐标（assets/ch2/weapons/weapons.json），已是 2 倍像素。
static func weapon_art_meta(art_id: String) -> Dictionary:
	_ensure_loaded()
	return _weapon_art.get(art_id, {})

## 武器贴图（assets/ch2/weapons/<id>.png），懒加载并缓存。art_id 为 null 或找不到图时返回 null（例如盾、二手位空缺）。
static func weapon_texture(art_id: Variant) -> Texture2D:
	if art_id == null or art_id == "":
		return null
	if _weapon_textures.has(art_id):
		return _weapon_textures[art_id]
	var path := WEAPON_ART_DIR + str(art_id) + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_error("Ch2WeaponDef: missing weapon art %s" % path)
	_weapon_textures[art_id] = tex
	return tex
