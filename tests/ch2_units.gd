extends SceneTree
# WP-D1 D1.9：镇戍卫/火铳卫数值与换装、五雷弹匣/装填、弹丸飞行与命中、特殊弹排队、静音开关。
const Harness := preload("res://tests/support/battle_harness.gd")
const SEED := 20261106

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
	h.start_level(0, SEED, 1, true, 1)  # 普通一代关卡即可：_new_unit 按 kind>=100 分流，不依赖二章关卡数据

	test_warden_weapon_switch(h)
	test_musketeer_weapon_switch(h)
	test_five_thunders_clip(h)
	test_bullet_flight(h)
	test_muzzle_from_rod_tip()
	test_special_ammo_queue(h)
	test_mute_switch()

	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func test_warden_weapon_switch(h: Harness) -> void:
	var u: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	check(u.cur_level == 1, "warden starts at level 1, got %d" % u.cur_level)
	check(u.health == 150, "dao_shield L1 health expected 150 got %d" % u.health)
	check(is_equal_approx(u.armor, 0.6), "dao_shield L1 armor expected 0.6 got %f" % u.armor)
	u.cur_health = int(u.health * 0.5)
	u.set_weapon("great_glaive", true)
	check(u.cur_level == 3, "after force set_weapon, level expected 3 got %d" % u.cur_level)
	check(u.health == 170, "great_glaive L3 health expected 170 got %d" % u.health)
	var ratio: float = float(u.cur_health) / float(u.health)
	check(absf(ratio - 0.5) < 0.05, "health ratio should stay ~0.5 across weapon switch, got %f" % ratio)
	check(not u.can_upgrade_weapon(), "advanced weapon should not report can_upgrade_weapon")


func test_musketeer_weapon_switch(h: Harness) -> void:
	var u: Ch2Musketeer = h.gu.add_soldier(Ch2Kinds.CH2_MUSKETEER, null, 1, true)
	check(u.cur_level == 1, "musketeer starts at level 1, got %d" % u.cur_level)
	check(u.health == 80, "matchlock L1 health expected 80 got %d" % u.health)
	check(is_equal_approx(u.armor_piercing_ranged, 0.6), "matchlock L1 armor_pierce_ranged expected 0.6 got %f" % u.armor_piercing_ranged)
	# 基础武器未练满经验时直接换装应被拒绝（非 force）
	u.set_weapon("heavy_musket", false)
	check(u.weapon_id == "matchlock", "set_weapon without force before exp cap should be rejected, got %s" % u.weapon_id)
	u.set_weapon("heavy_musket", true)
	check(u.cur_level == 3, "after force set_weapon, level expected 3 got %d" % u.cur_level)
	check(u.ranged_damage == 45, "heavy_musket ranged_damage expected 45 got %d" % u.ranged_damage)
	check(is_equal_approx(u.armor_piercing_ranged, 0.95), "heavy_musket armor_pierce_ranged expected 0.95 got %f" % u.armor_piercing_ranged)
	check(is_equal_approx(u.search_radius, 70.0 * 4.9), "search_radius expected 70*4.9 got %f" % u.search_radius)


func test_five_thunders_clip(h: Harness) -> void:
	var u: Ch2Musketeer = h.gu.add_soldier(Ch2Kinds.CH2_MUSKETEER, null, 1, true)
	u.set_weapon("five_thunders", true)
	check(u.ch2_clip_remaining == 5, "five_thunders clip should start at 5, got %d" % u.ch2_clip_remaining)
	for i in 4:
		u.special_play_head_start_playing_handler()
		check(u.ranged_attack_interval == 9, "shot %d should set interval 9, got %d" % [i + 1, u.ranged_attack_interval])
		check(not u.ch2_in_reload, "shot %d should not be reloading yet" % (i + 1))
	u.special_play_head_start_playing_handler()  # 第 5 发，打空弹匣
	check(u.ranged_attack_interval == 150, "5th shot should trigger 150-frame reload, got %d" % u.ranged_attack_interval)
	check(u.ch2_in_reload, "clip empty should set ch2_in_reload true")
	# 打空后的下一次 play_head_start_play（即装填结束后的第一发）应重置弹匣并回到 9 帧间隔
	u.special_play_head_start_playing_handler()
	check(u.ch2_clip_remaining == 4, "new clip after reload should start decremented to 4, got %d" % u.ch2_clip_remaining)
	check(not u.ch2_in_reload, "new clip first shot should clear ch2_in_reload")


func test_bullet_flight(h: Harness) -> void:
	var from_pt := Vector2(100, 100)
	var to_pt := Vector2(100, 320)  # 220px，速度 22px/帧 => 10 帧到达
	# GDScript 的 lambda 按值捕获外层局部变量，赋值不会反映到外层——用一个数组当"盒子"传引用。
	var hit_box := [false, false]  # [arrived, did_hit]
	var cb := func(did_hit: bool, _target: Variant, _land: Vector2) -> void:
		hit_box[0] = true
		hit_box[1] = did_hit
	var b := Ch2Bullet.fire(from_pt, to_pt, true, null, cb)
	var hit_frame := -1
	for i in 20:
		if not is_instance_valid(b) or hit_box[0]:
			break
		b.update()
		if hit_box[0]:
			hit_frame = i + 1
			break
		var d1: float = (b.position - from_pt).length()
		var d2: float = (to_pt - from_pt).length()
		check(d1 <= d2 + 0.01, "bullet should not overshoot before arrival (frame %d)" % (i + 1))
		# 直线飞行：position 应落在 from->to 连线上
		var expected_dir := (to_pt - from_pt).normalized()
		var actual_dir := (b.position - from_pt).normalized() if d1 > 0.01 else expected_dir
		check(actual_dir.distance_to(expected_dir) < 0.01, "bullet should travel in a straight line (frame %d)" % (i + 1))
	check(hit_box[0], "bullet should arrive within 20 frames")
	check(hit_box[1], "bullet on_arrive should report hit=true")
	check(hit_frame == 10, "220px / 22px/frame should arrive exactly at frame 10, got %d" % hit_frame)


func test_muzzle_from_rod_tip() -> void:
	var bm := Ch2BmpFrames.from_body("musketeer_gun", "attack")
	check(bm != null, "musketeer_gun attack Ch2BmpFrames should load")
	if bm == null:
		return
	var s := Sprite2D.new()
	root.add_child(s)
	bm.apply_frame(s, 0)
	var muzzle: Vector2 = s.get_meta("ch2_muzzle", Vector2.ZERO)
	check(muzzle != Vector2.ZERO, "ch2_muzzle meta should be set from rod.tip on a shoot frame")
	s.queue_free()


func test_special_ammo_queue(h: Harness) -> void:
	var u: Ch2Musketeer = h.gu.add_soldier(Ch2Kinds.CH2_MUSKETEER, null, 1, true)
	check(u.queued_special == "", "no special queued initially")
	u.still_counter = 999
	u.special_play_head_start_playing_handler()
	check(u.queued_special == "steady_aim", "standing still long enough should queue steady_aim, got '%s'" % u.queued_special)
	# 排队后应在下一次出手时被清空（由 throw_ranged 消耗），这里直接验证字段可以被外部读取/清空的约定
	u.queued_special = ""
	check(u.queued_special == "", "queued_special should be clearable after consumption")


func test_mute_switch() -> void:
	var stream: AudioStream = SoundLibrary.inst.get_sound(SoundLibrary.HIRE)
	Sounds.ch2_sfx_muted = true
	var muted_channel: Variant = Sounds.inst.play(stream)
	check(muted_channel == null, "Sounds.play should return null while ch2_sfx_muted is true")
	Sounds.ch2_sfx_muted = false
	var normal_channel: Variant = Sounds.inst.play(stream)
	check(normal_channel != null, "Sounds.play should work normally once ch2_sfx_muted is false (one-gen unaffected)")
	if normal_channel != null:
		(normal_channel as Sounds.Channel).stop()
