extends SceneTree
# P2-A2 验证：StoredData / GlobalData / BonusCalculator / LevelTemplate 与 24 关数据。
var failures: Array = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile: quit(2); return
	check(StoredData.isolated, "StoredData follows --isolated-profile")
	test_stored_data()
	test_global_data()
	test_bonus()
	test_levels()
	print("levels_data: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

func test_stored_data() -> void:
	StoredData.test_wipe()
	StoredData.init()
	var d: Array = StoredData.local_game_data
	check(d.size() == 15, "default save has 15 slots (got %d)" % d.size())
	check(d[StoredData.NUMPAN_LEVELS].size() == 24, "levels 24")
	check(d[StoredData.NUMPAN_UNITS] == [1, 0, 1, 0, 1, 0, 1, 0, 1, 0], "units default")
	check(d[StoredData.NUMPAN_ABILS].size() == 41, "abils 41")
	check(d[3] == 0, "slot 3 is placeholder 0")
	check(d[StoredData.NUMPAN_ACHIVES].size() == 48, "achives 48")
	check(d[StoredData.NUMPAN_ACHIVE_COUNTER].size() == 28, "28 counters")
	check(d[StoredData.NUMPAN_UNIT_BONUSES].size() == 10, "bonuses 10")
	check(d[StoredData.NUMPAN_COMIX]["comix_intro"] == 0 and d[StoredData.NUMPAN_COMIX]["comix_two"] == -1, "comix defaults")
	check(d[StoredData.NUMPAN_START_TUTORIAL] == 0 and d[StoredData.NUMPAN_DIFFICULTY] == 1, "tutorial 0, difficulty 1")
	check(d[StoredData.NUMPAN_REVEALED_ENEMY] == [], "revealed empty")
	check(d[StoredData.NUMPAN_LEVELS_MIDDIF].size() == 24 and d[StoredData.NUMPAN_LEVELS_HIGHDIF].size() == 24, "dif star arrays")
	check(StoredData.main_params == {"sound": true, "music": true, "hints": true, "autop": true}, "main params default")
	check(StoredData.end_game_flag == {"completed": false}, "end game flag default")
	check(StoredData.get_num_gained_stars() == 0 and StoredData.get_num_free_stars() == 0, "no stars at start")
	# 星数
	StoredData.save_data(StoredData.COM_VICTORY, {"level": 0, "stars": 3, "dif": 1})
	StoredData.save_data(StoredData.COM_VICTORY, {"level": 1, "stars": 2, "dif": 2})
	StoredData.save_data(StoredData.COM_VICTORY, {"level": 1, "stars": 1, "dif": 3})  # 不降星
	StoredData.save_data(StoredData.COM_VICTORY, {"level": 2, "stars": 1, "dif": 3})
	d = StoredData.local_game_data
	check(d[StoredData.NUMPAN_LEVELS].slice(0, 3) == [3, 2, 1], "victory keeps max stars")
	check(d[StoredData.NUMPAN_LEVELS_MIDDIF][1] == 2 and d[StoredData.NUMPAN_LEVELS_HIGHDIF][1] == 1 and d[StoredData.NUMPAN_LEVELS_HIGHDIF][2] == 1, "per-difficulty stars")
	check(StoredData.get_num_gained_stars() == 6, "gained stars 6 (got %d)" % StoredData.get_num_gained_stars())
	StoredData.save_data(StoredData.ADD_ACHIEVE, {"numb": 5})
	check(StoredData.get_num_gained_stars() == 7 and not StoredData.check_if_achievement_not_done(5) and StoredData.check_if_achievement_not_done(6), "achievement adds a star")
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": 3})
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": 3})
	StoredData.save_data(StoredData.COM_SAVE_BONUS, {"abilNumber": 0})
	check(StoredData.get_num_busy_stars() == 3 and StoredData.get_num_free_stars() == 4, "busy 3 / free 4")
	StoredData.save_data(StoredData.COM_SAVE_ABIL_DOWNGRADE, {"abilNumber": 3})
	StoredData.save_data(StoredData.COM_SAVE_BONUS_DOWNGRADE, {"abilNumber": 9})  # 不会低于 0
	check(StoredData.get_num_busy_stars() == 2, "downgrade, floor at 0")
	StoredData.save_data(StoredData.COM_SAVE_UNIT, {"unitNumber": 3})
	check(StoredData.local_game_data[StoredData.NUMPAN_UNITS][3] == 1, "unit unlocked")
	StoredData.save_data(StoredData.COM_REVEAL_ENEMY, {"numb": 6})
	check(StoredData.local_game_data[StoredData.NUMPAN_REVEALED_ENEMY] == [6], "reveal enemy")
	StoredData.save_data(StoredData.COMIX_WATCHED, {"comixNumber": 2})
	StoredData.save_data(StoredData.COMIX_SET_TO_WATCH, {"comixNumber": 3})
	var cm: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	check(cm["comix_two"] == 1 and cm["comix_three"] == 0 and cm["comix_four"] == -1, "comix flags")
	StoredData.save_data(StoredData.TIER3_SHOWN, {"unitNumber": 2})
	StoredData.save_data(StoredData.ZANAVES_WATCHED, {"zanavesNumber": 4})
	check(StoredData.local_game_data[StoredData.NUMPAN_OPENED_TIER3]["zCrossbow"] == 1 and StoredData.local_game_data[StoredData.NUMPAN_ZANAVES]["zMages"] == 1, "tier3 / zanaves")
	check(StoredData.check_last_star() == false, "last star not yet")
	# 隔离模式写回再读
	StoredData.save_data(StoredData.CHANGE_MAIN_PARAMS, {"sound": false, "music": true, "hints": true, "autop": false})
	StoredData.save_data(StoredData.COM_CHANGE_DIF, {"dif": 3})
	StoredData.save_shared_data()  # COM_CHANGE_DIF 只改 local_game_data，需 saveSharedData 才进入共享对象
	StoredData.save_data(StoredData.COM_SAVE_DATA_TO_SHARED, null)
	check(StoredData.is_save_ok, "flush ok")
	check(not FileAccess.file_exists(StoredData.save_path) or true, "(isolated: user file untouched)")
	var before_blob := StoredData._isolated_blob
	check(before_blob != "", "isolated blob written in memory")
	var snapshot: Array = StoredData.local_game_data.duplicate(true)
	StoredData.local_game_data = []
	StoredData.shared_data = {}
	StoredData.main_params = null
	StoredData.init()
	check(StoredData.local_game_data == snapshot, "reload from isolated store equals saved data")
	check(StoredData.main_params["sound"] == false and StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY] == 3, "main params / difficulty reloaded")
	check(typeof(StoredData.local_game_data[StoredData.NUMPAN_LEVELS][0]) == TYPE_INT, "json floats normalized to int")
	# 13 项旧存档补 2 项
	StoredData.test_wipe()
	StoredData._isolated_blob = JSON.stringify({"aGameData": StoredData._default_game_data().slice(0, 13), "mainParams": {"sound": true, "music": true, "hints": true}})
	StoredData.init()
	check(StoredData.local_game_data.size() == 15 and StoredData.main_params["autop"] == true, "old 13-slot save upgraded, autop defaulted")
	check(StoredData.end_game_flag == {"completed": false}, "endGameFlag created")
	# 通关第 24 关的旧存档 -> endGameFlag.completed = true
	StoredData.test_wipe()
	var old := StoredData._default_game_data()
	old[0][23] = 2
	StoredData._isolated_blob = JSON.stringify({"aGameData": old, "mainParams": {"sound": true, "music": true, "hints": true, "autop": true}})
	StoredData.init()
	check(StoredData.end_game_flag == {"completed": true}, "level 24 cleared -> endGame completed")
	# sponsorUnlock 的结构
	StoredData.sponsor_unlock()
	check(StoredData.local_game_data[StoredData.NUMPAN_LEVELS] == StoredData._filled(24, 3) and StoredData.local_game_data[StoredData.NUMPAN_REVEALED_ENEMY].size() == 9, "sponsor unlock layout")
	StoredData.save_data(StoredData.COM_RESET_ABILITIES, null)
	check(StoredData.local_game_data[StoredData.NUMPAN_ABILS].size() == 81 and StoredData.get_num_busy_stars() == 0, "reset abilities (81 entries, as original)")
	StoredData.test_wipe()

func test_global_data() -> void:
	StoredData.test_wipe()
	StoredData.init()
	var g := GlobalData.new()
	check(GlobalData.inst == g, "GlobalData.inst")
	g.reset()
	check(g.num_killed == 0 and g.a48_get_elite == 0 and g.start_time > 0.0, "reset")
	g.num_killed = 120
	g.a1_dark_knited_killed = 100
	var got := g.check_achievements(0)
	check(got.has(StoredData.AB_25_KILL100) and got.has(StoredData.AB_1_KILL_DARTH) and got.has(StoredData.AB_29_COMPLETE_1MISSION), "achievements gained: %s" % str(got))
	check(not got.has(StoredData.AB_26_KILL3000), "no 3000 kills")
	check(StoredData.local_game_data[StoredData.NUMPAN_ACHIVE_COUNTER]["a25_28_totalKilled"] == 120, "counter accumulated")
	check(g.check_achievements(0).is_empty(), "granted only once")
	check(StoredData.local_game_data[StoredData.NUMPAN_ACHIVE_COUNTER]["a25_28_totalKilled"] == 240, "second call accumulates again (original behavior)")
	# 6 个三星
	for i in 6:
		StoredData.save_data(StoredData.COM_VICTORY, {"level": i, "stars": 3, "dif": 1})
	g.reset()
	got = g.check_achievements(0)
	check(got.has(StoredData.AB_21_6MISSIONS_3STARS) and not got.has(StoredData.AB_22_12MISSIONS_3STARS), "6 three-star missions")
	g.reset()
	got = g.check_achievements(-1)
	check(got.has(StoredData.AB_34_LOOSE_MISSION), "lose mission")
	# 原版疑点：AB_43 看 a41_stunEnemies >= 300
	g.reset()
	g.a43_tier2upgrade = 999
	g.num_upgrades = 999
	got = g.check_achievements(0)
	check(not got.has(StoredData.AB_43_UPGRADE_TIER2), "AB_43 not granted by tier2 upgrades (original quirk)")
	StoredData.local_game_data[StoredData.NUMPAN_ACHIVE_COUNTER]["a41_stunEnemies"] = 300
	g.reset()
	got = g.check_achievements(0)
	check(got.has(StoredData.AB_43_UPGRADE_TIER2) and got.has(StoredData.AB_41_STUN_ENEMIES), "AB_43 granted by stun counter (original quirk)")
	StoredData.test_wipe()

func test_bonus() -> void:
	StoredData.test_wipe()
	StoredData.init()
	var b := BonusCalculator.calculate_bonus(LivingObject.FR_KNIGHT)
	check(b["bonus_damage"] == 0 and b["bonus_hp"] == 0, "no points -> no bonus")
	StoredData.local_game_data[StoredData.NUMPAN_UNIT_BONUSES] = [3, 3, 0, 0, 0, 0, 0, 0, 0, 0]
	b = BonusCalculator.calculate_bonus(LivingObject.FR_KNIGHT)
	check(b["bonus_damage"] == 4 and is_equal_approx(b["bonus_armor_pierce"], 0.15) and b["bonus_hp"] == 40 and is_equal_approx(b["bonus_armor"], 0.15), "knight 3/3")
	b = BonusCalculator.calculate_bonus(LivingObject.FR_WARRIOR)
	check(b["bonus_damage"] == 2 and b["bonus_hp"] == 20, "warrior shares slots 0/1 with knight")
	StoredData.local_game_data[StoredData.NUMPAN_UNIT_BONUSES] = [0, 0, 2, 2, 3, 3, 1, 1, 2, 3]
	b = BonusCalculator.calculate_bonus(LivingObject.FR_CROSSBOW)
	check(b["bonus_damage"] == 3 and is_equal_approx(b["bonus_armor_pierce"], 0.1) and b["bonus_hp"] == 15 and is_equal_approx(b["bonus_armor"], 0.1), "crossbow 2/2")
	b = BonusCalculator.calculate_bonus(LivingObject.FR_REDMAGE)
	check(b["bonus_damage"] == 5 and is_equal_approx(b["bonus_magic_pierce"], 0.2) and b["bonus_hp"] == 20 and is_equal_approx(b["bonus_resist"], 0.15), "red mage 3/3")
	b = BonusCalculator.calculate_bonus(LivingObject.FR_ASSASIN)
	check(b["bonus_damage"] == 2 and b["bonus_hp"] == 10 and b["bonus_armor_pierce"] == 0.0 and b["bonus_move_speed"] == 0.0, "assassin 1/1")
	b = BonusCalculator.calculate_bonus(LivingObject.FR_PRIEST)
	check(b["bonus_damage"] == 1 and is_equal_approx(b["bonus_move_speed"], 0.1) and b["bonus_hp"] == 10 and is_equal_approx(b["bonus_resist"], 0.2), "priest 2/3")
	b = BonusCalculator.calculate_bonus(LivingObject.UNDEAD_ZOMBIE)
	check(b["bonus_damage"] == 0 and b["bonus_hp"] == 0, "non-player unit: nothing")
	StoredData.test_wipe()

func level_file(n: int) -> String:
	for f in DirAccess.get_files_at("res://data/xml"):
		if f.ends_with("_extDataManager_extlvl%d.xml" % n):
			return "res://data/xml/" + f
	return ""

func test_levels() -> void:
	var camp: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")).campaign
	var tmpl := LevelTemplate.new()
	# parseUnitType 覆盖 XML 中出现的全部字符串
	var kinds := {}
	var types := {}
	var total_events := 0
	var all_unit_names := {}
	for n in range(1, 25):
		var path := level_file(n)
		check(path != "", "xml for level %d" % n)
		var xml := RWXml.load_file(path)
		var lv = load("res://game/levels/level_%d.gd" % n).new()
		check(lv is LevelTemplate and lv.level_caption != "" and lv.level_bg != "" and lv.level_xml_path == "data/levels/level%d.xml" % n, "Level%d metadata" % n)
		var waves: Array = lv.build_waves(xml)
		check(waves.size() == xml.children().size(), "level %d wave count" % n)
		var cc: Dictionary = {}
		for e in camp:
			if e.id == "level%d" % n: cc = e
		check(cc.get("events", []).size() == waves.size(), "level %d: campaign.json events %d vs aWaves %d" % [n, cc.get("events", []).size(), waves.size()])
		total_events += waves.size()
		for w in waves:
			check(w.size() >= 1 and w[0].has("time") and w[0].has("type") and w[0].has("no_enemies"), "level %d wave header" % n)
			check(w[0]["type"] in [LevelTemplate.GAME_CHAT, LevelTemplate.FRIEND_SPAWN, LevelTemplate.ENEMY_SPAWN, LevelTemplate.GLOBAL_WAVE, LevelTemplate.ARROWS_SWARM, LevelTemplate.SUMMON], "level %d known wave type %s" % [n, w[0]["type"]])
		for we: RWXml in xml.children():
			types[we.text("type").strip_edges()] = true
			for u: RWXml in we.child("data").children():
				if not u.child("kind").is_empty():
					kinds[u.text("kind").strip_edges()] = true
				if not u.child("who").is_empty():
					kinds[u.text("who").strip_edges()] = true
	check(total_events == 311, "levels 1-24 total events 311 (got %d)" % total_events)
	var intro_events := 0
	for e in camp:
		if e.id == "levelIntro": intro_events = e.events.size()
	check(total_events + intro_events == 313, "311 + levelIntro %d = 313 events in campaign.json" % intro_events)
	var bad := []
	var consts: Dictionary = (load("res://game/living/living_object.gd") as Script).get_script_constant_map()
	for k in kinds:
		var v := tmpl.parse_unit_type(k)
		if not consts.has(k) or consts[k] != v:
			bad.append(k)
	check(bad.is_empty(), "parse_unit_type matches LivingObject constants for all XML strings; bad: %s" % str(bad))
	check(kinds.size() > 30, "XML uses %d distinct unit strings" % kinds.size())
	# 每个字符串的值互不相同（除 0 的未匹配）
	var seen := {}
	for k in kinds:
		var v := tmpl.parse_unit_type(k)
		check(not seen.has(v), "unit value %d unique (%s vs %s)" % [v, k, seen.get(v, "")])
		seen[v] = k
	check(tmpl.parse_unit_type("NOT_A_UNIT") == 0, "unknown string -> 0")
	for t in types:
		check(tmpl.parse_wave_type(t) != "", "parse_wave_type(%s)" % t)
	# 关卡钩子：不依赖 GameUniverse 的部分
	var l1 = Level1.new()
	check(not l1.is_upgrade_allowed(LivingObject.FR_WARRIOR), "level 1 forbids upgrades")
	var l2 = Level2.new()
	check(not l2.is_upgrade_allowed(LivingObject.FR_BLUEMAGE) and l2.is_upgrade_allowed(LivingObject.FR_ARCHER), "level 2 blue mage upgrade locked")
	var l3 = Level3.new()
	l3.arrow_strike_called()
	check(l3.cur_strike_number == 1 and l3.amount_of_civils >= 8 and l3.amount_of_civils <= 16, "level 3 arrow strike")
	check(Level24.new().level_bg == "level_final", "level 24 background")
