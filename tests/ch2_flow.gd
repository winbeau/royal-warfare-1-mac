extends SceneTree
# WP-A：第二章「章节流程、存档与界面」端到端测试。参照 tests/input_e2e.gd 的真实点击写法。
# 运行：Godot --headless --path . --script tests/ch2_flow.gd -- --isolated-profile
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")


func click_at(pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	root.push_input(mm)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up)
	await process_frame
	await process_frame


func click_center(c: Control) -> void:
	await click_at(visual_center_global(c))


func visual_center_global(c: Control) -> Vector2:
	if c is FlashClip:
		var b: Rect2 = IfaceUtil.clip_bounds(c as FlashClip)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			return c.get_global_transform() * b.get_center()
	return c.get_global_rect().get_center()


func wait_until(cond: Callable, max_frames: int, label: String) -> bool:
	var max_ms := int(max_frames * 1000.0 / 30.0 * 2.0)
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
	var ok: bool = cond.call()
	check(ok, "%s（等待 %d ms 未满足）" % [label, Time.get_ticks_msec() - t0])
	return ok


## 两面旗帜的包围盒是否重叠（AABB），用于断言东渡船命中区不与 markers 任何按钮/旗帜重叠。
func rects_overlap(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)


## FlashClip 可见包围盒（clip_bounds，局部坐标）换算到全局坐标的轴对齐矩形。
func global_visual_rect(c: FlashClip) -> Rect2:
	var b: Rect2 = IfaceUtil.clip_bounds(c)
	var xf := c.get_global_transform()
	var p0: Vector2 = xf * b.position
	var p1: Vector2 = xf * (b.position + Vector2(b.size.x, 0))
	var p2: Vector2 = xf * (b.position + Vector2(0, b.size.y))
	var p3: Vector2 = xf * (b.position + b.size)
	var r := Rect2(p0, Vector2.ZERO)
	for p in [p1, p2, p3]:
		r = r.expand(p)
	return r


func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	root.size = Vector2i(700, 600)
	StoredData.test_wipe()

	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait_until(func() -> bool: return main.resources_loaded, 600, "资源加载完成")
	await process_frame
	await process_frame

	var flags: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	for k in flags.keys():
		flags[k] = 1
	LevelIntro.is_shown = true
	LevelIntro.can_end_intro = true
	StoredData.main_params["hints"] = false

	await wait_until(func() -> bool: return main.main_menu != null and main.main_menu.visible, 3000, "启动后出现主菜单")
	await wait_until(func() -> bool: return main.warmup_done, 3000, "后台预热完成")

	# ===== 1. 隔离存档、end_game_flag 未完成：一代地图上没有船 =====
	var b_play: Control = main.main_menu.get_node_or_null("bPlay")
	check(b_play != null, "主菜单 bPlay 节点存在")
	if b_play != null:
		await click_center(b_play)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "1. 点击 Play 后地图出现")
	var g_map: GameMapObject = main.g_map
	check(g_map != null and g_map.get("ch2_ship") == null, "1. end_game_flag 未完成时一代地图上没有东渡船")

	# ===== 2. end_game_flag 完成后重进一代地图：船出现，且与 markers 不重叠；真实点击船进入二章地图 =====
	StoredData.set_end_game_completed()
	await click_center(GameMapObject.markers.get_node("bMenu"))
	await wait_until(func() -> bool: return main.main_menu != null and main.main_menu.get_parent() != null, 300, "2. 点 Menu 回到主菜单")
	var b_play2: Control = main.main_menu.get_node_or_null("bPlay")
	if b_play2 != null:
		await click_center(b_play2)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "2. 再次点击 Play 后地图出现")
	g_map = main.g_map
	await process_frame
	await process_frame
	var ship: Ch2ShipButton = g_map.get("ch2_ship")
	check(ship != null, "2. end_game_flag 完成后一代地图上出现东渡船")
	if ship != null:
		var ship_rect := Rect2(ship.global_position, ship.size)
		var overlap_found := false
		for flag: FlashClip in g_map.a_markers:
			if flag.visible and rects_overlap(ship_rect, global_visual_rect(flag)):
				overlap_found = true
		for btn_name in ["bReset", "bOnline", "bUpgrades", "bMore", "bMenu", "bNext", "bAchives"]:
			var btn: FlashClip = GameMapObject.markers.get_node(btn_name)
			if btn.visible and rects_overlap(ship_rect, global_visual_rect(btn)):
				overlap_found = true
		check(not overlap_found, "2. 东渡船命中区域与 markers 的按钮/旗帜不重叠")
		await click_center(ship)
	await wait_until(func() -> bool: return main.current_chapter == 2, 180, "2. 点击船后 current_chapter == 2")
	await wait_until(func() -> bool: return main.ch2_map != null and main.ch2_map.get_parent() != null, 300, "2. 点击船后进入二章地图")

	# ===== 3. 二章地图上第 1 面旗可见，第 2 面不可见；点击第 1 面旗弹窗标题/正文等于 Ch2Text.level(1) =====
	var ch2_map: Ch2MapScreen = main.ch2_map
	await process_frame
	await process_frame
	check(ch2_map.a_markers.size() == 36, "3. 二章地图有 36 面旗帜")
	if ch2_map.a_markers.size() >= 2:
		check(ch2_map.a_markers[0].visible, "3. 第 1 面旗可见")
		check(not ch2_map.a_markers[1].visible, "3. 第 2 面旗不可见（未解锁）")
	var flag1: FlashClip = ch2_map.a_markers[0]
	var sens1: Control = flag1.get_node_or_null("sens")
	check(sens1 != null, "3. 第 1 面旗 sens 命中区存在")
	await wait_until(func() -> bool: return RWTween.get_tweens_of(flag1).is_empty(), 150, "3. 第 1 面旗入场动画播完")
	var banner1: FlashClip = flag1.get_node("eVisited") if flag1.get_node("eVisited").visible else flag1.get_node("eUnvisited")
	await click_at(visual_center_global(banner1))
	await wait_until(func() -> bool: return ch2_map.pop != null and ch2_map.pop.get_parent() != null, 180, "3. 点击第 1 面旗后弹窗出现")
	var popup: PopupMissionEx = ch2_map.pop
	var expect1: Dictionary = Ch2Text.level(1)
	check(popup != null and popup.t_mission_name.text == str(expect1.get("name", "")), "3. 弹窗标题等于 Ch2Text.level(1).name")
	check(popup != null and popup.t_mission_desc.text == str(expect1.get("briefing", "")), "3. 弹窗正文等于 Ch2Text.level(1).briefing")

	# ===== 4. 点开始后，main.last_level_num_ch2 与 game_uni.chapter == 2 正确 =====
	# M0 期间 A 包只验证到这一步：进入战斗后的目标/导演/地图几何由 B 包的测试覆盖。
	if popup != null and popup.b_playbtn != null:
		await click_center(popup.b_playbtn)
	await wait_until(func() -> bool: return main.game_uni != null, 300, "4. 点击 Start Battle 后 game_uni 存在")
	check(int(main.last_level_num_ch2) == 0, "4. last_level_num_ch2 记为 0（第 1 关 0 基）")
	check(main.game_uni.get("chapter") == 2, "4. game_uni.chapter == 2")

	# ===== 5. 胜利面板分支：桩关卡 compute_stars() 返回 2 =====
	var levels_before: Array = (StoredData.local_game_data[StoredData.NUMPAN_LEVELS] as Array).duplicate()
	var comix_before: Dictionary = (StoredData.local_game_data[StoredData.NUMPAN_COMIX] as Dictionary).duplicate()
	var stub := StubLevelCh2.new(2)
	main.game_uni.chapter = 2
	main.game_uni.level_info = stub
	var vic := VictoryPanelEx.create()
	main.game_screens_container.add_child(vic)
	vic.init(int(main.game_uni.num_max_lives), 0)
	check(StoredData.ch2_stars(1) == 2, "5. StoredData.ch2_stars(1) == 2")
	check(StoredData.ch2_level_unlocked(2), "5. ch2_level_unlocked(2) 为真")
	check((StoredData.local_game_data[StoredData.NUMPAN_LEVELS] as Array) == levels_before, "5. 一代的漫画标志（NUMPAN_LEVELS）未变")
	check((StoredData.local_game_data[StoredData.NUMPAN_COMIX] as Dictionary) == comix_before, "5. 一代的漫画解锁标志（NUMPAN_COMIX）未变")
	vic.queue_free()

	# ===== 6. 二章地图上点返回船：current_chapter == 1，显示一代地图 =====
	# 从当前的战斗画面直接回二章地图（等价于玩家从暂停菜单回地图，不改变已验证的返回路径）。
	main.current_chapter = 2
	main.load_ch2_map()
	await wait_until(func() -> bool: return main.ch2_map != null and main.ch2_map.get_parent() != null, 300, "6. 回到二章地图")
	ch2_map = main.ch2_map
	await process_frame
	await process_frame
	var back_ship: Ch2ShipButton = ch2_map.get("back_ship")
	check(back_ship != null, "6. 二章地图上有返回船")
	if back_ship != null:
		await click_center(back_ship)
	await wait_until(func() -> bool: return main.current_chapter == 1, 180, "6. 点返回船后 current_chapter == 1")
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "6. 点返回船后显示一代地图")

	main.queue_free()
	await process_frame

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


## 第 5 步用的桩关卡：只实现 compute_stars()，鸭子类型调用。
class StubLevelCh2 extends LevelTemplate:
	var _stars: int
	var level_number: int = 1

	func _init(stars: int) -> void:
		_stars = stars

	func compute_stars() -> int:
		return _stars

	func allows_default_end() -> bool:
		return false

	func uses_lives() -> bool:
		return false
