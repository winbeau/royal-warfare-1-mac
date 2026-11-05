extends SceneTree
# 真实输入端到端测试：实例化 scenes/main.tscn，用 push_input 发送真实的鼠标事件（不是直接调用处理函数），
# 走一遍"主菜单 Play -> 地图点关卡旗 -> 弹窗 Start Battle -> 战斗中招募/选中单位/点地面/HUD 按钮"。
# 舞台固定 700x600（root.size 直接设成舞台大小，和其余截图/capture 测试一致），点击坐标就是节点的
# global_position，不需要再换算窗口缩放。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
		print("FAIL: ", message, "  hovered=", _describe_hover())

func _describe_hover() -> String:
	var h := root.gui_get_hovered_control()
	if h == null:
		return "null"
	return "%s (mouse_filter=%d visible=%s)" % [str(h.get_path()), h.mouse_filter, h.visible]

func _initialize() -> void:
	call_deferred("run")

## 真实点击：鼠标移动到位置 -> 左键按下 -> 左键抬起，每步之间都真正让一帧跑过（gui_input 需要真实的
## InputEvent 经过 Viewport 的 GUI 路由，不能直接调用回调函数）。
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

## 真实玩家会点在"看起来"的按钮中心，即贴图实际覆盖的区域，而不是 Control.size/position 围出的
## 矩形——FlashClip 的 size 只是符号的名义包围盒，贴图常常相对它有偏移（见 IfaceUtil.clip_bounds 的
## 用法），直接用 get_global_rect() 当点击点会点偏，不代表真实输入路径。
func click_center(c: Control) -> void:
	await click_at(visual_center_global(c))

func visual_center_global(c: Control) -> Vector2:
	if c is FlashClip:
		var b: Rect2 = IfaceUtil.clip_bounds(c as FlashClip)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			return c.get_global_transform() * b.get_center()
	return c.get_global_rect().get_center()

## 等到 cond 为真或超过 max_frames 真实帧（真实渲染帧：RWTween 等用真实墙钟驱动的过渡在这期间会正常推进）。
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
	await process_frame
	# 跳过漫画/教学关的额外点击，专注验证列出的 7 步输入路径。注意：Main._load_step(76) 自己会在资源
	# 加载过程中调用一次 StoredData.init()（真实开机流程的一部分），所以要等 resources_loaded 之后
	# 再改存档标志，不然会被这次 init() 盖掉。
	var flags: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	for k in flags.keys():
		flags[k] = 1
	LevelIntro.is_shown = true
	LevelIntro.can_end_intro = true

	# 预载画面的 Start 按钮：真实点击（不是进入地图前要验证的 7 步之一，但同样走真实输入路径，
	# 也是用户反馈"进入游戏后点击没反应"最早可能发生的地方）。点击后走完整的原版链路：
	# startClicked -> 0.9 秒后 show_intro（maxgLogoIntro，546 帧 / 30fps≈18 秒）-> done -> max_done
	# -> 0.2 秒后 load_main_menu。这里不走任何快捷方式，让真实链路把预载画面真正换掉。
	await wait_until(func() -> bool: return main.start_game_button != null, 120, "预载 Start 按钮出现")
	await click_center(main.start_game_button)
	await wait_until(func() -> bool: return main.main_menu != null and main.main_menu.get_parent() != null and main.main_menu.visible, 3000, "点击预载 Start 按钮后主菜单出现")

	# ===== 1. 主菜单 Play 按钮 =====
	var b_play: Control = main.main_menu.get_node_or_null("bPlay")
	check(b_play != null, "主菜单 bPlay 节点存在")
	if b_play != null:
		await click_center(b_play)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "1. 点击 Play 后地图出现")

	# ===== 2. 地图上点关卡旗，弹出关卡弹窗 =====
	await process_frame
	var g_map: GameMapObject = main.g_map
	check(g_map.a_markers.size() > 0, "地图旗帜列表非空")
	var flag: FlashClip = g_map.a_markers[0] if g_map.a_markers.size() > 0 else null
	if flag != null:
		var sens: Control = flag.get_node_or_null("sens")
		check(sens != null, "第 1 面旗帜的 sens 命中区存在")
		if sens != null:
			await click_center(sens)
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "2. 点击关卡旗后弹窗出现")

	# ===== 3. 点 Start Battle，进入第 1 关战斗 =====
	var popup: PopupMissionEx = g_map.pop
	await process_frame
	if popup != null and popup.get_parent() != null:
		check(popup.b_playbtn != null, "弹窗 bPlaybtn 节点存在")
		if popup.b_playbtn != null:
			await click_center(popup.b_playbtn)
	await wait_until(func() -> bool: return main.game_uni != null and main.game_uni.get_parent() != null and main.game_uni.is_inside_tree(), 300, "3. 点击 Start Battle 后进入战斗")
	var gu: GameUniverse = main.game_uni

	# 让战斗稳定运行几帧（关卡开场对话框按原版需要先点掉）。
	for i in 20:
		if gu.is_paused and not gu.is_end_game:
			ChatFrameController.on_stage = false
			gu.unpause()
		gu._physics_process(1.0 / 30.0)
		RWTween.step(1.0 / 30.0)
		await process_frame

	# ===== 4. 招募一个单位：真实点击 HUD 的战士按钮打开子面板，再直接记一个单位（子面板具体选项不在本次输入 bug 范围内）。
	var ui: MainGameUIEx = gu.ingame_ui
	check(ui != null, "战斗 HUD（ingame_ui）存在")
	var money_before: float = gu.current_money
	if ui != null and ui.e1 != null:
		await click_center(ui.e1)
	for i in 10:
		gu._physics_process(1.0 / 30.0)
		RWTween.step(1.0 / 30.0)
		await process_frame
	var recruited: LivingObject = gu.add_soldier(LivingObject.FR_WARRIOR)
	check(recruited != null, "4. 招募一个单位成功")
	for i in 10:
		gu._physics_process(1.0 / 30.0)
		RWTween.step(1.0 / 30.0)
		await process_frame

	# ===== 5. 点击该单位，它被选中 =====
	if recruited != null:
		var screen_pos: Vector2 = recruited.sens.global_position
		await click_at(screen_pos)
	check(recruited != null and recruited.selected, "5. 点击单位后处于选中状态")

	# ===== 6. 点击地面，单位得到移动目的地 =====
	if recruited != null:
		var dest := Vector2(500, 400)
		var route_before: Array = (recruited.a_soldier_main_route as Array).duplicate()
		var pos_before: Vector2 = recruited.position
		await click_at(dest)
		for i in 5:
			gu._physics_process(1.0 / 30.0)
			RWTween.step(1.0 / 30.0)
			await process_frame
		var route_now: Array = recruited.a_soldier_main_route
		var moved: bool = route_now != route_before or recruited.position != pos_before
		check(moved, "6. 点击地面后单位收到移动目的地（路径或位置发生变化）")

	# ===== 7. 点击 HUD 暂停按钮生效 =====
	# ePause 对应 mainGameUI_ex.callControlledPause，翻的是 game_uni.is_controlled_pause
	# （RWTween.pause_all/resume_all），不是 gu.is_paused（那个是关卡对话框用的 pause/unpause）。
	if ui != null and ui.e_pause != null:
		var was_paused: bool = gu.is_controlled_pause
		await click_center(ui.e_pause)
		for i in 5:
			await process_frame
		check(gu.is_controlled_pause != was_paused, "7. 点击暂停按钮后 is_controlled_pause 状态翻转")
		if gu.is_controlled_pause:
			await click_center(ui.e_pause)  # 翻回去，避免影响退出流程
			for i in 5:
				await process_frame

	main.queue_free()
	await process_frame

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
