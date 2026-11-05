extends SceneTree
# UpgrPanelEx（升级面板）与三个存档弹窗。
# 运行：Godot --headless --path . --script tests/upgrade_panel.gd -- --isolated-profile
# 覆盖：给定存档下的星数计算；解锁兵种/技能加点写回 StoredData；星数不足时点击不生效；
# 重置后星数全部归还；技能描述文本取自技能类（SpecXxx.special_description / cur_level_params）。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame

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

	test_star_math()
	await test_unlock_and_ability_writes()
	await test_not_enough_stars()
	await test_reset_returns_stars()
	await test_ability_description()
	await test_zanaves_mask()
	await test_help_hint_click_closes()

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


## 幕布遮罩：initOnce 对五个 zanavesX 执行 getChildAt(0).mask = msk；动画移动的是 getChildAt(0)（e0），不是幕布本身。
func test_zanaves_mask() -> void:
	StoredData.reset_data()
	var panel := UpgrPanelEx.create()
	panel.init_once()
	root.add_child(panel)
	await settle()
	for z: FlashClip in [panel.zanaves_warriors, panel.zanaves_archers, panel.zanaves_priests, panel.zanaves_mages, panel.zanaves_thieves]:
		var msk := z.get_node_or_null("msk") as Control
		check(msk != null and msk.clip_contents, "%s.msk 已接成遮罩（clip_contents）" % z.name)
		var e0 := UpgrPanelEx.zanaves_child(z)
		check(e0 != null and e0.get_parent() == msk, "%s.getChildAt(0) 导出为 e0 并挂在 msk 下" % z.name)
		check(z.get_node_or_null("e0") == null, "%s 本身不再承载动画子图形" % z.name)
	# 全新存档：战士幕布未看过，added() 把 e0.y 置 0，1 秒（0.6 延迟 + 1 秒补间）后升到 -height，幕布节点本身不动
	var z := panel.zanaves_warriors
	var zy := z.position.y
	var e0 := UpgrPanelEx.zanaves_child(z)
	var h := IfaceUtil.clip_bounds(e0).size.y
	check(h > 100.0, "e0.height 取自子图形自身 (got %f)" % h)
	check(is_equal_approx(e0.position.y, 0.0), "added() 后 e0.y == 0 (got %f)" % e0.position.y)
	RWTween.step(0.6 + 1.0 + 0.05)
	check(is_equal_approx(e0.position.y, -h), "补间结束 e0.y == -height (got %f vs %f)" % [e0.position.y, -h])
	check(is_equal_approx(z.position.y, zy), "幕布节点位置不变")
	RWTween.kill_all()
	root.remove_child(panel)
	panel.free()


## 点击"?"显示提示；点击提示面板（原版 eHint 的点击监听，这里用真实鼠标事件，不直接调用 hide_hint）应关闭。
## 覆盖此前的 bug：eHint 内 4 个说明面板原是未命名子图形，aHintCoords 收集为空数组，hideHint 的 for 循环
## 什么也不做，点击后无法关闭（见 pipeline/ClipExporter.java 的 INDEXED_CHILD_IDS 625 注释）。
func test_help_hint_click_closes() -> void:
	StoredData.reset_data()
	var panel := UpgrPanelEx.create()
	root.add_child(panel)
	root.size = Vector2(700, 600)
	await settle()
	check(not panel.e_hint.visible, "初始不显示帮助提示")
	await click_at(panel.b_help.get_global_transform() * IfaceUtil.clip_bounds(panel.b_help).get_center())
	check(panel.e_hint.visible, "点击 ? 后显示帮助提示")
	check(panel.a_hint_coords.size() == 4, "aHintCoords 收集到 4 个说明面板（不再是空数组）")
	# 点在其中一个说明面板的可见像素上（取各面板自身包围盒中心，不是整个 eHint 的包围盒）
	var el: FlashClip = panel.a_hint_coords[0][0]
	await click_at(el.get_global_transform() * IfaceUtil.clip_bounds(el).get_center())
	RWTween.step(0.35)  # hideHint 的 TweenMax.to(...0.3...) 用墙钟驱动；紧跟着立刻断言，
	# 避免真实帧的 _process 用很小的墙钟增量覆盖 step() 推进的 root_time
	check(not panel.e_hint.visible, "点击说明面板后帮助提示关闭")
	root.remove_child(panel)
	panel.free()


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


## 1. 给定存档下的星数计算（StoredData.get_num_gained/busy/free_stars 与面板读到的 num_free_stars 一致）。
func test_star_math() -> void:
	StoredData.reset_data()
	var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS]
	StoredData._splice1(levels, 0, 3)
	StoredData._splice1(levels, 1, 2)
	StoredData._splice1(StoredData.local_game_data, StoredData.NUMPAN_LEVELS, levels.duplicate())
	var achives: Array = StoredData.local_game_data[StoredData.NUMPAN_ACHIVES]
	StoredData._splice1(achives, 0, 1)
	StoredData._splice1(StoredData.local_game_data, StoredData.NUMPAN_ACHIVES, achives.duplicate())
	# 2 技能 + 1 奖励已占用
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": StoredData.A_BLOCK})
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": StoredData.A_STUN})
	StoredData.save_data(StoredData.COM_SAVE_BONUS, {"abilNumber": 0})

	check(StoredData.get_num_gained_stars() == 6, "gained = 3+2(关卡)+1(成就) = 6 (got %d)" % StoredData.get_num_gained_stars())
	check(StoredData.get_num_busy_stars() == 3, "busy = 2(技能)+1(奖励) = 3 (got %d)" % StoredData.get_num_busy_stars())
	check(StoredData.get_num_free_stars() == 3, "free = gained-busy = 3 (got %d)" % StoredData.get_num_free_stars())

	var panel := UpgrPanelEx.create()
	root.add_child(panel)
	await settle()
	check(panel.num_free_stars == 3, "面板初始化读到的 numFreeStars == 3 (got %d)" % panel.num_free_stars)
	check(panel.t_free_stars.text == "3", "tFreeStars 文本显示 3 (got %s)" % panel.t_free_stars.text)
	root.remove_child(panel)
	panel.free()


## 2. 解锁兵种 + 技能/奖励加点点击后写回 StoredData 的值（COM_SAVE_ABIL / COM_SAVE_BONUS 的 _add_counter，
##    以及三级兵种自动解锁 locked_unit_unlocked 写 COM_SAVE_UNIT）。
func test_unlock_and_ability_writes() -> void:
	StoredData.reset_data()
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": StoredData.A_STUN})  # 预先给 5 颗可用星
	for i in 4:
		var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS]
		StoredData._splice1(levels, i, 3)
		StoredData._splice1(StoredData.local_game_data, StoredData.NUMPAN_LEVELS, levels.duplicate())

	var panel := UpgrPanelEx.create()
	root.add_child(panel)
	await settle()

	# uWarWarriorB -> A_STUN，已有 1 级，再点一次应变成 2 级，星数减 1
	var free_before := panel.num_free_stars
	var e := ButtonClass.ButtonEvent.new()
	e.target = panel.u_war_warrior_b
	panel.ability_clicked(e)
	check(int(StoredData._geti(StoredData.local_game_data[StoredData.NUMPAN_ABILS], StoredData.A_STUN)) == 2,
		"uWarWarriorB 点击一次后 abils[A_STUN] == 2")
	check(panel.num_free_stars == free_before - 1, "点击技能加点后 numFreeStars 减 1")
	check(panel.u_war_warrior_b.child_clip("eLock").current_frame == 4, "eLock 帧号随等级前进（1级->2级 = 第4帧）")

	# 星级进度图标（eLock 的内部 3 颗同名 "eStar"）：原版每颗星靠滤镜区分暗/亮（锁定/未点亮只有发光，
	# 点亮后发光+斜角），管线之前只把其中一颗追踪成活动子节点、永远冻结成创建时（暗）的贴图，导致
	# "第一颗星永远不亮"；现在三颗星都按帧栅格化。断言 1/2/3 级对应三张不同纹理（每级新点亮一颗）。
	var lock := panel.u_war_warrior_b.child_clip("eLock")
	var tex_by_level := {}
	for lvl in [1, 2, 3]:
		lock.goto_and_stop(lvl + 2)
		await settle(1)
		tex_by_level[lvl] = lock.back_texture()
		check(tex_by_level[lvl] != null, "等级 %d 的 eLock 有纹理" % lvl)
	check(tex_by_level[1] != tex_by_level[2] and tex_by_level[2] != tex_by_level[3] and tex_by_level[1] != tex_by_level[3],
		"1/2/3 级（1/2/3 颗星点亮）各自对应不同纹理，不再冻结成同一张")

	# uWarriorsAttack（奖励加点，下标 0）：从 0 级解锁到 1 级
	var e2 := ButtonClass.ButtonEvent.new()
	e2.target = panel.u_warriors_attack
	panel.ability_clicked(e2)
	check(int(StoredData._geti(StoredData.local_game_data[StoredData.NUMPAN_UNIT_BONUSES], 0)) == 1,
		"uWarriorsAttack 点击一次后 unitBonuses[0] == 1")

	# 三级兵种自动解锁：locked_unit_unlocked 写 COM_SAVE_UNIT
	panel.locked_unit_unlocked(panel.u_war_knight_unit)
	check(int(StoredData._geti(StoredData.local_game_data[StoredData.NUMPAN_UNITS], StoredData.U_KNIGHT)) == 1,
		"locked_unit_unlocked(uWarKnightUnit) 写 units[U_KNIGHT] == 1")
	check(panel.u_war_knight_unit.child_clip("eLock").current_frame == 2, "骑士解锁后 eLock 停在第 2 帧（解锁态）")

	root.remove_child(panel)
	panel.free()


## 3. 星数不足时点击不生效（原版 notEnoughStars，不消耗星数、不推进 eLock 帧号）。
func test_not_enough_stars() -> void:
	StoredData.reset_data()  # 全新存档：0 颗星
	var panel := UpgrPanelEx.create()
	root.add_child(panel)
	await settle()
	check(panel.num_free_stars == 0, "全新存档没有可用星（got %d）" % panel.num_free_stars)

	var lock := panel.u_war_warrior_a.child_clip("eLock")
	var frame_before := lock.current_frame
	var e := ButtonClass.ButtonEvent.new()
	e.target = panel.u_war_warrior_a
	panel.ability_clicked(e)
	check(lock.current_frame == frame_before, "星数不足时点击不推进 eLock 帧号")
	check(int(StoredData._geti(StoredData.local_game_data[StoredData.NUMPAN_ABILS], StoredData.A_BLOCK)) == 0,
		"星数不足时不写入 abils[A_BLOCK]")
	check(panel.t_hint_text.text.begins_with("Can't upgrage ability"), "提示文本变成 not_enough_stars 的那句")

	root.remove_child(panel)
	panel.free()


## 4. 重置（COM_RESET_ABILITIES）后已占用的星数全部归还，free == gained。
func test_reset_returns_stars() -> void:
	StoredData.reset_data()
	var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS]
	StoredData._splice1(levels, 0, 3)
	StoredData._splice1(StoredData.local_game_data, StoredData.NUMPAN_LEVELS, levels.duplicate())
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": StoredData.A_STUN})
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": StoredData.A_STUN})
	StoredData.save_data(StoredData.COM_SAVE_BONUS, {"abilNumber": 2})
	check(StoredData.get_num_busy_stars() == 3, "重置前占用 3 颗星（got %d）" % StoredData.get_num_busy_stars())

	StoredData.save_data(StoredData.COM_RESET_ABILITIES, null)  # bReset 按钮触发的存档操作
	check(StoredData.get_num_busy_stars() == 0, "重置后占用归零")
	check(StoredData.get_num_free_stars() == StoredData.get_num_gained_stars(),
		"重置后 free == gained（全部星数归还，got free=%d gained=%d）" % [StoredData.get_num_free_stars(), StoredData.get_num_gained_stars()])

	# 面板重新打开后也应读到归还后的星数
	var panel := UpgrPanelEx.create()
	root.add_child(panel)
	await settle()
	check(panel.num_free_stars == StoredData.get_num_gained_stars(), "面板重开后 numFreeStars 读到归还后的值")
	check(panel.u_war_knight_b.child_clip("eLock").current_frame == 1, "重置后技能加点面板回到锁定状态（第 1 帧）")
	root.remove_child(panel)
	panel.free()


## 5. 悬停技能加点按钮时，提示文本取自对应技能类的 special_description + cur_level_params()。
func test_ability_description() -> void:
	StoredData.reset_data()
	var panel := UpgrPanelEx.create()
	root.add_child(panel)
	await settle()

	var spec := SpecStun.new(true)  # uWarWarriorB -> A_STUN，未解锁（cur_spec_level 走 is_locked 分支）
	panel.icon_rovered(null, panel.u_war_warrior_b)
	var expected := spec.special_description + "<font size='4'><br></font>" + spec.cur_level_params()
	check(panel.t_hint_text.html_text == expected,
		"uWarWarriorB 的提示文本等于 SpecStun 的 special_description + cur_level_params()\n got=%s\n want=%s" % [panel.t_hint_text.html_text, expected])
	check(panel.t_hint_text.text.find("Stun") >= 0, "提示文本包含技能名 Stun")
	check(panel.t_hint_text.text.find("Ability locked") >= 0, "未解锁时 curLevelParams 提示 Ability locked")

	# 解锁一级后重新悬停，提示文本应变化（不再是"未解锁"）
	StoredData.save_data(StoredData.COM_SAVE_ABIL, {"abilNumber": StoredData.A_STUN})
	panel.icon_rovered(null, panel.u_war_warrior_b)
	check(panel.t_hint_text.text.find("Cooldown") >= 0, "解锁一级后提示文本变成含 Cooldown 的技能参数")

	root.remove_child(panel)
	panel.free()
