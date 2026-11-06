## 第二章英文文本（二次开发，原版无对应类）：按需读 data/ch2/text/*.json 并缓存。
## 运行时只用 "en"/"name"/"briefing" 等英文字段，中文字段仅供对照。
## 这些文件用 FileAccess 读取，导出时须在 export_presets.cfg 的 include_filter 里。
class_name Ch2Text
extends RefCounted

const DIR := "res://data/ch2/text/"

static var _cache: Dictionary = {}


static func _file(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var data: Dictionary = {}
	var f := FileAccess.open(DIR + name + ".json", FileAccess.READ)
	if f == null:
		push_error("Ch2Text: cannot open %s%s.json" % [DIR, name])
	else:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed
		else:
			push_error("Ch2Text: bad JSON in %s.json" % name)
	_cache[name] = data
	return data


static func glossary() -> Dictionary:
	return _file("glossary")


## 第 n 关（1 基）的文本：name、briefing、objectives、victory、failure、unlock_note。缺失时返回空字典。
static func level(n: int) -> Dictionary:
	for l: Dictionary in _file("levels").get("levels", []):
		if int(l.get("number", 0)) == n:
			return l
	return {}


static func section_name(n: int) -> String:
	for s: Dictionary in _file("levels").get("sections", []):
		if int(s.get("number", 0)) == n:
			return str(s.get("name", ""))
	return ""


## 对白事件（如 "D01-a"）：返回 [{speaker, speaker_zh, en}]，找不到时返回空数组。
static func dialogue(event_id: String) -> Array:
	for e: Dictionary in _file("dialogue").get("events", []):
		if str(e.get("id", "")) == event_id:
			return e.get("lines", [])
	return []


## 目标栏文字：先找关卡 objectives 里 id 匹配的 text，找不到返回 id 本身，便于发现漏译。
static func objective(level_n: int, objective_id: String) -> String:
	for o: Dictionary in level(level_n).get("objectives", []):
		if str(o.get("id", "")) == objective_id:
			return str(o.get("text", objective_id))
	return objective_id


## units.json 的分组（professions / weapons / skills / enemies / bosses）里按 id 取条目。
static func unit_entry(group: String, id: String) -> Dictionary:
	for e: Dictionary in _file("units").get(group, []):
		if str(e.get("id", e.get("weapon_id", ""))) == id:
			return e
	return {}


## units.json 的 skills 分组里属于某把武器的技能条目（文件里的顺序即技能 1、技能 2），weapon_text_id 如 "modao"。
static func weapon_skills(weapon_text_id: String) -> Array:
	var out: Array = []
	for e: Dictionary in _file("units").get("skills", []):
		if str(e.get("weapon_id", "")) == weapon_text_id:
			out.append(e)
	return out


static func clear_cache() -> void:
	_cache.clear()
