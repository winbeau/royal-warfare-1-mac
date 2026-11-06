# 二次开发：第二章三格界面（招募第二页、单位面板换武器、升级面板第二页）共用的数据与取图。
# 职业、武器、技能的对应关系、价格和图标路径都在这里；英文名取 Ch2Text（data/ch2/text/units.json）。
#
# 价格口径（spotlight 规格 D1.4，起测值）：
# - 招募价 = 对应一代兵种类的静态 unit_cost（骑士 320、弩手 340）；二章单位类自带 unit_cost 时以它为准。
# - 基础武器换高级武器 = 对应兵种 XML money_upgrade × 2（镇戍卫 600、火铳卫 300）；A、B 之间互换 × 1。
class_name Ch2UiData
extends RefCounted

const ICON_DIR := "res://assets/ch2/icons/"
const PAD_BG_PATH := "res://assets/ch2/ui/pad_bg.png"

## 一代格子图标区在 `_back` 烘焙位图里的比例（用户 2026-11-06 实测给出，左上角-右下角，0..1）：
## 技能格（Symbol_307 一类）与兵种格（Symbol_295/Symbol_543 一类）形状不同，比例也不同。
const SKILL_PAD_ICON_RATIO := [Vector2(0.069, 0.048), Vector2(0.873, 0.648)]
const UNIT_PAD_ICON_RATIO := [Vector2(0.094, 0.329), Vector2(0.849, 0.888)]

## 职业表。n = 一代招募子面板的 lastClickedUnitNumber（1 战士系、2 弓手系）；selector = eSelector 帧；
## money_upgrade = 对应一代兵种 XML 的 money_upgrade（换装费按它推出）。
const PROFESSIONS := {
	"warden": {
		"n": 1, "kind": 100, "selector": 1, "base": "dao_shield",
		"adv": ["great_glaive", "horse_cleaver"], "money_upgrade": 300,
	},
	"musketeer": {
		"n": 2, "kind": 101, "selector": 2, "base": "matchlock",
		"adv": ["five_thunders", "heavy_musket"], "money_upgrade": 150,
	},
}
## 升级面板第二页的五列顺序（后三个职业本阶段未开放）。
const PAGE_COLUMNS := ["warden", "musketeer", "outrider", "elementalist", "exorcist"]

## 本阶段已做出来的武器；其余职业的武器格子保留但不可选。
const AVAILABLE_WEAPONS := ["dao_shield", "great_glaive", "horse_cleaver", "matchlock", "five_thunders", "heavy_musket"]

## 武器 id（图标文件名、set_weapon 的参数）-> data/ch2/text/units.json 里的 id。
const WEAPON_TEXT_ID := {
	"dao_shield": "dao-shield", "great_glaive": "modao", "horse_cleaver": "horse-cleaver",
	"matchlock": "standard-gun", "five_thunders": "five-thunder", "heavy_musket": "heavy-gun",
}
## 用户 2026-11-06 规则改动：每个职业两个基础技能，每把高级武器一个"超集"升级技能（继承一个基础技能，
## 单位持有的另一槽仍是原来的基础技能）。武器 -> 两个技能 id（单位面板技能槽显示顺序）。
const WEAPON_SKILLS := {
	"dao_shield": ["hold_fast", "intercept"],
	"great_glaive": ["horsebreaker", "intercept"],
	"horse_cleaver": ["hold_fast", "follow_through"],
	"matchlock": ["steady_aim", "rending_shot"],
	"five_thunders": ["steady_aim", "scattershot"],
	"heavy_musket": ["heartpiercer", "rending_shot"],
}
## 职业的两个基础技能（升级面板基础列第 2、3 格；下标即该技能在网格里的行号 0/1）。
const BASE_SKILLS := {
	"warden": ["hold_fast", "intercept"],
	"musketeer": ["steady_aim", "rending_shot"],
}
## 高级武器的升级技能 -> 它继承的那个基础技能。升级面板里：继承技能所在的行放升级技能的加点格，
## 另一行放继承技能图标的灰色只读副本（提示 "Inherited: <继承技能名>"）。
const ADV_UPGRADE_SKILL := {
	"great_glaive": "horsebreaker", "horse_cleaver": "follow_through",
	"five_thunders": "scattershot", "heavy_musket": "heartpiercer",
}
const SKILL_INHERITS_FROM := {
	"horsebreaker": "hold_fast", "follow_through": "intercept",
	"scattershot": "rending_shot", "heartpiercer": "steady_aim",
}
## 技能 -> 图标文件名（assets/ch2/icons/skills/）。Intercept 沿用原来 Shield Bash 的图（shield_bash.png）；
## 英文名与说明不在这里写死，动态从 data/ch2/text/units.json 读（见 _skill_json），避免和文案改动脱节。
const SKILL_ICON := {
	"hold_fast": "hold_fast", "intercept": "shield_bash", "horsebreaker": "horsebreaker",
	"follow_through": "follow_through", "steady_aim": "steady_aim", "rending_shot": "rending_shot",
	"scattershot": "scattershot", "heartpiercer": "heartpiercer",
}
## 单位字段里弹匣剩余数的候选名（D1 的实际字段名不在本包决定，逐个探测）。
const AMMO_FIELDS := ["magazine_left", "ammo_left", "magazine", "ammo", "mag_left", "rounds_left"]

static var _tex_cache: Dictionary = {}


static func profession_of_kind(kind: int) -> String:
	for id: String in PROFESSIONS:
		if int(PROFESSIONS[id]["kind"]) == kind:
			return id
	return ""


static func profession_of_n(n: int) -> String:
	for id: String in PROFESSIONS:
		if int(PROFESSIONS[id]["n"]) == n:
			return id
	return ""


## 武器 id 归一化：兼容连字符写法（units.json 里的 id）。未知则原样返回。
static func normalize_weapon_id(raw: String) -> String:
	var s := raw.replace("-", "_")
	for id: String in WEAPON_TEXT_ID:
		if WEAPON_TEXT_ID[id] == raw:
			return id
	return s


## 二章友军：kind 在 100..149（150 起是二章敌人）。
static func is_ch2_friend(u: Object) -> bool:
	if u == null:
		return false
	var kind := int(u.get("kind") if u.get("kind") != null else -1)
	return profession_of_kind(kind) != ""


static func unit_profession(u: Object) -> String:
	if u == null:
		return ""
	return profession_of_kind(int(u.get("kind") if u.get("kind") != null else -1))


## 单位当前武器 id（鸭子类型：weapon 可以是字符串或带 id 的对象；也认 weapon_id 字段）。
static func unit_weapon_id(u: Object) -> String:
	if u == null:
		return ""
	var w: Variant = u.get("weapon")
	if w is String:
		return normalize_weapon_id(w)
	if w is Object:
		for field in ["id", "weapon_id"]:
			var v: Variant = (w as Object).get(field)
			if v is String and v != "":
				return normalize_weapon_id(v)
	var wid: Variant = u.get("weapon_id")
	if wid is String and wid != "":
		return normalize_weapon_id(wid)
	return ""


static func weapon_name(weapon_id: String) -> String:
	var e := Ch2Text.unit_entry("weapons", str(WEAPON_TEXT_ID.get(weapon_id, "")))
	return str(e.get("name", weapon_id))


static func profession_name(prof: String) -> String:
	return str(Ch2Text.unit_entry("professions", prof).get("name", prof))


## 该技能在 data/ch2/text/units.json 的 skills 分组里的条目：基础技能按职业基础武器的技能表顺序取
## （BASE_SKILLS 的下标 = Ch2Text.weapon_skills 的列表下标）；升级技能取它所属高级武器唯一的技能条目。
static func _skill_json(skill_id_: String) -> Dictionary:
	for prof: String in PROFESSIONS:
		var base_list: Array = BASE_SKILLS.get(prof, [])
		var idx := base_list.find(skill_id_)
		if idx >= 0:
			var arr := Ch2Text.weapon_skills(str(WEAPON_TEXT_ID.get(PROFESSIONS[prof]["base"], "")))
			if idx < arr.size():
				return arr[idx]
	for w: String in ADV_UPGRADE_SKILL:
		if ADV_UPGRADE_SKILL[w] == skill_id_:
			var arr2 := Ch2Text.weapon_skills(str(WEAPON_TEXT_ID.get(w, "")))
			if arr2.size() > 0:
				return arr2[0]
	return {}


static func skill_name(skill_id_: String) -> String:
	return str(_skill_json(skill_id_).get("name", skill_id_))


static func skill_description(skill_id_: String) -> String:
	return str(_skill_json(skill_id_).get("description", ""))


## 武器两个技能槽（0/1）里的技能 id，供单位面板技能图标显示。
static func skill_id(weapon_id: String, slot: int) -> String:
	var arr: Array = WEAPON_SKILLS.get(weapon_id, [])
	return str(arr[slot]) if slot >= 0 and slot < arr.size() else ""


## 职业的招募价。D1 的 data/ch2/units.json classes.<prof>.unit_cost 是权威来源（本阶段与我们按
## money_upgrade 推出的口径一致）；该文件不存在时退回一代对应兵种类的静态 unit_cost。
static func unit_cost(prof: String) -> int:
	var cls := Ch2WeaponDef.unit_class(prof)
	if cls.has("unit_cost"):
		return int(cls["unit_cost"])
	return FriendKnight.unit_cost if prof == "warden" else FriendCrossBowMan.unit_cost


## 基础武器换高级武器的换装费。优先取 D1 的 units.json upgrade_cost，缺失时退回 money_upgrade × 2。
static func upgrade_fee(prof: String) -> int:
	var cls := Ch2WeaponDef.unit_class(prof)
	if cls.has("upgrade_cost"):
		return int(cls["upgrade_cost"])
	return int(PROFESSIONS[prof]["money_upgrade"]) * 2


## 高级武器 A、B 之间互换的费用。优先取 D1 的 units.json swap_cost，缺失时退回 money_upgrade × 1。
static func swap_fee(prof: String) -> int:
	var cls := Ch2WeaponDef.unit_class(prof)
	if cls.has("swap_cost"):
		return int(cls["swap_cost"])
	return int(PROFESSIONS[prof]["money_upgrade"])


## 单位从 from_weapon（可为空表示新招募）换到 to_weapon 的换装费。
static func change_fee(prof: String, from_weapon: String, to_weapon: String) -> int:
	if from_weapon == to_weapon:
		return 0
	if from_weapon == PROFESSIONS[prof]["base"] or from_weapon == "":
		return upgrade_fee(prof)
	return swap_fee(prof)


## 页面格子 slot 0..2 对应的武器：第 1 格基础，第 2、3 格高级 A、B。
static func slot_weapon(prof: String, slot: int) -> String:
	if slot == 0:
		return str(PROFESSIONS[prof]["base"])
	return str((PROFESSIONS[prof]["adv"] as Array)[slot - 1])


## 武器当前可用（本阶段做出来了且已解锁）。
static func weapon_usable(weapon_id: String) -> bool:
	return AVAILABLE_WEAPONS.has(weapon_id) and StoredData.ch2_weapon_unlocked(weapon_id)


static func ammo_capacity(weapon_id: String) -> int:
	return 5 if weapon_id == "five_thunders" else 1


## 单位当前弹匣剩余数；单位上没有这个字段时按满匣算。
static func unit_ammo(u: Object, capacity: int) -> int:
	for f in AMMO_FIELDS:
		var v: Variant = u.get(f)
		if v is int or v is float:
			return clampi(int(v), 0, capacity)
	return capacity


static func portrait_tex(prof: String) -> Texture2D:
	return _tex(ICON_DIR + "portraits/" + prof + ".png")


static func weapon_tex(weapon_id: String) -> Texture2D:
	return _tex(ICON_DIR + "weapons/" + weapon_id + ".png")


static func skill_tex(skill: String) -> Texture2D:
	var icon: String = str(SKILL_ICON.get(skill, skill))
	return _tex(ICON_DIR + "skills/" + icon + ".png")


## 一个 FlashClip 自身烘焙图层（_back/_front）的可见包围盒，不下探子节点（同 IfaceUtil.clip_bounds
## 的前半段，但不合并子剪辑——升级面板第二页用它从一代的图标格里抠出"只含图标本身"的区域，排开
## 叠在上面的 eLock 星级子剪辑）。找不到任何图层时退回符号声明的 data.rect。
static func backdrop_bounds(clip: FlashClip) -> Rect2:
	var r := Rect2()
	var has := false
	for layer_name in ["_back", "_front"]:
		var layer: Sprite2D = clip.get(layer_name)
		if layer == null or not layer.visible or layer.texture == null:
			continue
		var tr := Rect2(layer.position, layer.texture.get_size() * layer.scale).abs()
		r = tr if not has else r.merge(tr)
		has = true
	if not has and clip.data != null:
		return clip.data.rect
	return r


## 格子图标区在 real 自己局部坐标系下的矩形：按 real 的 `_back` 贴图像素尺寸 × 比例算出，
## 再用 `_back` 自己的 position/scale 换算回 real 的坐标（`_back` 不旋转，仿射变换只有位移和缩放）。
## 取不到纹理时返回全零矩形（调用方应判空跳过，不强行叠图标）。
static func pad_icon_local_rect(real: FlashClip, is_unit_pad: bool) -> Rect2:
	var back: Sprite2D = real.get("_back")
	if back == null or back.texture == null:
		return Rect2()
	var tex_size: Vector2 = back.texture.get_size()
	var ratio: Array = UNIT_PAD_ICON_RATIO if is_unit_pad else SKILL_PAD_ICON_RATIO
	var p0: Vector2 = back.position + (ratio[0] as Vector2) * tex_size * back.scale
	var p1: Vector2 = back.position + (ratio[1] as Vector2) * tex_size * back.scale
	return Rect2(p0, p1 - p0)


static func pad_bg_tex() -> Texture2D:
	return _tex(PAD_BG_PATH)


static func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t


## 一个只显示图标的 TextureRect：居中放在 parent 的 center 处，保持比例缩进 box 内，不吃鼠标。
static func make_icon(parent: Control, box: Vector2, center: Vector2, tex: Texture2D = null) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = box
	r.position = center - box * 0.5
	r.texture = tex
	parent.add_child(r)
	return r
