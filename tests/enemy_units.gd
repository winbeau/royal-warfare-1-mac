extends SceneTree
# P3-D2：敌军兵种（undead*/monster*）。逐个实例化，断言 kind、units.xml 三档数值、技能槽类型、静态资源与对象池；
# 另测吸血鬼王的援军触发规则（血量 < 650 且 can_call_support 才触发一次，之后需重置）。
# 依赖缺失（基类或技能未完成）的兵种跳过并记录。
var checks := 0
var failures: Array = []
var skipped: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func skip(message: String) -> void:
	skipped.append(message)

func _initialize() -> void:
	call_deferred("run")

# [文件, 类名, xml 节点, kind 常量名, 技能槽 {zero/one/two: 类名}, 是否有 ranged 动画, 是否有 casting 动画]
const TABLE := [
	["undead_darth_archer", "UndeadDarthArcher", "storm_archer", "UNDEAD_STORMARCHER", {"one": "SpecPoison"}],
	["undead_darth_guardian", "UndeadDarthGuardian", "storm_guardian", "UNDEAD_STORMGUARDIAN", {"two": "SpecCorrupt"}],
	["undead_darth_knight", "UndeadDarthKnight", "darth_knight", "UNDEAD_DARTH_KNIGHT", {"one": "SpecMassStun"}],
	["undead_ghost", "UndeadGhost", "ghost", "UNDEAD_GHOST", {"two": "SpecMissGhost"}],
	["undead_gray_zombie", "UndeadGrayZombie", "grey_zombie", "UNDEAD_GRAY_ZOMBIE", {}],
	["undead_plague_zombie", "UndeadPlagueZombie", "plague_zombie", "UNDEAD_PLAGUE_ZOMBIE", {"one": "SpecWeakness"}],
	["undead_ranger", "UndeadRanger", "ranger", "UNDEAD_RANGER", {}],
	["undead_seeker", "UndeadSeeker", "seeker", "UNDEAD_SEEKER", {"zero": "SpecHide", "one": "SpecCrit"}],
	["undead_shaman", "UndeadShaman", "shaman", "UNDEAD_SHAMAN", {"one": "SpecStrongHeal", "two": "SpecSmallRessurect"}],
	["undead_skeletion_archer", "UndeadSkeletionArcher", "skeleton_archer", "UNDEAD_SKELETON_ARCHER", {"two": "SpecMissSkeleton"}],
	["undead_skeleton", "UndeadSkeleton", "skeleton", "UNDEAD_SKELETON", {"two": "SpecMissSkeleton"}],
	["undead_skeleton_armored", "UndeadSkeletonArmored", "skeleton_arm", "UNDEAD_SKELETON_ARM", {"two": "SpecMissSkeleton"}],
	["undead_skeleton_capitan", "UndeadSkeletonCapitan", "skeleton_cap", "UNDEAD_SKELETON_CAPITAN", {"two": "SpecMissSkeleton"}],
	["undead_storm_trooper", "UndeadStormTrooper", "darth_trooper", "UNDEAD_STORMTROOPER", {"one": "SpecParry"}],
	["undead_summoner", "UndeadSummoner", "Summoner", "UNDEAD_SUMMONER", {"one": "SpecSummonSkeletons"}],
	["undead_vampire", "UndeadVampire", "vampire", "UNDEAD_VAMPIRE", {"one": "SpecVampirizm"}],
	["undead_vampire_king", "UndeadVampireKing", "vampire_king", "UNDEAD_VAMPIRE_KING", {"one": "SpecVampirizm", "two": "SpecOgreStun"}],
	["undead_vampire_lord", "UndeadVampireLord", "vampire_lord", "UNDEAD_VAMPIRE_LORD", {"one": "SpecVampirizm", "two": "SpecWeakness"}],
	["undead_witch", "UndeadWitch", "witch", "UNDEAD_WITCH", {"one": "SpecIce", "two": "SpecCurse"}],
	["undead_zombie", "UndeadZombie", "zombie", "UNDEAD_ZOMBIE", {}],
	["monster_green_hound", "MonsterGreenHound", "green_hound", "MONSTER_GREEN_HOUND", {}],
	["monster_hound", "MonsterHound", "hound", "MONSTER_HOUND", {}],
	["monster_kamikaze", "MonsterKamikaze", "kamikaze", "MONSTER_KAMIKAZE", {"zero": "SpecSelfDestruct"}],
	["monster_ogre", "MonsterOgre", "ogre", "MONSTER_OGRE", {"one": "SpecOgreStun"}],
	["monster_shield_kamikaze", "MonsterShieldKamikaze", "shieldKamikaze", "MONSTER_KAMI_SHIELD", {"zero": "SpecSelfDestruct"}],
	["monster_troll", "MonsterTroll", "troll", "MONSTER_TROLL", {"one": "SpecRegen"}],
]

func triple(node: RWXml, tag: String) -> Array:
	var sub := node.child(tag)
	return [sub.to_number("one"), sub.to_number("two"), sub.to_number("three")]

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	var units := RWXml.load_file("res://data/xml/6611_extDataManager_units.xml")
	check(units != null, "units.xml loads")
	var gu: GameUniverse = null
	var gu_scr: Script = load("res://game/core/game_universe.gd")
	if gu_scr != null:
		gu = GameUniverse.new()
		gu.unit_xml = units
	else:
		skip("GameUniverse unavailable")
	for row in TABLE:
		test_unit(row, units, gu)
	test_king_phase()
	print(JSON.stringify({"checks": checks, "failures": failures, "skipped": skipped}))
	quit(0 if failures.is_empty() else 1)

func test_unit(row: Array, units: RWXml, gu: GameUniverse) -> void:
	var scr: Script = load("res://game/living/%s.gd" % row[0])
	if scr == null or not scr.can_instantiate():
		skip("%s: script does not compile (dependencies missing)" % row[1])
		return
	check(scr.get_global_name() == row[1], "%s class_name" % row[1])
	var u: LivingObject = scr.new()
	var node := units.child(row[2])
	check(not node.is_empty(), "%s: units.xml node '%s' exists" % [row[1], row[2]])
	if gu != null:
		u.update_stats()
	else:
		u.set_stats_from_xml(node)
	for pair in [["Health", "a_health_levels"], ["Armor", "a_armor_levels"], ["Resist", "a_resist_levels"],
			["Experience", "a_exp_levels"], ["armorPierceMelee", "a_armor_piercing_melee_levels"],
			["armorPierceRanged", "a_armor_piercing_ranged_levels"], ["magicPierce", "a_magic_piercing_levels"],
			["attackSpeedMelee", "a_attack_interval_levels"], ["attackSpeedRanged", "a_ranged_attack_interval_levels"],
			["accuracy", "a_ranged_shoot_accuracy"], ["damageMelee", "a_melee_damage_levels"],
			["damageRanged", "a_ranged_damage_levels"], ["walkSpeed", "a_walk_speed_levels"]]:
		check(u.get(pair[1]) == triple(node, pair[0]), "%s: %s matches units.xml (%s)" % [row[1], pair[0], u.get(pair[1])])
	check(u.class_name_ == node.text("className"), "%s: className '%s'" % [row[1], u.class_name_])
	if gu != null:
		var cost_expected: int = scr.get("unit_cost")
		check(u.money_cost == cost_expected, "%s: money_cost == unit_cost" % row[1])
	u.init()
	check(u.kind == _const(row[3]), "%s: kind %s" % [row[1], row[3]])
	check(u.friendly == false, "%s: enemy" % row[1])
	check(u.bmp_stay != null and u.bmp_walk != null and u.bmp_attack != null and u.bmp_dead != null, "%s: BmpFrames set" % row[1])
	check(u.bmp_stay == scr.get("local_bmp_stay"), "%s: bmp_stay is the static local frames" % row[1])
	check(u.sens_class.ends_with("Sens"), "%s: sens_class '%s'" % [row[1], u.sens_class])
	u.after_adding_new_unit_handler()
	for slot in ["zero", "one", "two"]:
		var sp: SpecialTemplate = u.get("special_" + slot)
		if row[4].has(slot):
			check(sp != null and sp.get_script().get_global_name() == row[4][slot], "%s: special_%s is %s" % [row[1], slot, row[4][slot]])
		else:
			check(sp == null, "%s: special_%s empty" % [row[1], slot])
	u.free()

func _const(n: String) -> int:
	return int((load("res://game/living/living_object.gd") as Script).get_script_constant_map()[n])

# 吸血鬼王：after_being_hit_handler 在 cur_health < 650 且 can_call_support 时触发一次 call_support，
# 之后 can_call_support 为 false，直到 after_adding_new_unit_handler（复活/新单位）或 remover_animation_completed 重置。
func test_king_phase() -> void:
	var scr: Script = load("res://game/living/undead_vampire_king.gd")
	if scr == null or not scr.can_instantiate():
		skip("UndeadVampireKing phase test: script does not compile")
		return
	var probe_scr: Script = load("res://tests/support/king_probe.gd")
	if probe_scr == null:
		skip("king_probe unavailable")
		return
	# 懒加载对象池：Script.get("cached_unit_data")（GameUniverse._new_unit 的取法）应创建 Main.loadResources 的 15 个实例
	var pool: Variant = scr.get("cached_unit_data")
	check(pool is SimpleCache, "king: lazy cached_unit_data is a SimpleCache")
	if pool is SimpleCache:
		var inst_k: Object = pool.get_data()
		check(inst_k != null and inst_k.get_script() == scr, "king: pool hands out UndeadVampireKing")
		pool.set_data(inst_k)
	RWRandom.set_seed(12345)
	var state := RWRandom.get_state()
	var k = probe_scr.new()
	k.can_call_support = true
	k.cur_health = 1200
	k.after_being_hit_handler()
	check(k.calls == 0, "king: health 1200 does not call support")
	k.cur_health = 650
	k.after_being_hit_handler()
	check(k.calls == 0, "king: health exactly 650 does not call support (strict <)")
	k.cur_health = 649
	k.after_being_hit_handler()
	check(k.calls == 1 and k.can_call_support == false, "king: 649 calls support once and clears the flag")
	k.cur_health = 100
	k.after_being_hit_handler()
	check(k.calls == 1, "king: no second call while flag is cleared")
	k.remover_animation_completed()
	check(k.can_call_support == true and k.visible == false, "king: remover_animation_completed re-arms and hides")
	k.after_being_hit_handler()
	check(k.calls == 2, "king: re-armed king calls again")
	check(RWRandom.get_state() == state, "king: phase switch consumes no RNG")
	k.free()
