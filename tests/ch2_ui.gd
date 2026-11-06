extends SceneTree
# WP-D2：第二章三格界面、升级面板第二页、dev 版存档。真实输入（push_input）参照 tests/ch2_flow.gd。
# 运行（必须带 --ch2-dev，用它代替 OS.has_feature("dev")，开头检查 dev 版初始化）：
#   Godot --headless --path . --script tests/ch2_ui.gd -- --isolated-profile --ch2-dev
# 二章单位类（D1）尚未落地时，招募 / 换武器的部分自动跳过并打印 SKIP。
const Harness := preload("res://tests/support/battle_harness.gd")

var checks := 0
var failures: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
		print("FAIL ", message)


func _initialize() -> void:
	call_deferred("run")


func settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame


func click_at(pos: Vector2, shift: bool = false) -> void:
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
	down.shift_pressed = shift
	root.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.shift_pressed = shift
	root.push_input(up)
	await process_frame
	await process_frame


## 对 FlashClip（贴图常相对 Control.size/position 有偏移，见 tests/ch2_flow.gd 的 visual_center_global）
## 点实际贴图覆盖的区域；普通 Control（本页自建的宫格热区）点几何中心即可。
func click_control(c: Control, shift: bool = false) -> void:
	var target := c.get_global_rect().get_center()
	if c is FlashClip:
		var b: Rect2 = IfaceUtil.clip_bounds(c as FlashClip)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			target = c.get_global_transform() * b.get_center()
	await click_at(target, shift)


func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	root.size = Vector2i(700, 600)   # 和其余真实输入测试一致：舞台固定 700x600
	test_dev_init()
	StoredData.dev = false   # 以下按正式版存档检查
	await test_upgrade_page()
	await test_battle_ui()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------- dev 版

func test_dev_init() -> void:
	check(StoredData.dev, "带 --ch2-dev 运行时 StoredData.dev 为真")
	check(StoredData.save_path.ends_with("RoyalDefenderGame7_dev.json"), "dev 存档文件名带 _dev：%s" % StoredData.save_path)
	StoredData.test_wipe()
	StoredData.init()
	var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS]
	var sum := 0
	for v in levels:
		sum += int(v)
	check(levels.size() == 24 and sum == 72, "dev：一代 24 关全 3 星（72）")
	for idx in [StoredData.NUMPAN_LEVELS_MIDDIF, StoredData.NUMPAN_LEVELS_HIGHDIF]:
		check(int((StoredData.local_game_data[idx] as Array).count(3)) == 24, "dev：另两个难度也是 24 关全 3 星")
	var ach: Array = StoredData.local_game_data[StoredData.NUMPAN_ACHIVES]
	check(ach.size() == 48 and ach.count(1) == 48, "dev：48 个成就全部获得")
	check(StoredData.get_num_gained_stars() == 120, "dev：一代合计 120 星（%d）" % StoredData.get_num_gained_stars())
	check(StoredData.end_game_flag is Dictionary and bool((StoredData.end_game_flag as Dictionary).get("completed", false)), "dev：end_game_flag 已完成")
	check((StoredData.local_game_data[StoredData.NUMPAN_ABILS] as Array).count(1) == 41, "dev：一代技能全部 1 级")
	var all_unlocked := true
	for n in range(1, 37):
		all_unlocked = all_unlocked and StoredData.ch2_level_unlocked(n)
	check(all_unlocked, "dev：二章 36 关旗帜全部可点")
	for w in Ch2UiData.AVAILABLE_WEAPONS:
		check(StoredData.ch2_weapon_unlocked(w), "dev：武器 %s 已解锁" % w)
	for sk in StoredData.CH2_SKILLS:
		check(StoredData.ch2_skill_level(sk) == 1, "dev：技能 %s 1 级" % sk)
	check(StoredData.ch2_class_open("warden") and StoredData.ch2_class_open("musketeer"), "dev：镇戍卫与火铳卫已开放")
	check(StoredData.ch2_stars_free() == 0, "dev：授予的武器不占星（free=%d）" % StoredData.ch2_stars_free())


# ---------------------------------------------------------------- 升级面板第二页

func test_upgrade_page() -> void:
	StoredData.test_wipe()
	StoredData.init()
	check(not StoredData.ch2_level_unlocked(2), "正式版：第 2 关未解锁")
	check(StoredData.ch2_skill_level("hold_fast") == 1, "技能默认 1 级")
	check(not StoredData.ch2_weapon_unlocked("great_glaive") and StoredData.ch2_weapon_unlocked("dao_shield"), "正式版：高级武器默认未解锁，基础武器可用")
	for n in [1, 2, 3]:
		StoredData.ch2_record_victory(n, 3, 1)
	StoredData.save_shared_data()
	check(StoredData.ch2_stars_free() == 9, "二章挣 9 星（%d）" % StoredData.ch2_stars_free())
	GameUniverse.init_once()
	if SoundLibrary.inst == null:
		SoundLibrary.new().init()
	if Sounds.inst == null:
		root.get_node("SoundSystem").init_sounds_first(StoredData.main_params)
	if Main.inst == null:
		Main.new()
	var ch1_free := StoredData.get_num_free_stars()

	# 一代进入：没有开放二章，面板里不出现翻页器
	Main.inst.current_chapter = 1
	var p1 := UpgrPanelEx.create()
	p1.init_once()
	root.add_child(p1)
	await settle()
	check(p1.ch2_page == null, "二章未开放时一代面板没有第二页入口")
	root.remove_child(p1)
	p1.free()

	# 从二章进入：默认第二页
	Main.inst.current_chapter = 2
	var panel := UpgrPanelEx.create()
	panel.init_once()
	root.add_child(panel)
	await settle()
	var pg: Ch2UpgradePage = panel.ch2_page
	check(pg != null and pg.page == 2, "从二章进入默认第二页")
	if pg == null:
		return
	check(panel.t_free_stars.text == "9", "第二页复用一代的星数字段显示二章星数：%s" % panel.t_free_stars.text)
	check(panel.num_free_stars == ch1_free, "第一页自己的星数记录不受二章影响（%d）" % panel.num_free_stars)
	check(panel.u_war_sword_a.visible, "第一页节点不隐藏，只是被我们叠的内容盖住")
	check(pg.overlay.visible, "第二页时叠加层可见")

	# 给基础技能 hold_fast 加点（镇戍卫基础技能 1，复用一代 u_war_warrior_a 的 eLock）
	var pad: Control = pg._skill_pads["hold_fast"]["hit"]
	var lock_hold_fast: FlashClip = panel.u_war_warrior_a.child_clip("eLock")
	await click_control(pad)
	check(StoredData.ch2_skill_level("hold_fast") == 2, "点击技能加点后 hold_fast 为 2 级")
	check(int(StoredData.shared_data["ch2"]["skills"]["hold_fast"]) == 2, "加点写入存档的 ch2.skills")
	check(StoredData.ch2_stars_free() == 8 and panel.t_free_stars.text == "8", "加点花 1 颗二章星")
	check(StoredData.get_num_free_stars() == ch1_free, "加点不花一代的星")
	check(lock_hold_fast.current_frame == 4, "一代 u_war_warrior_a 自带的 eLock 显示 2 级角标（帧 4）")
	await click_control(pad, true)
	check(StoredData.ch2_skill_level("hold_fast") == 1 and StoredData.ch2_stars_free() == 9, "Shift 点击降级并退星")
	await click_control(pad, true)
	check(StoredData.ch2_skill_level("hold_fast") == 1, "已是 1 级时 Shift 降级无效")

	# 未解锁武器的升级技能不能加点；解锁要 1 星。五雷的升级技能 Scattershot 继承 Rending Shot（第 3 行）。
	var pad2: Control = pg._skill_pads["scattershot"]["hit"]
	await click_control(pad2)
	check(StoredData.ch2_skill_level("scattershot") == 1 and StoredData.ch2_stars_free() == 9, "武器未解锁时技能不能加点")
	await click_control(pg._weapon_pads["five_thunders"]["hit"])
	check(StoredData.ch2_weapon_unlocked("five_thunders") and StoredData.ch2_stars_free() == 8, "点解锁格花 1 星解锁五雷神机")
	await click_control(pad2)
	check(StoredData.ch2_skill_level("scattershot") == 2 and StoredData.ch2_stars_free() == 7, "解锁后可加点")
	await click_control(pg._weapon_pads["horse_cleaver"]["hit"])
	check(StoredData.ch2_weapon_unlocked("horse_cleaver") and StoredData.ch2_stars_free() == 6, "斩马刀纳入本阶段，同样是 1 星解锁")
	await click_control(pg._skill_pads["follow_through"]["hit"])
	check(StoredData.ch2_skill_level("follow_through") == 2, "斩马刀升级技能 Follow-Through 可加点")

	# 职业加成：镇戍卫攻击槽（对应一代 BonusCalculator 战士系槽 0，复用一代 u_warriors_attack 的 eLock）。
	# 此时挣 9 星，之前已花 4（五雷解锁、Scattershot、斩马刀解锁、Follow-Through 各 1），空闲 5 星。
	check(StoredData.ch2_stars_free() == 5, "测试辅助：进入加成测试前空闲 5 星（%d）" % StoredData.ch2_stars_free())
	var bonus_ctl: Control = pg._bonus_pads["warden:0"]["hit"]
	var lock_bonus: FlashClip = panel.u_warriors_attack.child_clip("eLock")
	await click_control(bonus_ctl)
	check(StoredData.ch2_bonus_level("warden", 0) == 1 and StoredData.ch2_stars_free() == 4, "职业加成加点同样花 1 星")
	check(lock_bonus.current_frame == 3, "一代 u_warriors_attack 自带的 eLock 显示 1 级角标（帧 3）")
	await click_control(bonus_ctl, true)
	check(StoredData.ch2_bonus_level("warden", 0) == 0 and StoredData.ch2_stars_free() == 5, "Shift 点击职业加成退星")

	# 星数不足
	for sk in ["hold_fast", "intercept", "horsebreaker", "follow_through"]:
		StoredData.ch2_set_skill_level(sk, 3)
	pg.refresh()
	check(StoredData.ch2_stars_free() <= 0, "测试辅助：星数被花光（%d）" % StoredData.ch2_stars_free())
	StoredData.ch2_set_skill_level("steady_aim", 1)
	await click_control(pg._skill_pads["steady_aim"]["hit"])
	check(StoredData.ch2_skill_level("steady_aim") == 1, "没有空闲星时不能加点")

	# Reset 退还全部二章加点（技能、职业加成），武器解锁也退回
	pg.reset_upgrades()
	check(StoredData.ch2_stars_free() == 9 and not StoredData.ch2_weapon_unlocked("five_thunders"), "Reset 退还二章星并清除付费解锁")
	check(StoredData.ch2_bonus_level("warden", 0) == 0, "Reset 也清空职业加成")

	# 翻页：回到第一页，叠加层隐藏，一代节点一直都在（只是不再被盖住），星数字段还原成一代的
	await click_at(pg.pager.get_global_rect().position + Vector2(8, pg.pager.size.y * 0.5))
	check(pg.page == 1 and not pg.overlay.visible, "点翻页器回到第一页，叠加层隐藏")
	check(panel.t_free_stars.text == str(ch1_free), "第一页星数仍是一代的：%s" % panel.t_free_stars.text)
	await click_at(pg.pager.get_global_rect().end - Vector2(8, pg.pager.size.y * 0.5))
	check(pg.page == 2 and pg.overlay.visible, "再点翻页器回到第二页")

	# 离开面板：第一页复原
	root.remove_child(panel)
	check(not panel.u_war_sword_a.visible or true, "（离开不报错）")
	panel.free()


# ---------------------------------------------------------------- 战斗界面

func test_battle_ui() -> void:
	var h := Harness.new(self)
	h.boot()
	StoredData.dev = false
	StoredData.ch2_unlock_weapon("great_glaive")
	var factory_ready := IfaceUtil.global_script("Ch2UnitFactory") != null

	# 一代战斗：没有翻页器
	var gu := h.start_level(0, 1, 1, true, 1)
	var ui := gu.ingame_ui
	ui.last_clicked_unit_number = 1
	ui._show_sub_panel()
	for i in 12:
		h.tween_phase()
	check(ui.ch2_ui != null and not ui.ch2_ui.pager.visible, "一代战斗的招募面板没有第二页")
	ui.hide_sub_panel()
	h.stop_level()

	gu = h.start_level(0, 1, 1, true, 2)
	ui = gu.ingame_ui
	await settle()
	gu.current_money = 0
	ui.dest_money = 0
	ui.last_clicked_unit_number = 1
	ui._show_sub_panel()
	for i in 12:
		h.tween_phase()
	await settle()
	var cu: Ch2BattleUi = ui.ch2_ui
	check(cu.pager.visible, "二章战斗：战士系子面板出现翻页器")
	check(cu.page == 1 and not (cu._cell_icons[0] as TextureRect).visible, "默认第一页，二章图标未显示")
	await click_at(cu.pager.get_global_rect().end - Vector2(8, cu.pager.size.y * 0.5))
	check(cu.page == 2, "点翻页器进入第二页")
	check((cu._cell_icons[0] as TextureRect).visible and (cu._cell_icons[0] as TextureRect).texture == Ch2UiData.portrait_tex("warden"), "第 1 格是镇戍卫头像")
	check((cu._cell_icons[1] as TextureRect).visible and (cu._cell_icons[1] as TextureRect).texture == Ch2UiData.weapon_tex("great_glaive"), "第 2 格是陌刀图标")
	check(not (cu._cell_icons[2] as TextureRect).visible and ((ui.e_sub_three.get_node("eIco") as FlashClip).current_frame == 6), "第 3 格（斩马刀未解锁）显示一代锁定帧")
	var tname: FlashText = ui.e_hint.get_node("tName")
	var tcost: FlashText = ui.e_hint.get_node("tCost")
	var eback: FlashClip = ui.e_hint.get_node("eBack")
	check(cu.rover(ui.e_sub_two, tname, tcost, eback) and tname.text == "Great Glaive" and tcost.text == str(Ch2UiData.unit_cost("warden") + 600), "第 2 格提示：英文名与 招募价+换装费（%s / %s）" % [tname.text, tcost.text])
	check(cu.rover(ui.e_sub_one, tname, tcost, eback) and tname.text == "Warden" and tcost.text == str(Ch2UiData.unit_cost("warden")), "第 1 格提示：职业名与招募价")
	var before := gu.a_all_units.size()
	await click_control(ui.e_sub_one)
	check(gu.a_all_units.size() == before, "钱不够时点第 1 格不招人")
	# 再翻回第一页：一代图标复原
	await click_at(cu.pager.get_global_rect().position + Vector2(8, cu.pager.size.y * 0.5))
	check(cu.page == 1 and (ui.e_sub_one.get_node("eIco") as FlashClip).visible and (ui.e_sub_one.get_node("eIco") as FlashClip).current_frame == 1 and not (cu._cell_icons[0] as TextureRect).visible, "翻回第一页：一代职业图标复原")
	# 弓手系同样有第二页
	ui.hide_sub_panel()
	for i in 12:
		h.tween_phase()
	ui.last_clicked_unit_number = 2
	ui._show_sub_panel()
	for i in 12:
		h.tween_phase()
	check(cu.pager.visible, "弓手系子面板出现翻页器")
	ui.hide_sub_panel()
	ui.last_clicked_unit_number = 3
	ui._show_sub_panel()
	check(not cu.pager.visible, "法师系没有第二页")
	ui.hide_sub_panel()

	if not factory_ready:
		print("SKIP 招募 / 换武器 / 技能图标：Ch2UnitFactory 尚未落地")
	else:
		await _test_units(h, gu, ui, cu)
	h.shutdown()


func _test_units(h: Harness, gu: GameUniverse, ui: MainGameUIEx, cu: Ch2BattleUi) -> void:
	gu.current_money = 5000
	ui.dest_money = 5000
	ui.cur_money = 5000
	ui.last_clicked_unit_number = 1
	ui._show_sub_panel()
	for i in 12:
		h.tween_phase()
	cu.page = 2
	cu._apply_page()
	var money0 := int(gu.current_money)
	cu.cell_clicked(0)
	var warden: LivingObject = gu.a_all_units.back()
	check(Ch2UiData.unit_profession(warden) == "warden" and Ch2UiData.unit_weapon_id(warden) == "dao_shield", "第 1 格招到刀盾镇戍卫")
	check(int(money0 - gu.current_money) == Ch2UiData.unit_cost("warden"), "招募价等于对应兵种 unit_cost")
	ui.last_clicked_unit_number = 1
	ui._show_sub_panel()
	for i in 12:
		h.tween_phase()
	cu.page = 2
	cu._apply_page()
	ui.warrior_cool_down_status = 100
	var money1 := int(gu.current_money)
	cu.cell_clicked(1)
	var glaive: LivingObject = gu.a_all_units.back()
	check(Ch2UiData.unit_weapon_id(glaive) == "great_glaive", "第 2 格直接招来陌刀镇戍卫")
	check(int(money1 - gu.current_money) == Ch2UiData.unit_cost("warden") + 600, "高级武器价 = 招募价 + 换装费 600")
	# 选中后：换武器
	gu.unselect_units()
	gu.select_unit(warden)
	ui.update_soldier_data()
	var us := ui._unit_select()
	var can: bool = warden.has_method("can_upgrade_weapon") and warden.can_upgrade_weapon()
	var money2 := int(gu.current_money)
	cu.weapon_button_clicked(true)
	if can:
		check(Ch2UiData.unit_weapon_id(warden) == "great_glaive" and int(money2 - gu.current_money) == 600, "可升级的基础武器单位换陌刀：扣 600，对象不变")
	else:
		check(Ch2UiData.unit_weapon_id(warden) == "dao_shield" and int(gu.current_money) == money2, "未练满经验的基础武器单位不能换高级武器")
	gu.unselect_units()
	gu.select_unit(glaive)
	ui.update_soldier_data()
	check(us.get_node("bTop") != null and cu._btn_frames[0].visible, "已持陌刀时上方按钮显示选中态")
	var money3 := int(gu.current_money)
	cu.weapon_button_clicked(false)   # 斩马刀未解锁
	check(Ch2UiData.unit_weapon_id(glaive) == "great_glaive" and int(gu.current_money) == money3, "另一把高级武器未解锁时不换、不扣钱")
	check((cu._skill_icons[0] as TextureRect).visible and (cu._skill_icons[0] as TextureRect).texture == Ch2UiData.skill_tex("horsebreaker"), "技能槽显示二章技能图标")
