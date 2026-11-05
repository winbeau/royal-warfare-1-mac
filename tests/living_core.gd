extends SceneTree
# LivingObject / SpecialTemplate 的纯逻辑测试：不依赖完整 GameUniverse（除 check_obstacles 用一个未入树的最小实例提供 pathBD 和路点）。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func near(a: float, b: float, eps: float = 1e-9) -> bool:
	return absf(a - b) <= eps

class TestUnit extends LivingObject:
	var events: Array = []
	var last_damage: int = -1
	func on_play_head_done() -> void:
		events.append(["done", cur_frame])
	func on_play_head_action() -> void:
		events.append(["action", cur_frame])
	func on_play_head_stopped() -> void:
		events.append(["stopped", cur_frame])
	func got_experience(_p: float) -> void:
		pass
	func enemy_hit_sound() -> void:
		pass
	func bring_damage(p1: int, _p2: LivingObject, _p3: bool = false, _p4: bool = true) -> void:
		last_damage = p1

class RealTarget extends LivingObject:
	func got_experience(_p: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not root.get_node("Content").isolated_profile:
		quit(2)
		return
	test_proportional_reset()
	test_update_sprite_commands()
	test_stance_release()
	test_attack_damage_formula()
	test_bring_damage_min_damage()
	test_stats_from_xml()
	test_minus_units()
	test_check_obstacles()
	test_hit_sens()
	test_special_template()
	test_cooldown_tabs()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func test_proportional_reset() -> void:
	var u := TestUnit.new()
	# round(param1 * (param2 / param3))，<=0 记 1，>= param4 记 param4
	check(u.proportional_reset_int(30, 20, 40, 60) == 15, "proportional 30*(20/40)=15")
	check(u.proportional_reset_int(100, 50, 100, 80) == 50, "proportional 100*0.5=50")
	check(u.proportional_reset_int(100, 100, 100, 80) == 80, "proportional clamp to max")
	check(u.proportional_reset_int(0, 20, 40, 60) == 1, "proportional zero -> 1")
	check(u.proportional_reset_int(3, 1, 3, 60) == 1, "proportional 3*(1/3)=1")
	check(u.proportional_reset_int(5, 1, 2, 60) == 3, "proportional 2.5 rounds up to 3")
	check(u.proportional_reset_int(-5, 1, 2, 60) == 1, "proportional -2.5 -> -2 -> <=0 -> 1")
	u.free()

func test_update_sprite_commands() -> void:
	var bm := BmpFrames.from_symbol("warriorAttackAni")
	check(bm != null and bm.num_frames == 20, "warriorAttackAni has 20 frames")
	check(bm.frame_commands[0] == BmpFrames.STOP and bm.frame_commands[5] == BmpFrames.ACTION and bm.frame_commands[10] == BmpFrames.DONE, "warriorAttackAni commands STOP@0 ACTION@5 DONE@10")
	var u := TestUnit.new()
	u.sprite = Sprite2D.new()
	u.current_bm = bm
	u.cur_frame = 0
	u.in_action = true
	u.play_head_stance = LivingObject.PLAYING
	u.play_head_start_play()  # playFlag = true, playHeadStance = PLAYING(0)
	check(u.play_flag and u.play_head_stance == LivingObject.PLAYING, "playHeadStartPlay sets playFlag")
	# 第 1 次：frame 0 是 STOP，但 playFlag 为 true -> 放行；playFlag 复位，推进到 frame 1
	u.main_alg_update_sprite()
	check(u.events.is_empty(), "no hook on first frame with playFlag")
	check(not u.play_flag, "playFlag reset after first frame")
	check(u.cur_frame == 1, "advance to frame 1")
	check(u.sprite.texture == bm.get_frame_texture(1), "sprite shows frame 1 texture")
	for _i in 30:
		u.main_alg_update_sprite()
	check(u.events == [["action", 5], ["done", 10], ["stopped", 0]], "hooks fired at 5 (action), 10 (done), then STOP at 0: %s" % [u.events])
	check(u.play_head_stance == LivingObject.STOPPED and u.cur_frame == 0, "stopped on frame 0 after full cycle")
	u.sprite.free()
	u.free()

func test_stance_release() -> void:
	var attack := BmpFrames.from_symbol("warriorAttackAni")
	var stay := BmpFrames.from_symbol("warriorStayAni")
	var u := TestUnit.new()
	u.bmp_attack = attack
	u.bmp_stay = stay
	u.cur_stanse = LivingObject.FIGHTING
	u.current_bm = attack
	u.cur_frame = 7
	u.set_stance(LivingObject.STAND)
	check(u.cur_stanse == LivingObject.FIGHTING, "stance change deferred while attacking mid-animation")
	check(u.attack_stance_release_counter == 20 - 7 + 10, "FIGHTING release counter = totalFrames - curFrame + 10")
	check(u.next_stance == LivingObject.STAND, "nextStance recorded")
	var v := TestUnit.new()
	v.bmp_ranged = attack
	v.cur_stanse = LivingObject.RANGED_SHOOT
	v.current_bm = attack
	v.cur_frame = 7
	v.set_stance(LivingObject.STAND)
	check(v.attack_stance_release_counter == 20 - 7, "RANGED release counter = totalFrames - curFrame (no +10)")
	var w := TestUnit.new()
	w.bmp_casting = attack
	w.cur_stanse = LivingObject.FIGHTING
	w.current_bm = attack
	w.cur_frame = 7
	w.bmp_casting = attack
	w.set_stance(LivingObject.CASTING)
	check(w.cur_stanse == LivingObject.CASTING and w.attack_stance_release_counter == 0, "switching to CASTING is immediate")
	# 倒数结束：清零、curFrame = 0、setStance(next)；STAND 取随机起始帧（消耗 1 次 rand）
	u.in_action = true
	u.play_head_stance = LivingObject.STOPPED  # 不处理帧命令，仅走收尾
	RWRandom.set_seed(777)
	var probe_seed := 777
	RWRandom.set_seed(probe_seed)
	var expected_frame := RWRandom.rand_range(0, stay.num_frames - 1)
	var state_after_one := RWRandom.get_state()
	RWRandom.set_seed(probe_seed)
	for _i in 22:
		u.main_alg_update_sprite()
	check(u.cur_stanse == LivingObject.FIGHTING and u.attack_stance_release_counter == 1, "still counting down after 22 ticks")
	u.main_alg_update_sprite()
	check(u.cur_stanse == LivingObject.STAND and u.attack_stance_release_counter == 0, "stance switched when counter hits 0")
	check(u.cur_frame == expected_frame, "STAND start frame comes from randRange(0, totalFrames-1)")
	check(RWRandom.get_state() == state_after_one, "exactly one rand consumed by the switch")
	u.free()
	v.free()
	w.free()

func test_attack_damage_formula() -> void:
	var attacker := TestUnit.new()
	var target := TestUnit.new()
	attacker.cur_target = target
	var cases := [[10, 0.5, 0.1, 6], [7, 0.7, 0.2, 3], [10, 0.2, 0.5, 10], [9, 1.0, 0.0, 0], [20, 0.3, 0.3, 20]]
	for c in cases:
		attacker.cur_damage = c[0]
		attacker.armor_piercing_melee = c[2]
		target.cur_armor = c[1]
		target.cur_health = 50
		target.last_damage = -1
		attacker.attack_done(null)
		var expected := int(c[0] * (1 - maxf(0.0, c[1] - c[2])))
		check(target.last_damage == expected, "attack_done damage %s -> %d (got %d)" % [c, expected, target.last_damage])
		check(expected == c[3], "formula expectation sanity %s" % [c])
	target.cur_health = 0
	target.last_damage = -1
	attacker.attack_done(null)
	check(target.last_damage == -1, "no damage to a dead target")
	attacker.free()
	target.free()

func test_bring_damage_min_damage() -> void:
	var saved_inst := GlobalData.inst
	var u := RealTarget.new()
	u.g = GlobalData.new()
	u.friendly = false
	var seen_one := false
	var seen_zero := false
	for sd in [1, 2, 3, 12345, 99, 31337, 424242]:
		RWRandom.set_seed(sd)
		var r := RWRandom.rand()
		var state1 := RWRandom.get_state()
		RWRandom.set_seed(sd)
		u.health = 100
		u.has_weak_spot = false
		u.is_harm_resisted = false
		u.bring_damage(0, null, true, false)
		var expect_hp := 99 if r > 0.66 else 100
		check(u.cur_health == expect_hp, "min damage rule seed %d: rand %.4f -> hp %d (got %d)" % [sd, r, expect_hp, u.cur_health])
		check(RWRandom.get_state() == state1, "0 damage consumes exactly one rand (seed %d)" % sd)
		if expect_hp == 99:
			seen_one = true
		else:
			seen_zero = true
	check(seen_one and seen_zero, "both branches of rand > 0.66 exercised")
	# 非 0 伤害不消耗 rand
	RWRandom.set_seed(5)
	var st := RWRandom.get_state()
	u.g.damage_dealt = 0
	u.health = 100
	u.bring_damage(5, null, true, false)
	check(u.cur_health == 95 and RWRandom.get_state() == st, "non-zero damage consumes no rand")
	check(int(u.g.damage_dealt) == 5, "damageDealt counts hits on enemies")
	# 弱点：floor(param1 * curWeakMod)；免疫：>0 记 1
	u.health = 100
	u.has_weak_spot = true
	u.cur_weak_mod = 1.5
	u.bring_damage(5, null, true, false)
	check(u.cur_health == 100 - 7, "weak spot floor(5 * 1.5) = 7")
	u.has_weak_spot = false
	u.health = 100
	u.is_harm_resisted = true
	u.bring_damage(40, null, true, false)
	check(u.cur_health == 99, "harm resisted caps positive damage at 1")
	u.is_harm_resisted = false
	# 治疗：负伤害不超过 health
	u.health = 100
	u.cur_health = 90
	u.bring_damage(-30, null, true, false)
	check(u.cur_health == 100, "heal clamps to health")
	GlobalData.inst = saved_inst
	u.free()

func test_stats_from_xml() -> void:
	var root_xml := RWXml.load_file("res://data/xml/6611_extDataManager_units.xml")
	check(root_xml != null, "units.xml loads")
	var warrior := root_xml.child("warrior")
	check(not warrior.is_empty(), "warrior node present")
	var u := TestUnit.new()
	u.set_stats_from_xml(warrior)
	check(u.a_health_levels == [80.0, 85.0, 90.0], "warrior Health 80/85/90: %s" % [u.a_health_levels])
	check(u.class_name_ != "", "warrior className read: '%s'" % u.class_name_)
	check(u.a_exp_levels.size() == 3 and u.a_walk_speed_levels.size() == 3, "triples")
	check(near(float(u.a_armor_levels[0]), 0.3), "warrior Armor.one 0.3")
	u.free()

func test_minus_units() -> void:
	var u := TestUnit.new()
	u.friendly = true
	for k in [LivingObject.FR_WARRIOR, LivingObject.FR_SWORDMASTER, LivingObject.FR_KNIGHT]:
		LivingObject.unit_num_warriors = 3
		u.kind = k
		u.minus_units()
		check(LivingObject.unit_num_warriors == 2, "minusUnits decrements warriors for kind %d" % k)
	LivingObject.unit_num_warriors = 3
	u.kind = LivingObject.FR_KING
	u.minus_units()
	check(LivingObject.unit_num_warriors == 3, "FR_KING is not decremented (original asymmetry)")
	LivingObject.unit_num_archers = 2
	u.kind = LivingObject.FR_SNIPER
	u.minus_units()
	check(LivingObject.unit_num_archers == 1, "sniper decrements archers")
	u.friendly = false
	LivingObject.unit_num_archers = 2
	u.minus_units()
	check(LivingObject.unit_num_archers == 2, "enemies never decrement")
	LivingObject.unit_num_warriors = 0
	LivingObject.unit_num_archers = 0
	u.free()

func ring_clip(points: Array) -> RWLayoutClip:
	var parent := RWLayoutClip.new()
	for i in points.size():
		var c := RWLayoutClip.new()
		c.name = "p1_%d" % i
		c.x = points[i].x
		c.y = points[i].y
		parent.children.append(c)
	return parent

func test_check_obstacles() -> void:
	var universe := GameUniverse.new()
	var bd := RWBitmapData.new("", 700, 600)
	# 阻挡 (150,150) 像素
	var idx := (150 * 700 + 150) * 3
	bd._data[idx] = 255
	universe.path_bd = bd
	var u := TestUnit.new()
	var ring := [Vector2(100, 100), Vector2(200, 100), Vector2(300, 100), Vector2(300, 200), Vector2(200, 200), Vector2(100, 200)]
	universe.obstacle_way_points = ring_clip(ring)
	# 下一步没被挡：不生成绕障路线
	var free_step := u.check_obstacles(Vector2(10, 10), Vector2(11, 11), Vector2(300, 300))
	check(free_step == Vector2(11, 11) and u.a_obstacle_route.is_empty(), "free step leaves aObstacleRoute empty")
	# 起点最近 p1_0，终点最近 p1_3：正反向等长(3) -> 取正向，去掉首点
	var ret := u.check_obstacles(Vector2(90, 120), Vector2(150, 150), Vector2(310, 190))
	check(ret == Vector2(150, 150), "checkObstacles always returns param2")
	check(u.a_obstacle_route == [Vector2(200, 100), Vector2(300, 100)], "tie picks forward: %s" % [u.a_obstacle_route])
	# 已有绕障路线时不重算
	var before := u.a_obstacle_route.duplicate()
	u.check_obstacles(Vector2(205, 95), Vector2(150, 150), Vector2(95, 205))
	check(u.a_obstacle_route == before, "existing route kept")
	# 起点最近 p1_1，终点最近 p1_5：正向 4 点，反向 2 点 -> 反向，去首点后剩 p1_0
	u.reset_obstacles()
	u.check_obstacles(Vector2(205, 95), Vector2(150, 150), Vector2(95, 205))
	check(u.a_obstacle_route == [Vector2(100, 100)], "shorter backward direction: %s" % [u.a_obstacle_route])
	# 正向经过屏幕外的点 -> 正向作废，取反向
	var ring2 := ring.duplicate()
	ring2[2] = Vector2(300, -50)
	universe.obstacle_way_points = ring_clip(ring2)
	u.reset_obstacles()
	u.check_obstacles(Vector2(90, 120), Vector2(150, 150), Vector2(310, 190))
	check(u.a_obstacle_route == [Vector2(100, 200), Vector2(200, 200)], "off-screen forward ring discarded: %s" % [u.a_obstacle_route])
	# 起终点同一路点：不绕障
	universe.obstacle_way_points = ring_clip(ring)
	u.reset_obstacles()
	u.check_obstacles(Vector2(90, 120), Vector2(150, 150), Vector2(95, 95))
	check(u.a_obstacle_route.is_empty(), "same nearest waypoint -> no detour")
	GameUniverse.inst = null
	universe.free()
	u.free()

func test_hit_sens() -> void:
	var u := TestUnit.new()
	u.sens_class = "warriorSens"
	u.health = 10
	u.init()
	root.add_child(u)
	u.position = Vector2(200, 300)
	check(u.sens != null and absf(u.sens.position.y + 13.25) < 1e-6, "sens.y = -sens.height / 2 (%f)" % u.sens.position.y)
	check(u.sprite != null and u.sprite.name == "sprite" and u.sprite_bm == u.sprite, "sprite node named 'sprite'")
	# sens 图像为全透明（Flash 透明热区栅格化后 alpha 全为 0），退化为包围盒：x -8..9，y(单位坐标) -26.5..0
	check(u.hit_test_sens(Vector2(200, 290)), "hit inside sens box")
	check(u.hit_test_sens(Vector2(193, 275)), "hit near top-left corner")
	check(not u.hit_test_sens(Vector2(200, 301)), "miss below feet")
	check(not u.hit_test_sens(Vector2(230, 290)), "miss to the right")
	u.sprite.scale.x = -1
	check(u.hit_test_sens(Vector2(193, 275)), "sens does not flip with sprite.scale.x (original: sens is not a child of sprite)")
	u.sens_mouse_enabled = false
	check(not u.hit_test_sens(Vector2(200, 290)), "mouseEnabled = false blocks hits")
	u.sens_mouse_enabled = true
	u.set_coordinates(10.5, -2.5)
	check(u.position == Vector2(11, -2), "setCoordinates rounds like Math.round (-2.5 -> -2)")
	root.remove_child(u)
	u.free()

func test_special_template() -> void:
	var sp := SpecialTemplate.new()
	check(sp.get_cur_counter == -1 and sp.get_count_percent == 100, "initial counter -1 -> 100%")
	sp.time_until_update = 10
	sp.reset_counter()
	check(sp.get_count_percent == 0 and not sp.can_use_special(), "counter 0 -> 0%")
	for _i in 5:
		sp.update()
	check(sp.get_count_percent == 50, "5/10 -> 50%")
	for _i in 5:
		sp.update()
	check(sp.can_use_special() and sp.get_count_percent == 100, "10/10 usable")
	sp.lock_special()
	check(sp.can_use_special(), "lockSpecial only clears isActive")
	sp.is_locked = true
	check(not sp.can_use_special(), "isLocked blocks use")
	sp.unlock_special()
	check(not sp.is_locked and sp.is_active, "unlockSpecial")
	check(sp.get_spec_level(false, 0) == 2, "getSpecLevel(false) = 2")
	RWRandom.set_seed(9)
	var expected := RWRandom.rand_range(1, 10)
	RWRandom.set_seed(9)
	sp.set_random_time()
	check(sp.get_cur_counter == expected, "setRandomTime = randRange(1, timeUntilUpdate)")

func test_cooldown_tabs() -> void:
	check(LivingObject.A_ARCHER_COOLDOWN_TAB[16] == 2223, "A_ARCHER_COOLDOWN_TAB keeps 2223")
	check(LivingObject.A_ARCHER_COOLDOWN_TAB.size() == 27 and LivingObject.A_WARRIOR_COOLDOWN_TAB.size() == 28, "cooldown tab sizes")
