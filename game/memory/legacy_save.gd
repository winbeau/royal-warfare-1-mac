# 旧版存档迁移（二次开发新增，原版没有对应类）
# 旧近似实现把进度写在 user://campaign.json：
#   {"version": 1, "slots": [15 个槽], "sound": bool, "music": bool, "autopause": bool, "intro_seen": bool}
# 其中 slots 的下标和 NUMPAN_* 一致（见 data/save_schema.json），即原版 aGameData 的 15 个槽。
# 新存档 user://RoyalDefenderGame7.json 由 StoredData 读写：{"aGameData": [...], "mainParams": {...}, "endGameFlag": {...}}。
#
# 规则：新存档已存在则不动；新存档不存在且旧存档可解析时转换。旧文件只读，不修改、不删除。
# 字段类型或长度对不上的槽保持新存档默认值，并记入返回的 report。
class_name LegacySave
extends RefCounted

const OLD_PATH := "user://campaign.json"
const NEW_PATH := "user://RoyalDefenderGame7.json"

## 槽 -> 期望长度（数组槽）。
const ARRAY_LENGTHS := {0: 24, 1: 10, 2: 41, 4: 48, 6: 10, 13: 24, 14: 24}
const DICT_SLOTS := [5, 7, 8, 10]  # 成就计数、漫画、zanaves、三级兵


## 首次启动迁移。返回 {"migrated": bool, "report": Array[String]}。
static func migrate_if_needed(old_path: String = OLD_PATH, new_path: String = NEW_PATH) -> Dictionary:
	if FileAccess.file_exists(new_path) or not FileAccess.file_exists(old_path):
		return {"migrated": false, "report": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(old_path))
	if not (parsed is Dictionary):
		return {"migrated": false, "report": ["旧存档不是有效的 JSON 对象，跳过迁移"]}
	var result := convert_profile(parsed)
	if result.is_empty():
		return {"migrated": false, "report": ["旧存档缺少 slots，跳过迁移"]}
	var tmp := new_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"migrated": false, "report": ["无法写入新存档：%s" % FileAccess.get_open_error()]}
	f.store_string(JSON.stringify(result.save))
	f.close()
	DirAccess.rename_absolute(tmp, new_path)
	return {"migrated": true, "report": result.report}


## 纯函数：旧 profile -> {"save": {aGameData, mainParams, endGameFlag}, "report": [...]}；无法识别返回 {}。
static func convert_profile(old: Dictionary) -> Dictionary:
	var slots: Variant = old.get("slots")
	if not (slots is Array):
		return {}
	var report: Array = []
	var data: Array = StoredData._default_game_data()
	for i in 15:
		if i == 3:
			continue  # 占位槽，恒为 0
		if i >= (slots as Array).size():
			report.append("槽 %d 缺失，保持默认值" % i)
			continue
		var value: Variant = slots[i]
		if ARRAY_LENGTHS.has(i):
			if value is Array and (value as Array).size() == ARRAY_LENGTHS[i] and _all_numbers(value):
				var arr: Array = []
				for v in value:
					arr.append(int(v))
				data[i] = arr
			else:
				report.append("槽 %d 不是长度 %d 的数字数组，保持默认值" % [i, ARRAY_LENGTHS[i]])
		elif DICT_SLOTS.has(i):
			if value is Dictionary:
				var merged: Dictionary = (data[i] as Dictionary).duplicate()
				for k in merged.keys():
					if (value as Dictionary).has(k) and _is_number(value[k]):
						merged[k] = int(value[k])
					else:
						report.append("槽 %d 缺少字段 %s，保持默认值" % [i, k])
				data[i] = merged
			else:
				report.append("槽 %d 不是对象，保持默认值" % i)
		elif i == 9 or i == 12:
			if _is_number(value):
				data[i] = int(value)
			else:
				report.append("槽 %d 不是数字，保持默认值" % i)
		elif i == 11:
			if value is Array and _all_numbers(value):
				var ids: Array = []
				for v in value:
					ids.append(int(v))
				data[i] = ids
			else:
				report.append("槽 11（已揭示敌人）无法识别，保持默认值")
	var main_params := {"sound": true, "music": true, "hints": true, "autop": true}
	for pair in [["sound", "sound"], ["music", "music"], ["autopause", "autop"]]:
		if old.get(pair[0]) is bool:
			main_params[pair[1]] = old[pair[0]]
		else:
			report.append("设置 %s 缺失，保持默认值" % pair[0])
	# 旧版没有 hints（战内提示）开关，用默认值 true；intro_seen 没有对应项（漫画进度已在槽 7）。
	report.append("hints 无对应旧字段，使用默认值 true")
	if old.has("intro_seen"):
		report.append("intro_seen 无对应新字段，未迁移（漫画进度来自槽 7）")
	var finished: bool = (data[StoredData.NUMPAN_LEVELS] as Array)[23] > 0
	return {
		"save": {"aGameData": data, "mainParams": main_params, "endGameFlag": {"completed": finished}},
		"report": report,
	}


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _all_numbers(arr: Array) -> bool:
	for v in arr:
		if not _is_number(v):
			return false
	return true
