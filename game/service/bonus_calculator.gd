# 移植自 S/gameCore/serviceUtils/bonusCalculator.as
# 兵种加点加成：从 StoredData 的 NUMPAN_UNIT_BONUSES 读两个等级（每个职业 2 个槽位：[伤害槽, 生命槽]），
# 返回 bonusDamage / bonusHP / bonusArmorPierce / bonusArmor / bonusResist / bonusMagicPierce / bonusMoveSpeed。
#
# 原版是逐兵种的 switch，每个兵种有 3 级伤害加点（1 级、2 级相同，3 级更高）和 3 级生命加点：
#   伤害槽：1 级 -> bonusDamage = d1；2 级 -> bonusDamage = d1 且 extra = e2；3 级 -> bonusDamage = d3 且 extra = e3
#   生命槽：同理，作用于 bonusHP 与另一项 extra
# 本文件把 switch 压缩为数据表 TABLE（由原文件逐分支机械提取并核对：每个兵种都满足“2 级主值同 1 级”）。
# 表项：[d1, d3, 伤害 extra 键, e2, e3, h1, h3, 生命 extra 键, e2, e3]
# 偏离：原版 FR_ASSASIN 末分支的 `while(_loc12_ == 3){...break;}` 等价于 if，已按此处理。
class_name BonusCalculator
extends RefCounted

static var TABLE: Dictionary = {
	LivingObject.FR_WARRIOR: [1, 2, "bonusArmorPierce", 0.1, 0.15,  10, 20, "bonusArmor", 0.1, 0.15],
	LivingObject.FR_SWORDMASTER: [2, 3, "bonusArmorPierce", 0.1, 0.15,  15, 30, "bonusArmor", 0.1, 0.15],
	LivingObject.FR_KNIGHT: [2, 4, "bonusArmorPierce", 0.1, 0.15,  20, 40, "bonusArmor", 0.1, 0.15],
	LivingObject.FR_ARCHER: [1, 2, "bonusArmorPierce", 0.1, 0.15,  5, 10, "bonusMoveSpeed", 0.1, 0.15],
	LivingObject.FR_CROSSBOW: [3, 4, "bonusArmorPierce", 0.1, 0.2,  15, 30, "bonusArmor", 0.1, 0.15],
	LivingObject.FR_SNIPER: [1, 2, "bonusArmorPierce", 0.1, 0.15,  10, 20, "bonusMoveSpeed", 0.1, 0.15],
	LivingObject.FR_BLUEMAGE: [2, 4, "bonusMagicPierce", 0.1, 0.15,  5, 10, "bonusResist", 0.1, 0.2],
	LivingObject.FR_REDMAGE: [3, 5, "bonusMagicPierce", 0.1, 0.2,  10, 20, "bonusResist", 0.1, 0.15],
	LivingObject.FR_BLACKMAGE: [4, 6, "bonusMagicPierce", 0.1, 0.15,  10, 20, "bonusResist", 0.1, 0.15],
	LivingObject.FR_PRIEST: [1, 2, "bonusMoveSpeed", 0.1, 0.15,  5, 10, "bonusResist", 0.1, 0.2],
	LivingObject.FR_HEALER: [2, 4, "bonusMoveSpeed", 0.1, 0.15,  10, 20, "bonusResist", 0.1, 0.15],
	LivingObject.FR_BLESSER: [2, 3, "bonusMoveSpeed", 0.1, 0.15,  10, 20, "bonusResist", 0.1, 0.15],
	LivingObject.FR_ROGUE: [1, 2, "bonusArmorPierce", 0.1, 0.15,  7, 15, "bonusMoveSpeed", 0.1, 0.15],
	LivingObject.FR_SABOTEUR: [2, 3, "bonusArmorPierce", 0.1, 0.15,  10, 20, "bonusMoveSpeed", 0.1, 0.15],
	LivingObject.FR_ASSASIN: [2, 4, "bonusArmorPierce", 0.1, 0.15,  10, 20, "bonusMoveSpeed", 0.1, 0.15],
}


## 兵种 -> [伤害槽下标, 生命槽下标]（原版 if 链：战士/骑士/剑豪 0,1；弓 2,3；法师 4,5；盗贼 6,7；牧师 8,9）
static func _slots(kind: int) -> Array:
	if kind == LivingObject.FR_WARRIOR or kind == LivingObject.FR_KNIGHT or kind == LivingObject.FR_SWORDMASTER:
		return [0, 1]
	if kind == LivingObject.FR_ARCHER or kind == LivingObject.FR_CROSSBOW or kind == LivingObject.FR_SNIPER:
		return [2, 3]
	if kind == LivingObject.FR_BLACKMAGE or kind == LivingObject.FR_BLUEMAGE or kind == LivingObject.FR_REDMAGE:
		return [4, 5]
	if kind == LivingObject.FR_ROGUE or kind == LivingObject.FR_SABOTEUR or kind == LivingObject.FR_ASSASIN:
		return [6, 7]
	if kind == LivingObject.FR_BLESSER or kind == LivingObject.FR_HEALER or kind == LivingObject.FR_PRIEST:
		return [8, 9]
	return [-1, -1]


static func calculate_bonus(param1: int) -> Dictionary:
	var result := {
		"bonusDamage": 0.0, "bonusHP": 0.0, "bonusArmorPierce": 0.0, "bonusArmor": 0.0,
		"bonusResist": 0.0, "bonusMagicPierce": 0.0, "bonusMoveSpeed": 0.0,
	}
	var bonuses: Array = (StoredData.local_game_data[StoredData.NUMPAN_UNIT_BONUSES] as Array).duplicate()
	var slots := _slots(param1)
	var lvl_dmg := 0
	var lvl_hp := 0
	if slots[0] >= 0:
		lvl_dmg = StoredData._geti(bonuses, slots[0])
		lvl_hp = StoredData._geti(bonuses, slots[1])
	if not TABLE.has(param1):
		return result
	var t: Array = TABLE[param1]
	if lvl_dmg == 1:
		result["bonusDamage"] = float(t[0])
	if lvl_dmg == 2:
		result["bonusDamage"] = float(t[0])
		result[t[2]] = t[3]
	if lvl_dmg == 3:
		result["bonusDamage"] = float(t[1])
		result[t[2]] = t[4]
	if lvl_hp == 1:
		result["bonusHP"] = float(t[5])
	if lvl_hp == 2:
		result["bonusHP"] = float(t[5])
		result[t[7]] = t[8]
	if lvl_hp == 3:
		result["bonusHP"] = float(t[6])
		result[t[7]] = t[9]
	return result
