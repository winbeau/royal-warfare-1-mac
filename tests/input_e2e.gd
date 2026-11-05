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

## 只移动鼠标，不点击：用于单独验证 rollOver（原版 buttonClass.addButtonFull 的第一个回调）有没有被
## 触发，不依赖随后的点击是否生效。
func move_to(pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	root.push_input(mm)
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
	StoredData.main_params["hints"] = false  # 关掉战内教学幻灯片（startTutorialMC），它和本次要测的输入路径无关，只会挡住后续点击

	# 预载画面的 Start 按钮：真实点击（不是进入地图前要验证的 7 步之一，但同样走真实输入路径，
	# 也是用户反馈"进入游戏后点击没反应"最早可能发生的地方）。点击后走完整的原版链路：
	# startClicked -> 0.9 秒后 show_intro（maxgLogoIntro，546 帧 / 30fps≈18 秒）-> done -> max_done
	# -> 0.2 秒后 load_main_menu。这里不走任何快捷方式，让真实链路把预载画面真正换掉。
	await wait_until(func() -> bool: return main.start_game_button != null, 120, "预载 Start 按钮出现")
	await click_center(main.start_game_button)
	await wait_until(func() -> bool: return main.main_menu != null and main.main_menu.get_parent() != null and main.main_menu.visible, 3000, "点击预载 Start 按钮后主菜单出现")

	# ===== 1. 主菜单 Play 按钮：先悬停确认命中的真的是 bPlay（不是被别的层挡住），再点 =====
	var b_play: Control = main.main_menu.get_node_or_null("bPlay")
	check(b_play != null, "主菜单 bPlay 节点存在")
	if b_play != null:
		await move_to(visual_center_global(b_play))
		var hovered1: Control = root.gui_get_hovered_control()
		check(hovered1 != null and (hovered1 == b_play or b_play.is_ancestor_of(hovered1)), "1a. 悬停在 bPlay 图案中心时命中的是 bPlay（实际命中 %s）" % _describe_hover())
		await click_center(b_play)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "1b. 点击 Play 后地图出现")

	# ===== 2. 地图上悬停/点关卡旗：用旗帜贴图的可见中心（不是 sens 节点 Control.size 的几何中心——
	# 两者并不总是重合，真实玩家是对着画出来的旗子点，不是对着 sens 这个隐藏节点的包围盒点），验证
	# rollOver 效果（buttonClass.addButtonFull 的 bannerRover：旗帜放大 + 关卡名淡入）先触发，
	# 再点击弹出关卡弹窗 =====
	await process_frame
	var g_map: GameMapObject = main.g_map
	check(g_map.a_markers.size() > 0, "地图旗帜列表非空")
	var flag: FlashClip = g_map.a_markers[0] if g_map.a_markers.size() > 0 else null
	if flag != null:
		var sens: Control = flag.get_node_or_null("sens")
		check(sens != null, "第 1 面旗帜的 sens 命中区存在")
		var banner: FlashClip = flag.get_node("eVisited") if flag.get_node("eVisited").visible else flag.get_node("eUnvisited")
		var banner_pos := visual_center_global(banner)
		var scale_before: Vector2 = banner.scale
		var name_alpha_before: float = (flag.get_node("tLevelName") as FlashText).modulate.a
		await move_to(banner_pos)
		var hovered2: Control = root.gui_get_hovered_control()
		check(sens != null and hovered2 == sens, "2a. 悬停在旗帜图案中心时命中的是 sens（实际命中 %s）" % _describe_hover())
		await wait_until(func() -> bool: return banner.scale != scale_before, 60, "2b. 悬停旗帜图案中心触发 bannerRover（旗帜放大）")
		check((flag.get_node("tLevelName") as FlashText).modulate.a > name_alpha_before, "2c. 悬停旗帜图案中心后关卡名淡入（bannerRover 的另一半效果）")
		await click_at(banner_pos)
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "2d. 点击旗帜图案中心后弹窗出现")

	# ===== (a) 关闭弹窗（点 X），再悬停/点击同一面旗帜 =====
	# 先等弹窗入场动画（RWTween.from(popup, 0.3, {"y":"-300","alpha":0})）真正结束再点 X：弹窗刚弹出的
	# 那一瞬间 bClosebtn 的全局坐标还在跟着入场动画变化，这时点击算出来的"图案中心"是动画中途的位置，
	# 不代表真实玩家会点的地方（真实玩家一般也不会在入场动画还没播完时去点关闭）。
	var popup_a: PopupMissionEx = g_map.pop
	await wait_until(func() -> bool: return popup_a != null and popup_a.popup.modulate.a > 0.99, 300, "(a) 弹窗入场动画播完")
	await process_frame
	if popup_a != null and popup_a.b_closebtn != null:
		await click_center(popup_a.b_closebtn)
		await wait_until(func() -> bool: return popup_a.get_parent() == null, 300, "(a) 点 X 后弹窗从树上移除")
	await process_frame
	await process_frame
	var vis_a: FlashClip = flag.get_node("eVisited") if flag.get_node("eVisited").visible else flag.get_node("eUnvisited")
	var pos_a: Vector2 = visual_center_global(vis_a)
	var scale_before_a: Vector2 = vis_a.scale
	await move_to(pos_a)
	check(root.gui_get_hovered_control() == flag.get_node("sens"), "(a) 关闭弹窗后再次悬停旗帜图案中心命中 sens（实际命中 %s）" % _describe_hover())
	await wait_until(func() -> bool: return vis_a.scale != scale_before_a, 60, "(a) 关闭弹窗后再次悬停旗帜仍触发 rollover")
	await click_at(pos_a)
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "(a) 关闭弹窗后再次点击旗帜仍弹出弹窗")

	# ===== (b) 地图 -> Upgrades -> Back to Map -> 点旗帜（刻意不先关上面弹窗就离开，覆盖"弹窗开着时
	# 跳到别的面板"这条路——game_map_object.gd._removed() 原来不会把仍挂着的单例 pop 摘下来，回地图后
	# 再点旗帜，banner_clicked 会把已经挂在树上的 pop 再 add_child 一次而报错，之后旗帜再也点不开）=====
	var markers_b: FlashClip = GameMapObject.markers
	await click_center(markers_b.get_node("bUpgrades"))
	await wait_until(func() -> bool: return main.upgrade_panel != null and main.upgrade_panel.get_parent() != null, 300, "(b) 点 Upgrades 后升级面板出现")
	var up: UpgrPanelEx = main.upgrade_panel
	await process_frame
	await process_frame
	if up != null and up.get("b_next") != null:
		await click_center(up.b_next)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "(b) 点 Back to Map 后地图重新出现")
	await process_frame
	await process_frame
	var vis_b: FlashClip = flag.get_node("eVisited") if flag.get_node("eVisited").visible else flag.get_node("eUnvisited")
	var pos_b: Vector2 = visual_center_global(vis_b)
	var scale_before_b: Vector2 = vis_b.scale
	await move_to(pos_b)
	check(root.gui_get_hovered_control() == flag.get_node("sens"), "(b) 从升级面板返回地图后悬停旗帜图案中心命中 sens（实际命中 %s）" % _describe_hover())
	await wait_until(func() -> bool: return vis_b.scale != scale_before_b, 60, "(b) 从升级面板返回地图后悬停旗帜仍触发 rollover")
	await click_at(pos_b)
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "(b) 从升级面板返回地图后点击旗帜仍弹出弹窗")

	# ===== (c) 地图 -> Menu -> 主菜单 Play -> 地图 -> 点旗帜 =====
	var markers_c: FlashClip = GameMapObject.markers
	await click_center(markers_c.get_node("bMenu"))
	await wait_until(func() -> bool: return main.main_menu != null and main.main_menu.get_parent() != null, 300, "(c) 点 Menu 后主菜单出现")
	var b_play_c: Control = main.main_menu.get_node_or_null("bPlay")
	if b_play_c != null:
		await click_center(b_play_c)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "(c) 点 Play 后地图重新出现")
	await process_frame
	await process_frame
	var vis_c: FlashClip = flag.get_node("eVisited") if flag.get_node("eVisited").visible else flag.get_node("eUnvisited")
	var pos_c: Vector2 = visual_center_global(vis_c)
	var scale_before_c: Vector2 = vis_c.scale
	await move_to(pos_c)
	check(root.gui_get_hovered_control() == flag.get_node("sens"), "(c) 从主菜单返回地图后悬停旗帜图案中心命中 sens（实际命中 %s）" % _describe_hover())
	await wait_until(func() -> bool: return vis_c.scale != scale_before_c, 60, "(c) 从主菜单返回地图后悬停旗帜仍触发 rollover")
	await click_at(pos_c)
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "(c) 从主菜单返回地图后点击旗帜仍弹出弹窗")

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
	# 注意：a_buttons（e1/e4/e3/e2/e5）的 mouseEnabled 本来就随 showRedButton/hideRedButton 切换
	# （原版 mainGameUI_ex.as 的 hideRedButton 同样把 aButtons 全部 mouseEnabled=false，关卡一开始
	# 就调用 hideRedButton，和这里一致），不是本次命中规则要修的东西，所以悬停检查放在下面始终
	# mouseEnabled 的 ePause 按钮上（4a），而不是这里的 e1。
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
		await move_to(visual_center_global(ui.e_pause))
		var hovered7: Control = root.gui_get_hovered_control()
		check(hovered7 != null and (hovered7 == ui.e_pause or ui.e_pause.is_ancestor_of(hovered7)), "7a. 悬停在战斗 HUD ePause 图案中心时命中的是 ePause（实际命中 %s）" % _describe_hover())
		var was_paused: bool = gu.is_controlled_pause
		await click_center(ui.e_pause)
		for i in 5:
			await process_frame
		check(gu.is_controlled_pause != was_paused, "7. 点击暂停按钮后 is_controlled_pause 状态翻转")
		if gu.is_controlled_pause:
			await click_center(ui.e_pause)  # 翻回去，避免影响退出流程
			for i in 5:
				await process_frame

	# ===== (d) 用测试方式直接触发失败面板（真实的 end_game -> 2 秒延时 -> 加面板流程，不跳过延时），
	# 点面板的"地图"按钮回地图，再点旗帜。end_game 内部的延时是 RWTween 按真实墙钟驱动的
	# delayed_call(2.0, ...)，不是按引擎帧数算的，这里等待帧数要给够（headless 下引擎 tick 可能比墙钟快
	# 很多，不能直接拿"帧数 ≈ 帧数/30 秒"换算）=====
	gu.end_game(GameUniverse.DEFEAT)
	await wait_until(func() -> bool: return gu.def_panel != null and gu.def_panel.get_parent() != null, 600, "(d) end_game(DEFEAT) 后失败面板出现")
	var dp: DefeatPanelEx = gu.def_panel
	await process_frame
	await process_frame
	if dp != null and dp.b_map != null:
		await click_center(dp.b_map)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 600, "(d) 点失败面板地图按钮后回到地图")
	await process_frame
	await process_frame
	var flag_d: FlashClip = g_map.a_markers[0]
	var vis_d: FlashClip = flag_d.get_node("eVisited") if flag_d.get_node("eVisited").visible else flag_d.get_node("eUnvisited")
	var pos_d: Vector2 = visual_center_global(vis_d)
	var scale_before_d: Vector2 = vis_d.scale
	await move_to(pos_d)
	check(root.gui_get_hovered_control() == flag_d.get_node("sens"), "(d) 从失败面板回地图后悬停旗帜图案中心命中 sens（实际命中 %s）" % _describe_hover())
	await wait_until(func() -> bool: return vis_d.scale != scale_before_d, 60, "(d) 从失败面板回地图后悬停旗帜仍触发 rollover")
	await click_at(pos_d)
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "(d) 从失败面板回地图后点击旗帜仍弹出弹窗")

	main.queue_free()
	await process_frame

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
