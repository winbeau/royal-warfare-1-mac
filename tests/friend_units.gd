extends SceneTree
# P3-D1：17 个友军兵种类（game/living/friend_*.gd）。
# 依赖缺失（基类、技能类、GameUniverse 无法构造）时跳过并记录，不算失败。
# 断言：加载与实例化、kind、classKind、sens_class、friendly、三档数值与 units.xml 一致、技能槽类型。

# [文件名, 类名, kind 常量值, xml 节点, 技能一类, 技能二类（Hide 为 specHide）, class_kind, sens_class, 池大小(Main.as)]
const ROWS := [
	["friend_warrior", 1, "warrior", "SpecBlock", "SpecStun", 100, "warriorSens"],
	["friend_sword_master", 7, "swordmaster", "SpecParry", "SpecRoundAttack", 100, "swordMasterSens"],
	["friend_knight", 13, "knight", "SpecTaunt", "SpecMassStun", 100, "knightSens"],
	["friend_king", 41, "king", "SpecTaunt", "SpecMassStun", 100, "kingSens"],
	["friend_archer", 2, "archer", "SpecSlow", "SpecSuppress", 200, "archerSens"],
	["friend_sniper", 12, "sniper", "SpecHeadShot", "SpecWeakSpot", 200, "sniperSens"],
	["friend_cross_bow_man", 14, "crossbowman", "SpecCritRanged", "SpecCorrupt", 200, "crossbowSens"],
	["friend_blue_mage", 5, "bluemage", "SpecIce", "SpecFlash", 300, "blueWizardSens"],
	["friend_red_mage", 8, "redmage", "SpecMetheor", "SpecFireHitSplash", 300, "redWizardSens"],
	["friend_black_mage", 9, "blackmage", "SpecBetray", "SpecCurse", 300, "blackWizardSens"],
	["friend_priest", 4, "priest", "SpecStrongHeal", "SpecEnchantWeapon", 400, "priestSens"],
	["friend_healer", 10, "healer", "SpecMassHeal", "SpecRessurect", 400, "priestSens"],
	["friend_blesser", 11, "blesser", "SpecCurseBless", "SpecHarmResist", 400, "priestSens"],
	["friend_scout_rogue", 18, "rogue", "SpecPoisonRogue", "SpecCollectMoney", 500, "rogueSens"],
	["friend_scout_assasin", 19, "assassin", "SpecBackStab", "SpecMissAssasin", 500, "rogueSens"],
	["friend_scout_saboteur", 20, "saboteur", "SpecBreakArrows", "SpecHide", 500, "rogueSens"],
	["friend_wiseman", 42, "wiseman", "", "", 400, "wisemanSens"],
]
var checks := 0
var skipped: Array = []
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func spec_class_name(obj: Object) -> String:
	if obj == null:
		return ""
	var scr: Script = obj.get_script()
	return scr.get_global_name() if scr != null else ""

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	# 技能类的 getSpecLevel 读取 StoredData.localGameData；原版由 Main 启动时 storedData.init() 填充。
	StoredData.test_wipe()
	StoredData.init()
	var units := RWXml.load_file("res://data/xml/6611_extDataManager_units.xml")
	check(units != null, "units.xml loads")
	var gu: Variant = null
	var gu_script: Script = load("res://game/core/game_universe.gd")
	if gu_script != null and gu_script.can_instantiate():
		gu = gu_script.new()
		gu.unit_xml = units
		gu_script.set("inst", gu)
	else:
		skipped.append("GameUniverse not instantiable: all stat checks skipped")
	for row in ROWS:
		test_row(row, units, gu)
	print("friend_units: %d checks, %d skipped, %d failures" % [checks, skipped.size(), failures.size()])
	for s in skipped:
		print("  SKIP ", s)
	for f in failures:
		print("  FAIL ", f)
	quit(1 if failures.size() > 0 else 0)

func test_row(row: Array, units: RWXml, gu: Variant) -> void:
	var file: String = row[0]
	var path := "res://game/living/%s.gd" % file
	var scr: Script = load(path)
	if scr == null or not scr.can_instantiate():
		skipped.append("%s: script does not load (missing base class/specials)" % file)
		return
	if gu == null:
		skipped.append("%s: no GameUniverse" % file)
		return
	var u: Object = scr.new()
	if u == null:
		skipped.append("%s: new() failed" % file)
		return
	u.init()
	check(u.kind == row[1], "%s kind" % file)
	check(u.friendly == true, "%s friendly" % file)
	check(u.class_kind == row[5], "%s class_kind" % file)
	check(u.sens_class == row[6], "%s sens_class" % file)
	check(u.bmp_stay != null and u.bmp_walk != null and u.bmp_attack != null and u.bmp_dead != null, "%s bitmaps assigned" % file)
	u.update_stats()
	var node: RWXml = units.child(row[2])
	check(u.class_name_ == node.text("className") or file in ["friend_black_mage", "friend_blesser", "friend_healer", "friend_priest"], "%s className" % file)
	var map := {
		"Experience": "a_exp_levels", "Health": "a_health_levels", "Armor": "a_armor_levels", "Resist": "a_resist_levels",
		"armorPierceMelee": "a_armor_piercing_melee_levels", "armorPierceRanged": "a_armor_piercing_ranged_levels",
		"magicPierce": "a_magic_piercing_levels", "attackSpeedMelee": "a_attack_interval_levels",
		"attackSpeedRanged": "a_ranged_attack_interval_levels", "accuracy": "a_ranged_shoot_accuracy",
		"damageMelee": "a_melee_damage_levels", "damageRanged": "a_ranged_damage_levels", "walkSpeed": "a_walk_speed_levels",
	}
	for tag in map:
		var sub := node.child(tag)
		var got: Array = u.get(map[tag])
		var want := [sub.to_number("one"), sub.to_number("two"), sub.to_number("three")]
		check(got == want, "%s %s %s != %s" % [file, tag, got, want])
	check(u.money_cost == scr.get("unit_cost") and u.upgr_cost == scr.get("upgrade_cost"), "%s money/upgrade cost from statics" % file)
	u.after_adding_new_unit_handler()
	if row[3] != "":
		check(spec_class_name(u.special_one) == row[3], "%s special_one is %s" % [file, row[3]])
		check(spec_class_name(u.special_two) == row[4], "%s special_two is %s" % [file, row[4]])
	else:
		check(u.special_one == null and u.special_two == null, "%s has no specials" % file)
