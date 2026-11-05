extends SceneTree
# S2：世界地图 / 主菜单 / 成就 / 手册 / 制作名单界面测试。
# 运行：Godot --headless --path . --script tests/menu_screens.gd -- --isolated-profile
# 覆盖：地图旗帜在给定存档下的解锁/星数状态、关卡弹窗的难度选择写回存档、成就列表完成状态、
# 手册翻页的页数与边界、未发现敌人的占位文本、主菜单按钮回调到 Main.inst（用替身记录调用）。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

class SpyMain extends Main:
	var calls: Array = []
	func load_map() -> void: calls.append("load_map")
	func load_main_menu(_e = null) -> void: calls.append("load_main_menu")
	func load_more_games(_e = null) -> void: calls.append("load_more_games")
	func load_achievements(from_map: bool = false) -> void: calls.append("load_achievements:%s" % from_map)
	func load_upgrade_panel() -> void: calls.append("load_upgrade_panel")
	func load_credits() -> void: calls.append("load_credits")
	func load_how_to() -> void: calls.append("load_how_to")
	func load_strategy_games(_e = null) -> void: calls.append("load_strategy_games")
	func load_host_it_page(_e = null) -> void: calls.append("load_host_it_page")
	func load_intro() -> void: calls.append("load_intro")
	func load_act_two() -> void: calls.append("load_act_two")
	func load_act_three() -> void: calls.append("load_act_three")
	func load_act_four() -> void: calls.append("load_act_four")
	func load_act_five() -> void: calls.append("load_act_five")
	func load_final() -> void: calls.append("load_final")
	func load_game(level: int = -1, play_music: bool = true) -> void: calls.append("load_game:%d" % level)
	func check_armor_quests() -> void: calls.append("check_armor_quests")

var main_spy: SpyMain

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame

func click(mc: FlashClip) -> void:
	(mc.get_meta(ButtonClass.HUB_META) as Object).dispatch(ButtonClass.CLICK)

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	StoredData.test_wipe()
	StoredData.init()
	if SoundLibrary.inst == null:
		SoundLibrary.new().init()
	if Sounds.inst == null:
		root.get_node("SoundSystem").init_sounds_first(StoredData.main_params)
	if ExtDataManager.inst == null:
		ExtDataManager.new().init()
	if GameUniverse.selection_ramka == null:
		GameUniverse.init_once()
	GameUniverse.load_levels(0, 24)
	# 原版 Main.loadResources case 77 在预载阶段就 new gameUniverse()（设置 gameUniverse.self），
	# howtoPlayScreen_ex 展示敌人图鉴时依赖它已存在；这里按同样时序补上（不进入任何关卡）。
	if GameUniverse.inst == null:
		GameUniverse.new()
	RWTween.inst_().manual_clock = true
	RWTween.reset()
	main_spy = SpyMain.new()
	Main.inst = main_spy

	await test_game_map()
	await test_popup_mission_difficulty()
	await test_achives_screen()
	await test_howto_screen()
	await test_main_menu()
	await test_credits_screen()

	RWTween.reset()
	Main.inst = null
	main_spy.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


## 地图在给定存档下的旗帜解锁和星数状态：前 3 关已通关（3/2/1 星），第 4 关未访问（下一关），其余未访问。
func test_game_map() -> void:
	var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS]
	levels[0] = 3
	levels[1] = 2
	levels[2] = 1
	# NUMPAN_LEVELS_MIDDIF/HIGHDIF 留空（全 0），决定 eVisited 具体播放哪一帧（普通/中/高难）
	var map := GameMapObject.create()
	root.add_child(map)
	await settle()

	check(map.get_child_count() >= 3, "GameMapObject._added() 挂上了 mapBitmap/anims/markers")
	var f0: FlashClip = map.a_markers[0]
	check(f0.get_node("eVisited").visible == true and f0.get_node("eUnvisited").visible == false,
			"第 1 关 3 星：eVisited 可见，eUnvisited 隐藏")
	check((f0.get_node("eVisited").get_node("eStar") as FlashClip).current_frame == 3,
			"第 1 关星级图标停在第 3 帧（3 星）")
	# stars(3) > mid(0) 且 > high(0) -> eVisited 第 1 帧（普通难度完成）
	check(f0.get_node("eVisited").current_frame == 1, "第 1 关只在普通难度打过 -> eVisited 第 1 帧")
	var f3: FlashClip = map.a_markers[3]
	check(f3.get_node("eVisited").visible == false, "第 4 关（下一关）未访问：eVisited 隐藏")
	check(map.next_unvisited == 3, "next_unvisited 指向第一个 0 星关卡（下标 3）")
	check(map.red_circle.get_parent() == map.markers, "红圈标记加到了 markers 容器里")
	check(map.red_circle.visible, "红圈标记可见")
	var f4: FlashClip = map.a_markers[4]
	check(f4.visible == false, "next_unvisited 之后的关卡保持隐藏（未解锁）")
	root.remove_child(map)
	await settle()


## 难度选择写回存档：点击 popup 的 d1/d2/d3 分别写 NUMPAN_DIFFICULTY=1/2/3；bPlaybtn -> Main.load_game(pos)。
func test_popup_mission_difficulty() -> void:
	var popup := PopupMissionEx.new()
	popup.init(2)
	root.add_child(popup)
	await settle()

	check((popup.get_node("popup") as FlashClip).get_node("tMissionName") != null, "popup 挂到了树上")
	var tmpl: LevelTemplate = GameUniverse.a_levels_templates_inited[2]
	var t_name: FlashText = popup.get_node("popup").get_node("tMissionName")
	check(t_name.text == tmpl.level_caption, "弹窗标题取自 levelCaption")

	click(popup.d2)
	check(int(StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY]) == 2, "点击 d2 -> 难度写 2（HARD）")
	click(popup.d3)
	check(int(StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY]) == 3, "点击 d3 -> 难度写 3（NIGHTMARE）")
	click(popup.d1)
	check(int(StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY]) == 1, "点击 d1 -> 难度写 1（NORMAL）")

	main_spy.calls.clear()
	click(popup.b_playbtn)
	check(main_spy.calls == ["load_game:2"], "bPlaybtn -> Main.load_game(pos)")
	await settle()


## 成就列表的完成状态：解锁第一页若干项，验证奖章显隐与分页循环；bLeft 在第 0 页会绕回第 3 页。
func test_achives_screen() -> void:
	var achives: Array = StoredData.local_game_data[StoredData.NUMPAN_ACHIVES]
	achives[0] = 1  # Kill 100 Darth Knights：已完成
	achives[1] = 0  # Kill 50 Vampires：未完成
	var ach := AchivesScreenEx.create()
	root.add_child(ach)
	await settle()

	check(ach.current_list == 0, "初始显示第 1 页（下标 0）")
	var m0: FlashClip = ach.a_medals[0]
	var m1: FlashClip = ach.a_medals[1]
	check(m0.visible == true, "已完成成就 0 的奖章可见")
	check(m1.visible == false, "未完成成就 1 的奖章隐藏")
	var t0: FlashText = ach.a_texts[0]
	check(t0.text == AchivesScreenEx.a_achives_description[0], "成就文案取自 a_achives_description")

	click(ach.b_left)
	check(ach.current_list == 3, "第 1 页点 bLeft 绕回第 4 页（下标 3）")
	click(ach.b_right)
	check(ach.current_list == 0, "绕回第 1 页")

	main_spy.calls.clear()
	ach.is_map = true
	click(ach.b_menu)
	check(main_spy.calls == ["load_map"], "isMap=true 时 bMenu -> Main.load_map()")
	main_spy.calls.clear()
	ach.is_map = false
	click(ach.b_menu)
	check(main_spy.calls == ["load_main_menu"], "isMap=false 时 bMenu -> Main.load_main_menu()")
	main_spy.calls.clear()
	click(ach.b_more)
	check(main_spy.calls == ["load_more_games"], "bMore -> Main.load_more_games()")
	root.remove_child(ach)
	await settle()


## 手册翻页的页数和边界：共 62 页；bLeft 在第 1 页绕到最后一页，bRight 在最后一页绕回第 1 页；
## 未发现的敌人（NUMPAN_REVEALED_ENEMY 为空或条目不足）显示原版占位文本和 "???" 属性。
func test_howto_screen() -> void:
	var revealed: Array = StoredData.local_game_data[StoredData.NUMPAN_REVEALED_ENEMY]
	revealed.clear()
	revealed.append(LivingObject.UNDEAD_ZOMBIE)  # 只揭示了第一个敌人
	var howto := HowtoPlayScreenEx.create()
	root.add_child(howto)
	await settle()

	check(howto.e_content.total_frames == 62, "手册共 62 页")
	check(howto.current_list == 1, "初始停在第 1 页")

	click(howto.b_left)
	check(howto.current_list == 62, "第 1 页点 bLeft 绕到最后一页（62）")
	click(howto.b_right)
	check(howto.current_list == 1, "最后一页点 bRight 绕回第 1 页")

	howto.current_list = 50
	howto.e_content.goto_and_stop(50)
	howto.set_cur_list_visible()
	check(howto.t1.visible and howto.ico1.visible, "第 50 页（敌人图鉴首页）显示第一个敌人")
	check(howto.t1.text.find("Slow, weak creature") >= 0,
			"已揭示的 UNDEAD_ZOMBIE 显示真实描述：%s" % howto.t1.text)
	check(howto.t2.text.find("This enemy has not been encountered yet.") == 0,
			"未揭示的第二个敌人显示原版占位文本：%s" % howto.t2.text)
	check((howto.t_ico2.get_node("tHealth") as FlashText).text == "???",
			"未揭示敌人的属性显示 ???")
	root.remove_child(howto)
	await settle()


## 主菜单按钮回调到 Main.inst（用替身记录调用）。
func test_main_menu() -> void:
	var mm := MainMenuScreen.create()
	root.add_child(mm)
	await settle()

	for case in [
		[mm.b_play, "load_map"], [mm.b_achieves, "load_achievements:false"], [mm.b_more, "load_more_games"],
		[mm.b_credits, "load_credits"], [mm.b_how_to, "load_how_to"],
		[mm.e_strategy_guide, "load_strategy_games"], [mm.e_host_it, "load_host_it_page"],
		[mm.e_max_games, "load_more_games"],
	]:
		main_spy.calls.clear()
		click(case[0])
		check(main_spy.calls == [case[1]], "主菜单按钮 -> Main.%s（实际 %s）" % [case[1], str(main_spy.calls)])

	# 声音/音乐开关：写回 StoredData.main_params 并切到对应帧
	var p: Dictionary = StoredData.main_params
	p["sound"] = true
	StoredData.main_params = p
	mm.draw_main_buttons()
	click(mm.b_sound)
	check(StoredData.main_params.get("sound") == false, "点击 bSound 切换 main_params.sound")
	check(mm.b_sound.current_frame == 2, "bSound 切到关闭帧（第 2 帧）")
	click(mm.b_sound)
	check(StoredData.main_params.get("sound") == true, "再次点击切回开启")
	check(mm.b_sound.current_frame == 1, "bSound 切回开启帧（第 1 帧）")
	root.remove_child(mm)
	await settle()


## 制作名单：bMenu -> Main.load_main_menu；点击邮件反馈解锁 AB_42_WRITE_LETTER 成就。
func test_credits_screen() -> void:
	var credits := CreditsScreenEx.create()
	root.add_child(credits)
	await settle()

	main_spy.calls.clear()
	click(credits.b_menu)
	check(main_spy.calls == ["load_main_menu"], "creditsScreen bMenu -> Main.load_main_menu()")

	check(StoredData.check_if_achievement_not_done(StoredData.AB_42_WRITE_LETTER) == true,
			"AB_42_WRITE_LETTER 尚未解锁")
	credits.message_clicked()
	var achives: Array = StoredData.local_game_data[StoredData.NUMPAN_ACHIVES]
	check(int(achives[StoredData.AB_42_WRITE_LETTER]) == 1, "点击邮件反馈解锁 AB_42_WRITE_LETTER")
	check(credits.e_achievement.visible == true, "成就弹出图标可见")
	root.remove_child(credits)
	await settle()
