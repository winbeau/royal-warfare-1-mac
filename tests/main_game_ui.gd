extends SceneTree
# HUD-1：MainGameUIEx（战斗主界面）与 ButtonClass。
# 运行：Godot --headless --path . --script tests/main_game_ui.gd -- --isolated-profile
# 覆盖：初始化显隐状态、金钱/生命/波数文字、兵种按钮锁定与解锁、招募冷却盘与技能冷却盘的帧号、
# 红色“下一波”按钮倒计时、受控暂停对 RWTween 的暂停/恢复、失焦自动暂停的设置开关、ButtonClass 的悬停/点击事件。
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
	var tw := RWTween.inst_()
	tw.manual_clock = true
	RWTween.reset()

	# GameUniverse 作替身提供 get_money / get_game_time / is_controlled_pause 等（不加入场景树，不启动关卡）
	var gu := GameUniverse.new()
	check(GameUniverse.inst == gu, "GameUniverse.inst set")

	var ui := MainGameUIEx.create()
	check(ui != null, "scene scenes/ifaces/main_game_ui_ex.tscn instantiates MainGameUIEx")
	# 核心在 add_child 之前就会调 unlockUnits / lockUnits
	ui.unlock_units()
	ui.lock_units([LivingObject.BUTTON_WARRIORS, LivingObject.BUTTON_MAGES, LivingObject.FR_KNIGHT])
	root.add_child(ui)
	await settle()
	check(MainGameUIEx.inst == ui, "MainGameUIEx.inst is the scene instance")
	test_init_state(ui)
	test_texts(ui, gu)
	test_locks(ui)
	await test_cool_downs(ui, gu)
	test_red_button(ui, gu)
	test_pause(ui, gu)
	await test_focus_out(ui, gu)
	await test_buttons(ui, gu)
	test_tiers(ui)

	await test_readd_and_new(ui, gu)

	if ui.get_parent() != null:
		root.remove_child(ui)
	ui.free()
	gu.free()
	RWTween.reset()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func test_init_state(ui: MainGameUIEx) -> void:
	check(ui.e_unit_panel.visible == false, "eUnitPanel hidden at start")
	check(ui.e_unit_panel.position.y > 600.0, "eUnitPanel parked below the screen (y=%s)" % ui.e_unit_panel.position.y)
	check(ui.e_hint.visible == false, "eHint hidden")
	check(ui.e_small_hint.visible == false, "eSmallHint hidden")
	check(ui.e_fader.visible == false, "eFader hidden")
	check(ui.e_focus.visible == false, "eFocus hidden")
	check(ui.arrow_target_circle.visible == false, "arrowTargetCircle hidden")
	check(ui.e_sens_archers.visible == false, "eSensArchers hidden")
	check(ui.b_archers.visible == false, "bArchers hidden until enableArchersButton")
	check(ui.t_pause_message.visible == false, "tPauseMessage hidden")
	check(ui.e_game_paused_message.visible == false, "eGamePausedMessage hidden")
	for mc: FlashClip in ui.a_sub_units_panel:
		check(mc.visible == false, "sub-unit panel %s hidden" % mc.name)
	check(ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "UI root ignores the mouse (mouseEnabled=false)")
	check(ui.e_money.mouse_filter == Control.MOUSE_FILTER_IGNORE, "eMoney ignores the mouse")
	check(ui.a_buttons == [ui.e1, ui.e4, ui.e3, ui.e2, ui.e5], "aButtons order e1,e4,e3,e2,e5")
	check(ui.b_archers_cooldown == true, "bArchersCooldown starts true")
	check(ui.e_unit_panel.get_node("eUpgrade").position.y == ui.e_upgrade_down_coord, "eUpgrade parked at eUpgradeDownCoord")
	check(ui.warrior_cool_down_status == 100 and ui.rogue_cool_down_status == 100, "unit cooldown statuses start at 100")
	check(MainGameUIEx.is_attack_button_clicked == false and MainGameUIEx.is_formation_clicked == false, "stance buttons not clicked")
	# 右侧按钮初始都是灰态（hideRightButton 登记到 aDisabledButtons）
	for mc: FlashClip in [ui.e_vert, ui.e_horiz, ui.e_got_upgrade, ui.e_formation, ui.e_attack_def, ui.e_defend, ui.small_horiz, ui.small_vert]:
		check(ui.a_disabled_buttons.has(mc), "%s starts disabled" % mc.name)
	check(ui.e1.get_node("eCoolDown").current_frame == 100, "e1 cooldown disc at its last frame")
	check(ui.e_unit_panel.get_node("eOne/eAbility").current_frame == 1, "ability icon 1 shows frame 1")
	check(is_equal_approx(ui.cost_multiplier, 0.5), "costMultiplier default 0.5")

func test_texts(ui: MainGameUIEx, gu: GameUniverse) -> void:
	ui.draw_lives(20)
	check(ui.e_hp.get_node("tText").text == "20", "drawLives writes 20")
	ui.draw_current_wave(3, 10)
	check(ui.e_wave.get_node("tText").text == "3/10", "drawCurrentWave writes 3/10")
	ui.draw_current_wave(2.7, 5)
	check(ui.e_wave.get_node("tText").text == "2/5", "drawCurrentWave truncates the wave number")
	gu.current_money = 1234
	ui.set_money()
	check(ui.dest_money == 1234, "setMoney reads GameUniverse.getMoney")
	var guard := 0
	while ui.cur_money != ui.dest_money and guard < 200:
		ui.update_data()
		guard += 1
	check(ui.cur_money == 1234 and ui.e_money.get_node("tMoney").text == "1234", "money counter converges to 1234 (text=%s, %d steps)" % [ui.e_money.get_node("tMoney").text, guard])
	# 一步 = int(round(diff)/5)，差值小于 5 时直接对齐
	ui.cur_money = 100
	ui.dest_money = 200
	ui.update_data()
	check(ui.cur_money == 120, "money counter step is diff/5 (got %d)" % ui.cur_money)
	ui.cur_money = 198
	ui.update_data()
	check(ui.cur_money == 200, "money counter snaps when the step is 0")

func test_locks(ui: MainGameUIEx) -> void:
	# 在 ready 之前下发的 unlock + lock 在 added() 里补做
	check(ui.e1.get_node("eLocked").visible and not ui.e1.get_node("eIco").visible, "e1 locked (queued before ready)")
	check(ui.e2.get_node("eLocked").visible and not ui.e2.get_node("eIco").visible, "e2 locked (queued before ready)")
	check(not ui.e4.get_node("eLocked").visible and ui.e4.get_node("eIco").visible, "e4 not locked")
	check(ui.a_locked_units_and_buttons.has(LivingObject.FR_KNIGHT), "locked list keeps tier-3 knight")
	ui.unlock_units()
	for mc: FlashClip in ui.a_buttons:
		check(not mc.get_node("eLocked").visible and mc.get_node("eIco").visible, "%s unlocked" % mc.name)
	ui.lock_units([LivingObject.BUTTON_ARCHERS, LivingObject.BUTTON_PRIESTS, LivingObject.BUTTON_THIEVES])
	check(ui.e4.get_node("eLocked").visible and ui.e3.get_node("eLocked").visible and ui.e5.get_node("eLocked").visible, "archers/priests/thieves locked")
	check(not ui.e1.get_node("eLocked").visible and not ui.e2.get_node("eLocked").visible, "warriors/mages still unlocked")
	ui.unlock_units()
	check(ui.a_locked_units_and_buttons.is_empty(), "unlockUnits clears the list")

func test_cool_downs(ui: MainGameUIEx, gu: GameUniverse) -> void:
	# 战士：A_WARRIOR_COOLDOWN_TAB[0] = 8 秒 = 240 帧；已过 120 帧 -> 50%
	LivingObject.unit_num_warriors = 1
	ui.warrior_cool_down_status = 0
	ui.warrior_last_built_time = 0
	gu.global_counter = 120
	ui.update_data()
	check(ui.warrior_cool_down_status == 50, "warrior cooldown status 50 (got %d)" % ui.warrior_cool_down_status)
	check(ui.e1.get_node("eCoolDown").current_frame == 50, "e1 cooldown disc on frame 50")
	check(ui.e1.get_node("eCoolDown").visible, "cooldown disc is visible while cooling")
	gu.global_counter = 239
	ui.update_data()
	check(ui.warrior_cool_down_status == 99 and ui.e1.get_node("eCoolDown").current_frame == 99, "239/240 frames -> 99%")
	gu.global_counter = 240
	ui.update_data()
	check(ui.warrior_cool_down_status == 100 and ui.e1.get_node("eCoolDown").current_frame == 100, "240/240 frames -> 100%")
	# 法师：表 [15,...]，两个法师 -> 16 秒 = 480 帧；240 帧 -> 50%
	LivingObject.unit_num_mages = 2
	ui.mage_cool_down_status = 0
	ui.mage_last_built_time = 0
	gu.global_counter = 240
	ui.update_data()
	check(ui.e2.get_node("eCoolDown").current_frame == 50, "e2 cooldown disc on frame 50 (got %d)" % ui.e2.get_node("eCoolDown").current_frame)
	LivingObject.unit_num_warriors = 0
	LivingObject.unit_num_mages = 0
	# 技能冷却盘：gotoAndStop(getCountPercent)
	var sp := SpecialTemplate.new()
	sp.time_until_update = 60
	sp.counter = 30
	sp.number_in_panel = 5
	ui._update_ability_slot(1, sp)
	var cd1: FlashClip = ui.e_unit_panel.get_node("eOne/eCoolDown")
	check(cd1.current_frame == 50, "ability 1 disc on frame 50 (got %d)" % cd1.current_frame)
	check(ui.e_unit_panel.get_node("eOne/eAbility").current_frame == 5, "ability icon uses numberInPanel-1 (frame 5)")
	sp.counter = 60
	ui._update_ability_slot(2, sp)
	check(ui.e_unit_panel.get_node("eTwo/eCoolDown").current_frame == 100, "ready ability disc on frame 100")
	sp.is_locked = true
	ui._update_ability_slot(1, sp)
	check(cd1.current_frame == 100 and ui.e_unit_panel.get_node("eOne/eAbility").current_frame == 1, "locked ability: icon 0, disc 100")
	ui._update_ability_slot(1, null)
	check(cd1.current_frame == 100, "no ability: disc 100")
	# 弓箭雨按钮
	ui.enable_archers_button()
	check(ui.b_archers.visible, "enableArchersButton shows bArchers")
	ui.b_archers_cooldown = true
	ui.update_b_archers_cooldown(40)
	check(ui.b_archers.get_node("eCoolDown").current_frame == 40 and ui.b_archers_cooldown, "bArchers disc follows the status")
	ui.update_b_archers_cooldown(100)
	check(ui.b_archers_cooldown == false and ui.b_archers.get_node("eCoolDown").current_frame == 100, "bArchers ready at 100")
	await settle(1)

func test_red_button(ui: MainGameUIEx, gu: GameUniverse) -> void:
	ui.update_red_button(45 * 30)
	check(ui.e_next_wave_pad.get_node("eAutostartPad/tCounter").text == "45", "45 s countdown")
	ui.update_red_button(44 * 30 + 29)
	check(ui.e_next_wave_pad.get_node("eAutostartPad/tCounter").text == "44", "countdown floors")
	ui.update_red_button(-5)
	check(ui.e_next_wave_pad.get_node("eAutostartPad/tCounter").text == "0", "countdown clamps at 0")
	ui.show_red_button()
	check(ui.red_button_shown == true, "red button shown flag")
	check(ui.a_buttons[0].mouse_enabled == true, "unit buttons enabled while the red button shows")
	ui.hide_red_button()
	check(ui.red_button_shown == false, "red button hidden flag")
	check(ui.a_buttons[0].mouse_enabled == false, "unit buttons disabled after hideRedButton")

func test_pause(ui: MainGameUIEx, gu: GameUniverse) -> void:
	RWTween.reset()
	var probe := Control.new()
	root.add_child(probe)
	RWTween.to(probe, 10.0, {"x": 100})
	gu.is_controlled_pause = false
	ui.call_controlled_pause()
	check(gu.is_controlled_pause == true, "callControlledPause sets isControlledPause")
	check(ui.e_pause.get_node("eIcon").current_frame == 2, "pause icon frame 2")
	var handles: Array = RWTween.get_tweens_of(probe)
	check(handles.size() > 0 and handles[0].paused, "RWTween paused by controlled pause")
	check(ui.e_game_paused_message.position == ui.e_game_paused_message_coords or ui.e_game_paused_message.position.y == 115.0, "paused message placed")
	ui.call_controlled_pause()
	check(gu.is_controlled_pause == false, "second call resumes")
	check(ui.e_pause.get_node("eIcon").current_frame == 1, "pause icon frame 1")
	handles = RWTween.get_tweens_of(probe)
	check(handles.size() > 0 and not handles[0].paused, "RWTween resumed")
	probe.free()
	RWTween.reset()

func test_focus_out(ui: MainGameUIEx, gu: GameUniverse) -> void:
	# NOTIFICATION_APPLICATION_FOCUS_OUT 在 added() 与 removed() 之间生效，受 mainParams.autop 控制
	StoredData.main_params["autop"] = false
	gu.is_paused = false
	gu.is_end_game = false
	gu.add_child(Node.new())  # 保持 gu 可 free
	ui.flash_deactive()
	check(ui.t_pause_message.visible == false, "autop=false: focus loss does not pause")
	StoredData.main_params["autop"] = true
	ui.flash_deactive()
	check(ui.t_pause_message.visible == true, "autop=true: focus loss shows the pause message")
	check(gu.is_paused == true, "autop=true: GameUniverse paused")
	# 点击暂停提示恢复
	ui._set_unpause()
	check(ui.t_pause_message.visible == false and gu.is_paused == false, "clicking the pause message resumes")
	await settle(1)
	StoredData.main_params["autop"] = true

func test_buttons(ui: MainGameUIEx, gu: GameUniverse) -> void:
	# ButtonClass：悬停提亮 + rover 回调，点击回调
	var hits := {"over": 0, "out": 0, "click": 0}
	var mc: FlashClip = ui.e_money
	var over := func(_e: ButtonClass.ButtonEvent) -> void: hits.over += 1
	var out := func(_e: ButtonClass.ButtonEvent) -> void: hits.out += 1
	var click := func() -> void: hits.click += 1   # 0 参数回调也可以
	ButtonClass.add_button_full(mc, over, out, click)
	var hub: Object = mc.get_meta(ButtonClass.HUB_META)
	hub.dispatch(ButtonClass.ROLL_OVER)
	hub.dispatch(ButtonClass.ROLL_OUT)
	hub.dispatch(ButtonClass.CLICK)
	check(hits.over == 1 and hits.out == 1 and hits.click == 1, "ButtonClass dispatches rollOver/rollOut/click")
	ButtonClass.add_event_listener(mc, ButtonClass.CLICK, click)   # 重复登记只算一次
	hub.dispatch(ButtonClass.CLICK)
	check(hits.click == 2, "duplicate listener registered once")
	ButtonClass.remove_button_full(mc, over, out, click)
	hub.dispatch(ButtonClass.CLICK)
	check(hits.click == 2, "removeButtonFull removes the listeners")
	# 静态处理函数可被 removeEventListener 精确移除（Callable 相等）
	var mc2: FlashClip = ui.e_hp
	ButtonClass.add_button_scale(mc2, click)
	(mc2.get_meta(ButtonClass.HUB_META) as Object).dispatch(ButtonClass.ROLL_OVER)
	check(RWTween.get_tweens_of(mc2).size() > 0, "addButtonScale: rollOver starts a scale tween")
	ButtonClass.remove_button_scale(mc2, click)
	check(RWTween.get_tweens_of(mc2).size() == 0, "removeButtonScale kills tweens")
	check(mc2.modulate.a == 1.0, "removeButtonOnFrames restores alpha")
	var listeners: Dictionary = (mc2.get_meta(ButtonClass.HUB_META) as Object).listeners
	var left := 0
	for k in listeners:
		left += (listeners[k] as Array).size()
	check(left == 0, "removeButtonScale leaves no listeners (left=%d)" % left)
	# addButtonOnFramesRD：帧 1/2/3 与 eLight
	var bs: FlashClip = ui.e_next_wave_pad.get_node("bStart")
	var bhub: Object = bs.get_meta(ButtonClass.HUB_META)
	bhub.dispatch(ButtonClass.ROLL_OVER)
	check(bs.current_frame == 2, "bStart rollOver -> frame 2")
	bhub.dispatch(ButtonClass.MOUSE_DOWN)
	check(bs.current_frame == 3, "bStart mouseDown -> frame 3")
	bhub.dispatch(ButtonClass.MOUSE_UP)
	check(bs.current_frame == 2, "bStart mouseUp -> frame 2")
	bhub.dispatch(ButtonClass.ROLL_OUT)
	check(bs.current_frame == 1, "bStart rollOut -> frame 1")
	# 攻防按钮状态
	MainGameUIEx.is_attack_button_clicked = false
	ui.enable_attack_def_button()
	check(MainGameUIEx.is_attack_button_clicked == true, "enableAttackDefButton sets the flag")
	ui.reset_attack_def_button()
	check(MainGameUIEx.is_attack_button_clicked == false, "resetAttackDefButton clears the flag")
	ui.enable_formation_button()
	check(MainGameUIEx.is_formation_clicked == true, "enableFormationButton sets the flag")
	ui.reset_formation_button()
	check(MainGameUIEx.is_formation_clicked == false, "resetFormationButton clears the flag")
	await settle(1)

func test_tiers(ui: MainGameUIEx) -> void:
	# 三档兵种表与原版 hint 文案/单位一致
	check(MainGameUIEx.tier_one()[3][0] == "Blue Wizard" and MainGameUIEx.tier_two()[4][0] == "Cleric" and MainGameUIEx.tier_three()[5][0] == "Spy", "tier tables carry the original unit names")
	# 招募：金钱不足 -> 不创建单位，冷却状态不变
	ui.last_clicked_unit_number = 1
	ui.dest_money = 0
	ui.warrior_cool_down_status = 100
	ui._selected_tier(MainGameUIEx.tier_one(), true)
	check(ui.warrior_cool_down_status == 100, "not enough gold: no cooldown started")
	# 锁定的兵种：不招募
	ui.dest_money = 99999
	ui.lock_units([LivingObject.FR_WARRIOR])
	ui._selected_tier(MainGameUIEx.tier_one(), true)
	check(ui.warrior_cool_down_status == 100, "locked unit: no cooldown started")
	# 费用公式：floor(unitCost + mult * num * unitCost)
	LivingObject.unit_num_warriors = 3
	var uc: float = FriendWarrior.unit_cost
	var want: float = floorf(uc + 0.5 * 3 * uc)
	check(want == floorf(uc + ui.cost_multiplier * LivingObject.unit_num_warriors * uc), "tier-1 cost formula uses costMultiplier")
	LivingObject.unit_num_warriors = 0
	ui.unlock_units()

func test_readd_and_new(ui: MainGameUIEx, gu: GameUniverse) -> void:
	# 下一关：GameUniverse 把同一个界面摘下再挂回，added() 重新初始化（原版 ADDED_TO_STAGE 再次触发）
	ui.a_disabled_buttons.clear()
	ui.e_unit_panel.visible = true
	root.remove_child(ui)
	check(ui._attached == false, "removed from the tree: removed() ran")
	root.add_child(ui)
	await settle(1)
	check(ui._attached == true and ui.e_unit_panel.visible == false, "re-added: added() ran again and hid the unit panel")
	check(ui.a_disabled_buttons.size() == 8, "re-added: right-hand buttons disabled again (%d)" % ui.a_disabled_buttons.size())
	var hub: Object = ui.e1.get_meta(ButtonClass.HUB_META)
	check((hub.listeners[ButtonClass.CLICK] as Array).size() == 1, "re-added: no duplicated click listeners")
	# GameUniverse 用 `MainGameUIEx.new()`：符号类子节点由 IfaceUtil.adopt 并入，行为一致
	var ui2 := MainGameUIEx.new()
	root.add_child(ui2)
	await settle(1)
	check(ui2.e_unit_panel != null and ui2.e_unit_panel.visible == false and ui2.e_hint.visible == false, "MainGameUIEx.new() path initialises like the scene")
	ui2.draw_lives(7)
	check(ui2.e_hp.get_node("tText").text == "7", "MainGameUIEx.new(): drawLives works")
	root.remove_child(ui2)
	ui2.free()
	MainGameUIEx.inst = ui
	HintsManager.init(ui.e_new_enemy, ui.e_new_hint)   # 静态单例改回 ui 的子节点
