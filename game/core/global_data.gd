# 移植自 S/gameCore/globalData.as
# 一局内的统计（击杀、伤害、金币等）与 48 项成就统计字段 a1..a48；check_achievements 把本局数据累加进存档并判定成就。
# 站点相关（Kongregate 提交、Main.self.addArmorQuests）不移植；addArmorQuests 的参数仅是 Armor Games 任务名列表，
# 此处保留收集过程（armor_quests），不外传。
class_name GlobalData
extends RefCounted

static var inst: GlobalData

var num_killed: int = 0
var num_soldiers_dead: int = 0
var damage_dealt: int = 0
var damage_received: int = 0
var num_healed: int = 0
var num_hired: int = 0
var num_upgrades: int = 0
var gold_gained: int = 0
var gold_spent: int = 0
var start_time: float = 0.0  # Date -> Unix 秒
var a1_dark_knited_killed: int = 0
var a2_vampires_killed: int = 0
var a3_witches_killed: int = 0
var a4_ogres_killed: int = 0
var a5_archers_killed: int = 0
var a6_skeletons_killed: int = 0
var a7_kill_15oneshot: int = 0
var a8_killed_by_rogues: int = 0
var a9_poisoned: int = 0
var a10_frozen: int = 0
var a11_kill_with_bomberman: int = 0
var a12_zombie_killed: int = 0
var a13_mind_control: int = 0
var a14_ogre_killed_but_not_hit: int = 0
var a15_kill_by_metheor: int = 0
var a16_kill_flash: int = 0
var a18_make_damage: int = 0
var a19_heal_damage: int = 0
var a20_tank_damage: int = 0
var a21_24_total_mis_3star: int = 0
var a21_6mis3star: int = 0
var a22_12mis3star: int = 0
var a23_18mis3star: int = 0
var a24_24mis3star: int = 0
var a25_28_total_killed: int = 0
var a25_kill100: int = 0
var a26_kill3000: int = 0
var a27_kill6000: int = 0
var a28_kill10000: int = 0
var a29_pass1: int = 0
var a30_pass12: int = 0
var a31_pass21: int = 0
var a32_pass24: int = 0
var a34_loose_mission: int = 0
var a35_36_lost_soldiers: int = 0
var a35_lost50: int = 0
var a36_lost150: int = 0
var a37_ressurect: int = 0
var a38_protection: int = 0
var a39_farm_gold: int = 0
var a40_steal_gold: int = 0
var a41_stun_enemies: int = 0
var a43_tier2upgrade: int = 0
var a44_hire_units: int = 0
var a45_curse_enemies: int = 0
var a46_break_armor: int = 0
var a47_lost_no_one: int = 0
var a48_get_elite: int = 0
## 最近一次 check_achievements 收集的 Armor Games 任务名（原版传给 Main.addArmorQuests，此处不使用）。
var armor_quests: Array = []


func _init() -> void:
	inst = self


func reset() -> void:
	num_killed = 0
	num_soldiers_dead = 0
	damage_dealt = 0
	damage_received = 0
	num_upgrades = 0
	start_time = Time.get_unix_time_from_system()
	num_healed = 0
	num_hired = 0
	gold_gained = 0
	gold_spent = 0
	a29_pass1 = 0
	a30_pass12 = 0
	a31_pass21 = 0
	a32_pass24 = 0
	a34_loose_mission = 0
	a1_dark_knited_killed = 0
	a2_vampires_killed = 0
	a3_witches_killed = 0
	a4_ogres_killed = 0
	a5_archers_killed = 0
	a6_skeletons_killed = 0
	a8_killed_by_rogues = 0
	a9_poisoned = 0
	a10_frozen = 0
	a12_zombie_killed = 0
	a13_mind_control = 0
	a15_kill_by_metheor = 0
	a21_24_total_mis_3star = 0
	a21_6mis3star = 0
	a22_12mis3star = 0
	a23_18mis3star = 0
	a24_24mis3star = 0
	a16_kill_flash = 0
	a37_ressurect = 0
	a38_protection = 0
	a40_steal_gold = 0
	a41_stun_enemies = 0
	a45_curse_enemies = 0
	a46_break_armor = 0
	a47_lost_no_one = 0
	a48_get_elite = 0
	a18_make_damage = 0
	a19_heal_damage = 0
	a20_tank_damage = 0
	a25_28_total_killed = 0
	a25_kill100 = 0
	a26_kill3000 = 0
	a27_kill6000 = 0
	a28_kill10000 = 0
	a35_36_lost_soldiers = 0
	a39_farm_gold = 0
	a43_tier2upgrade = 0
	a44_hire_units = 0
	a7_kill_15oneshot = 0
	a11_kill_with_bomberman = 0
	a14_ogre_killed_but_not_hit = 0
	a35_lost50 = 0
	a36_lost150 = 0


## 累加计数器类成就的公共部分：达到阈值且尚未获得时登记成就。返回是否新获得。
func _grant(ab: int, gained: Array, quests: Array, quest: String = "") -> void:
	if StoredData.check_if_achievement_not_done(ab):
		StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": ab})
		gained.push_back(ab)
		if quest != "":
			quests.push_back(quest)


# 反编译破损，按 P-code 重建：
# - a14 分支里的 `while(true){push "shootTheOgre"}` 是跳转伪影，实际只执行一次 push，随后顺序进入 `a21_24_total_mis_3star = 0`
#   与按关卡统计 3 星的循环；
# - a21_24 的 6/12/18/24 判定嵌套（P-code 中失败都跳到 switch(param1) 入口）；
# - case 23 的 `while(_loc2_ == true)` 等价于 if。
# 注意原版疑点（照搬）：a43_tier2upgrade 累加后，AB_43_UPGRADE_TIER2 的判定用的是 a41_stun_enemies >= 300。
func check_achievements(param1: int = 0) -> Array:
	var gained: Array = []
	var levels: Array = (StoredData.local_game_data[StoredData.NUMPAN_LEVELS] as Array).duplicate()
	var c: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_ACHIVE_COUNTER]
	var quests: Array = []
	if param1 == -1:
		a34_loose_mission = 1
		_grant(StoredData.AB_34_LOOSE_MISSION, gained, quests)
	a18_make_damage = damage_dealt
	a19_heal_damage = num_healed
	a20_tank_damage = damage_received
	a25_28_total_killed = num_killed
	a35_36_lost_soldiers = num_soldiers_dead
	a39_farm_gold = gold_gained
	a43_tier2upgrade = num_upgrades
	a44_hire_units = num_hired
	if a7_kill_15oneshot != 0:
		_grant(StoredData.AB_7_KILL_15_ONCE, gained, quests)
	if a11_kill_with_bomberman != 0:
		_grant(StoredData.AB_11_KILL_BOMBERMAN, gained, quests, "bombermanDetonated")
	if a14_ogre_killed_but_not_hit != 0:
		_grant(StoredData.AB_14_SHOOT_OGRE, gained, quests, "shootTheOgre")
	a21_24_total_mis_3star = 0
	while levels.size() > 0:
		var star: int = int(levels.pop_front())
		if star == 3:
			a21_24_total_mis_3star += 1
	# Kongregate stats.submit(FULL_STARS_ACHIEVED, ...)：站点功能，不移植。
	if a21_24_total_mis_3star >= 6:
		a21_6mis3star = 1
		_grant(StoredData.AB_21_6MISSIONS_3STARS, gained, quests)
		if a21_24_total_mis_3star >= 12:
			a22_12mis3star = 1
			_grant(StoredData.AB_22_12MISSIONS_3STARS, gained, quests)
			if a21_24_total_mis_3star >= 18:
				a23_18mis3star = 1
				_grant(StoredData.AB_23_18MISSIONS_3STARS, gained, quests)
				if a21_24_total_mis_3star == 24:
					_grant(StoredData.AB_24_24MISSIONS_3STARS, gained, quests, "Master")
					a24_24mis3star = 1
	match param1:
		0:
			a29_pass1 = 1
			_grant(StoredData.AB_29_COMPLETE_1MISSION, gained, quests, "firstMissonCompleted")
		11:
			a30_pass12 = 1
			_grant(StoredData.AB_30_COMPLETE_12MISSION, gained, quests)
		20:
			a31_pass21 = 1
			_grant(StoredData.AB_31_COMPLETE_21MISSION, gained, quests, "destroyedPortal")
		23:
			a32_pass24 = 1
			_grant(StoredData.AB_32_COMPLETE_24MISSION, gained, quests)
	if param1 == 23:
		if a35_36_lost_soldiers == 0:
			a47_lost_no_one = 1
			_grant(StoredData.AB_47_ALL_ALIVE12, gained, quests)
	c["a1_darkKnitedKilled"] += a1_dark_knited_killed
	if c["a1_darkKnitedKilled"] >= 100:
		_grant(StoredData.AB_1_KILL_DARTH, gained, quests)
	c["a2_vampiresKilled"] += a2_vampires_killed
	if c["a2_vampiresKilled"] >= 50:
		_grant(StoredData.AB_2_KILL_WAMPS, gained, quests)
	c["a3_witchesKilled"] += a3_witches_killed
	if c["a3_witchesKilled"] >= 30:
		_grant(StoredData.AB_3_KILL_WITCHES, gained, quests)
	c["a4_ogresKilled"] += a4_ogres_killed
	if c["a4_ogresKilled"] >= 25:
		_grant(StoredData.AB_4_KILL_OGRES, gained, quests)
	c["a5_archersKilled"] += a5_archers_killed
	if c["a5_archersKilled"] >= 150:
		_grant(StoredData.AB_5_KILL_ARCHERS, gained, quests)
	c["a6_skeletonsKilled"] += a6_skeletons_killed
	if c["a6_skeletonsKilled"] >= 1500:
		_grant(StoredData.AB_6_KILL_SKELETONS, gained, quests)
	c["a8_killedByRogues"] += a8_killed_by_rogues
	if c["a8_killedByRogues"] >= 100:
		_grant(StoredData.AB_8_KILL_WITH_ROGUES, gained, quests)
	c["a9_poisoned"] += a9_poisoned
	if c["a9_poisoned"] >= 100:
		_grant(StoredData.AB_9_POISON, gained, quests)
	c["a10_frozen"] += a10_frozen
	if c["a10_frozen"] >= 400:
		_grant(StoredData.AB_10_FROZEN, gained, quests)
	c["a12_zombieKilled"] += a12_zombie_killed
	if c["a12_zombieKilled"] >= 500:
		_grant(StoredData.AB_12_KILL_ZOMBIES, gained, quests)
	c["a13_mindControl"] += a13_mind_control
	if c["a13_mindControl"] >= 100:
		_grant(StoredData.AB_13_MIND_CONTROL, gained, quests)
	c["a15_killByMetheor"] += a15_kill_by_metheor
	if c["a15_killByMetheor"] >= 300:
		_grant(StoredData.AB_15_KILL_METHEOR, gained, quests)
	c["a16_killFlash"] += a16_kill_flash
	if c["a16_killFlash"] >= 120:
		_grant(StoredData.AB_16_KILL_FLASH, gained, quests)
	c["a18_makeDamage"] += a18_make_damage
	if c["a18_makeDamage"] >= 50000:
		_grant(StoredData.AB_18_MAKE_DAMAGE, gained, quests, "damageDealed")
	c["a19_healDamage"] += a19_heal_damage
	if c["a19_healDamage"] >= 5000:
		_grant(StoredData.AB_19_HEAL_DAMAGE, gained, quests, "damageHealed")
	c["a20_tankDamage"] += a20_tank_damage
	if c["a20_tankDamage"] >= 10000:
		_grant(StoredData.AB_20_ABSORB_DAMAGE, gained, quests)
	c["a25_28_totalKilled"] += a25_28_total_killed
	if c["a25_28_totalKilled"] >= 100:
		_grant(StoredData.AB_25_KILL100, gained, quests)
	if c["a25_28_totalKilled"] >= 3000:
		_grant(StoredData.AB_26_KILL3000, gained, quests)
	if c["a25_28_totalKilled"] >= 6000:
		_grant(StoredData.AB_27_KILL6000, gained, quests)
	if c["a25_28_totalKilled"] >= 10000:
		_grant(StoredData.AB_28_KILL10000, gained, quests)
	c["a35_36_lostSoldiers"] += a35_36_lost_soldiers
	if c["a35_36_lostSoldiers"] >= 10:
		_grant(StoredData.AB_35_KIA_10, gained, quests)
	if c["a35_36_lostSoldiers"] >= 50:
		_grant(StoredData.AB_36_KIA_50, gained, quests)
	c["a37_ressurect"] += a37_ressurect
	if c["a37_ressurect"] >= 15:
		_grant(StoredData.AB_37_FRIENDS_RESSURECTED, gained, quests, "ressurectedAllies")
	c["a38_protection"] += a38_protection
	if c["a38_protection"] >= 180:
		_grant(StoredData.AB_38_PROTECT_400_TIMES, gained, quests)
	c["a39_farmGold"] += a39_farm_gold
	if c["a39_farmGold"] >= 100000:
		_grant(StoredData.AB_39_FARM_GOLD, gained, quests)
	c["a40_stealGold"] += a40_steal_gold
	if c["a40_stealGold"] >= 10000:
		_grant(StoredData.AB_40_STEAL_GOLD, gained, quests)
	c["a41_stunEnemies"] += a41_stun_enemies
	if c["a41_stunEnemies"] >= 200:
		_grant(StoredData.AB_41_STUN_ENEMIES, gained, quests)
	c["a43_tier2upgrade"] += a43_tier2upgrade
	if c["a41_stunEnemies"] >= 300:  # 原版疑点：此处本应是 a43_tier2upgrade，照搬
		_grant(StoredData.AB_43_UPGRADE_TIER2, gained, quests)
	c["a44_hireUnits"] += a44_hire_units
	if c["a44_hireUnits"] >= 250:
		_grant(StoredData.AB_44_HIRE_UNITS, gained, quests)
	c["a45_curseEnemies"] += a45_curse_enemies
	if c["a45_curseEnemies"] >= 400:
		_grant(StoredData.AB_45_CURSE_UNITS, gained, quests)
	c["a46_breakArmor"] += a46_break_armor
	if c["a46_breakArmor"] >= 150:
		_grant(StoredData.AB_46_BREAK_ARMOR, gained, quests)
	c["a48_getElite"] += a48_get_elite
	if c["a48_getElite"] >= 50:
		_grant(StoredData.AB_48_NUMBER_ELITES, gained, quests)
	StoredData.save_data(StoredData.COM_SAVE_ABIL_BUFFER, c)
	armor_quests = quests.duplicate()  # Main.self.addArmorQuests(quests.concat())：站点功能，不移植
	if StoredData.check_last_star():
		StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": StoredData.AB_33_GET_119_STARS})
		gained.push_back(StoredData.AB_33_GET_119_STARS)
	return gained
