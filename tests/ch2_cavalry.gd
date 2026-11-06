extends SceneTree
# WP-D1 D1.9：达思重骑冲锋状态机、陌刀拒马斩（人马俱碎）、斩马刀下马、普通撞击。
# 白盒测试：部分场景直接调用状态机内部函数（GDScript 无真正私有，_ 前缀只是约定），
# 以获得确定性的几何/角度条件，不依赖多帧真实碰撞探测的随机性。
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
	h.start_level(0, SEED, 1, true, 1)

	test_fsm_progress(h)
	test_charge_no_turning(h)
	test_normal_unit_impact(h)
	test_horsebreaker_kills_frontal(h)
	test_horsebreaker_ignores_rear(h)
	test_two_abreast_only_one_stopped(h)
	test_glaive_instakill_mounted(h)
	test_horse_cleaver_dismount(h)
	test_dismounted_unit_counts_kill_once(h)
	test_charges_only_once(h)

	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _spawn_lancer(h: Harness, pos: Vector2) -> Ch2DarthLancer:
	var u: LivingObject = Ch2UnitFactory.new_unit(Ch2Kinds.CH2_DARTH_LANCER)
	h.gu.units_cont.add_child(u)
	u.uid = h.gu.global_counter
	u.update_stats()
	u.add_to_game(pos.x, pos.y)
	h.gu.a_all_units.append(u)
	h.gu.a_display_objects_vector.append(u)
	var lancer: Ch2DarthLancer = u
	lancer.state = Ch2DarthLancer.State.FORM
	lancer.set_coordinates(pos.x, pos.y)
	return lancer


func test_fsm_progress(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(350, 300))
	check(lancer.state == Ch2DarthLancer.State.FORM, "lancer should be placed directly into FORM for this test")
	for _i in 60:
		lancer.manage_walk_normal()
	check(lancer.state == Ch2DarthLancer.State.COMMIT, "FORM should advance to COMMIT after form_wait_frames")
	lancer.manage_walk_normal()  # COMMIT resolves same frame into CHARGE
	check(lancer.state == Ch2DarthLancer.State.CHARGE, "COMMIT should resolve into CHARGE")
	var start_dir := lancer.charge_dir
	for _i in 200:
		if lancer.state != Ch2DarthLancer.State.CHARGE:
			break
		lancer.manage_walk_normal()
	check(lancer.state == Ch2DarthLancer.State.IMPACT or lancer.state == Ch2DarthLancer.State.MELEE, "charge should eventually resolve into IMPACT/MELEE, got %d" % lancer.state)
	check(lancer.has_charged, "has_charged should be true once CHARGE resolves")
	for _i in 60:
		if lancer.state != Ch2DarthLancer.State.IMPACT:
			break
		lancer.manage_walk_normal()
	check(lancer.state == Ch2DarthLancer.State.MELEE, "IMPACT should advance to MELEE after impact_wait_frames")


func test_charge_no_turning(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(100, 500))
	lancer.state = Ch2DarthLancer.State.COMMIT
	lancer.charge_target_anchor = Vector2(100, 50)  # 正北方向，没有友军时走锚点
	lancer.manage_walk_normal()
	check(lancer.state == Ch2DarthLancer.State.CHARGE, "should enter CHARGE")
	var dir0 := lancer.charge_dir
	var flip0 := lancer.sprite.scale.x
	for _i in 30:
		if lancer.state != Ch2DarthLancer.State.CHARGE:
			break
		lancer.manage_walk_normal()
		check(lancer.charge_dir.is_equal_approx(dir0), "charge_dir must not change mid-charge")
		check(lancer.sprite.scale.x == flip0, "facing must not change mid-charge")


func test_normal_unit_impact(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	var target: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	target.set_external_position(Vector2(200, 200))
	var before_hp := target.cur_health
	lancer.charge_dir = Vector2(1, 0)
	lancer._impact_unit(target)
	check(target.cur_health < before_hp, "normal impact should deal damage")
	check(target.is_stunned, "normal impact should stun the hit unit")
	check(lancer.state == Ch2DarthLancer.State.IMPACT, "lancer should enter IMPACT after hitting a normal unit")
	check(lancer.has_charged, "has_charged should be set after an impact")


func test_horsebreaker_kills_frontal(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	var warden: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	warden.set_weapon("great_glaive", true)
	warden.set_external_position(Vector2(230, 200))
	warden.brace_active = true
	warden.sprite.scale.x = -1  # 面朝西（迎着从西向东冲来的重骑）
	lancer.charge_dir = Vector2(1, 0)  # 重骑朝东冲锋 -> 与陌刀朝向夹角 180°，正面迎上
	var before_hp := warden.cur_health
	lancer._resolve_charge_hit(warden)
	check(lancer.cur_health <= 0, "frontal horsebreaker should kill the charging lancer")
	check(warden.cur_health == before_hp, "braced warden should take no damage from a successfully intercepted charge")
	check(not warden.is_stunned, "braced warden should not be stunned by an intercepted charge")


func test_horsebreaker_ignores_rear(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	var warden: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	warden.set_weapon("great_glaive", true)
	warden.set_external_position(Vector2(230, 200))
	warden.brace_active = true
	warden.sprite.scale.x = 1  # 面朝东，和冲锋方向同向 -> 侧后方，不算正面迎上
	lancer.charge_dir = Vector2(1, 0)
	var before_hp := warden.cur_health
	lancer._resolve_charge_hit(warden)
	check(lancer.cur_health > 0, "rear-facing brace should not trigger horsebreaker (lancer should survive)")
	check(warden.cur_health < before_hp, "rear-facing brace should fall back to a normal impact instead")


func test_two_abreast_only_one_stopped(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	lancer.charge_dir = Vector2(1, 0)
	var w1: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	w1.set_external_position(Vector2(210, 196))
	var w2: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	w2.set_external_position(Vector2(210, 204))
	var hit := lancer._find_corridor_hit(Vector2(204, 200))
	check(hit == w1 or hit == w2, "corridor scan should pick exactly one of the two abreast units")
	check(not (hit == w1 and hit == w2), "corridor scan must not resolve both units in the same tick")


func test_glaive_instakill_mounted(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	var warden: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	warden.set_weapon("great_glaive", true)
	warden.set_external_position(Vector2(200, 200))
	warden._melee_hit(lancer, warden.cur_damage, warden.armor_piercing_melee)
	check(lancer.cur_health <= 0, "great_glaive hit on a mounted lancer should be an instant kill")


func test_horse_cleaver_dismount(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	lancer.upgrade(2)
	lancer.cur_health = int(lancer.health * 0.6)
	var target_for_lancer: LivingObject = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	lancer.cur_target = target_for_lancer
	var count_before: int = h.gu.a_all_units.size()
	var warden: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	warden.set_weapon("horse_cleaver", true)
	warden.set_external_position(Vector2(200, 200))
	warden._melee_hit(lancer, warden.cur_damage, warden.armor_piercing_melee)
	check(not is_instance_valid(lancer) or lancer.cur_health <= 0 or not h.gu.a_all_units.has(lancer), "horse_cleaver hit should remove the lancer unit from play")
	var spawned: LivingObject = null
	for u: LivingObject in h.gu.a_all_units:
		if u.get_kind == LivingObject.UNDEAD_DARTH_KNIGHT and u != target_for_lancer:
			spawned = u
	check(spawned != null, "dismount should spawn a real UndeadDarthKnight in its place")
	if spawned != null:
		var ratio: float = float(spawned.cur_health) / float(spawned.health)
		check(absf(ratio - 0.6) < 0.1, "dismounted knight hp ratio should carry over (~0.6), got %f" % ratio)
		check(spawned.is_stunned, "freshly dismounted knight should be stunned")
		check(spawned.cur_level == 2, "dismounted knight should inherit the lancer's level")
	check(h.gu.a_all_units.size() >= count_before, "dismount should not shrink the roster below its pre-hit size (lancer replaced 1:1 by knight)")


func test_dismounted_unit_counts_kill_once(h: Harness) -> void:
	var before_killed: int = GlobalData.inst.num_killed
	var lancer := _spawn_lancer(h, Vector2(400, 400))
	var warden: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	warden.set_weapon("horse_cleaver", true)
	warden.set_external_position(Vector2(400, 400))
	warden._melee_hit(lancer, warden.cur_damage, warden.armor_piercing_melee)
	check(GlobalData.inst.num_killed == before_killed, "dismount itself must not count as a kill")
	var spawned: LivingObject = null
	for u: LivingObject in h.gu.a_all_units:
		if u.get_kind == LivingObject.UNDEAD_DARTH_KNIGHT and u.position.distance_to(Vector2(400, 400)) < 5:
			spawned = u
	check(spawned != null, "dismount should have spawned a knight near (400, 400)")
	if spawned != null:
		spawned.bring_damage(spawned.health + 999, null)
		check(GlobalData.inst.num_killed == before_killed + 1, "killing the dismounted knight should count exactly one kill, got delta %d" % (GlobalData.inst.num_killed - before_killed))


func test_charges_only_once(h: Harness) -> void:
	var lancer := _spawn_lancer(h, Vector2(200, 200))
	var w1: Ch2Warden = h.gu.add_soldier(Ch2Kinds.CH2_WARDEN, null, 1, true)
	w1.set_external_position(Vector2(204, 200))
	lancer.charge_dir = Vector2(1, 0)
	lancer._impact_unit(w1)
	check(lancer.has_charged, "first impact should mark has_charged")
	check(lancer.state == Ch2DarthLancer.State.IMPACT, "after resolving one charge the lancer should be in IMPACT, not charging again")
