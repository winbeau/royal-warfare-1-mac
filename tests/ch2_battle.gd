extends SceneTree
# WP-B 验证：第二章第 01、02 关端到端战斗。参照 tests/battle_level1.gd 与 tests/support/battle_harness.gd。
# 每关各跑两局（胜局、败局），1x 和 2x 速度各一次：
#   - 胜局：每个敌人出生满 N 帧后直接杀死，以此推进阶段；断言全部阶段推进、胜利触发、星数在 1-3、无脚本错误。
#   - 败局：直接杀死护送者/设施并让倒地窗口超时；断言失败触发。
const Harness := preload("res://tests/support/battle_harness.gd")
const SEED := 20261102
const MAX_FRAMES := 20000

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
	for level in [0, 1]:  # 0 基：01.json / 02.json
		for speed in [1, 2]:
			win_scenario(h, level, speed)
		lose_scenario(h, level)
	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


## Harness.dismiss_chat() 只复位 on_stage 并 unpause，不调用 LevelTemplate.chat_closed()（真正的
## ChatFrameController.close_chat() 才调用）。二章的对白 tag 关闭靠这个钩子转发给 Ch2Director，
## 所以这里在 dismiss 之前先手动补一次钩子调用，不改共享的 battle_harness.gd。
func _ch2_frame(h: Harness) -> void:
	if h.gu.is_paused and not h.gu.is_end_game:
		h.gu.level_info.chat_closed()
	h.frame()


## 每个出生满 N 帧的敌人直接杀死：以此替代真实作战推进阶段（关注导演/目标流程，不关注战斗数值）。
func _kill_grown_enemies(gu: GameUniverse, born_at: Dictionary, grow_frames: int) -> void:
	for u: LivingObject in gu.a_all_units.duplicate():
		if u.friendly:
			continue
		if not born_at.has(u):
			born_at[u] = gu.global_counter
		elif gu.global_counter - int(born_at[u]) >= grow_frames and u.cur_health > 0:
			u.bring_damage(u.health + 999, null)


func win_scenario(h: Harness, level: int, speed: int) -> void:
	var tag := "level%d x%d win" % [level + 1, speed]
	var gu := h.start_level(level, SEED + level, 1, true, 2)
	h.set_speed(speed)
	var director: Ch2Director = (gu.level_info as LevelCh2).director
	check(director != null, "%s: director exists" % tag)
	var born_at := {}
	var frames := 0
	var err_before := h.catcher.errors.size()
	while frames < MAX_FRAMES and not h.ended():
		_kill_grown_enemies(gu, born_at, 10)
		_ch2_frame(h)
		frames += 1
	check(h.ended(), "%s: battle reaches an ending within %d frames" % [tag, MAX_FRAMES])
	check(gu.is_end_game and gu.vic_panel != null and gu.vic_panel.get_parent() != null, "%s: victory panel is on stage" % tag)
	for ph: Dictionary in director.phases:
		check(str(ph["state"]) == "done", "%s: phase %s reached done (got %s)" % [tag, ph["id"], ph["state"]])
	var level_info: LevelCh2 = gu.level_info as LevelCh2
	var stars := level_info.compute_stars()
	check(stars >= 1 and stars <= 3, "%s: compute_stars in 1..3 (got %d)" % [tag, stars])
	check(h.catcher.errors.size() == err_before, "%s: no script errors (%s)" % [tag, h.catcher.errors.slice(err_before, err_before + 5)])


## 败局：直接打倒护送/撤离目标里的第一个单位（若是 escort，等倒地窗口超时；若是 evac，直接视为战损），
## 并在设施类目标上直接清空血量；两者任一都应触发 failure。
func lose_scenario(h: Harness, level: int) -> void:
	var tag := "level%d lose" % (level + 1)
	var gu := h.start_level(level, SEED + 100 + level, 1, true, 2)
	var director: Ch2Director = (gu.level_info as LevelCh2).director
	var err_before := h.catcher.errors.size()
	# 把玩家可控单位挪到角落：避免它们恰好停留在倒地目标 30px 范围内把它救起，
	# 让败局测试稳定地只测"没人救援时会不会真的判负"。
	for u: LivingObject in gu.a_all_units:
		if u.friendly and not u.is_npc and not u.ch2_uncontrollable:
			u.set_external_position(Vector2(690, 10))
	var frames := 0
	while frames < MAX_FRAMES and not h.ended():
		for obj: Ch2ObjectiveBase in director.objectives:
			if obj is Ch2EscortObjective:
				for m: Ch2EscortNpc in (obj as Ch2EscortObjective).members:
					if is_instance_valid(m) and m.cur_health > 0 and not m.is_downed:
						m.bring_damage(m.cur_health + 10, null)
			elif obj is Ch2ProtectObjective:
				var facility: LivingObject = (obj as Ch2ProtectObjective).facility
				if is_instance_valid(facility) and facility.cur_health > 0:
					facility.bring_damage(facility.health + 999, null)
		h.frame()
		frames += 1
	check(h.ended(), "%s: battle reaches an ending within %d frames" % [tag, MAX_FRAMES])
	check(gu.is_end_game and gu.def_panel != null and gu.def_panel.get_parent() != null, "%s: defeat panel is on stage" % tag)
	check(h.catcher.errors.size() == err_before, "%s: no script errors (%s)" % [tag, h.catcher.errors.slice(err_before, err_before + 5)])
