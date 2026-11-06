## 第二章设计包的兵种 id（如 RW_ZOMBIE）到一代 LivingObject 常量的映射。
## 新职业（CH2_*）在 M1 之后加入；M0 只有设计包里 "RW_" 开头的原版敌人和一代友军 kind。
class_name Ch2Kinds
extends RefCounted

## 设计包 id -> 一代敌人 kind
static func enemy_map() -> Dictionary:
	return {
		"RW_ZOMBIE": LivingObject.UNDEAD_ZOMBIE,
		"RW_GREY_ZOMBIE": LivingObject.UNDEAD_GRAY_ZOMBIE,
		"RW_PLAGUE_ZOMBIE": LivingObject.UNDEAD_PLAGUE_ZOMBIE,
		"RW_SKELETON": LivingObject.UNDEAD_SKELETON,
		"RW_SKELETON_ARCHER": LivingObject.UNDEAD_SKELETON_ARCHER,
		"RW_ARMORED_SKELETON": LivingObject.UNDEAD_SKELETON_ARM,
		"RW_SKELETON_CAPTAIN": LivingObject.UNDEAD_SKELETON_CAPITAN,
		"RW_DARTH_KNIGHT": LivingObject.UNDEAD_DARTH_KNIGHT,
		"RW_DARTH_GUARDIAN": LivingObject.UNDEAD_STORMGUARDIAN,
		"RW_DARTH_ARCHER": LivingObject.UNDEAD_STORMARCHER,
		"RW_DARTH_SLAYER": LivingObject.UNDEAD_STORMTROOPER,
		"RW_SHAMAN": LivingObject.UNDEAD_SHAMAN,
		"RW_WITCH": LivingObject.UNDEAD_WITCH,
		"RW_UNDEAD_RANGER": LivingObject.UNDEAD_RANGER,
		"RW_HOUND": LivingObject.MONSTER_HOUND,
		"RW_BOMBER": LivingObject.MONSTER_KAMIKAZE,
		"RW_OGRE": LivingObject.MONSTER_OGRE,
		"RW_GHOST": LivingObject.UNDEAD_GHOST,
		"RW_VAMPIRE": LivingObject.UNDEAD_VAMPIRE,
	}


## WP-D1 新增：第二章新职业/新敌人 kind 常量。一代的 kind 都小于 100，不与这些冲突。
const CH2_WARDEN := 100
const CH2_MUSKETEER := 101
const CH2_DARTH_LANCER := 150

## 第二章新职业 kind 名（关卡 JSON 的 start.units / allies 用）-> 常量。镇戍卫、火铳卫都是友军。
static func ch2_friend_kind_map() -> Dictionary:
	return {
		"CH2_WARDEN": CH2_WARDEN,
		"CH2_MUSKETEER": CH2_MUSKETEER,
	}


## 第二章新敌人 kind 名 -> 常量。
static func ch2_enemy_kind_map() -> Dictionary:
	return {
		"CH2_DARTH_LANCER": CH2_DARTH_LANCER,
	}


## kind 常量 -> 名字（用于调试/报错展示，不用于存档或数据 id）。
static func ch2_kind_name(kind: int) -> String:
	match kind:
		CH2_WARDEN:
			return "CH2_WARDEN"
		CH2_MUSKETEER:
			return "CH2_MUSKETEER"
		CH2_DARTH_LANCER:
			return "CH2_DARTH_LANCER"
	return ""


## 一代友军 kind 名（关卡 JSON 的 start.units / allies 用）-> 常量
static func friend_map() -> Dictionary:
	return {
		"FR_WARRIOR": LivingObject.FR_WARRIOR,
		"FR_SWORDMASTER": LivingObject.FR_SWORDMASTER,
		"FR_KNIGHT": LivingObject.FR_KNIGHT,
		"FR_ARCHER": LivingObject.FR_ARCHER,
		"FR_CROSSBOW": LivingObject.FR_CROSSBOW,
		"FR_SNIPER": LivingObject.FR_SNIPER,
		"FR_PRIEST": LivingObject.FR_PRIEST,
		"FR_HEALER": LivingObject.FR_HEALER,
		"FR_BLESSER": LivingObject.FR_BLESSER,
		"FR_BLUEMAGE": LivingObject.FR_BLUEMAGE,
		"FR_REDMAGE": LivingObject.FR_REDMAGE,
		"FR_BLACKMAGE": LivingObject.FR_BLACKMAGE,
		"FR_ROGUE": LivingObject.FR_ROGUE,
		"FR_ASSASIN": LivingObject.FR_ASSASIN,
		"FR_SABOTEUR": LivingObject.FR_SABOTEUR,
		"FR_KING": LivingObject.FR_KING,
		"NPC_MAN": LivingObject.NPC_MAN,
		"NPC_OLDMAN": LivingObject.NPC_OLDMAN,
		"NPC_WOMAN": LivingObject.NPC_WOMAN,
	}


## 招募按钮/职业锁定常量名（level JSON 的 "locked" 字段、get_locked_units 用）-> 常量
static func lock_map() -> Dictionary:
	var m: Dictionary = friend_map()
	m.merge({
		"BUTTON_WARRIORS": LivingObject.BUTTON_WARRIORS,
		"BUTTON_MAGES": LivingObject.BUTTON_MAGES,
		"BUTTON_ARCHERS": LivingObject.BUTTON_ARCHERS,
		"BUTTON_PRIESTS": LivingObject.BUTTON_PRIESTS,
		"BUTTON_THIEVES": LivingObject.BUTTON_THIEVES,
	})
	return m


## 解析任意 kind 名；未知返回 -1（调用方负责报错）。
static func resolve(kind_name: String) -> int:
	var e: Dictionary = enemy_map()
	if e.has(kind_name):
		return int(e[kind_name])
	var f: Dictionary = friend_map()
	if f.has(kind_name):
		return int(f[kind_name])
	var cf: Dictionary = ch2_friend_kind_map()
	if cf.has(kind_name):
		return int(cf[kind_name])
	var ce: Dictionary = ch2_enemy_kind_map()
	if ce.has(kind_name):
		return int(ce[kind_name])
	return -1


static func resolve_lock(name: String) -> int:
	var m: Dictionary = lock_map()
	if m.has(name):
		return int(m[name])
	return -1


static func is_enemy(kind_name: String) -> bool:
	return enemy_map().has(kind_name) or ch2_enemy_kind_map().has(kind_name)
