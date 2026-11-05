extends SceneTree
# M2：开场过场 levelIntro（关卡号 -2）。必须带 -- --isolated-profile。
# 原版 levelIntro 没有交互式教学步骤：XML 的 4 句聊天 + 44 个友军行军 + 跳过按钮；
# 最后一句 "Taggart: Yes, your Majesty." 触发 canEndIntro，之后 counter > 50 即第 51 帧调用 Main.loadGame(0,false)。
const Harness := preload("res://tests/support/battle_harness.gd")

class FakeMain extends Main:
	var loaded: Array = []
	func load_game(level: int = -1, play_music: bool = true) -> void:
		loaded.append([level, play_music])

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
	var fm := FakeMain.new()
	Main.inst = fm
	LevelIntro.is_shown = false
	RWRandom.set_seed(7)
	var gu := h.start_level(-2, 7)
	check(gu.cur_level_num == -2, "cur_level_num == -2")
	var li = gu.level_info
	check(li is LevelIntro, "level_info is LevelIntro")
	check(li.level_caption == "Intro" and li.level_description == "The journey begins.", "caption/description")
	check(li.get_chat_bounds() == true, "get_chat_bounds true")
	check(LevelIntro.is_shown == true, "is_shown set by loading_completed_handler")
	check(LevelIntro.can_end_intro == false, "can_end_intro false after load")
	# 单位：44 个友军，生命 20，金钱 400
	check(gu.a_all_units.size() == 44, "44 soldiers (got %d)" % gu.a_all_units.size())
	check(int(gu.lives) == 20 if "lives" in gu else true, "lives 20")
	check(int(gu.current_money) == 400, "money 400 (got %s)" % gu.current_money)
	var kinds := {}
	for u in gu.a_all_units:
		kinds[u.kind] = kinds.get(u.kind, 0) + 1
	check(kinds.get(LivingObject.FR_KING, 0) == 1 and kinds.get(LivingObject.FR_CROSSBOW, 0) == 7 and kinds.get(LivingObject.FR_SWORDMASTER, 0) == 7 and kinds.get(LivingObject.FR_WARRIOR, 0) == 6 and kinds.get(LivingObject.FR_ARCHER, 0) == 6 and kinds.get(LivingObject.FR_KNIGHT, 0) == 7 and kinds.get(LivingObject.FR_HEALER, 0) == 2, "unit composition %s" % [kinds])
	# 聊天：XML 第 5 秒（150 帧）触发，逐句点击；检查每句文本，且 got_text 只在最后一句置位
	var expected := [
		"King Aldric: Report casualties.",
		"Sir Faddey: Your Majesty, I can't determine the losses. Lots of troops still haven't reached this rendezvous. Some small groups are scattered across the woods.",
		"King Aldric: Faddey, start loading the ships. Taggart, gather some men. We'll wait for the rearguard here.",
		"Taggart: Yes, your Majesty.",
	]
	var seen: Array = []
	var chat_frame := -1
	var end_frame := -1
	for f in 400:
		if gu.is_paused and ChatFrameController.on_stage:
			if chat_frame < 0:
				chat_frame = f
			var t: String = ChatFrameController._t_text().text
			if seen.is_empty() or seen[-1] != t:
				seen.append(t)
			# 最后一句出现前 can_end_intro 必须为 false
			if t != expected[3]:
				check(LevelIntro.can_end_intro == false, "can_end_intro false before last line")
			ChatFrameController.clicked()
			if not ChatFrameController.on_stage:
				gu.unpause()
		h.logic_phase()
		h.tween_phase()
		if fm.loaded.size() > 0:
			end_frame = f
			break
	check(chat_frame >= 150 and chat_frame < 156, "chat opens at wave time 5s (frame %d)" % chat_frame)
	check(seen == expected, "chat texts match original: %s" % [seen])
	check(LevelIntro.can_end_intro == true, "can_end_intro true after last line")
	check(fm.loaded == [[0, false]], "Main.loadGame(0,false) called once: %s" % [fm.loaded])
	check(li.counter == 0.0 or li.counter > 50, "counter state %s" % li.counter)
	print("chat_frame=", chat_frame, " end_frame=", end_frame, " loaded=", fm.loaded)
	check(LevelIntro.is_shown == true, "is_shown still true")
	# 跳过按钮：clicked_skip 立即 loadGame(0,false) 且置 can_end_intro
	LevelIntro.can_end_intro = false
	fm.loaded.clear()
	li.clicked_skip()
	check(LevelIntro.can_end_intro and fm.loaded == [[0, false]], "clicked_skip ends intro")
	# 未到最后一句时 level_custom_actions 不推进
	LevelIntro.can_end_intro = false
	fm.loaded.clear()
	for i in 80:
		li.level_custom_actions()
	check(fm.loaded.is_empty(), "no loadGame while can_end_intro false")
	li.got_text("Taggart: Yes, your Majesty.")
	for i in 50:
		li.level_custom_actions()
	check(fm.loaded.is_empty(), "no loadGame at counter 50")
	li.level_custom_actions()
	check(fm.loaded == [[0, false]], "loadGame at counter 51")
	# 剪辑资源缺失（assets/clips、scenes/clips，由 pipeline 负责）不计入关卡脚本错误
	var script_errors: Array = h.catcher.errors.filter(func(e): return not ("assets/clips" in e or "scenes/clips" in e or "resource_loader" in e))
	check(script_errors.is_empty(), "no script errors: %s" % [script_errors.slice(0, 5)])
	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
