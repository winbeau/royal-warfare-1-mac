extends SceneTree
# AS3 未捕获异常语义（game/rw/as3.gd）：事件监听里的错误只中止"这一次"监听调用。
# 战斗主循环是单个 ENTER_FRAME 监听 globalUpdate，所以单位 update() 抛错后，本帧剩下的内容全部跳过
# （后面所有单位的更新、质心、z 排序、尸体处理、UI、updateEffects、2x 速度的第二遍），下一帧照常运行。
# 覆盖：
#  - level_23greenroad 第 4 环 ringPoints[12] 越界（check_obstacles）：同帧后面的单位没更新、全局计数 +1 而非 +2（2x），
#    下一帧恢复；抛错前的状态保留（aObstacleRoute 已清空）、调用链上的 setCoordinates 没执行；
#  - enemy_hit_sound 的 cur_target 为 null：抛错穿透 attack_done，帧推进/收尾被跳过；
#  - IceVisual.update 的 enemy 为 null、Level3 set_external_position(null)、VinDef 翻页越界：置标志；
#  - 入口隔离：begin_entry 清标志，Tween 回调里抛错不影响下一个回调与主循环。
# 运行：Godot --headless --path . --script tests/as3_abort.gd -- --isolated-profile
const Harness := preload("res://tests/support/battle_harness.gd")

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
	AS3.log_errors = false
	var h := Harness.new(self)
	h.boot()
	test_primitives()
	test_frame_abort(h, 1)
	test_frame_abort(h, 2)
	test_enemy_hit_sound(h)
	test_other_sites()
	test_entries_isolated(h)
	check(h.catcher.errors.is_empty(), "no engine script errors: %s" % [h.catcher.errors.slice(0, 5)])
	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func test_primitives() -> void:
	AS3.begin_entry()
	var n := AS3.error_count
	check(not AS3.aborted, "begin_entry clears the flag")
	AS3.throw_error("x")
	check(AS3.aborted and AS3.error_count == n + 1 and AS3.last_error == "x", "throw_error sets flag, counts and records")
	AS3.end_entry()
	check(not AS3.aborted, "end_entry clears the flag")


## level_23greenroad 第 4 环只有 12 个点、编号 1..12：ringPoints[12] 为 undefined（第 20 关会出现）。
func ring4_clip() -> RWLayoutClip:
	var parent := RWLayoutClip.new()
	for i in range(1, 13):
		var c := RWLayoutClip.new()
		c.name = "p4_%d" % i
		c.x = 100 + 40 * i
		c.y = 100
		parent.children.append(c)
	return parent


func make_walker(gu: GameUniverse, x: float, y: float) -> LivingObject:
	var u := gu.add_soldier(LivingObject.FR_WARRIOR, null, 1, true)
	u.set_coordinates(x, y)
	u.a_soldier_main_route = []
	u.a_obstacle_route = []
	u.cur_target = null
	u.cur_battle = null
	u.in_action = true
	return u


func test_frame_abort(h, speed: int) -> void:
	h.boot()
	var gu: GameUniverse = h.start_level(0, 777)
	h.dismiss_chat()
	h.set_speed(speed)
	# 路径掩码：整张图不可走，使任何一步都进入 check_obstacles 的绕障分支
	var bd := RWBitmapData.new("", 700, 600)
	for i in range(0, 700 * 600 * 3, 3):
		bd._data[i] = 255
	gu.path_bd = bd
	gu.obstacle_way_points = ring4_clip()
	# 清掉关卡自带单位的影响：只保留我们的三个探针（A 在前，B 抛错，C 在后）
	gu.a_all_units.clear()
	var a := make_walker(gu, 300, 300)
	var b := make_walker(gu, 100 + 40 * 12 + 2, 100)  # 最近的路点是 p4_12 -> start_num 12 == ring_points.size()
	var c := make_walker(gu, 320, 320)
	check(gu.a_all_units == [a, b, c], "probe units are in update order a, b, c")
	# B 的目的地靠近 p4_3，使起终点是不同路点
	b.a_soldier_main_route = [Vector2(100 + 40 * 3, 100)]
	b.dest_point = b.a_soldier_main_route[0]
	var bx := b.position.x
	var by := b.position.y
	# 基线：路径可走时一帧里每个单位的 attack_counter 增量（每次 update 的增量由单位实现决定，这里不假设）
	var open_bd := RWBitmapData.new("", 700, 600)
	var solid_bd := gu.path_bd
	gu.path_bd = open_bd
	b.a_soldier_main_route = []
	var base_a := a.attack_counter
	var base_c := c.attack_counter
	gu._physics_process(1.0 / 30.0)
	var da := a.attack_counter - base_a
	var dc := c.attack_counter - base_c
	check(da > 0 and da == dc, "baseline frame: a and c both updated (%d, %d)" % [da, dc])
	gu.path_bd = solid_bd
	b.set_coordinates(bx, by)
	b.a_obstacle_route = []
	b.a_soldier_main_route = [Vector2(100 + 40 * 3, 100)]
	b.dest_point = b.a_soldier_main_route[0]
	var a0 := a.attack_counter
	var c0 := c.attack_counter
	var g0 := gu.global_counter
	var errs := AS3.error_count
	AS3.begin_entry()
	gu._physics_process(1.0 / 30.0)
	var tag := "[%dx]" % speed
	check(AS3.error_count == errs + 1 and AS3.last_error.contains("checkObstacles ringPoints[12]"), tag + " check_obstacles throws exactly once (got %s)" % AS3.last_error)
	check(not AS3.aborted, tag + " global_update clears the flag when the entry ends")
	check(a.attack_counter == a0 + da / speed, tag + " unit before the thrower was updated once (da %d, %d->%d)" % [da, a0, a.attack_counter])
	check(b.a_obstacle_route.is_empty(), tag + " thrower keeps the pre-throw state (aObstacleRoute cleared)")
	check(b.position == Vector2(bx, by), tag + " set_coordinates after check_obstacles did not run (call chain unwound)")
	check(c.attack_counter == c0, tag + " units after the thrower were NOT updated this frame")
	check(gu.global_counter == g0 + 1, tag + " second pass at 2x skipped; main_update_function ran once (counter %d -> %d)" % [g0, gu.global_counter])
	# 下一帧恢复：路径可走，B 不再抛错，C 恢复更新，2x 下计数 +2
	gu.path_bd = open_bd
	var a1 := a.attack_counter
	var c1 := c.attack_counter
	var g1 := gu.global_counter
	var errs2 := AS3.error_count
	gu._physics_process(1.0 / 30.0)
	check(AS3.error_count == errs2, tag + " next frame has no error")
	check(c.attack_counter - c1 == dc and a.attack_counter - a1 == da, tag + " next frame: later units update again (%d pass(es)) a %d->%d c %d->%d" % [speed, a1, a.attack_counter, c1, c.attack_counter])
	check(gu.global_counter == g1 + speed, tag + " next frame runs %d main_update_function pass(es)" % speed)
	h.stop_level()


class Attacker extends LivingObject:
	func got_experience(_p: float) -> void:
		pass

## bring_damage 的副作用清空攻击者的 curTarget（如 SpecMissAssasin 一类）。
class Victim extends LivingObject:
	var attacker: LivingObject = null
	var clear_attacker_target := true
	func bring_damage(_p1: int, _p2: LivingObject, _p3: bool = false, _p4: bool = true) -> void:
		if clear_attacker_target:
			attacker.cur_target = null


## attack_done -> enemy_hit_sound 在 cur_target 为 null 时抛错：异常穿透 attack_done -> on_play_head_done ->
## main_alg_update_sprite，帧推进（cur_frame += 1）与收尾都被跳过；没抛错时照常推进。
func test_enemy_hit_sound(h) -> void:
	h.boot()
	var bm := BmpFrames.from_symbol("warriorAttackAni")
	var done_frame := 10
	check(bm.frame_commands[done_frame] == BmpFrames.DONE, "warriorAttackAni frame 10 is DONE")
	for clear in [true, false]:
		var u := Attacker.new()
		var v := Victim.new()
		u.sprite = Sprite2D.new()
		u.s = SoundLibrary.inst
		u.current_bm = bm
		u.cur_frame = done_frame
		u.cur_stanse = LivingObject.FIGHTING
		u.in_action = true
		u.play_head_stance = LivingObject.PLAYING
		u.play_flag = false
		u.cur_damage = 10
		v.attacker = u
		v.clear_attacker_target = clear
		v.cur_health = 50
		u.cur_target = v
		AS3.begin_entry()
		u.main_alg_update_sprite()
		if clear:
			check(AS3.aborted and AS3.last_error.contains("enemyHitSound"), "cur_target cleared by bring_damage -> enemy_hit_sound throws")
			check(u.cur_frame == done_frame, "exception unwound main_alg_update_sprite: cur_frame not advanced")
		else:
			check(not AS3.aborted and u.cur_frame == done_frame + 1, "no throw: frame advances normally")
		AS3.end_entry()
		u.sprite.free()
		u.free()
		v.free()


func test_other_sites() -> void:
	# IceVisual.update：enemy 为 null 且冰冻计数未结束
	AS3.begin_entry()
	var ice := IceVisual.new()
	ice.freeze_counter = 5
	ice.enemy = null
	ice.update()
	check(AS3.aborted and AS3.last_error.contains("IceVisual.update"), "IceVisual.update with null enemy throws")
	check(ice.freeze_counter == 4, "IceVisual.update: freezeCounter-- happened before the throw")
	AS3.end_entry()
	ice.free()
	# VinDefPanelAchivesController.show_page 越界
	AS3.begin_entry()
	var holder := Control.new()
	var ec := FlashClip.new()
	holder.add_child(ec)
	VinDefPanelAchivesController.e_cont = ec
	VinDefPanelAchivesController.a_pages = [[1, 2]]
	VinDefPanelAchivesController.show_page(2)
	check(AS3.aborted and AS3.last_error.contains("showPage"), "VinDefPanelAchivesController.show_page out of range throws")
	AS3.end_entry()
	holder.free()
	VinDefPanelAchivesController.a_pages = []
	VinDefPanelAchivesController.e_cont = null


func test_entries_isolated(h) -> void:
	# Tween 回调是独立入口：回调里抛错只中止该回调；之后的回调和主循环不受影响
	h.boot()
	var seen := []
	var d := Node2D.new()
	RWTween.delayed_call(0.1, func():
		AS3.throw_error("in tween callback")
		seen.append("first"))
	RWTween.delayed_call(0.2, func():
		seen.append("second:" + str(AS3.aborted)))
	RWTween.step(0.3)
	check(seen.has("first") and seen.has("second:false"), "tween callbacks run independently of an earlier throw (%s)" % [seen])
	check(not AS3.aborted, "flag cleared after the tween callback entry")
	d.free()
	# 按钮监听：一个监听抛错不影响其余监听
	AS3.begin_entry()
	AS3.throw_error("stale")
	AS3.begin_entry()
	check(not AS3.aborted, "begin_entry on a new entry discards a stale flag")
