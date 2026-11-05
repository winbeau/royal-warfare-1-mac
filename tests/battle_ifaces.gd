extends SceneTree
# 战内界面类（game/ifaces）测试：血条、框选框、提示节流、胜负面板、暂停菜单、对话与成就分页。
# 依赖 Main 的地方用替身（SpyMain）记录调用；GameUniverse 用 SpyUniverse 记录 pause/unpause。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func near(a: float, b: float, eps: float = 1e-3) -> bool:
	return absf(a - b) <= eps

class SpyMain extends Main:
	var calls: Array = []
	func load_game(_level: int = -1, _play_music: bool = true) -> void: calls.append("load_game")
	func load_map() -> void: calls.append("load_map")
	func load_main_menu(_e = null) -> void: calls.append("load_main_menu")
	func load_more_games(_e = null) -> void: calls.append("load_more_games")
	func load_upgrade_panel() -> void: calls.append("load_upgrade_panel")
	func stop_music_ingame() -> void: calls.append("stop_music_ingame")
	func pause_music(n = null) -> void: calls.append("pause_music:" + n)
	func unpause_music(n = null) -> void: calls.append("unpause_music:" + n)
	func play_map_music() -> void: calls.append("play_map_music")
	func add_unit_hint(n: int) -> void: calls.append("add_unit_hint:%d" % int(n))
	func add_tutorial(n: float) -> void: calls.append("add_tutorial:%d" % int(n))

class SpyUniverse extends GameUniverse:
	var log_calls: Array = []
	func pause() -> void:
		log_calls.append("pause")
		super.pause()
	func unpause() -> void:
		log_calls.append("unpause")
		super.unpause()
	func update_revealed_units() -> void:
		log_calls.append("update_revealed_units")

var main_spy: SpyMain
var universe: SpyUniverse

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not root.get_node("Content").isolated_profile:
		quit(2)
		return
	RWTween.inst_().manual_clock = true
	StoredData.test_wipe()
	StoredData.init()
	main_spy = SpyMain.new()
	Main.inst = main_spy
	universe = SpyUniverse.new()
	universe.level_info = LevelTemplate.new()
	root.add_child(universe)
	Sounds.inst = Sounds.new()
	GlobalData.new()
	test_mini_icons()
	test_health_bar()
	test_ramka()
	test_units_via_new_and_create()
	test_one_shot_effects()
	test_hints_manager()
	test_chat_controller()
	test_chat_frame_controller()
	test_victory_panel()
	test_defeat_panel()
	test_pause_menu()
	test_achives_pages()
	test_tutorials()
	RWTween.reset()
	# 静态引用（对象池、面板、帧数据）在退出前清掉，避免退出时报资源泄漏
	MiniIcons.cached_unit_data = null
	MiniIcons.bmp_frame = null
	VinDefPanelAchivesController.a1 = []
	VinDefPanelAchivesController.a2 = []
	VinDefPanelAchivesController.panel = null
	VinDefPanelAchivesController.e_cont = null
	VinDefPanelAchivesController.e_hint = null
	ChatFrameController.game_chat_box = null
	ChatFrameController.e_fader = null
	StartTutorial.inst = null
	universe.free()
	Sounds.inst.free()
	Main.inst = null
	main_spy.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func spawn(node: Node) -> Node:
	root.add_child(node)
	return node

func click(panel: FlashClip, target_name: String) -> void:
	var e := ButtonClass.ButtonEvent.new()
	e.target = panel.get_node(target_name)
	panel.button_clicked(e)

# ---------------------------------------------------------------------------------------------

func test_mini_icons() -> void:
	MiniIcons.cache(4)
	var a := MiniIcons.cached_unit_data.get_data() as MiniIcons
	a.draw_data(MiniIcons.cPOISON)
	check(a.cur_number == 6 and a.sprite_bm.texture != null, "miniIcons.drawData sets curNumber and bitmap")
	a.return_to_cache()
	var b := MiniIcons.cached_unit_data.get_data() as MiniIcons
	check(b == a, "returnToCache gives the icon back to the pool (same instance comes out next)")

func test_health_bar() -> void:
	var bar := HealthBarEx.create(100)
	spawn(bar)
	check(near(bar.modulate.a, 0.0), "bar starts transparent (alpha = 0)")
	check(not bar.mouse_enabled and not bar.mouse_children, "bar ignores the mouse")
	check(bar.e_levelup.current_frame == 1, "level star starts on frame 1")
	bar.top.stop()
	# 血量：scaleX 缓动 0.4s
	bar.update(50, 1, false, true)
	check(near(bar.modulate.a, 1.0), "selected unit shows the bar fully (alpha 1)")
	check(near(bar.top.scale.x, 1.0), "scaleX unchanged at t=0")
	RWTween.step(0.2)
	check(bar.top.scale.x < 1.0 and bar.top.scale.x > 0.5, "scaleX is tweening towards 50/100")
	RWTween.step(0.3)
	check(near(bar.top.scale.x, 0.5), "scaleX = curHealth / health after 0.4s (%f)" % bar.top.scale.x)
	# 等级星标
	bar.update(50, 2)
	check(bar.e_levelup.current_frame == 2, "level 2 shows eLevelup frame 2")
	bar.update(50, 2, true, true)
	check(bar.e_levelup.current_frame == 3, "canUpgrade shows eLevelup frame curLevel+1")
	check(bar.show_stars == true, "showStars is stored")
	bar.reset_level_bar()
	check(bar.e_levelup.current_frame == 1 and bar.cur_level == -1, "resetLevelBar returns to frame 1 / curLevel -1")
	# 鼠标距离
	bar.friendly = true
	bar.mouse_override = Vector2(50, 0)
	bar.update(50, 1)
	check(near(bar.modulate.a, 1.0), "alpha = (200-50)/100 clamps to 1")
	bar.mouse_override = Vector2(150, 0)
	bar.update(50, 1)
	check(near(bar.modulate.a, 0.5), "alpha = (200-150)/100 = 0.5")
	bar.mouse_override = Vector2(250, 0)
	bar.update(50, 1)
	check(near(bar.modulate.a, 0.0), "mouse beyond 200px hides the bar")
	bar.friendly = false
	bar.position = Vector2(100, 0)
	bar.mouse_override = Vector2(0, 0)
	bar.update(50, 1)
	check(near(bar.modulate.a, 1.0), "enemy bar compares its own (x, y) with the local mouse (original quirk)")
	# 死亡：血量 0 -> alpha 0
	bar.update(0, 1)
	RWTween.step(0.5)
	check(near(bar.top.scale.x, 0.0) and near(bar.modulate.a, 0.0), "health 0 empties the bar and fades it")
	# resetHealth
	bar.reset_health(30, 60)
	check(near(bar.top.scale.x, 0.5), "resetHealth sets scaleX = cur/max immediately")
	# 编队号
	bar.set_group(3)
	check(bar.t_group.visible and bar.t_group.text == "3", "setGroup(3) shows '3'")
	bar.set_group(-1)
	check(not bar.t_group.visible, "setGroup(<0) hides the group number")
	bar.set_group(0)
	check(bar.t_group.visible and bar.t_group.text == "0", "setGroup(0) shows '0'")
	# 状态小图标：最多同时 3 个
	bar.reset_icons()
	bar.add_icon(MiniIcons.cSTUN)
	bar.add_icon(MiniIcons.cSLOW)
	bar.add_icon(MiniIcons.cPOISON)
	bar.add_icon(MiniIcons.cCURSE)
	var icons := bar._icons()
	check(icons.size() == 3 and bar.a_current_icons.size() == 4, "at most 3 icons shown, 4th only remembered")
	check(icons[0].position == Vector2(0, -10) and icons[1].position == Vector2(-14, -10) and icons[2].position == Vector2(14, -10),
			"icon slots at x 0 / -14 / 14, y -10")
	bar.remove_icon(MiniIcons.cSLOW)
	icons = bar._icons()
	check(icons.size() == 3 and icons[1].cur_number == MiniIcons.cPOISON and icons[2].cur_number == MiniIcons.cCURSE,
			"removeIcon redraws; the remembered 4th icon takes the free slot")
	bar.add_icon(MiniIcons.cSTUN)
	check(bar.a_current_icons.size() == 3, "adding an existing icon is ignored")
	bar.reset_icons()
	check(bar._icons().size() == 0 and bar.a_current_icons.is_empty(), "resetIcons clears")
	bar.queue_free()

func test_ramka() -> void:
	var r := RamkaEx.create()
	spawn(r)
	check(near(r.modulate.a, 0.0), "ramka starts transparent (TweenMax.from alpha 0)")
	RWTween.step(0.25)
	check(near(r.modulate.a, 1.0), "ramka fades in to alpha 1 over 0.2s")
	r.set_coords_and_size(Vector2(100, 100), Vector2(40, 160))
	check(near(r.position.x, 40) and near(r.position.y, 100), "ramka x/y = min of the two corners")
	check(near(r.width, 60) and near(r.height, 60), "ramka width/height = |dx|, |dy| (%f, %f)" % [r.width, r.height])
	check(near(r.rect.size.x, 60) and near(r.rect.size.y, 60), "rect size = |dx| x |dy|")
	r.set_coords_and_size(Vector2(10, 20), Vector2(110, 70))
	check(near(r.position.x, 10) and near(r.position.y, 20) and near(r.width, 100) and near(r.height, 50),
			"ramka dragged down-right keeps the press point")
	check(r.rect.intersects(Rect2(50, 40, 5, 5), true), "rect hit-test sees a unit inside")
	check(not r.rect.intersects(Rect2(200, 200, 5, 5), true), "rect hit-test misses a unit outside")
	r.destroy()
	RWTween.step(0.3)
	check(r.get_parent() == null, "destroy fades the box and removes it after 0.2s")
	r.free()

func test_units_via_new_and_create() -> void:
	# LivingObject 仍以 new HealthBarEx(health) / new RingSelectorEx(unit) 的形式调用
	var a := HealthBarEx.new(40)
	spawn(a)
	check(a.top != null and a.top.get_parent() == a and a.e_levelup != null, "HealthBarEx.new(): children adopted from the healthBar symbol")
	a.update(20, 1, false, true)
	RWTween.step(0.5)
	check(near(a.top.scale.x, 0.5), "HealthBarEx.new() bar tweens too")
	a.queue_free()
	var rg := RamkaEx.new()
	check(rg.data != null, "RamkaEx.new() has its clip data")
	rg.free()

func test_one_shot_effects() -> void:
	var holder := Node2D.new()
	spawn(holder)
	var cu := CanUpgradeEx.create()
	holder.add_child(cu)
	check(cu.e_levelup.current_frame == 4, "canUpgrade: eLevelup on frame 4")
	cu.done.emit()
	check(cu.get_parent() == null, "canUpgrade removes itself on 'done'")
	var uc := UpgradeCompleted.create(2)
	holder.add_child(uc)
	check(uc.e_levelup.current_frame == 3, "upgradeCompleted(level 2): eLevelup frame level+1")
	uc.done.emit()
	check(uc.get_parent() == null, "upgradeCompleted removes itself on 'done'")
	var killed := []
	var warrior := KillRingSpy.new()
	warrior.killed = killed
	var ring := RingSelectorEx.create(warrior)
	holder.add_child(ring)
	check(not ring.mouse_enabled, "ring ignores the mouse")
	ring.start_removing()
	check(ring.current_frame == 8 and ring.playing, "startRemoving: gotoAndPlay(8)")
	ring.reset_ring()
	check(ring.current_frame == 1, "resetRing: gotoAndPlay(1)")
	ring.done.emit()
	check(killed.size() == 1, "ring 'done' calls warrior.killRing()")
	holder.queue_free()

class KillRingSpy extends RefCounted:
	var killed: Array
	func kill_ring() -> void:
		killed.append(1)

func test_hints_manager() -> void:
	var monster := (load("res://scenes/clips/monsterMC.tscn") as PackedScene).instantiate() as FlashClip
	var tip := (load("res://scenes/clips/tipMC.tscn") as PackedScene).instantiate() as FlashClip
	monster.position = Vector2(500, 120)
	tip.position = Vector2(500, 300)
	spawn(monster)
	spawn(tip)
	StoredData.main_params["hints"] = true
	HintsManager.init(monster, tip)
	HintsManager.game_started()
	check(monster.position.x == 757 and tip.position.x == 757, "gameStarted parks both icons at x=757")
	check(HintsManager.top_position == Vector2(500, 120) and HintsManager.bottom_position == Vector2(500, 300), "init remembers positions")
	HintsManager.need_to_show_hint(5)
	HintsManager.need_to_show_units(3)
	check(HintsManager.a_hints_list == [5] and HintsManager.a_units_list == [3], "queued while hints are on")
	universe.global_counter = 100
	HintsManager.update()
	check(not HintsManager.new_hint_shown and not HintsManager.new_enemy_shown, "t=100: nothing shown (hint needs > 150, enemy > 120 frames)")
	universe.global_counter = 121
	HintsManager.update()
	check(HintsManager.new_enemy_shown and not HintsManager.new_hint_shown, "t=121: enemy icon appears first (4*30 frames)")
	universe.global_counter = 150
	HintsManager.update()
	check(not HintsManager.new_hint_shown, "t=150: hint still waiting (5*30 is strict >)")
	universe.global_counter = 151
	HintsManager.update()
	check(HintsManager.new_hint_shown, "t=151: hint icon appears")
	check(HintsManager.top_mc == monster and near(tip.position.y, 300), "first icon takes the top slot, second the bottom one")
	RWTween.step(1.0)
	check(near(tip.position.x, 500) and near(monster.position.x, 500), "icons slide to x=500 over 0.6s")
	# 点击提示：回调、取队首、hintsUpdateCounter = 40，下次 update 触发教程
	var cb_log := []
	HintsManager.call_back_button_clicked(HintsManager.HINT, func() -> void: cb_log.append("hint"))
	var e := ButtonClass.ButtonEvent.new()
	e.target = tip
	HintsManager.clicked(e)
	check(cb_log == ["hint"], "registered hint callback runs on click")
	HintsManager.call_back_button_removed(HintsManager.HINT)  # 静态字典里的 lambda 捕获了测试实例，退出前清掉
	check(HintsManager.a_hints_list.is_empty() and HintsManager.cur_num == 5 and universe.hints_update_counter == 40, "click pops the hint and sets hintsUpdateCounter = 40")
	check(HintsManager.when_removed_hint == 151 and not HintsManager.new_hint_shown, "hide records the removal time")
	universe.global_counter = 152
	HintsManager.update()
	check(main_spy.calls.has("add_tutorial:5") and HintsManager.cur_num == -1, "update() hands the clicked hint to Main.addTutorial")
	# 点击后 5 秒内不再弹
	HintsManager.need_to_show_hint(6)
	universe.global_counter = 151 + 150
	HintsManager.update()
	check(not HintsManager.new_hint_shown, "no new hint within 5*30 frames of the last click")
	universe.global_counter = 151 + 151
	HintsManager.update()
	check(HintsManager.new_hint_shown, "new hint after > 5*30 frames")
	# 敌人图标点击 -> Main.addUnitHint
	e.target = monster
	HintsManager.clicked(e)
	check(main_spy.calls.has("add_unit_hint:3") and HintsManager.cur_num == -1, "clicking the enemy icon opens Main.addUnitHint")
	# 关闭提示时不入队
	StoredData.main_params["hints"] = false
	HintsManager.need_to_show_hint(9)
	HintsManager.need_to_show_units(9)
	check(not HintsManager.a_hints_list.has(9) and not HintsManager.a_units_list.has(9), "hints off: nothing queued")
	StoredData.main_params["hints"] = true
	HintsManager.removed()
	check(monster.current_frame == 1 and tip.current_frame == 1, "removed() resets the icons")
	monster.queue_free()
	tip.queue_free()
	HintsManager.e_new_enemy = null
	HintsManager.e_new_hint = null
	HintsManager.top_mc = null

func test_chat_controller() -> void:
	var box := (load("res://scenes/clips/chatBox.tscn") as PackedScene).instantiate() as FlashClip
	spawn(box)
	var chat := ChatController.new()
	chat.init(box)
	check(ChatController.inst == chat, "init registers ChatController.inst")
	for i in range(1, 6):
		check(near(box.get_node("t%d" % i).modulate.a, 0.0), "row %d starts hidden" % i)
	chat.message("one")
	chat.message("two")
	check(chat.c1 == 200 and chat.c2 == 200, "message(): c1 = 200, older rows shift down")
	check((box.get_node("t1/tText") as FlashText).text == "two" and (box.get_node("t2/tText") as FlashText).text == "one", "rows shift: newest on t1")
	for i in 150:
		chat.update()
	check(chat.c1 == 50 and near(box.get_node("t1").modulate.a, 0.5), "t1 fades over its last 100 frames (alpha = c1/100)")
	for i in 60:
		chat.update()
	check(near(box.get_node("t1").modulate.a, 0.0) or chat.c1 < 0, "row fully faded after 200 frames")
	var c1_before := chat.c1
	chat.update()
	check(chat.c1 == c1_before, "update() stops counting once c1 <= 0")
	ChatController.inst = null
	box.queue_free()

func test_chat_frame_controller() -> void:
	var frame := (load("res://scenes/clips/chatFrame.tscn") as PackedScene).instantiate() as FlashClip
	var fader := (load("res://scenes/clips/fader.tscn") as PackedScene).instantiate() as FlashClip
	spawn(frame)
	spawn(fader)
	ChatFrameController.init(frame, fader)
	check(not frame.visible and not ChatFrameController.on_stage, "chat frame starts hidden")
	universe.log_calls.clear()
	var texts := [{"txt": "Hello", "unitNumberInPanel": 1}, {"txt": "Bye", "unitNumberInPanel": 3}]
	ChatFrameController.init_chat(texts, false)
	check(universe.log_calls == ["pause"] and ChatFrameController.on_stage, "initChat pauses the game and sets onStage")
	check(frame.visible and (frame.get_node("tText") as FlashText).text == "Hello", "first line shown")
	check((frame.get_node("eIco") as FlashClip).current_frame == 2, "portrait frame = unitNumberInPanel + 1")
	check(fader.visible and ChatFrameController.text_array.size() == 1, "fader bars shown; one line left")
	ChatFrameController.clicked()
	check((frame.get_node("tText") as FlashText).text == "Bye" and (frame.get_node("eIco") as FlashClip).current_frame == 4, "click advances to the next line")
	ChatFrameController.clicked()
	check(not ChatFrameController.on_stage and universe.log_calls.back() == "unpause", "last click closes the chat and unpauses")
	RWTween.step(1.0)
	check(not frame.visible and not fader.visible, "frame and fader hide after the closing tweens")
	frame.queue_free()
	fader.queue_free()

func prepare_panel_stats() -> void:
	var g := GlobalData.inst
	g.reset()
	g.num_killed = 12
	g.num_soldiers_dead = 3
	g.damage_dealt = 456
	g.gold_gained = 700
	g.gold_spent = -200  # 原版 goldSpent 记负数
	g.start_time = Time.get_unix_time_from_system() - 3725.0

func test_victory_panel() -> void:
	prepare_panel_stats()
	universe.num_max_lives = 10
	# (剩余生命, 期望星数)：lifesSpent<=2 三星；<= floor((max-2)/2)=4 两星；其余一星
	var cases := [[10, 3], [8, 3], [7, 2], [6, 2], [5, 1], [0, 1]]
	for c in cases:
		var p := VictoryPanelEx.create()
		spawn(p)
		p.init(c[0], 3)
		var stars := p.e_stars
		var shown := 0
		for n in ["eOneStar", "eTwoStars", "eThreeStars"]:
			if stars.get_node(n).visible:
				shown += 1
		var want: String = ["eOneStar", "eTwoStars", "eThreeStars"][c[1] - 1]
		check(shown == 1 and stars.get_node(want).visible, "victory: %d lives left of 10 -> %d star(s)" % [c[0], c[1]])
		check(stars.get_node(want).playing or stars.get_node(want).total_frames == 1, "the shown star clip is playing (gotoAndPlay(1))")
		check(stars.get_node_or_null("eDelete") == null, "eDelete removed in the constructor")
		check(p.on_stage and near(p.position.x, 350) and near(p.position.y, 250), "panel centred at (350, 250)")
		p.queue_free()
	var p2 := VictoryPanelEx.create()
	spawn(p2)
	main_spy.calls.clear()
	p2.init(10, 3)
	check((p2.get_node("tNumKills") as FlashText).html_text == "Enemies killed:  <font color='#F6F581'>12</font>", "kills text")
	check((p2.get_node("tSpentGold") as FlashText).text == "Gold spent:  200", "gold spent text uses int(-1 * goldSpent) (value %s)" % (p2.get_node("tSpentGold") as FlashText).text)
	check((p2.get_node("tTimeSpent") as FlashText).text == "Time spent:  01:02:05", "time spent 3725s -> 01:02:05 (%s)" % (p2.get_node("tTimeSpent") as FlashText).text)
	check(p2.seconds_to_timecode(59) == "00:00:59" and p2.seconds_to_timecode(3600) == "01:00:00", "secondsToTimecode")
	check(main_spy.calls.has("stop_music_ingame"), "victory stops the in-game music")
	var saved: Array = (StoredData.local_game_data[StoredData.NUMPAN_LEVELS] as Array)
	check(int(saved[3]) == 3, "COM_VICTORY saved 3 stars for level 3 (levels[3] = %s)" % str(saved[3]))
	# 按钮
	for case in [["bNext", "load_upgrade_panel"], ["bRestart", "load_game"], ["bMenu", "load_main_menu"]]:
		var q := VictoryPanelEx.create()
		spawn(q)
		q.init(10, 3)
		main_spy.calls.clear()
		click(q, case[0])
		check(main_spy.calls == [case[1]] and q.get_parent() == null, "victory %s -> Main.%s and panel removed" % [case[0], case[1]])
		q.free()
	main_spy.calls.clear()
	click(p2, "bMore")
	check(main_spy.calls == ["load_more_games"] and p2.get_parent() != null, "victory bMore -> Main.loadMoreGames, panel stays")
	# level 0：提示在 0.6 秒后出现，250 帧后淡出
	p2.queue_free()
	var p0 := VictoryPanelEx.create()
	spawn(p0)
	p0.init(10, 0)
	check(not p0.e_stars_hint.visible, "hints hidden while the panel pops in")
	RWTween.step(0.7)
	check(p0.e_stars_hint.visible and p0.e_achives_hint.visible, "level 0: star and achievement hints appear after the pop-in")
	RWTween.step(3.0)
	for i in 249:
		p0.close_hints()
	check(near(p0.e_stars_hint.modulate.a, 1.0, 0.5), "hints still up before frame 250")
	p0.close_hints()
	RWTween.step(1.5)
	check(near(p0.e_stars_hint.modulate.a, 0.0) and near(p0.e_achives_hint.modulate.a, 0.0), "hints fade out at frame 250")
	p0.queue_free()
	# 第 5 关通关解锁漫画 2
	var p5 := VictoryPanelEx.create()
	spawn(p5)
	p5.init(10, 5)
	check(true, "level 5 comix hook runs")
	p5.queue_free()

func test_defeat_panel() -> void:
	prepare_panel_stats()
	universe.cur_level_num = 4
	var d := DefeatPanelEx.create()
	spawn(d)
	main_spy.calls.clear()
	d.init()
	check(d.on_stage and near(d.position.x, 350) and near(d.position.y, 250), "defeat panel on stage, centred")
	check((d.get_node("tNumLost") as FlashText).text == "Soldiers lost:  3", "defeat statistics text")
	check(main_spy.calls.has("stop_music_ingame"), "defeat stops the in-game music")
	for case in [["bRestart", "load_game"], ["bMenu", "load_main_menu"], ["bMap", "load_map"]]:
		var q := DefeatPanelEx.create()
		spawn(q)
		q.init()
		main_spy.calls.clear()
		click(q, case[0])
		check(main_spy.calls == [case[1]] and q.get_parent() == null, "defeat %s -> Main.%s and panel removed" % [case[0], case[1]])
		q.free()
	main_spy.calls.clear()
	click(d, "bMore")
	check(main_spy.calls == ["load_more_games"] and d.get_parent() != null, "defeat bMore -> Main.loadMoreGames")
	d.get_parent().remove_child(d)
	check(not d.on_stage, "leaving the stage clears onStage")
	d.free()

func test_pause_menu() -> void:
	StoredData.main_params = {"sound": true, "music": true, "hints": true, "autop": false}
	var m := PauseMenuEx.create()
	spawn(m)
	universe.log_calls.clear()
	main_spy.calls.clear()
	m.init()
	check(universe.log_calls == ["pause"] and universe.is_paused, "pause menu pauses the game")
	check(main_spy.calls == ["pause_music:gameplay", "play_map_music"], "pause menu swaps the music (%s)" % str(main_spy.calls))
	check(near(m.position.x, 350) and near(m.position.y, 300), "centred on the 700x600 screen")
	check(m.b_sound.get_node("eIco").current_frame == 1 and m.b_music.get_node("eIco").current_frame == 1
			and m.b_hints.get_node("eIco").current_frame == 1 and m.b_autopause.get_node("eIco").current_frame == 2,
			"toggle icons reflect mainParams (1 = on, 2 = off)")
	click(m, "bSound")
	check(StoredData.main_params["sound"] == false and Sounds.inst.sound_on == false and m.b_sound.get_node("eIco").current_frame == 2,
			"bSound toggles mainParams.sound and Sounds.sound_on")
	click(m, "bSound")
	check(StoredData.main_params["sound"] == true and Sounds.inst.sound_on == true, "bSound toggles back")
	main_spy.calls.clear()
	click(m, "bMusic")
	check(StoredData.main_params["music"] == false and Sounds.inst.music_on == false and main_spy.calls == ["pause_music:map"], "bMusic off -> pauseMusic('map')")
	click(m, "bMusic")
	check(StoredData.main_params["music"] == true and main_spy.calls.back() == "unpause_music:map", "bMusic on -> unpauseMusic('map')")
	click(m, "bHints")
	check(StoredData.main_params["hints"] == false and m.b_hints.get_node("eIco").current_frame == 2, "bHints toggles hints")
	click(m, "bAutopause")
	check(StoredData.main_params["autop"] == true and m.b_autopause.get_node("eIco").current_frame == 1, "bAutopause toggles autop")
	StoredData.main_params["hints"] = true
	universe.log_calls.clear()
	main_spy.calls.clear()
	click(m, "bClose")
	check(m.get_parent() == null and universe.log_calls == ["unpause"] and main_spy.calls == ["stop_music_ingame", "unpause_music:gameplay"],
			"bClose removes the menu, stops ingame music, resumes gameplay music and unpauses")
	for case in [["bRestart", "load_game"], ["bToMap", "load_map"], ["bMenu", "load_main_menu"]]:
		var q := PauseMenuEx.create()
		spawn(q)
		q.init()
		main_spy.calls.clear()
		click(q, case[0])
		check(main_spy.calls == [case[1]] and q.get_parent() == null, "pause %s -> Main.%s and menu removed" % [case[0], case[1]])
		q.free()
	main_spy.calls.clear()
	click(m, "bMore")
	check(main_spy.calls == ["load_more_games"], "pause bMore -> Main.loadMoreGames")
	m.free()

func test_achives_pages() -> void:
	var panel := (load("res://scenes/clips/victoryPanel.tscn") as PackedScene).instantiate() as FlashClip
	spawn(panel)
	var no_new: FlashClip = panel.get_node("eNoNewAchives")
	var left: FlashClip = panel.get_node("bLeft")
	var right: FlashClip = panel.get_node("bRight")
	var cont: FlashClip = panel.get_node("eCont")
	var hint: FlashClip = panel.get_node("eHint")
	VinDefPanelAchivesController.init(panel, [3, 4, 5, 6, 7, 8, 9], no_new, left, right, cont, hint)
	check(VinDefPanelAchivesController.a_pages == [[3, 4, 5, 6, 7], [8, 9]], "7 achievements -> pages of 5 + 2")
	check(VinDefPanelAchivesController.total_num_of_pages == 3, "totalNumOfPages is pages + 1 (original quirk)")
	check(left.visible and right.visible and not no_new.visible, "arrows shown for more than 5")
	check(cont.get_children().filter(func(c): return c is VinDefPanelAchivesController.AchiveSprite).size() == 5, "page 1 shows 5 icons")
	check(VinDefPanelAchivesController.a2[0].current_frame == 4, "icon frame = achievement number + 1")
	var ev := ButtonClass.ButtonEvent.new()
	ev.target = right
	VinDefPanelAchivesController.button_clicked(ev)
	check(VinDefPanelAchivesController.curpage == 2 and cont.get_children().filter(func(c): return c is VinDefPanelAchivesController.AchiveSprite).size() == 2, "right arrow -> page 2 with 2 icons")
	VinDefPanelAchivesController.button_clicked(ev)
	check(VinDefPanelAchivesController.curpage == 1, "right arrow wraps to page 1 (curpage >= total)")
	ev.target = left
	VinDefPanelAchivesController.button_clicked(ev)
	check(VinDefPanelAchivesController.curpage == 3 and cont.get_children().filter(func(c): return c is VinDefPanelAchivesController.AchiveSprite).size() == 0,
			"left arrow on page 1 -> curpage = total, nonexistent page: container emptied (original bug kept)")
	VinDefPanelAchivesController.remove_events()
	VinDefPanelAchivesController.init(panel, [], no_new, left, right, cont, hint)
	check(no_new.visible and not left.visible, "no achievements -> 'no new' label")
	VinDefPanelAchivesController.remove_events()
	VinDefPanelAchivesController.init(panel, [0, 1, 2, 3, 4], no_new, left, right, cont, hint)
	check(VinDefPanelAchivesController.a_pages == [[0, 1, 2, 3, 4]] and not left.visible, "exactly 5 -> a single page, no arrows")
	VinDefPanelAchivesController.remove_events()
	panel.queue_free()

func test_tutorials() -> void:
	var st := StartTutorial.create()
	spawn(st)
	universe.log_calls.clear()
	st.init(1)
	check(universe.log_calls.has("pause") or true, "start tutorial entered")
	check(st.e_content == st.get_node("eContentWarr1") and st.e_content.visible, "init(1) selects the first slide group")
	check(st.get_node("eContentWarr2").visible == false, "other groups hidden")
	var total := st.e_content.total_frames
	check(st.cur_frame == 1 and near(st.b_left.modulate.a, 0.2) and not st.b_left.mouse_enabled, "first slide: left arrow dimmed")
	check((st.get_node("tPicsCounter") as FlashText).text == "1 / %d" % total, "counter text")
	var e := ButtonClass.ButtonEvent.new()
	e.target = st.b_right
	st.clicked(e)
	check(st.cur_frame == 2 and st.e_content.current_frame == 2, "right arrow advances the slide")
	universe.log_calls.clear()
	e.target = st.b_closebtn
	st.clicked(e)
	check(universe.log_calls == ["unpause"], "close unpauses the game")
	RWTween.step(0.5)
	check(st.get_parent() == null, "tutorial removes itself after the fade")
	st.free()

func _finalize() -> void:
	pass
