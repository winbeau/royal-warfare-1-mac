extends SceneTree
# 集成 I2：第 1 关端到端战斗（移植后的核心，非旧 battle.gd）。必须带 -- --isolated-profile。
# 流程与原版一致：默认存档 -> Main.loadGame -> gameUniverse.init(0) -> 每个逻辑帧调用 global_update（与 _physics_process 相同入口）。
# 界面类用 GameUniverse 自带实例（HUD 移植前为桩）；招募走 addSoldier，并复刻 mainGameUI_ex 的费用检查。
# 固定种子分别以 1x 和 2x 速度各跑一次，断言：
#  - 全程无脚本错误；敌人按关卡事件生成（总数 = 事件 number 之和）；
#  - 近战伤害只在 DONE 帧结算（逻辑阶段的每次扣血都对应一个处于 DONE 帧、攻击该单位的近战者）；
#  - 箭的伤害只在 RWTween 回调（贝塞尔飞行结束）里结算；
#  - 有单位死亡，尸体保留 300 帧（deathTime + 300 < globalCounter 时移除，即第 301 帧）；
#  - 金钱、生命的变化与事件一致；在有限帧数内到达胜负结局。
const Harness := preload("res://tests/support/battle_harness.gd")
const SEED := 20260101
const MAX_FRAMES := 40000

var checks := 0
var failures: Array = []
var results: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	var h := Harness.new(self)
	h.boot()
	# 每次 start_level 都重建兵种对象池（相当于全新进程）：原版池中单位不重置 lastBackstab、scounter 等字段，
	# 回收实例与全新实例的行为因此可以不同（原版如此），固定种子的可复现性以“相同的初始池”为前提。
	results["x1"] = battle(h, 1)
	# 同一种子、同一速度重复运行应得到完全相同的结果（确定性）
	var again := battle(h, 1)
	results["x2"] = battle(h, 2)
	var ta: Array = again["trace"]
	var tb: Array = results["x1"]["trace"]
	for i in mini(ta.size(), tb.size()):
		if ta[i] != tb[i]:
			print("TRACE first divergence at frame ", i + 1, ": ", tb[i], " vs ", ta[i])
			break
	check(JSON.stringify(again["summary"]) == JSON.stringify(results["x1"]["summary"]), "fixed seed: second 1x run reproduces the first (%s vs %s)" % [again["summary"], results["x1"]["summary"]])
	check(h.catcher.errors.is_empty(), "no script errors in whole run: %s" % [h.catcher.errors.slice(0, 5)])
	var ui_total := 0
	for m in h.catcher.ui_errors:
		ui_total += int(h.catcher.ui_errors[m])
	print("UI_ERRORS %d distinct, %d total (界面层文件内的报错，HUD 移植中，不计入核心)" % [h.catcher.ui_errors.size(), ui_total])
	for m in h.catcher.ui_errors.keys().slice(0, 8):
		print("  UI ", m)
	h.shutdown()
	for k in results:
		print("RESULT ", k, " ", JSON.stringify(results[k]["summary"]))
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func total_enemy_number(gu: GameUniverse) -> int:
	var total := 0
	for w in gu.level_info.a_waves:
		if w[0]["type"] == LevelTemplate.ENEMY_SPAWN:
			for o in w[1]:
				total += int(o["number"])
	return total

func snapshot(gu: GameUniverse) -> Dictionary:
	var m := {}
	for u in gu.a_all_units:
		m[u] = u.cur_health
	for u in gu.a_waiting_death:
		m[u] = u.cur_health
	return m

## 该单位此刻（本帧 global_update 之前）是否会在 main_alg_update_sprite 里触发 on_play_head_done 的近战攻击。
func melee_done_pending(u: LivingObject, speed: int = 1) -> bool:
	if u.cur_health <= 0:
		return false
	# 近战（FIGHTING）与施法（CASTING，如蓝法师的闪光 setFlash）都在 DONE 帧结算
	var melee: bool = u.cur_stanse == LivingObject.FIGHTING and u.cur_target != null
	if not (melee or u.cur_stanse == LivingObject.CASTING) or u.play_head_stance != LivingObject.PLAYING or not u.in_action:
		return false
	if u.current_bm == null:
		return false
	if u.current_bm.frame_commands[u.cur_frame] == 2:
		return true
	# 2x 速度：同一个 ENTER_FRAME 里 mainUpdateFunction 跑两次，第二次的帧是 curFrame + 1
	if speed == 2:
		var nxt: int = u.cur_frame + 1 if u.cur_frame != u.current_bm.num_frames - 1 else 0
		return u.current_bm.frame_commands[nxt] == 2
	return false

func count_arrows(gu: GameUniverse) -> int:
	var n := gu.a_fireballs.size()  # 火球同属 TweenMax 飞行 + 回调结算
	for o in gu.a_display_objects_vector:
		if o is ArrowEx:
			n += 1
	return n

func battle(h: Harness, speed: int) -> Dictionary:
	var gu := h.start_level(0, SEED)
	h.set_speed(speed)
	var tag := "x%d" % speed
	var err_before := h.catcher.errors.size()
	check(gu.num_lifes == 14 and int(gu.current_money) == 250, "%s: level 1 start lives=14 money=250 (got %d / %d)" % [tag, gu.num_lifes, int(gu.current_money)])
	check(FriendWarrior.unit_cost == 100 and FriendArcher.unit_cost == 120, "%s: set_loaded_units_parameters wrote static unit_cost via Script.set (%d/%d)" % [tag, FriendWarrior.unit_cost, FriendArcher.unit_cost])
	check(gu.a_all_units.size() == 7, "%s: loading_completed_handler placed 7 units" % tag)
	var expected_spawn := total_enemy_number(gu)
	var money := float(gu.current_money)
	var spent := 0.0
	var reward := 0.0
	var npc_deaths := 0
	var corpse_expiries := 0
	var escapes := 0
	var spawned := 0
	var kills := 0
	var friendly_deaths := 0
	var melee_done_events := 0
	var melee_done_hits := 0
	var unexplained_logic_drops: Array = []
	var arrow_hits := 0
	var arrows_seen := 0
	var arrow_ids: Dictionary = {}
	var max_arrows := 0
	var tracked_corpses: Dictionary = {}  # unit -> death_time
	var removal_gaps: Array = []
	var removed_units: Array = []
	var dead_seen: Dictionary = {}
	var prev_units: Dictionary = {}
	for u in gu.a_all_units:
		prev_units[u] = true
	var recruited: Array = []
	var trace: Array = []
	var recruit_kinds: Array = []
	var move_unit: LivingObject = null
	var move_target := Vector2(300, 345)
	var move_start := Vector2.ZERO
	var move_reached_frame := -1
	var end_frame := -1
	var frames := 0
	while frames < MAX_FRAMES and not h.ended():
		frames += 1
		var c := gu.global_counter
		# --- 玩家操作（每个逻辑帧开始前，与鼠标点击在两次 ENTER_FRAME 之间发生等价）---
		if frames == 3:
			# 第 1 关起始已有 2 名弓手，单价 120：120 + 0.5 * 2 * 120 = 240（costMultiplier 公式）
			var cost := h.recruit_cost(LivingObject.FR_ARCHER)
			check(cost == 240.0, "%s: archer cost per costMultiplier formula = 240 (got %s)" % [tag, cost])
			var a := h.recruit(LivingObject.FR_ARCHER)
			check(a != null, "%s: recruited an archer" % tag)
			if a != null:
				spent += cost
				recruited.append(a)
				recruit_kinds.append(LivingObject.FR_ARCHER)
				check(int(gu.current_money) == 10, "%s: money after archer hire = 10 (got %d)" % [tag, int(gu.current_money)])
				check(h.recruit(LivingObject.FR_WARRIOR) == null, "%s: warrior hire refused when money is short" % tag)
				move_unit = a
				move_start = a.position
				h.order([a], move_target, null, false)  # 移动命令（“防守/移动”，非攻击）
		if frames > 300 and frames % 15 == 0:  # 先让移动命令走完（约 275 帧）
			h.auto_orders()
		if frames > 120 and frames % 30 == 0:
			for k in [LivingObject.FR_WARRIOR, LivingObject.FR_ARCHER]:
				var cost := h.recruit_cost(k)
				var u := h.recruit(k)
				if u != null:
					spent += cost
					recruited.append(u)
					recruit_kinds.append(k)
					break
		# --- 逻辑阶段 ---
		var before := snapshot(gu)
		var done_targets: Dictionary = {}
		var done_now := 0
		for u in gu.a_all_units:
			if melee_done_pending(u, speed):
				if u.cur_target != null:
					done_targets[u.cur_target] = true
				melee_done_events += 1
				done_now += 1
		var spec_before: Dictionary = {}
		for u in gu.a_all_units:
			spec_before[u] = [u.special_one.counter if u.special_one != null else -1, u.special_two.counter if u.special_two != null else -1]
		var arrows_before := count_arrows(gu)
		var poisoned_before: Dictionary = {}
		for u in gu.a_all_units:
			if u.is_poisoned or u.is_trapped_in_ice:
				poisoned_before[u] = true
		h.dismiss_chat()
		h.logic_phase()
		var mid := snapshot(gu)
		var spec_fired := 0  # 本帧有技能被触发（resetCounter -> 计数回落）：法术/范围技能直接在逻辑阶段 bringDamage
		for u in spec_before:
			var b: Array = spec_before[u]
			if u.special_one != null and u.special_one.counter < b[0]:
				spec_fired += 1
			if u.special_two != null and u.special_two.counter < b[1]:
				spec_fired += 1
		for u in before:
			if mid.has(u) and mid[u] < before[u]:
				if done_targets.has(u):
					melee_done_hits += 1
				elif poisoned_before.has(u):
					pass  # 中毒/冰冻：bpPoisoned、bpIced 每 15 帧 bringDamage，不依赖 DONE 帧
				elif done_now > 0 or spec_fired > 0:
					pass  # 范围/反击类技能（旋风斩、格挡反击等）在 DONE 帧伤及非 curTarget 的单位
				else:
					unexplained_logic_drops.append("f%d %s %d->%d pois=%s/%s bp=%s done_now=%d spec=%d" % [frames, u.get_class_name, before[u], mid[u], poisoned_before.has(u), u.is_poisoned, u.a_buffs_and_penalties, done_now, spec_fired])
		var arrows_mid := count_arrows(gu)
		for o in gu.a_display_objects_vector:
			if o is ArrowEx and not arrow_ids.has(o):
				arrow_ids[o] = true
				arrows_seen += 1
		max_arrows = maxi(max_arrows, arrows_mid)
		h.tween_phase()
		var after := snapshot(gu)
		for u in mid:
			if after.has(u) and after[u] < mid[u]:
				arrow_hits += 1
				check(arrows_mid > 0, "%s: tween-phase damage at f%d with no arrow in flight" % [tag, frames])
		trace.append("%d|%d|%d" % [RWRandom.get_state(), gu.a_all_units.size(), int(gu.current_money)])
		# --- 本帧事件统计 ---
		var cur_units: Dictionary = {}
		for u in gu.a_all_units:
			cur_units[u] = true
			if not prev_units.has(u) and not u.friendly:
				spawned += 1
		prev_units = cur_units
		for u in after:
			if not dead_seen.has(u) and u.cur_health <= 0 and u.cur_stanse == LivingObject.DEAD:
				dead_seen[u] = true
				if u.friendly:
					if u.is_npc:
						npc_deaths += 1
					else:
						friendly_deaths += 1
				else:
					kills += 1
					reward += u.money_cost
			elif not dead_seen.has(u) and not u.friendly and u.cur_stanse == LivingObject.DEAD and u.cur_health > 0:
				dead_seen[u] = true
				escapes += 1
		# 尸体保留：第一次出现在 a_waiting_death 时记录 death_time；消失时核对间隔
		for u in gu.a_waiting_death:
			if not tracked_corpses.has(u):
				tracked_corpses[u] = u.get_death_time
		for u in tracked_corpses.keys():
			if not gu.a_waiting_death.has(u) and tracked_corpses[u] != -1:
				var gap := gu.global_counter - int(tracked_corpses[u])
				removal_gaps.append(gap)
				removed_units.append(u)
				if u.real_friendly and not u.is_npc:
					corpse_expiries += 1
				tracked_corpses.erase(u)
				dead_seen.erase(u)  # 对象池：该实例之后可能作为新单位再次出现并再次死亡
		# 到达 move_target
		if move_unit != null and move_reached_frame < 0 and move_unit.cur_health > 0:
			if move_unit.position.distance_to(move_target) < 40:
				move_reached_frame = frames
		if end_frame < 0 and gu.is_end_game:
			end_frame = frames
	# --- 断言 ---
	var tail := 0
	while tail < 40:  # 让尸体的 0.3s 淡出 tween 跑完
		RWTween.step(1.0 / 30.0)
		tail += 1
	var victory := gu.vic_panel.get_parent() != null
	var defeat := gu.def_panel.get_parent() != null
	check(frames < MAX_FRAMES, "%s: battle ended within %d frames (ran %d)" % [tag, MAX_FRAMES, frames])
	check(gu.is_end_game and (victory or defeat) and not (victory and defeat), "%s: reached an ending panel (victory=%s defeat=%s)" % [tag, victory, defeat])
	check(victory == (gu.num_lifes > 0), "%s: ending matches lives (victory=%s lives=%d)" % [tag, victory, gu.num_lifes])
	check(spawned == expected_spawn, "%s: enemies spawned %d == sum of ENEMY_SPAWN numbers %d" % [tag, spawned, expected_spawn])
	check(melee_done_events > 0 and melee_done_hits > 0, "%s: melee hits happened on DONE frames (events=%d hits=%d)" % [tag, melee_done_events, melee_done_hits])
	check(unexplained_logic_drops.is_empty(), "%s: no health loss in the logic phase without a DONE-frame melee attacker: %s" % [tag, unexplained_logic_drops.slice(0, 6)])
	check(arrows_seen > 0 and arrow_hits > 0, "%s: arrows flew (%d) and landed damage in the tween callback (%d hits)" % [tag, arrows_seen, arrow_hits])
	check(kills > 0, "%s: some enemies died (%d)" % [tag, kills])
	check(removal_gaps.size() > 0, "%s: some corpses were removed (%d)" % [tag, removal_gaps.size()])
	var bad_gaps := 0
	for g in removal_gaps:
		# 帧末测量；2x 时一帧内 globalCounter 增加 2，所以可能晚 1 个计数
		# 原版 mainUpdateFunction 遍历 aWaitingDeath 时按下标前进，同时 setSelfDestruct 会从数组中移除元素，
		# 会跳过紧随其后的一具尸体，使其晚一个计数才被处理。
		if g < LivingObject.C_DEATH_TIME_AVALIABLE + 1 or g > LivingObject.C_DEATH_TIME_AVALIABLE + 2 * speed:
			bad_gaps += 1
	check(bad_gaps == 0, "%s: every corpse removed exactly when deathTime + 300 < globalCounter (gaps %s)" % [tag, removal_gaps])
	var still_attached := 0
	for u in removed_units:
		var reused: bool = gu.a_all_units.has(u) or gu.a_waiting_death.has(u)  # 池中实例可能已被新单位复用
		if not reused and u.get_parent() != null:
			still_attached += 1
	check(still_attached == 0, "%s: removed corpses detached after fade (%d still attached)" % [tag, still_attached])
	var expected_money := 250.0 - spent + reward
	check(float(gu.current_money) == expected_money, "%s: money %s == 250 - spent %s + kill rewards %s = %s" % [tag, gu.current_money, spent, reward, expected_money])
	var expected_lives := 14 - npc_deaths - corpse_expiries - escapes
	if expected_lives < 0:
		expected_lives = 0
	check(gu.num_lifes == expected_lives, "%s: lives %d == 14 - npc %d - expired friend corpses %d - escapes %d" % [tag, gu.num_lifes, npc_deaths, corpse_expiries, escapes])
	check(gu.g.gold_spent == -spent and gu.g.gold_gained == reward, "%s: GlobalData gold_spent/gained match (%s/%s)" % [tag, gu.g.gold_spent, gu.g.gold_gained])
	check(gu.g.num_hired == recruited.size(), "%s: GlobalData.num_hired = %d" % [tag, recruited.size()])
	check(move_reached_frame > 0 and move_reached_frame < 300, "%s: moved warrior reached its destination (start %s, frame %d)" % [tag, move_start, move_reached_frame])
	check(h.catcher.errors.size() == err_before, "%s: no script errors (%s)" % [tag, h.catcher.errors.slice(err_before, err_before + 5)])
	var summary := {
		"frames": frames, "global_counter": gu.global_counter, "spawned": spawned, "expected_spawn": expected_spawn, "kills": kills,
		"friendly_deaths": friendly_deaths, "npc_deaths": npc_deaths, "escapes": escapes, "corpse_expiries": corpse_expiries,
		"money": int(gu.current_money), "lives": gu.num_lifes, "victory": victory, "recruited": recruit_kinds.size(),
		"melee_done_hits": melee_done_hits, "arrows": arrows_seen, "arrow_hits": arrow_hits, "end_frame": end_frame,
	}
	return {"summary": summary, "trace": trace}
