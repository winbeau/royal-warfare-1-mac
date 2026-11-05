# 移植自 S/gameCore/Memory/storedData.as
# 原版是静态类，SharedObject.getLocal("RoyalDefenderGame7") 改为 user://RoyalDefenderGame7.json。
# 结构与原 sharedData.data 一致：{"aGameData": [...], "mainParams": {...}, "endGameFlag": {...}}，
# aGameData 的下标含义见 NUMPAN_*。
# 隔离模式（命令行 --isolated-profile，与 Content.isolated_profile 约定相同）：flush 不写磁盘，
# 只把序列化文本存入内存 _isolated_blob，init() 从它读回，因此测试不会触碰玩家存档。
# JSON 解析会把整数变成浮点；加载后把“值为整数的浮点”还原为 int（统计量若本为小数且恰为整数则类型可能不同，数值相等）。
# onlineSave / onlineLoad 是 Armor Games 站点云存档功能，不移植。
# 偏离：A_*/U_* 在原版是 static var，这里用 const（无人修改）；achivesScreen_ex.aAchivesKong 的 Kongregate 上报不移植。
class_name StoredData
extends RefCounted

const SAVE_GAME_NAME := "RoyalDefenderGame7"

const U_SWORDMASTER := 0
const U_KNIGHT := 1
const U_SNIPER := 2
const U_CROSSBOW := 3
const U_RED := 4
const U_BLACK := 5
const U_HEAL := 6
const U_BLESS := 7
const U_ASSASIN := 8
const U_SABOT := 9
const A_BACKSTAB := 0
const A_BETRAY := 1
const A_BLOCK := 2
const A_CURSE_BLACK := 3
const A_BREAKARROW := 4
const A_COLLECTMONEY := 5
const A_CORRUPT := 6
const A_CRIT := 7
const A_CRITRANGED := 8
const A_CURSEBLESS := 9
const A_FIREHITSPLASH := 10
const A_FLASH := 11
const A_FLEE := 12
const A_HARMRESIST := 13
const A_HEADSHOT := 14
const A_HIDE := 15
const A_ICE := 16
const A_MASSHEAL := 17
const A_MASSSTUN := 18
const A_METHEOR := 19
const A_PARRY := 20
const A_WEAKSPOT := 21
const A_RESURRECT := 22
const A_ROUNDATTACK := 23
const A_ENCHANT := 24
const A_SILENCE := 25
const A_SLOW := 26
const A_STRONGHEAL := 27
const A_STUN := 28
const A_SUPPRESS := 29
const A_TAUNT := 30
const A_VAMPIRIZM := 31
const A_SELFDESTRUCT := 32
const A_WEAKNESS := 33
const A_POISON_THIEF := 34
const A_MISS_ASSASIN := 35
const NUMPAN_LEVELS := 0
const NUMPAN_UNITS := 1
const NUMPAN_ABILS := 2
const NUMPAN_ACHIVES := 4
const NUMPAN_ACHIVE_COUNTER := 5
const NUMPAN_UNIT_BONUSES := 6
const NUMPAN_COMIX := 7
const NUMPAN_ZANAVES := 8
const NUMPAN_START_TUTORIAL := 9
const NUMPAN_OPENED_TIER3 := 10
const NUMPAN_REVEALED_ENEMY := 11
const NUMPAN_DIFFICULTY := 12
const NUMPAN_LEVELS_MIDDIF := 13
const NUMPAN_LEVELS_HIGHDIF := 14
const COM_SAVE_UNIT := "saveUnit"
const COM_SAVE_ABIL := "saveAbil"
const COM_SAVE_BONUS := "saveBonus"
const COM_SAVE_BONUS_DOWNGRADE := "saveBonusDown"
const COM_VICTORY := "victory"
const COM_SAVE_DATA_TO_SHARED := "saveToShared"
const COM_RESET_ABILITIES := "resetAbilities"
const COMIX_WATCHED := "introDone"
const COMIX_SET_TO_WATCH := "comixSetToWatch"
const ZANAVES_WATCHED := "zanavesWatched"
const START_TUTORIAL_WATCHED := "startTutorialWatched"
const TIER3_SHOWN := "tier3Shown"
const CHANGE_MAIN_PARAMS := "changeMainParams"
const AB_1_KILL_DARTH := 0
const AB_2_KILL_WAMPS := 1
const AB_3_KILL_WITCHES := 2
const AB_4_KILL_OGRES := 3
const AB_5_KILL_ARCHERS := 4
const AB_6_KILL_SKELETONS := 5
const AB_7_KILL_15_ONCE := 6
const AB_8_KILL_WITH_ROGUES := 7
const AB_9_POISON := 8
const AB_10_FROZEN := 9
const AB_11_KILL_BOMBERMAN := 10
const AB_12_KILL_ZOMBIES := 11
const AB_13_MIND_CONTROL := 12
const AB_14_SHOOT_OGRE := 13
const AB_15_KILL_METHEOR := 14
const AB_16_KILL_FLASH := 15
const AB_17_FULL_UPGRADE := 16
const AB_18_MAKE_DAMAGE := 17
const AB_19_HEAL_DAMAGE := 18
const AB_20_ABSORB_DAMAGE := 19
const AB_21_6MISSIONS_3STARS := 20
const AB_22_12MISSIONS_3STARS := 21
const AB_23_18MISSIONS_3STARS := 22
const AB_24_24MISSIONS_3STARS := 23
const AB_25_KILL100 := 24
const AB_26_KILL3000 := 25
const AB_27_KILL6000 := 26
const AB_28_KILL10000 := 27
const AB_29_COMPLETE_1MISSION := 28
const AB_30_COMPLETE_12MISSION := 29
const AB_31_COMPLETE_21MISSION := 30
const AB_32_COMPLETE_24MISSION := 31
const AB_33_GET_119_STARS := 32
const AB_34_LOOSE_MISSION := 33
const AB_35_KIA_10 := 34
const AB_36_KIA_50 := 35
const AB_37_FRIENDS_RESSURECTED := 36
const AB_38_PROTECT_400_TIMES := 37
const AB_39_FARM_GOLD := 38
const AB_40_STEAL_GOLD := 39
const AB_41_STUN_ENEMIES := 40
const AB_42_WRITE_LETTER := 41
const AB_43_UPGRADE_TIER2 := 42
const AB_44_HIRE_UNITS := 43
const AB_45_CURSE_UNITS := 44
const AB_46_BREAK_ARMOR := 45
const AB_47_ALL_ALIVE12 := 46
const AB_48_NUMBER_ELITES := 47
const ADD_ACHIEVE := "addAchieve"
const COM_SAVE_ABIL_BUFFER := "comSaveAbilBuffer"
const COM_REVEAL_ENEMY := "comRevealEnemy"
const COM_CHANGE_DIF := "comChangeDif"
const COM_SAVE_REVEALED_UNITS := "comSaveRevealedUnits"
const COM_SAVE_ABIL_DOWNGRADE := "comSaveAbilDowngrade"

## 对应 SharedObject.data：键 aGameData / main_params / end_game_flag；缺键即 undefined。
static var shared_data: Dictionary = {}
static var local_game_data: Array = []
static var is_save_ok: bool = false
static var main_params = null
static var end_game_flag = null

## 隔离模式：不读写 user://，序列化文本只保留在内存。
static var isolated: bool = OS.get_cmdline_user_args().has("--isolated-profile")
static var _isolated_blob: String = ""
## 测试可改写；默认 user://RoyalDefenderGame7.json。
static var save_path: String = "user://" + SAVE_GAME_NAME + ".json"
## 原版 flush 失败时弹 popupStorageFailure；这里改为日志 + 可选回调（占位）。
static var on_storage_failure: Callable = Callable()


## 测试用：丢弃内存中的隔离存档与静态状态，相当于全新安装。
static func test_wipe() -> void:
	_isolated_blob = ""
	shared_data = {}
	local_game_data = []
	main_params = null
	end_game_flag = null
	is_save_ok = false


static func _read_store() -> void:
	# SharedObject.getLocal：读出已有数据，没有则为空对象。
	shared_data = {}
	var text := ""
	if isolated:
		text = _isolated_blob
	elif FileAccess.file_exists(save_path):
		text = FileAccess.get_file_as_string(save_path)
	if text == "":
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		shared_data = _normalize(parsed)


static func _normalize(v: Variant) -> Variant:
	if v is float and is_finite(v) and v == floorf(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Array:
		for i in v.size():
			v[i] = _normalize(v[i])
		return v
	if v is Dictionary:
		for k in v.keys():
			v[k] = _normalize(v[k])
		return v
	return v


## SharedObject.flush()：成功返回 true。隔离模式只写内存。
static func _flush() -> bool:
	var text := JSON.stringify(shared_data)
	if isolated:
		_isolated_blob = text
		return true
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return DirAccess.rename_absolute(tmp, save_path) == OK


static func _storage_failure() -> void:
	# 原版：popupStorageFailure。此处占位。
	push_warning("StoredData: 存档写入失败（原版弹出 popupStorageFailure）")
	if on_storage_failure.is_valid():
		on_storage_failure.call()


static func init() -> void:
	_read_store()
	if not shared_data.has("aGameData"):
		reset_data()
		reset_main_params()
		resetif_end_game()
	else:
		local_game_data = (shared_data["aGameData"] as Array).duplicate(false)  # concat：浅拷贝
		main_params = shared_data.get("mainParams")
		if main_params == null:
			# 原版此处会对 undefined 取属性而抛错；首次启动路径（reset_data 内 flush 时 main_params 为空）可能产生这种存档。
			main_params = {}
			shared_data["mainParams"] = main_params
		if not main_params.has("autop"):
			main_params["autop"] = true
		if local_game_data.size() == 13:
			var z := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			local_game_data.push_back(z.duplicate())
			local_game_data.push_back(z.duplicate())
		if not shared_data.has("endGameFlag"):
			resetif_end_game()
			var lv: Array = (StoredData.local_game_data[StoredData.NUMPAN_LEVELS] as Array).duplicate()
			var v = lv[23]
			if v > 0:
				set_end_game_completed()
		else:
			end_game_flag = shared_data["endGameFlag"]


static func reset_main_params() -> void:
	main_params = {"sound": true, "music": true, "hints": true, "autop": true}
	shared_data["mainParams"] = main_params


static func resetif_end_game() -> void:
	end_game_flag = {"completed": false}
	shared_data["endGameFlag"] = end_game_flag


static func set_end_game_completed() -> void:
	end_game_flag = {"completed": true}
	shared_data["endGameFlag"] = end_game_flag


## AS3 Array.splice(index, 1, value)：index 越界时等价于追加。
static func _splice1(arr: Array, index: int, value: Variant) -> void:
	if index < arr.size():
		arr[index] = value
	else:
		arr.push_back(value)


static func _geti(arr: Array, index: int) -> int:
	if index >= 0 and index < arr.size():
		return int(arr[index])
	return 0


static func _g(data: Variant, key: String, default_value: Variant = 0) -> Variant:
	if data is Dictionary and data.has(key):
		return data[key]
	return default_value


static func _zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0)
	return a


# 反编译破损，按 P-code 重建：TIER3_SHOWN / ZANAVES_WATCHED / COMIX_WATCHED / COMIX_SET_TO_WATCH 内层 switch 的
# §§goto 与 if(false) 只是 break 伪影，语义即“按编号设置对应键”；其余分支反编译清晰。
static func save_data(event: String, data: Variant = null) -> void:
	match event:
		COM_SAVE_REVEALED_UNITS:
			_splice1(local_game_data, NUMPAN_REVEALED_ENEMY, data["units"])
		COM_CHANGE_DIF:
			_splice1(local_game_data, NUMPAN_DIFFICULTY, data["dif"])
		COM_REVEAL_ENEMY:
			local_game_data[NUMPAN_REVEALED_ENEMY].push_back(data["numb"])
		COM_SAVE_ABIL_BUFFER:
			_splice1(local_game_data, NUMPAN_ACHIVE_COUNTER, data)
		ADD_ACHIEVE:
			var ach_number := int(data["numb"])
			_splice1(local_game_data[NUMPAN_ACHIVES], ach_number, 1)
			# 原版此后向 Kongregate 提交成就（achivesScreen_ex.aAchivesKong），站点功能，不移植。
		CHANGE_MAIN_PARAMS:
			main_params = data
			save_shared_data()
		START_TUTORIAL_WATCHED:
			_splice1(local_game_data, NUMPAN_START_TUTORIAL, 1)
		TIER3_SHOWN:
			var obj: Dictionary = local_game_data[NUMPAN_OPENED_TIER3]
			match int(data["unitNumber"]):
				1: obj["zKnight"] = 1
				2: obj["zCrossbow"] = 1
				3: obj["zMonk"] = 1
				4: obj["zBlack"] = 1
				5: obj["zSpy"] = 1
			_splice1(local_game_data, NUMPAN_OPENED_TIER3, obj)
		ZANAVES_WATCHED:
			var obj: Dictionary = local_game_data[NUMPAN_ZANAVES]
			match int(data["zanavesNumber"]):
				1: obj["zWarriors"] = 1
				2: obj["zArchers"] = 1
				3: obj["zPriests"] = 1
				4: obj["zMages"] = 1
				5: obj["zThieves"] = 1
			_splice1(local_game_data, NUMPAN_ZANAVES, obj)
		COMIX_WATCHED:
			var obj: Dictionary = local_game_data[NUMPAN_COMIX]
			match int(data["comixNumber"]):
				1: obj["comix_intro"] = 1
				2: obj["comix_two"] = 1
				3: obj["comix_three"] = 1
				4: obj["comix_four"] = 1
				5: obj["comix_five"] = 1
				6: obj["comix_end"] = 1
			_splice1(local_game_data, NUMPAN_COMIX, obj)
		COMIX_SET_TO_WATCH:
			var obj: Dictionary = local_game_data[NUMPAN_COMIX]
			match int(data["comixNumber"]):
				1:
					if obj["comix_intro"] < 0: obj["comix_intro"] = 0
				2:
					if obj["comix_two"] < 0: obj["comix_two"] = 0
				3:
					if obj["comix_three"] < 0: obj["comix_three"] = 0
				4:
					if obj["comix_four"] < 0: obj["comix_four"] = 0
				5:
					if obj["comix_five"] < 0: obj["comix_five"] = 0
				6:
					if obj["comix_end"] < 0: obj["comix_end"] = 0
			_splice1(local_game_data, NUMPAN_COMIX, obj)
		COM_VICTORY:
			var lvl := int(data["level"])
			var stars := int(data["stars"])
			var difn := int(data["dif"])
			var a_levels: Array = local_game_data[NUMPAN_LEVELS]
			var old_stars := _geti(a_levels, lvl)
			if old_stars < stars:
				_splice1(a_levels, lvl, stars)
			_splice1(local_game_data, NUMPAN_LEVELS, a_levels.duplicate())
			if difn == 2:
				a_levels = local_game_data[NUMPAN_LEVELS_MIDDIF]
				old_stars = _geti(a_levels, lvl)
				if old_stars < stars:
					_splice1(a_levels, lvl, stars)
				_splice1(local_game_data, NUMPAN_LEVELS_MIDDIF, a_levels.duplicate())
			if difn == 3:
				a_levels = local_game_data[NUMPAN_LEVELS_HIGHDIF]
				old_stars = _geti(a_levels, lvl)
				if old_stars < stars:
					_splice1(a_levels, lvl, stars)
				_splice1(local_game_data, NUMPAN_LEVELS_HIGHDIF, a_levels.duplicate())
		COM_SAVE_UNIT:
			var unit_number := int(data["unitNumber"])
			var a_units: Array = local_game_data[NUMPAN_UNITS]
			_splice1(a_units, unit_number, 1)
			_splice1(local_game_data, NUMPAN_UNITS, a_units.duplicate())
		COM_SAVE_ABIL:
			_add_counter(NUMPAN_ABILS, int(data["abilNumber"]), 1)
		COM_SAVE_ABIL_DOWNGRADE:
			_add_counter(NUMPAN_ABILS, int(data["abilNumber"]), -1)
		COM_SAVE_BONUS:
			_add_counter(NUMPAN_UNIT_BONUSES, int(data["abilNumber"]), 1)
		COM_SAVE_BONUS_DOWNGRADE:
			_add_counter(NUMPAN_UNIT_BONUSES, int(data["abilNumber"]), -1)
		COM_RESET_ABILITIES:
			_splice1(local_game_data, NUMPAN_ABILS, _zeros(81))  # 原版重置为 81 项（初始为 41 项，照搬）
			_splice1(local_game_data, NUMPAN_UNIT_BONUSES, _zeros(10))
		COM_SAVE_DATA_TO_SHARED:
			# 原版仅 flush（不先写 aGameData）；PENDING 状态（磁盘配额对话框）在此不存在。
			is_save_ok = true
			if not _flush():
				is_save_ok = false
				_storage_failure()


static func _add_counter(pan: int, index: int, delta: int) -> void:
	var a: Array = local_game_data[pan]
	var new_amount := _geti(a, index) + delta
	if delta < 0 and new_amount < 0:
		new_amount = 0
	_splice1(a, index, new_amount)
	_splice1(local_game_data, pan, a.duplicate())


static func get_num_gained_stars() -> int:
	var total := 0
	for v in local_game_data[NUMPAN_LEVELS]:
		total += int(v)
	for v in local_game_data[NUMPAN_ACHIVES]:
		total += int(v)
	return total


static func get_num_busy_stars() -> int:
	var total := 0
	for v in local_game_data[NUMPAN_ABILS]:
		total += int(v)
	for v in local_game_data[NUMPAN_UNIT_BONUSES]:
		total += int(v)
	return total


static func get_num_free_stars() -> int:
	return get_num_gained_stars() - get_num_busy_stars()


static func ext_reset() -> void:
	reset_data()


static func check_if_achievement_not_done(index: int) -> bool:
	var arr: Array = local_game_data[NUMPAN_ACHIVES]
	if index >= 0 and index < arr.size() and arr[index] == 0:
		return true
	return false


static func check_last_star() -> bool:
	var result := true
	var arr: Array = (local_game_data[NUMPAN_ACHIVES] as Array).duplicate()
	for i in arr.size():
		if arr[i] == 0:
			if i != AB_33_GET_119_STARS:
				result = false
	return result


static func _default_counters() -> Dictionary:
	return {
		"a1_darkKnitedKilled": 0, "a2_vampiresKilled": 0, "a3_witchesKilled": 0, "a4_ogresKilled": 0,
		"a5_archersKilled": 0, "a6_skeletonsKilled": 0, "a8_killedByRogues": 0, "a9_poisoned": 0,
		"a10_frozen": 0, "a12_zombieKilled": 0, "a13_mindControl": 0, "a15_killByMetheor": 0,
		"a16_killFlash": 0, "a18_makeDamage": 0, "a19_healDamage": 0, "a20_tankDamage": 0,
		"a25_28_totalKilled": 0, "a35_36_lostSoldiers": 0, "a37_ressurect": 0, "a38_protection": 0,
		"a39_farmGold": 0, "a40_stealGold": 0, "a41_stunEnemies": 0, "a43_tier2upgrade": 0,
		"a44_hireUnits": 0, "a45_curseEnemies": 0, "a46_breakArmor": 0, "a48_getElite": 0,
	}


## 默认存档，下标与 NUMPAN_* 对应：0 关卡星 / 1 兵种 / 2 技能 / 3 占位 0 / 4 成就 / 5 成就计数 /
## 6 兵种加成 / 7 漫画 / 8 zanaves / 9 开场教学 / 10 三级兵 / 11 已揭示敌人 / 12 难度 / 13 中难星 / 14 高难星
static func _default_game_data() -> Array:
	return [
		_zeros(24),
		[1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
		_zeros(41),
		0,
		_zeros(48),
		_default_counters(),
		_zeros(10),
		{"comix_intro": 0, "comix_two": -1, "comix_three": -1, "comix_four": -1, "comix_five": -1, "comix_end": -1},
		{"zWarriors": 0, "zArchers": 0, "zPriests": 0, "zMages": 0, "zThieves": 0},
		0,
		{"zKnight": 0, "zCrossbow": 0, "zMonk": 0, "zBlack": 0, "zSpy": 0},
		[],
		1,
		_zeros(24),
		_zeros(24),
	]


static func reset_data() -> void:
	# SharedObject.getLocal 返回同一缓存对象，故不重新读盘，shared_data 保持。
	local_game_data = _default_game_data().duplicate(false)
	save_shared_data()


static func save_shared_data() -> void:
	shared_data["aGameData"] = local_game_data.duplicate(false)  # concat：浅拷贝，内层数组与 local_game_data 共享
	shared_data["mainParams"] = main_params
	is_save_ok = true
	if not _flush():
		is_save_ok = false
		_storage_failure()


## 赞助商全解锁存档。
static func sponsor_unlock() -> void:
	var d := _default_game_data()
	d[NUMPAN_LEVELS] = _filled(24, 3)
	d[NUMPAN_UNITS] = _filled(10, 1)
	d[NUMPAN_ABILS] = _filled(41, 1)
	d[NUMPAN_ACHIVES] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	d[NUMPAN_UNIT_BONUSES] = [1, 1, 1, 0, 0, 0, 0, 0, 1, 0]
	d[NUMPAN_COMIX] = {"comix_intro": 1, "comix_two": 1, "comix_three": 1, "comix_four": 1, "comix_five": 1, "comix_end": 1}
	d[NUMPAN_ZANAVES] = {"zWarriors": 1, "zArchers": 1, "zPriests": 1, "zMages": 1, "zThieves": 1}
	d[NUMPAN_START_TUTORIAL] = 1
	d[NUMPAN_OPENED_TIER3] = {"zKnight": 1, "zCrossbow": 1, "zMonk": 1, "zBlack": 1, "zSpy": 1}
	d[NUMPAN_REVEALED_ENEMY] = [LivingObject.UNDEAD_ZOMBIE, LivingObject.UNDEAD_SKELETON, LivingObject.UNDEAD_SKELETON_ARM, LivingObject.UNDEAD_SKELETON_CAPITAN, LivingObject.UNDEAD_SKELETON_ARCHER, LivingObject.UNDEAD_DARTH_KNIGHT, LivingObject.UNDEAD_GRAY_ZOMBIE, LivingObject.MONSTER_OGRE, LivingObject.UNDEAD_WITCH]
	local_game_data = d.duplicate(false)
	save_shared_data()


static func _filled(n: int, v: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a


# onlineSave() / onlineLoad()：Armor Games 站点云存档（agi.storage），不移植。
