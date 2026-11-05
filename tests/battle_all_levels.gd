extends SceneTree
# 集成 I2：24 关冒烟测试。每关按原版流程初始化（Main.loadGame -> gameUniverse.init(下标)），逐帧运行最多 FRAMES 帧，
# 带简单的自动招募与攻击指令，并在开局放入全部 17 种友军（满级技能全解锁）以覆盖各兵种和技能路径。
# 目的：暴露关卡钩子、兵种、技能、特效在实际运行中触发的运行时错误（任何核心脚本错误都算失败）。
# 教学关 levelIntro（下标 -2）尚未移植，跳过。必须带 -- --isolated-profile。
const Harness := preload("res://tests/support/battle_harness.gd")
const FRAMES := 3000
const SEED := 424242

# 友军全部 kind（LivingObject.FR_*），由 add_soldier(kind, null, 3, true) 免费放置（与关卡钩子 loading_completed_handler 同一路径）
const FRIEND_KINDS := [
	LivingObject.FR_WARRIOR, LivingObject.FR_SWORDMASTER, LivingObject.FR_KNIGHT, LivingObject.FR_ARCHER,
	LivingObject.FR_CROSSBOW, LivingObject.FR_SNIPER, LivingObject.FR_BLUEMAGE, LivingObject.FR_REDMAGE,
	LivingObject.FR_BLACKMAGE, LivingObject.FR_PRIEST, LivingObject.FR_HEALER, LivingObject.FR_BLESSER,
	LivingObject.FR_ROGUE, LivingObject.FR_ASSASIN, LivingObject.FR_SABOTEUR,
]

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
	var only := _arg_level()
	var rows: Array = []
	var all_kinds_seen: Dictionary = {}
	for level in range(0, 24):
		if only >= 0 and level != only:
			continue
		var r := run_level(h, level)
		rows.append(r)
		for k in r["kinds"]:
			all_kinds_seen[k] = true
		print("LEVEL %2d frames=%d counter=%d enemies_spawned=%d dead=%d friends_dead=%d money=%d lives=%d ended=%s victory=%s core_errors=%d ui_errors=%d kinds=%d mem=%dMB nodes=%d orphans=%d" % [
			level + 1, r["frames"], r["counter"], r["spawned"], r["dead"], r["friends_dead"], r["money"], r["lives"], r["ended"], r["victory"], r["core_errors"], r["ui_errors"], r["kinds"].size(), OS.get_static_memory_usage() / 1048576, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	var ui_total := 0
	for m in h.catcher.ui_errors:
		ui_total += int(h.catcher.ui_errors[m])
	print("UI_ERRORS %d distinct, %d total (界面层文件内的报错，不计入核心)" % [h.catcher.ui_errors.size(), ui_total])
	for m in h.catcher.ui_errors.keys().slice(0, 12):
		print("  UI ", m)
	print("unit kinds seen alive at some point: ", all_kinds_seen.size())
	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _arg_level() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			return int(a.trim_prefix("--level=")) - 1
	return -1

func run_level(h: Harness, level: int) -> Dictionary:
	var err_before := h.catcher.errors.size()
	var ui_before := h.catcher.ui_errors.size()
	# 难度 1/2/3 轮换、奇数下标的关卡用 2x 速度，扩大覆盖面（difficulty 2/3 会提升敌人等级）
	var gu := h.start_level(level, SEED + level, 1 + level % 3, false)
	h.set_speed(2 if level % 2 == 1 else 1)
	var tag := "level %d" % (level + 1)
	check(gu.level_info != null and gu.level_info.level_bg != "", "%s: level template loaded" % tag)
	check(gu.num_lifes > 0, "%s: lives set (%d)" % [tag, gu.num_lifes])
	var spawned := 0
	var dead := 0
	var friends_dead := 0
	var kinds: Dictionary = {}
	var dead_seen: Dictionary = {}
	var prev: Dictionary = {}
	for u in gu.a_all_units:
		prev[u] = true
		kinds[u.kind] = true
	var frames := 0
	var squad_added := false
	var upgraded := 0
	var recruit_cycle := [LivingObject.FR_WARRIOR, LivingObject.FR_ARCHER, LivingObject.FR_PRIEST, LivingObject.FR_BLUEMAGE, LivingObject.FR_ROGUE]
	while frames < FRAMES and not h.ended():
		frames += 1
		if frames == 20 and not squad_added:
			squad_added = true
			var i := 0
			for k in FRIEND_KINDS:
				var u := gu.add_soldier(k, null, 3, true)
				if u != null:
					u.unlock_abils_set_max_level()
					u.set_external_position(Vector2(160 + 22 * (i % 5), 200 + 40 * (i / 5)))
				i += 1
		if frames == 300:
			# 升级路径：mainGameUI_ex 的升级按钮最终调用 addSoldier(新兵种, 旧单位)
			var up := {LivingObject.FR_WARRIOR: LivingObject.FR_KNIGHT, LivingObject.FR_ARCHER: LivingObject.FR_SNIPER,
				LivingObject.FR_BLUEMAGE: LivingObject.FR_BLACKMAGE, LivingObject.FR_PRIEST: LivingObject.FR_BLESSER,
				LivingObject.FR_ROGUE: LivingObject.FR_SABOTEUR}
			for old in h.friends():
				if up.has(old.kind) and old.cur_health > 0 and upgraded < 5:
					upgraded += 1
					gu.add_soldier(up[old.kind], old)
					up.erase(old.kind)
		if frames > 60 and frames % 60 == 0:
			h.auto_recruit(recruit_cycle)
		if frames > 40 and frames % 20 == 0:
			h.auto_orders()
		h.frame()
		for u in gu.a_all_units:
			kinds[u.kind] = true
			if not prev.has(u) and not u.friendly:
				spawned += 1
			if u.cur_health <= 0 and not dead_seen.has(u):
				dead_seen[u] = true
				if u.real_friendly:
					friends_dead += 1
				else:
					dead += 1
		var cur: Dictionary = {}
		for u in gu.a_all_units:
			cur[u] = true
		prev = cur
		for u in dead_seen.keys():
			if not gu.a_all_units.has(u) and not gu.a_waiting_death.has(u):
				dead_seen.erase(u)
	var new_errors := h.catcher.errors.slice(err_before)
	check(new_errors.is_empty(), "%s: no core script errors: %s" % [tag, _summarize(new_errors)])
	check(upgraded > 0, "%s: upgrade path exercised (%d)" % [tag, upgraded])
	check(frames > 0 and gu.global_counter >= frames, "%s: ran %d frames (global_counter %d)" % [tag, frames, gu.global_counter])
	var victory := gu.vic_panel.get_parent() != null
	return {
		"frames": frames, "counter": gu.global_counter, "spawned": spawned, "dead": dead, "friends_dead": friends_dead,
		"money": int(gu.current_money), "lives": gu.num_lifes, "ended": gu.is_end_game, "victory": victory,
		"core_errors": new_errors.size(), "ui_errors": h.catcher.ui_errors.size() - ui_before, "kinds": kinds.keys(),
	}

func _summarize(errs: Array) -> String:
	var counts := {}
	for e in errs:
		counts[e] = int(counts.get(e, 0)) + 1
	var out: Array = []
	for k in counts:
		out.append("%dx %s" % [counts[k], str(k).left(240)])
		if out.size() >= 6:
			break
	return "; ".join(out)
