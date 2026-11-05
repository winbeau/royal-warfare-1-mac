extends SceneTree
# 单位/特效审计复核（F1）的确定性测试，必须带 -- --isolated-profile：
#  1. 选中友军后用真实鼠标事件点击敌人 -> livingObject.clicked 的 else 分支调用 gameUniverse.enemyUnitClicked，
#     选中的友军获得攻击目标（原版 livingObject.as:clicked）。点击友军仍走 friendlyUnitClicked。
#  2. strikeBackStab：友军无视速度、60 帧冷却、伤害 curDamage * 3，写 lastBackstab。
#  3. sort_on_prop（Array.sortOn(prop, NUMERIC[|DESCENDING]) 的共用稳定实现）。
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
	if not root.get_node("Content").isolated_profile:
		quit(2)
		return
	test_sort_on_prop()
	root.size = Vector2i(700, 600)  # 舞台固定 700x600，点击坐标即舞台坐标（同 input_e2e）
	var h := Harness.new(self)
	h.boot()
	await test_enemy_click(h)
	test_strike_back_stab(h)
	check(h.catcher.errors.is_empty(), "no script errors: %s" % [h.catcher.errors.slice(0, 5)])
	h.shutdown()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

class Item extends RefCounted:
	var v: float
	var tag: String
	func _init(p_v: float, p_tag: String) -> void:
		v = p_v
		tag = p_tag

func tags(arr: Array) -> String:
	var out := ""
	for it in arr:
		out += it.tag
	return out

func test_sort_on_prop() -> void:
	var a: Array = [Item.new(3, "a"), Item.new(1, "b"), Item.new(3, "c"), Item.new(2, "d"), Item.new(1, "e")]
	LivingObject.sort_on_prop(a, "v")
	check(tags(a) == "bedac", "sortOn NUMERIC ascending, ties keep order: %s" % tags(a))
	var b: Array = [Item.new(3, "a"), Item.new(1, "b"), Item.new(3, "c"), Item.new(2, "d"), Item.new(1, "e")]
	LivingObject.sort_on_prop(b, "v", true)
	check(tags(b) == "acdbe", "sortOn NUMERIC|DESCENDING, ties keep order: %s" % tags(b))
	var c: Array = [Item.new(2, "x")]
	LivingObject.sort_on_prop(c, "v")
	check(tags(c) == "x", "single element")

func click_at(pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	root.push_input(mm)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame

func place(u: LivingObject, p: Vector2) -> void:
	u.set_coordinates(p.x, p.y)
	u.zero_point = p
	u.dest_point = p

func test_enemy_click(h) -> void:
	var gu: GameUniverse = h.start_level(0, 777)
	h.dismiss_chat()
	var warrior: LivingObject = gu.add_soldier(LivingObject.FR_WARRIOR)
	var archer: LivingObject = gu.add_soldier(LivingObject.FR_ARCHER)
	var ogre: LivingObject = gu.load_enemy(LivingObject.MONSTER_OGRE, 1, 1)
	check(warrior != null and archer != null and ogre != null, "units created")
	place(warrior, Vector2(200, 300))
	place(archer, Vector2(200, 400))
	place(ogre, Vector2(420, 300))
	for u in [warrior, archer, ogre]:
		u.a_obstacle_route = []
	gu.set_physics_process(false)  # 点击期间不推进逻辑帧（否则弓箭手会在 await 的帧里自动索敌，掩盖点击的效果）
	var epos: Vector2 = ogre.get_sens_rect().get_center()
	check(ogre.hit_test_sens(epos), "ogre sens centre is hit-testable at %s" % epos)

	# 选中友军战士，点击敌人 -> 战士获得攻击目标
	gu.a_selected_units = []
	gu.select_unit(warrior)
	check(warrior.cur_target == null, "warrior has no target before the click")
	await click_at(epos)
	check(warrior.cur_target == ogre, "selected warrior targets the clicked enemy (cur_target=%s)" % [warrior.cur_target])

	# 选中弓箭手，点击敌人 -> pursuit_target：archerGotoTarget + 远程攻击
	warrior.set_target(null)
	gu.a_selected_units.clear()
	warrior.unselect()
	gu.select_unit(archer)
	# 引擎在 await 期间会推进 _physics_process，弓箭手可能已自动索敌：先清掉，只测点击
	archer.set_target(null)
	archer.archer_goto_target = false
	await click_at(epos)
	check(archer.cur_target == ogre, "selected archer targets the clicked enemy")
	check(archer.archer_goto_target and archer.attacking_with_ranged_weapon, "archer pursues the clicked enemy (goto_target + ranged)")

	# 点击友军仍走 friendlyUnitClicked：切换选中，不给任何单位设敌人为目标
	archer.set_target(null)
	var wpos: Vector2 = warrior.get_sens_rect().get_center()
	await click_at(wpos)
	check(gu.a_selected_units.size() == 1 and gu.a_selected_units[0] == warrior, "clicking a friendly selects it")
	check(warrior.cur_target == null and archer.cur_target == null, "clicking a friendly sets no target")

	# 没有选中任何单位时点击敌人 -> groundClicked 无选中单位，什么也不发生，不报错
	gu.unselect_all()
	await click_at(epos)
	check(warrior.cur_target == null, "no selection: enemy click does not give anyone a target")
	h.stop_level()

func test_strike_back_stab(h) -> void:
	var gu: GameUniverse = h.start_level(0, 778)
	h.dismiss_chat()
	var warrior: LivingObject = gu.add_soldier(LivingObject.FR_WARRIOR)
	var ogre: LivingObject = gu.load_enemy(LivingObject.MONSTER_OGRE, 1, 1)
	place(warrior, Vector2(200, 300))
	place(ogre, Vector2(230, 300))
	warrior.set_target(ogre)
	gu.global_counter = 1000
	warrior.in_action = true
	ogre.last_backstab = 0
	var hp: int = warrior.cur_health
	var ogre_hp: int = ogre.cur_health
	# 友军：即使目标走得更快也会背刺（elif friendly）
	ogre.walk_speed = warrior.walk_speed + 5
	var dmg: int = int(warrior.cur_damage) * 3
	var stabbed: bool = warrior.strike_back_stab(ogre)
	check(stabbed, "friendly strikeBackStab succeeds (cooldown over, in_action)")
	check(ogre.last_backstab == 1000, "targt.lastBackstab = getGameTime")
	check(warrior.cur_target.cur_health < warrior.cur_target.health, "curTarget took backstab damage")
	check(not warrior.strike_back_stab(ogre), "second stab inside 60 frames is refused")
	gu.global_counter = 1060
	check(not warrior.strike_back_stab(ogre), "lastBackstab + 60 < tm is strict: exactly 60 frames later is refused")
	gu.global_counter = 1061
	check(warrior.strike_back_stab(ogre), "61 frames later stabs again")
	# 敌人（非友军）：目标走得不比自己慢（targt.walkSpeed >= walkSpeed）才背刺，目标更慢则不
	var enemy_striker: LivingObject = ogre
	enemy_striker.set_target(warrior)
	enemy_striker.in_action = true
	warrior.last_backstab = 0
	warrior.walk_speed = enemy_striker.walk_speed - 0.5
	check(not enemy_striker.strike_back_stab(warrior), "enemy does not stab a slower target")
	warrior.walk_speed = enemy_striker.walk_speed
	check(enemy_striker.strike_back_stab(warrior), "enemy stabs a target that is not slower")
	check(dmg > 0 and hp > 0 and ogre_hp > 0, "sanity")
	h.stop_level()
