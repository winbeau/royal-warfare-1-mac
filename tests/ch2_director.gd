extends SceneTree
# WP-B 验证：Ch2Director 的条件求值、spawn 出兵、recruit_window/dialogue 进队出队、victory/failure
# 判定、护送目标的倒地/救助/超时死亡、compute_stars。固定种子，跑第二章第 1 关（data/ch2/levels/01.json）。
const Harness := preload("res://tests/support/battle_harness.gd")
const SEED := 20261101

var checks := 0
var failures: Array = []


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
	test_condition_evaluator(h)
	test_spawn_and_tags(h)
	test_escort_downed_rescue_timeout(h)
	test_compute_stars(h)
	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _fresh_director(h: Harness) -> Ch2Director:
	RWRandom.set_seed(SEED)
	var gu := h.start_level(0, SEED, 1, true, 2)
	return (gu.level_info as LevelCh2).director


## Harness.dismiss_chat() 只是"等价于玩家立刻点完"的簡化（复位 on_stage、unpause），不会调用
## LevelTemplate.chat_closed()（真正的 ChatFrameController.close_chat() 才会调）。二章的对白 tag
## 关闭完全靠这个钩子转发给 Ch2Director（见 level_ch2.gd / ch2_director.gd 的 on_chat_closed），
## 所以这里在 dismiss 之前先手动补一次钩子调用，不改共享的 battle_harness.gd。
func _ch2_frame(h: Harness) -> void:
	if h.gu.is_paused and not h.gu.is_end_game:
		h.gu.level_info.chat_closed()
	h.frame()


## 条件求值：all/any 嵌套、time_s、cleared、flag、window_closed、objective_failed、no_combat_power。
func test_condition_evaluator(h: Harness) -> void:
	var director := _fresh_director(h)
	check(director != null, "level 1 (chapter 2) builds a Ch2Director")
	check(director.phases_by_id.has("p1") and director.phases_by_id.has("p4"), "phases p1..p4 parsed")
	check(director.objectives_by_id.has("escort_ferrymen") and director.objectives_by_id.has("medicine_chest"), "objectives parsed")

	check(director._eval_cond({"time_s": 0.0}) == true, "time_s 0 is true at frame 0")
	check(director._eval_cond({"time_s": 999.0}) == false, "time_s far in the future is false")
	check(director._eval_cond({"flag": "nope"}) == false, "unknown flag defaults false")
	director.set_flag("x.y")
	check(director._eval_cond({"flag": "x.y"}) == true, "set_flag latches true")
	check(director._eval_cond({"all": [{"flag": "x.y"}, {"time_s": 0.0}]}) == true, "all() true when both true")
	check(director._eval_cond({"all": [{"flag": "x.y"}, {"time_s": 999.0}]}) == false, "all() false when one false")
	check(director._eval_cond({"any": [{"flag": "nope"}, {"time_s": 0.0}]}) == true, "any() true when one true")
	check(director._eval_cond({"window_closed": "never_opened"}) == false, "window never opened is not closed")
	director.tags["w1"] = "open"
	check(director._eval_cond({"window_closed": "w1"}) == false, "open tag is not closed")
	director.tags["w1"] = "closed"
	check(director._eval_cond({"window_closed": "w1"}) == true, "closed tag reports closed")
	check(director._eval_cond({"enemies_alive": 0}) == true, "no enemies spawned yet -> enemies_alive 0 true")
	check(director._eval_cond({"objective_failed": "escort_ferrymen"}) == false, "objective not failed yet")
	check(director._eval_cond({"no_combat_power": true}) == false, "start units are alive -> has combat power")


## 推进到 p1 的 spawn 全部完成，断言出兵总数 == 4（配置里的 count），且难度 1 时等级不被上调。
## 推进 recruit_window（p2 的 do）打开后，通过 red_button_clicked() 关闭，确认 director 能侦测到 tag 关闭。
## 对白（p1 的 D01-a）在约 3 秒后打开聊天框，dismiss 后确认 chat_closed 回调把 tag 标为 closed。
func test_spawn_and_tags(h: Harness) -> void:
	var gu := h.start_level(0, SEED, 1, true, 2)
	var director: Ch2Director = (gu.level_info as LevelCh2).director
	# 出生即杀：p1、p2 两个阶段都会出 RW_ZOMBIE（同一个 kind），单靠事后数活着/等死的单位分不清
	# 是哪一阶段出的；这里逐帧按生成顺序累计计数，并立刻清场，让 "cleared:pN" 不必等真实战斗结果，
	# 阶段推进只取决于导演自己的出兵/标签记账。
	var seen := {}
	var p1_spawn_count := 0
	var frames := 0
	while frames < 2000 and str(director.phases_by_id["p1"]["state"]) != "done":
		for u: LivingObject in gu.a_all_units.duplicate():
			if not u.friendly and not seen.has(u):
				seen[u] = true
				p1_spawn_count += 1
			if not u.friendly and u.cur_health > 0:
				u.bring_damage(u.health + 999, null)
		_ch2_frame(h)
		frames += 1
	# 循环以"p1 已经 done"为退出条件，收尾帧里可能还有一只刚出生、这一轮 kill-on-sight 还没扫到的敌人。
	for u: LivingObject in gu.a_all_units.duplicate():
		if not u.friendly and not seen.has(u):
			seen[u] = true
			p1_spawn_count += 1
		if not u.friendly and u.cur_health > 0:
			u.bring_damage(u.health + 999, null)
	check(str(director.phases_by_id["p1"]["state"]) == "done", "phase p1 reaches done within 2000 frames (got stuck at frame %d)" % frames)
	check(p1_spawn_count == 4, "phase p1 spawns exactly 4 zombies (got %d)" % p1_spawn_count)
	check(str(director.tags.get("D01-a", "")) == "closed", "D01-a dialogue tag auto-closed once its chat was dismissed")
	check(director.enemies_alive() == 0, "battlefield stays clear (everything spawned so far was killed on sight)")

	# 手动把渡夫护送到终点，触发 p2（招募窗口 rw1 + 6 只僵尸）。继续出生即杀，否则场上有敌人时
	# 红按钮不会显示（GameUniverse 的 GLOBAL_WAVE 分支要求 checkEnemiesExistence() == false）。
	var escort: Ch2EscortObjective = director.objectives_by_id["escort_ferrymen"]
	for m: Ch2EscortNpc in escort.members:
		m.position = escort.path[1]
		m.set_coordinates(escort.path[1].x, escort.path[1].y)
	frames = 0
	while frames < 300 and str(director.tags.get("rw1", "")) != "open":
		for u: LivingObject in gu.a_all_units.duplicate():
			if not u.friendly and u.cur_health > 0:
				u.bring_damage(u.health + 999, null)
		_ch2_frame(h)
		frames += 1
	check(str(director.tags.get("rw1", "")) == "open", "recruit_window rw1 opens once escort_ferrymen.at_1 fires and p1 is cleared")
	check(director.flags.get("escort_ferrymen.at_1", false) == true, "escort_ferrymen.at_1 flag set")
	# 红按钮要等 GameUniverse 真正处理到这条 GLOBAL_WAVE 记录（场上清空）才会显示，这里先等它出现再点。
	frames = 0
	while frames < 300 and not gu.is_shown_red_button:
		for u: LivingObject in gu.a_all_units.duplicate():
			if not u.friendly and u.cur_health > 0:
				u.bring_damage(u.health + 999, null)
		_ch2_frame(h)
		frames += 1
	check(gu.is_shown_red_button, "red button shows once the GLOBAL_WAVE record reaches the queue head with no enemies alive")
	gu.red_button_clicked()
	frames = 0
	while frames < 200 and str(director.tags.get("rw1", "")) != "closed":
		_ch2_frame(h)
		frames += 1
	check(str(director.tags.get("rw1", "")) == "closed", "recruit_window rw1 closes after red_button_clicked")


## 护送目标的倒地 / 救助 / 超时死亡：直接构造一个 Ch2EscortObjective 做单元级验证（不依赖战斗随机性）。
func test_escort_downed_rescue_timeout(h: Harness) -> void:
	var gu := h.start_level(0, SEED, 1, true, 2)
	var director: Ch2Director = (gu.level_info as LevelCh2).director
	# downed_window_s 取 3s（90 帧），留出足够空间让 60 帧（2s）的救助窗口在超时前完成。
	var data := {"id": "t_escort", "type": "escort", "count": 1, "min": 1, "path": [[200, 300], [250, 300]], "downed_window_s": 3.0}
	var obj := Ch2EscortObjective.new(data, director)
	var npc: Ch2EscortNpc = obj.members[0]

	# 一次性伤害 >= 当前血量：进入倒地而不是死亡
	npc.bring_damage(npc.cur_health + 10, null)
	check(npc.is_downed == true and npc.cur_health > 0, "lethal hit enters downed state instead of dying")
	check(npc.in_hide == true, "downed npc is in_hide (not a valid search target)")

	# 放一个可控友军在 30px 内，连续 2 秒（60 帧）后应被扶起
	var rescuer: LivingObject = gu.add_soldier(LivingObject.FR_WARRIOR, null, 1, true)
	rescuer.set_external_position(npc.position + Vector2(10, 0))
	for _i in 61:
		obj.update()
	check(npc.is_downed == false, "60 frames of a rescuer nearby revives the downed npc")
	check(npc.cur_health == int(npc.health * 0.3), "revive restores 30%% health (got %d/%d)" % [npc.cur_health, npc.health])

	# 超时：再次打倒地，这次没有救援者在附近，downed_window_s=3.0 (90 帧) 后应真正死亡
	npc.bring_damage(npc.cur_health + 10, null)
	check(npc.is_downed == true, "second lethal hit re-enters downed")
	rescuer.set_external_position(Vector2(600, 10))  # 移出救援半径
	for _i in 92:
		obj.update()
	check(npc.is_downed == false and npc.cur_health <= 0, "downed window timeout (90 frames) kills the npc for real (cur_health=%d)" % npc.cur_health)
	check(obj.state == Ch2ObjectiveBase.STATE_FAILED, "escort objective fails once survivors drop below min")


## compute_stars：1 星胜利；2 星达到 losses_max；3 星再加 optional 完成。
func test_compute_stars(h: Harness) -> void:
	var gu := h.start_level(0, SEED, 1, true, 2)
	var level: LevelCh2 = gu.level_info as LevelCh2
	level.director.losses = 0
	check(level.compute_stars() == 2, "0 losses (<= tier-2 losses_max 3), optional not done -> 2 stars (got %d)" % level.compute_stars())
	level.director.losses = 5
	check(level.compute_stars() == 1, "losses exceed tier-2 losses_max -> only 1 star (got %d)" % level.compute_stars())
	level.director.losses = 0
	level.director.objectives_by_id["medicine_chest"].state = Ch2ObjectiveBase.STATE_COMPLETE
	check(level.compute_stars() == 3, "0 losses + optional complete -> 3 stars (got %d)" % level.compute_stars())
