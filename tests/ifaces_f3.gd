extends SceneTree
# F3 界面层审计的回归测试：
#  - 地图上的 Reset 弹窗被反复打开（真实鼠标事件）：第二次打开仍有动画和可点的按钮；
#  - gameMapObject 构造里 3 个弹窗的类型、动画元素的 RNG 次数、红圈只补间 scaleX（原版对象字面量笔误）；
#  - 升级面板的技能说明取自 GameUniverse.a_specials[idx]，A_WEAKNESS 为 null；
#  - mmAnimSoldiers_ex.init 给动画士兵随机起始帧；
#  - update_b_archers_cooldown 是唯一命名；
#  - 胜负面板 secondsToTimecode / setStatistics 的耗时。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
		print("FAIL: ", message)

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

func center_of(c: Control) -> Vector2:
	if c is FlashClip:
		var b: Rect2 = IfaceUtil.clip_bounds(c as FlashClip)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			return c.get_global_transform() * b.get_center()
	return c.get_global_rect().get_center()

func wait_until(cond: Callable, max_frames: int, label: String) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1
	var ok: bool = cond.call()
	check(ok, "%s（等待 %d 帧未满足）" % [label, n])
	return ok

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

	# ---- 纯逻辑部分 ----
	# a_specials：下标即 StoredData.A_*，A_WEAKNESS 为 null；升级面板用它查技能说明
	check(GameUniverse.a_specials[StoredData.A_WEAKNESS] == null, "a_specials[A_WEAKNESS] 为 null")
	check(GameUniverse.a_specials[StoredData.A_STUN] is SpecStun, "a_specials[A_STUN] 是 SpecStun")
	check(not _has_method(UpgrPanelEx, "_spec_for_abil"), "升级面板不再有本地 _spec_for_abil 查表")
	check(not _has_method(MainGameUIEx, "update_barchers_cooldown"), "只保留 update_b_archers_cooldown 命名")
	check(_has_method(MainGameUIEx, "update_b_archers_cooldown"), "update_b_archers_cooldown 存在")

	# 耗时文字：getTime 两次 -> 秒数 -> secondsToTimecode
	check(_timecode(3725) == "01:02:05", "secondsToTimecode(3725) == 01:02:05（得到 %s）" % _timecode(3725))
	check(_timecode(59) == "00:00:59", "secondsToTimecode(59) == 00:00:59")

	# mmAnimSoldiers_ex.init：随机起始帧（装饰性 Math.random -> randf）
	var mm := MmAnimSoldiersEx.create()
	root.add_child(mm)
	await process_frame
	mm.init()
	var frames := {}
	for c: FlashClip in mm.a_frames:
		frames[c.current_frame] = true
	check(frames.size() > 3, "动画士兵拿到了不同的随机起始帧（不同帧数 %d）" % frames.size())
	mm.stop_anim()
	mm.queue_free()

	# ---- 地图：构造期的弹窗、RNG、红圈 ----
	var flags: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	for k in flags.keys():
		flags[k] = 1
	var expected_state := _state_after_draws(12345, GameMapObject.anims.get_child_count())
	RWRandom.set_seed(12345)
	var gm := GameMapObject.create()
	check(RWRandom.get_state() == expected_state, "gameMapObject 构造按原版对 anims 的每个子剪辑取一次 randRange")
	check(gm.reset_pop is PopupResetEx and gm.armor_save_pop is PopupSaveLoadEx and gm.storage_popup is PopupStorageFailureEx,
		"gameMapObject 构造里 new 了三个弹窗")
	gm.free()

	main.load_map()
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null and main.g_map.visible, 300, "地图出现")
	await process_frame
	await process_frame
	var g_map: GameMapObject = main.g_map
	check(absf(g_map.red_circle.scale.y - 1.0) < 0.001, "红圈 scaleY 不被补间（原版字面量写了两次 scaleX）")
	check(g_map.red_circle.scale.x > 1.0, "红圈 scaleX 从 1.5 往 1 补间")

	# ---- Reset 弹窗：连续打开两次，两次都能用真实鼠标关闭 ----
	var b_reset: FlashClip = GameMapObject.markers.get_node("bReset")
	var pop: PopupResetEx = g_map.reset_pop
	for round in 2:
		await click_at(center_of(b_reset))
		await wait_until(func() -> bool: return pop.get_parent() == g_map, 120, "第 %d 次点 bReset 后弹窗出现" % (round + 1))
		await wait_until(func() -> bool: return pop.popup.modulate.a > 0.99, 120, "第 %d 次弹窗入场动画播完" % (round + 1))
		await wait_until(func() -> bool: return absf(pop.popup.position.y - 300.0) < 1.0, 120, "弹窗入场位移结束")
		check(absf(pop.popup.position.y - 300.0) < 1.0, "第 %d 次弹窗落在舞台中央（y=%.1f）" % [round + 1, pop.popup.position.y])
		await click_at(center_of(pop.popup.child_clip("bClose")))
		await wait_until(func() -> bool: return pop.get_parent() == null, 180, "第 %d 次点 bClose 后弹窗移除" % (round + 1))
		await process_frame

	main.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _timecode(sec: float) -> String:
	return _tc(sec)

func _has_method(script: GDScript, method_name: String) -> bool:
	for m in script.get_script_method_list():
		if m["name"] == method_name:
			return true
	return false

func _tc(sec: float) -> String:
	var panel: Node = (load("res://scenes/ifaces/victory_panel_ex.tscn") as PackedScene).instantiate()
	var r: String = panel.seconds_to_timecode(sec)
	panel.free()
	return r

func _state_after_draws(seed_value: int, n: int) -> int:
	RWRandom.set_seed(seed_value)
	for i in n:
		RWRandom.rand_range(1, 1)
	var s := RWRandom.get_state()
	return s
