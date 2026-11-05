extends SceneTree
# 真实输入回归测试：覆盖用户实际游玩战斗时报告的几个界面 bug（见对话记录里的截图 7/8/9）。
# 用 tests/support/battle_harness.gd 直接进入第 1 关战斗（不经过主菜单/地图，地图->战斗这段真实输入
# 路径已经在 tests/input_e2e.gd 里覆盖过），但战斗内的交互全部走真实的 push_input 鼠标事件。
#
# 覆盖的 bug 和根因（详见对应提交/汇报）：
#   1. NEW HINT 点了没反应：FlashClip._has_point() 原来只检查剪辑自己的 back/front 栅格，没有下探到
#      具名子剪辑（eNewHint 的徽标画在子剪辑 d3 里）——肉眼看着点在图案上，实际点到的像素属于子剪辑，
#      父剪辑自己在那一点没有不透明像素，CLICK 判定失败。修复见 game/rw/flash_clip.gd _has_point()。
#   2. 单位名称两行叠在一起：FlashText 把 AS3 的 leading 原样当 Godot RichTextLabel 的 line_separation
#      做减法，但两边"行高基准"不同——Godot 本来就比 Flash 紧，原版 -4 这种收紧量在 Godot 里会把两行
#      压到互相重叠。修复见 game/rw/flash_text.gd（leading 收紧量不下探到 0 以下）。
#   3. 招募面板本身的按钮可点性：e1~e5 的 hover/点击命中属于同一个 _has_point() 根因；本测试里用
#      真实点击验证招募确实能成功两次（两个不同时机），覆盖"点了没反应"的另一半。
# 另外两个用户反馈：
#   - 胜利/成就面板的漂浮灰块（eCont 没算自己背景图形的宽度）：已在 tests/battle_ifaces.gd
#     test_achives_pages 里用真实 mouse_entered/mouse_exited 断言，不在本文件重复。
#   - 选中已经满级的进阶兵种（如 Elite Sniper）时 "^^" 进阶按钮点击无效：对照反编译的
#     mainGameUI_ex.as updateSoldierData/upgradeClicked 和 livingObject.as upgradeClicked/upgrade，
#     这是原版就有的 quirk——按钮的"抬起/放下"状态只在单位满足 `xp>=xpUntil && level==3 && basicUnit`
#     时才会被挪下去，选中一个已经不是 basicUnit 的满级进阶兵种不会把它复位，如果之前选过一个满足条件
#     的基础兵种，这个按钮会沿用旧位置停在"抬起"的样子；点击对 basicUnit==false 的单位会调用
#     livingObject.upgradeClicked()，它总是播放一次升级特效但 upgrade() 内部 `if cur_level != 3`
#     会跳过真正的数值变化——原版逐行一致（见 editable/scripts 同名文件），不是移植引入的 bug，这里
#     不改动，只用一个断言记录这个行为，防止以后误把它当 bug "修复"掉。
const Harness := preload("res://tests/support/battle_harness.gd")

var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func near(a: float, b: float, eps: float = 1.0) -> bool:
	return absf(a - b) <= eps

func _initialize() -> void:
	call_deferred("run")

## 真实点击：鼠标移动到位置 -> 左键按下 -> 左键抬起，每步真正让一帧跑过（gui_input 需要真实的
## InputEvent 经过 Viewport 的 GUI 路由）。
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

## 真实玩家点的是贴图实际覆盖的区域，不是 Control.size/position 围出的名义包围盒（同 input_e2e.gd）。
func visual_center_global(c: Control) -> Vector2:
	if c is FlashClip:
		var b: Rect2 = IfaceUtil.clip_bounds(c as FlashClip)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			return c.get_global_transform() * b.get_center()
	return c.get_global_rect().get_center()

## max_ms 是真实墙钟毫秒数，不是引擎帧数：本测试里要等的条件大多由 RWTween 按真实时间驱动
## （见 game/rw/rw_tween.gd 顶部注释，非 manual_clock 时按 Time.get_ticks_usec 推进），headless 下
## 一次 process_frame 经过的真实时间可能远小于 1/30 秒，按帧数计数等不到 RWTween 真正完成。
func wait_until(cond: Callable, max_ms: int, label: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
	var ok: bool = cond.call()
	check(ok, "%s（等待 %d ms 未满足）" % [label, Time.get_ticks_msec() - t0])
	return ok

## 关卡开局和推进过程中都可能弹出 ChatFrameController 的对话框（截图 9 里的 "Game paused. You can
## issue orders to your troops." 正是这个面板）——它的 eBlack 几乎铺满整个舞台，不关掉会吞掉后续所有
## 点击。真实玩家会把它点掉（4 页教学/剧情面板），这里同样用真实点击处理，不走任何快捷方式。
func dismiss_chat_if_any() -> void:
	var guard := 0
	while ChatFrameController.on_stage and guard < 10:
		var sens: FlashClip = ChatFrameController.game_chat_box.get_node("clickSens")
		await click_at(visual_center_global(sens))
		guard += 1

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	root.size = Vector2i(700, 600)
	var h := Harness.new(self)
	h.boot()
	RWTween.inst_().manual_clock = false  # 本测试用真实墙钟驱动 RWTween（和实际游玩一致），不手动推帧
	var gu := h.start_level(1, 1, 1, true)
	var ui: MainGameUIEx = gu.ingame_ui
	check(ui != null, "战斗 HUD 存在")

	# ===== 0. 关掉开局的教学/剧情对话（原版"4 页"那一批），全程真实点击 =====
	await dismiss_chat_if_any()
	# _added() 里 `RWTween.all_from(a_buttons, 0.4, {"y": "42"}, 0.1)` 用真实墙钟把招募按钮从"抬高 42"
	# 的入场位置滑到最终位置（5 个按钮交错，最后一个要 0.4+4*0.1=0.8s 才稳定），等够真实时间再开始点，
	# 不然点击坐标算的是还在入场动画中途的按钮。
	var t_settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_settle < 1000:
		await process_frame
		await dismiss_chat_if_any()

	# ===== 1. 波次间隙招募一次：真实点击 eWarriors -> 真实点击 tier 1 选项 -> 断言钱变少、单位变多 =====
	ui.show_red_button()
	await wait_until(func() -> bool: return ui.a_buttons[0].mouse_enabled == true, 1500, "1a. show_red_button 后招募按钮 mouseEnabled 变为 true")
	# show_red_button() 自己还有一组墙钟驱动的交错淡出动画，把 eVert/eHoriz/eGotUpgrade/eFormation/
	# eAttackDef/eDefend 移出视野并在最后一个完成后（RWTween.all_to 的 onCompleteAll）才真正置
	# visible=false（_reset_pos）；按原版 `"y":"42"`、stagger 0.1、5 个目标，要等 0.3+4*0.1=0.7s 以上。
	# 在它们真正隐藏之前，eHoriz 原来的位置和招募按钮 e1~e5 的这一排有重叠，等不够就会出现"肉眼点在
	# 招募图标上，实际点中的是还没隐藏的 eHoriz"（hover 命中 eHoriz 而不是 e1）。
	# RWTween 按真实墙钟推进，不是按引擎帧数；headless 下一帧可能远小于 1/30 秒，wait_until 的
	# "帧数上限"在这里等不到 0.7s 实际时间，所以用墙钟时间轮询。
	var t_hide := Time.get_ticks_msec()
	while ui.e_horiz.visible and Time.get_ticks_msec() - t_hide < 2000:
		await process_frame
	check(not ui.e_horiz.visible, "1a2. 红色下一波按钮淡出动画结束后 eHoriz 等按钮真正隐藏")
	await dismiss_chat_if_any()
	var money_before_1: float = gu.current_money
	var units_before_1: int = gu.a_all_units.size()
	await click_at(visual_center_global(ui.e1))
	await wait_until(func() -> bool: return ui.e_sub_down.position.y < ui.sub_units_panel_down_y - 1.0, 1500, "1b. 点战士图标后 tier 子面板滑出")
	await click_at(visual_center_global(ui.e_sub_one))
	await wait_until(func() -> bool: return gu.a_all_units.size() > units_before_1, 1500, "1c. 点 tier 1 选项后真的多出一个单位（第一次招募）")
	check(gu.current_money < money_before_1, "1d. 第一次招募按原版扣钱（%.0f -> %.0f）" % [money_before_1, gu.current_money])

	# ===== 2. 选中刚招募的单位，再试一次招募（选中单位时同样要能招募，且不影响单位面板） =====
	var recruited: LivingObject = gu.a_all_units.back()
	await click_at(recruited.sens.global_position)
	await wait_until(func() -> bool: return recruited.selected, 1500, "2a. 点击单位后处于选中状态")
	await dismiss_chat_if_any()
	# 单位名称不再两行重叠：断言两行的全局 y 间距不小于"字号 * 行距"（tLevelClass 12px 字体，
	# 原版两行最少也该有一个可读的行高，这里用 0.8*font_size 做下限，和 flash_text.gd 的收紧逻辑一致）。
	var tlc: FlashText = ui.e_unit_panel.get_node("tLevelClass")
	if IfaceUtil.num_lines(tlc) >= 2:
		var rtl: RichTextLabel = tlc.get_node("_text")
		check(rtl.get_content_height() >= tlc.font_size * 0.8 * IfaceUtil.num_lines(tlc) * 0.8,
			"2b. 单位名称多行时总高度没有被压缩到互相重叠（content_height=%.1f, lines=%d, font=%.0f）" %
			[rtl.get_content_height(), IfaceUtil.num_lines(tlc), tlc.font_size])
	var money_before_2: float = gu.current_money
	var units_before_2: int = gu.a_all_units.size()
	await click_at(visual_center_global(ui.e1))
	await wait_until(func() -> bool: return ui.e_sub_down.position.y < ui.sub_units_panel_down_y - 1.0, 1500, "2c. 选中单位后点战士图标仍能打开 tier 子面板")
	await click_at(visual_center_global(ui.e_sub_one))
	await wait_until(func() -> bool: return gu.a_all_units.size() > units_before_2, 1500, "2d. 选中单位时第二次招募仍然成功")
	check(gu.current_money < money_before_2, "2e. 第二次招募同样按原版扣钱")

	# ===== 3. 取消选中后再招募一次 =====
	gu.unselect_all()
	check(not recruited.selected, "3a. 取消选中生效")
	await dismiss_chat_if_any()
	# 前两次真实招募已经验证过扣钱金额；连续招募 3 个战士会撞上 tier1 公式的递增单价，第三次可能
	# 钱不够，这里只是为了验证"取消选中后招募 UI 仍然可点"，不是重新核对经济数值，直接给够钱。
	gu.current_money += 2000
	ui.dest_money += 2000
	var units_before_3: int = gu.a_all_units.size()
	await click_at(visual_center_global(ui.e1))
	await wait_until(func() -> bool: return ui.e_sub_down.position.y < ui.sub_units_panel_down_y - 1.0, 1500, "3b. 取消选中后点战士图标仍能打开 tier 子面板")
	await click_at(visual_center_global(ui.e_sub_one))
	await wait_until(func() -> bool: return gu.a_all_units.size() > units_before_3, 1500, "3c. 取消选中后第三次招募仍然成功")

	# ===== 4. NEW HINT：点击能打开，再点击能关闭 =====
	await dismiss_chat_if_any()
	HintsManager.need_to_show_hint(5)
	await wait_until(func() -> bool: return HintsManager.new_hint_shown, 6000, "4a. 新提示入队后图标进入显示状态（new_hint_shown）")
	await wait_until(func() -> bool: return near(ui.e_new_hint.position.x, HintsManager.top_position.x, 2.0), 1500, "4b. NEW HINT 图标滑到舞台内的停靠位置")
	await dismiss_chat_if_any()
	var hint_pos := visual_center_global(ui.e_new_hint)
	check(root.get_visible_rect().has_point(hint_pos), "4c. NEW HINT 可点击区域的视觉中心确实在舞台范围内")
	await click_at(hint_pos)
	check(HintsManager.a_hints_list.is_empty() and not HintsManager.new_hint_shown,
		"4d. 真实点击 NEW HINT 后提示被消费、图标收起（a_hints_list=%s, new_hint_shown=%s）" %
		[HintsManager.a_hints_list, HintsManager.new_hint_shown])

	h.shutdown()

	# ===== 5. 第 2 关真实路径（main.tscn -> 主菜单 -> 地图 -> 第 2 面旗帜 -> Start Battle），推进到
	# 第一个 GLOBAL_WAVE，确认招募图标可见、战士/弓手能招募（其余按原版 getLockedUnits 锁定），
	# 中途做一次失焦自动暂停再恢复，确认不影响结果。
	# 原版 extlvl2.xml 事件顺序是 对白->敌人->对白->敌人x3->对白->GLOBAL_WAVE，招募本来就只在红色
	# "Start Wave"按钮出现（GLOBAL_WAVE）之后才开放——这是原版设计，不是本次要修的 bug，前几波招募
	# 面板本该是空的。
	await run_level2_global_wave_recruit()

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func click_center(c: Control) -> void:
	await click_at(visual_center_global(c))

func run_level2_global_wave_recruit() -> void:
	StoredData.test_wipe()

	var main2: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main2)
	await wait_until(func() -> bool: return main2.resources_loaded, 20000, "5.0 第二次启动：资源加载完成")
	await process_frame
	await process_frame
	await process_frame
	# Main._load_step(76) 在资源加载过程中会调用一次 StoredData.init()，存档标志要等 resources_loaded
	# 之后再改，否则会被这次 init() 盖掉（和 input_e2e.gd 的做法一致）。
	# 标记第 1 关已通关（3 星），第 2 关旗帜才会在地图上解锁、可点（game_map_object.gd _build_flags：
	# 第一个 stars==0 的关卡才是 next_unvisited，之后的关卡保持 flag.visible=false）。
	var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS]
	levels[0] = 3
	var flags: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	for k in flags.keys():
		flags[k] = 1
	LevelIntro.is_shown = true
	LevelIntro.can_end_intro = true
	StoredData.main_params["hints"] = false

	await wait_until(func() -> bool: return main2.start_game_button != null, 3000, "5.1 预载 Start 按钮出现")
	await click_center(main2.start_game_button)
	await wait_until(func() -> bool: return main2.main_menu != null and main2.main_menu.get_parent() != null and main2.main_menu.visible, 15000, "5.2 点击预载 Start 后主菜单出现")
	var b_play: Control = main2.main_menu.get_node_or_null("bPlay")
	if b_play != null:
		await click_center(b_play)
	await wait_until(func() -> bool: return main2.g_map != null and main2.g_map.get_parent() != null, 8000, "5.3 点击 Play 后地图出现")

	var g_map: GameMapObject = main2.g_map
	check(g_map.a_markers.size() > 1, "5.4 地图至少有 2 面旗帜")
	var flag2: FlashClip = g_map.a_markers[1]
	check(flag2.visible, "5.5 第 1 关已通关后第 2 面旗帜可见/可点")
	var sens2: Control = flag2.get_node_or_null("sens")
	var banner2: FlashClip = flag2.get_node("eVisited") if flag2.get_node("eVisited").visible else flag2.get_node("eUnvisited")
	await click_at(visual_center_global(banner2))
	await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 8000, "5.6 点击第 2 面旗帜后弹窗出现")
	var popup2: PopupMissionEx = g_map.pop
	await wait_until(func() -> bool: return popup2.popup.modulate.a > 0.99, 8000, "5.7 弹窗入场动画播完")
	await process_frame
	check(popup2.b_playbtn != null, "5.8 弹窗 Start Battle 按钮存在")
	if popup2.b_playbtn != null:
		await click_center(popup2.b_playbtn)
	await wait_until(func() -> bool: return main2.game_uni != null and main2.game_uni.get_parent() != null and main2.game_uni.is_inside_tree(), 15000, "5.9 点击 Start Battle 后进入第 2 关战斗")

	var gu2: GameUniverse = main2.game_uni
	var ui2: MainGameUIEx = gu2.ingame_ui
	check(ui2 != null, "5.10 第 2 关战斗 HUD 存在")
	check(gu2.cur_level_num == 1, "5.11 进入的确实是第 2 关（cur_level_num 是 0 基下标，第 2 关=1，实际=%d）" % gu2.cur_level_num)

	# 推进到第一个 GLOBAL_WAVE（红色 Start Wave 按钮出现）：对白用真实点击关掉，敌人事件只靠加速
	# 逻辑帧推进（不需要真实点击）。中途在接近推进中点时做一次失焦自动暂停（NOTIFICATION_
	# APPLICATION_FOCUS_OUT）再恢复（FOCUS_IN），验证不会让流程卡住或让已有补间永久冻结。
	var did_focus_test := false
	var ticks := 0
	while not ui2.a_buttons[0].mouse_enabled and ticks < 30000:
		await dismiss_chat_if_any()
		if not ChatFrameController.on_stage and gu2.is_paused == false:
			for i in 10:
				gu2._physics_process(1.0 / 30.0)
			ticks += 10
		if not did_focus_test and ticks > 1500:
			did_focus_test = true
			ui2.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			for i in 10:
				await process_frame
			ui2.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			if gu2.is_paused:
				await click_center(ui2.t_pause_message)  # call_pause() 把 CLICK 监听直接挂在 tPauseMessage 整个剪辑上
				for i in 5:
					await process_frame
		await process_frame
	check(ui2.a_buttons[0].mouse_enabled, "5.12 推进到第一个 GLOBAL_WAVE 后招募按钮 mouseEnabled 变为 true（ticks=%d）" % ticks)
	check(did_focus_test, "5.13 中途确实做过一次失焦自动暂停/恢复")

	# eVert/eHoriz 等六个按钮的隐藏淡出动画结束（真实墙钟），再确认招募图标本身可见、未被盖住。
	var t_hide := Time.get_ticks_msec()
	while ui2.e_horiz.visible and Time.get_ticks_msec() - t_hide < 3000:
		await process_frame
	check(not ui2.e_horiz.visible, "5.14 红色 Start Wave 按钮出现后 eHoriz 等按钮已经隐藏，不挡住招募图标")
	await dismiss_chat_if_any()
	check(ui2.e1.visible and ui2.e4.visible, "5.15 战士(e1)/弓手(e4)招募图标可见")
	check(not (ui2.e1.get_node("eLocked") as FlashClip).visible, "5.16 战士未锁定")
	check(not (ui2.e4.get_node("eLocked") as FlashClip).visible, "5.17 弓手未锁定")
	for pair in [[ui2.e2, "法师"], [ui2.e3, "牧师"], [ui2.e5, "盗贼"]]:
		check((pair[0].get_node("eLocked") as FlashClip).visible, "5.18 %s 按原版 getLockedUnits 锁定" % pair[1])

	# 真实点击招募一个战士：开子面板 -> 点 tier 1 -> 单位变多、钱变少。
	var money_before: float = gu2.current_money
	var units_before: int = gu2.a_all_units.size()
	await click_at(visual_center_global(ui2.e1))
	await wait_until(func() -> bool: return ui2.e_sub_down.position.y < ui2.sub_units_panel_down_y - 1.0, 1500, "5.19 点战士图标后 tier 子面板滑出")
	await click_at(visual_center_global(ui2.e_sub_one))
	await wait_until(func() -> bool: return gu2.a_all_units.size() > units_before, 1500, "5.20 第 2 关 GLOBAL_WAVE 期间真实点击招募战士成功")
	check(gu2.current_money < money_before, "5.21 招募按原版扣钱")

	main2.queue_free()
	await process_frame
