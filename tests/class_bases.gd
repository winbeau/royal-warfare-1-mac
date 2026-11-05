extends SceneTree
# 兵种基类与核心投射物（P3-C）：远程三堆选目标、throwRanged 预判与命中判定、贝塞尔中点抬高、visualsTemplate 的 DELAYED 与 DONE。
# 固定 RWRandom 种子；期望值由测试内独立复算（探测序列 probe）。
var checks := 0
var failures: Array = []
var universe: GameUniverse

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func near(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) <= eps

class TRanged extends RangedFighter:
	var shots := 0
	var hits: Array = []
	func get_ranged_shoot_sound() -> void:
		shots += 1
	func missile_hit_handler(arrow: ArrowEx = null, target: LivingObject = null) -> void:
		hits.append([arrow, target])

class TMage extends MageClass:
	var shots := 0
	var hits: Array = []
	func get_ranged_shoot_sound() -> void:
		shots += 1
	func missile_hit_handler(target: LivingObject) -> void:
		hits.append(target)

class TVisual extends VisualsTemplate:
	var done_calls := 0
	var end_calls := 0
	func init() -> void:
		bmp_list = BmpFrames.from_symbol("warriorAttackAni")  # 20 帧：DONE 在下标 10
		super.init()
	func on_play_head_done() -> void:
		done_calls += 1
	func on_play_head_end() -> void:
		end_calls += 1
		super.on_play_head_end()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not root.get_node("Content").isolated_profile:
		quit(2)
		return
	RWTween.inst_().manual_clock = true
	RWTween.reset()
	universe = GameUniverse.new()
	universe.units_cont = Node2D.new()
	universe.effects_cont = Node2D.new()
	universe.bottom_effects_cont = Node2D.new()
	root.add_child(universe.units_cont)
	root.add_child(universe.effects_cont)
	root.add_child(universe.bottom_effects_cont)
	var lib := SoundLibrary.new()
	lib.init()
	var snd := Sounds.new()
	root.add_child(snd)
	snd.init_sounds_first({"music": true, "sound": true})
	ArrowEx.cache(8)
	SmallFireballEx.cache()
	test_ranged_heaps()
	test_mage_heaps()
	test_throw_ranged_hit()
	test_throw_ranged_miss()
	test_bezier_lift()
	test_visuals_delayed_and_done()
	test_melee_priority()
	test_priest_target()
	RWTween.reset()
	GameUniverse.inst = null
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

# 以种子 seed 取前 n 个 rand，随后恢复为 seed（探测，不影响被测代码）
func probe(seed_: int, n: int) -> Array:
	RWRandom.set_seed(seed_)
	var out: Array = []
	for i in n:
		out.append(RWRandom.rand())
	RWRandom.set_seed(seed_)
	return out

func state_after(seed_: int, n: int) -> int:
	RWRandom.set_seed(seed_)
	for i in n:
		RWRandom.rand()
	var st := RWRandom.get_state()
	RWRandom.set_seed(seed_)
	return st

func find_seed(pred: Callable) -> int:
	var s := 1
	while s < 100000:
		if pred.call(probe(s, 4)):
			return s
		s += 1
	return -1

func enemy(x: float, y: float, health: int = 10, kind_: int = 0, archer: bool = false) -> LivingObject:
	var u := LivingObject.new()
	u.friendly = false
	u.position = Vector2(x, y)
	u._x = x
	u._y = y
	u.health = health  # 原版 setter 同时设置 curHealth
	u.cur_health = health
	u.kind = kind_
	u.is_archer = archer
	return u

func shooter(cls: Script, x: float, y: float) -> LivingObject:
	var u: LivingObject = cls.new()
	u.friendly = true
	u._instance = u
	u.position = Vector2(x, y)
	u._x = x
	u._y = y
	u.search_radius = 100.0
	u.search_radius_ranged_modifier = 1.0
	u.sens_height = 30.0
	u.cur_stanse = LivingObject.STAND
	u.search_counter = 9
	return u

func set_units(units: Array) -> void:
	universe.a_all_units = units

func test_ranged_heaps() -> void:
	var r: TRanged = shooter(TRanged, 300, 300)
	# 1. kamikaze 堆优先：1 个元素，rand > 0.3 的判定消耗 1 次 rand，randomSort 单元素不比较
	var kami := enemy(350, 300, 10, LivingObject.MONSTER_KAMIKAZE)
	var arch := enemy(340, 300, 10, 0, true)
	var norm := enemy(310, 300)
	set_units([norm, arch, kami])
	RWRandom.set_seed(777)
	r.search_target(false)
	check(r.cur_target == kami, "ranged: kamikaze heap wins")
	check(RWRandom.get_state() == state_after(777, 1), "ranged: kamikaze heap consumes exactly 1 rand")
	check(r.attacking_with_ranged_weapon and r.search_counter == 0, "ranged: attackingWithRangedWeapon set, counter reset")
	# 2. 弓手堆：两名弓手。rand0 > 0.3 -> randomSort（1 次比较，rand >= 0.5 则交换）；否则按 curHealth 升序
	var a1 := enemy(340, 300, 8, 0, true)
	var a2 := enemy(345, 300, 3, 0, true)
	var s_hi := find_seed(func(p): return p[0] > 0.3 and p[1] >= 0.5)
	var s_lo := find_seed(func(p): return p[0] > 0.3 and p[1] < 0.5)
	var s_hp := find_seed(func(p): return p[0] <= 0.3)
	set_units([a1, a2, norm])
	r.cur_target = null
	r.search_counter = 9
	RWRandom.set_seed(s_hi)
	r.search_target(false)
	check(r.cur_target == a2, "ranged: archer heap randomSort swap -> second element")
	check(RWRandom.get_state() == state_after(s_hi, 2), "ranged: archer heap consumes 2 rands (check + 1 compare)")
	r.cur_target = null
	r.search_counter = 9
	RWRandom.set_seed(s_lo)
	r.search_target(false)
	check(r.cur_target == a1, "ranged: archer heap randomSort no swap -> first element")
	r.cur_target = null
	r.search_counter = 9
	RWRandom.set_seed(s_hp)
	r.search_target(false)
	check(r.cur_target == a2 and RWRandom.get_state() == state_after(s_hp, 1), "ranged: archer heap sorted by curHealth ascending (rand<=0.3)")
	# 3. 其他堆：最近者在 searchRadius 内 -> 不再洗牌，不消耗 rand
	var n1 := enemy(380, 300)
	var n2 := enemy(330, 300)
	set_units([n1, n2])
	r.cur_target = null
	r.search_counter = 9
	RWRandom.set_seed(5)
	r.search_target(false)
	check(r.cur_target == n2 and RWRandom.get_state() == state_after(5, 0), "ranged: nearest regular enemy, no rand")
	# 4. 最近者超出 searchRadius 且其目标不是弓手：armorPiercingMelee == 0 时 rand > 0.5 -> randomSort，否则按距离
	var far1 := enemy(390, 300)
	var far2 := enemy(380, 300)
	r.search_radius_ranged_modifier = 2.0  # 距离 90 / 80 不超出 searchRadius(100)，把半径放到 100 以内要缩小：见下
	r.search_radius = 60.0
	set_units([far1, far2])
	r.cur_target = null
	r.search_counter = 9
	var s_rs := find_seed(func(p): return p[0] > 0.5 and p[1] >= 0.5)
	RWRandom.set_seed(s_rs)
	r.search_target(false)
	# 距离升序后为 [far2, far1]；randomSort 一次比较 rand>=0.5 -> 交换 -> far1
	check(r.cur_target == far1 and RWRandom.get_state() == state_after(s_rs, 2), "ranged: far third-heap -> randomSort branch")
	var s_ds := find_seed(func(p): return p[0] <= 0.5)
	r.cur_target = null
	r.search_counter = 9
	RWRandom.set_seed(s_ds)
	r.search_target(false)
	check(r.cur_target == far2 and RWRandom.get_state() == state_after(s_ds, 1), "ranged: far third-heap -> distance branch")
	# 5. 入堆的"黏性"标志：先出现的单位距离在 (r-0.5, r] 时 flag 还未置位，被排除
	r.search_radius = 100.0
	r.search_radius_ranged_modifier = 1.0
	var edge := enemy(399.8, 300, 10, LivingObject.MONSTER_KAMIKAZE)  # 距离 99.8
	var inner := enemy(350, 300)
	set_units([edge, inner])
	r.cur_target = null
	r.search_counter = 9
	RWRandom.set_seed(9)
	r.search_target(false)
	check(r.cur_target == inner, "ranged: unit in (r-0.5, r] before any inner unit is excluded (sticky flag)")
	set_units([inner, edge])
	r.cur_target = null
	r.search_counter = 9
	r.search_target(false)
	check(r.cur_target == edge, "ranged: after an inner unit the edge kamikaze is admitted")
	# 6. 周期：未到 GLOBAL_SEARCH_COUNTER 不搜索；RANGED_SHOOT 阶段不搜索
	r.cur_target = null
	r.search_counter = 0
	r.search_target(false)
	check(r.cur_target == null and r.search_counter == 1, "ranged: counter below GLOBAL_SEARCH_COUNTER does not search")
	r.search_counter = 9
	r.cur_stanse = LivingObject.RANGED_SHOOT
	r.search_target(false)
	check(r.cur_target == null and r.search_counter == 0, "ranged: RANGED_SHOOT stance skips search but resets counter")
	for u in [kami, arch, norm, a1, a2, n1, n2, far1, far2, edge, inner]:
		u.free()
	r.free()

func test_mage_heaps() -> void:
	var m: TMage = shooter(TMage, 300, 300)
	var ghost := enemy(350, 300, 10, LivingObject.UNDEAD_GHOST)
	var norm := enemy(310, 300)
	set_units([norm, ghost])
	RWRandom.set_seed(31)
	m.search_target(false)
	check(m.cur_target == ghost and RWRandom.get_state() == state_after(31, 0), "mage: ghost heap wins, sorted by distance, no rand")
	# 第一堆最近者超出 searchRadius：rand <= 0.7 -> randomSort，否则 curArmor 降序
	m.search_radius = 60.0
	m.search_radius_ranged_modifier = 2.0
	var f1 := enemy(390, 300)
	f1.cur_armor = 0.1
	var f2 := enemy(380, 300)
	f2.cur_armor = 0.5
	set_units([f1, f2])
	m.cur_target = null
	m.search_counter = 9
	var s_a := find_seed(func(p): return p[0] <= 0.7 and p[1] >= 0.5)
	RWRandom.set_seed(s_a)
	m.search_target(false)
	check(m.cur_target == f1 and RWRandom.get_state() == state_after(s_a, 2), "mage: far enemy, rand<=0.7 -> randomSort")
	var s_b := find_seed(func(p): return p[0] > 0.7)
	m.cur_target = null
	m.search_counter = 9
	RWRandom.set_seed(s_b)
	m.search_target(false)
	check(m.cur_target == f2 and RWRandom.get_state() == state_after(s_b, 1), "mage: far enemy, rand>0.7 -> curArmor descending")
	# CASTING 阶段不搜索
	m.cur_target = null
	m.search_counter = 9
	m.cur_stanse = LivingObject.CASTING
	m.search_target(false)
	check(m.cur_target == null, "mage: CASTING stance skips search")
	for u in [ghost, norm, f1, f2]:
		u.free()
	m.free()

# 预判点：飞行时间 dist/400 秒 *30 帧 * 目标速度，沿 get_cur_destination() 方向
func expected_lead(from: Vector2, tpos: Vector2, dest: Vector2, speed: float, div: float) -> Vector2:
	var d := from.distance_to(tpos)
	var frames := d / div * 30.0
	var f := 1.0 - speed * frames / tpos.distance_to(dest)
	if not (f >= 0.0):
		f = 0.0
	return tpos * f + dest * (1.0 - f)

func test_throw_ranged_hit() -> void:
	var r: TRanged = shooter(TRanged, 100, 300)
	var t := enemy(300, 300)
	t.cur_stanse = LivingObject.WALKING
	t.dest_point = Vector2(500, 300)
	t.walk_speed = 2.0
	r.cur_target = t
	r.shoot_accuracy = 1.0  # rand <= 1 恒成立 -> 命中
	var from := Vector2(100, 300 - 15)
	var lead := expected_lead(from, Vector2(300, 300), Vector2(500, 300), 2.0, 400.0)
	check(lead.x > 300 and lead.x < 500 and near(lead.y, 300), "lead point lies ahead of the target on its path (%s)" % [lead])
	RWRandom.set_seed(4242)
	var before := universe.a_display_objects_vector.size()
	r.throw_ranged(null)
	check(r.shots == 1 and universe.a_display_objects_vector.size() == before + 1, "throwRanged: arrow added, shoot sound called")
	var arrow: ArrowEx = universe.a_display_objects_vector[universe.a_display_objects_vector.size() - 1]
	check(near(arrow.position.x, from.x) and near(arrow.position.y, from.y - 2), "arrow starts at (x, y-2) of launch point")
	check(RWRandom.get_state() == state_after(4242, 2), "hit: 1 rand for accuracy + 1 for bezier lift")
	var dur := from.distance_to(lead) / 450.0
	RWTween.step(dur * 0.5)
	RWTween.step(dur * 0.5 + 0.001)
	check(near(arrow.position.x, lead.x, 1e-4) and near(arrow.position.y, lead.y, 1e-4), "arrow lands on lead point (%s vs %s)" % [arrow.position, lead])
	check(r.hits.size() == 1 and r.hits[0][0] == arrow and r.hits[0][1] == t, "hit callback fired on complete with (arrow, target)")
	check(arrow.get_parent() != null, "hit arrow still present until the 0.1s fade")
	RWTween.step(0.2)
	check(arrow.get_parent() == null and universe.a_display_objects_vector.find(arrow) < 0, "hit arrow removed after fade")
	# 目标静止：瞄准 (x, y-3)
	t.cur_stanse = LivingObject.STAND
	RWRandom.set_seed(11)
	r.throw_ranged(null)
	var arrow2: ArrowEx = universe.a_display_objects_vector[universe.a_display_objects_vector.size() - 1]
	RWTween.step(1.0)
	check(near(arrow2.position.x, 300, 1e-4) and near(arrow2.position.y, 297, 1e-4), "standing target aimed at (x, y-3)")
	RWTween.step(0.2)
	t.free()
	r.free()

func test_throw_ranged_miss() -> void:
	var r: TRanged = shooter(TRanged, 100, 300)
	var t := enemy(300, 300)
	t.cur_stanse = LivingObject.STAND
	r.cur_target = t
	r.shoot_accuracy = 0.0  # rand <= 0 不成立 -> 未命中
	var seed_ := 90210
	var p := probe(seed_, 5)
	var aim := Vector2(300, 297)
	var landing := Vector2(aim.x - 15 + 30 * p[1], aim.y - 15 + 30 * p[2])
	check(p[0] > 0.0, "probe: accuracy roll is above 0")
	r.throw_ranged(null)  # 先用随机种子跑一次是多余的；下面重置种子重跑
	RWTween.step(2.0)
	RWRandom.set_seed(seed_)
	r.hits.clear()
	r.throw_ranged(null)
	var arrow: ArrowEx = universe.a_display_objects_vector[universe.a_display_objects_vector.size() - 1]
	var from := Vector2(100, 285)
	var dur := from.distance_to(landing) / 450.0
	RWTween.step(dur + 0.001)
	check(near(arrow.position.x, landing.x, 1e-4) and near(arrow.position.y, landing.y, 1e-4), "miss: lands at aim point offset by (-15+30*r1, -15+30*r2) (%s vs %s)" % [arrow.position, landing])
	check(absf(arrow.position.x - aim.x) <= 15.0 and absf(arrow.position.y - aim.y) <= 15.0, "miss offset within +-15px")
	check(r.hits.is_empty(), "miss: no damage callback")
	check(arrow.get_parent() != null and arrow.modulate.a == 1.0, "missed arrow sticks in the ground")
	RWTween.step(3.9)
	check(arrow.get_parent() != null, "missed arrow still present before 4 s")
	RWTween.step(0.3)
	RWTween.step(0.2)
	check(arrow.get_parent() == null, "missed arrow faded out and returned after 4 s")
	t.free()
	r.free()

func test_bezier_lift() -> void:
	# 普通箭：中点抬高 dist/(3+5*rand)；弩箭：dist/(8+2*rand)；飞行时间 dist/450；中点在 t=0.5 经过
	for crossbow in [false, true]:
		var a: ArrowEx = ArrowEx.cached_data.get_data() as ArrowEx
		universe.add_arrow(a)
		var p0 := Vector2(50, 200)
		var p1 := Vector2(450, 200)
		RWRandom.set_seed(1234)
		var r0: float = probe(1234, 1)[0]
		a.init(null, p0, p1, Callable(), false, crossbow, true)
		var dist := p0.distance_to(p1)
		var lift := dist / ((8.0 + 2.0 * r0) if crossbow else (3.0 + 5.0 * r0))
		var dur := dist / 450.0
		RWTween.step(dur * 0.5)
		check(near(a.position.x, 250, 1e-3) and near(a.position.y, 200 - lift, 1e-3), "bezier midpoint lifted by %.4f (crossbow=%s): got %s" % [lift, crossbow, a.position])
		RWTween.step(dur * 0.5 + 0.001)
		check(near(a.position.x, 450, 1e-3) and near(a.position.y, 200, 1e-3), "bezier ends at target")
		a.remove_arrow()
	# 小火球：飞行 dist/600，抬高 dist/(6+3*rand)
	var f: SmallFireballEx = SmallFireballEx.cached_data.get_data() as SmallFireballEx
	universe.add_small_fireball(f)
	var q0 := Vector2(60, 250)
	var q1 := Vector2(460, 250)
	RWRandom.set_seed(77)
	var r1: float = probe(77, 1)[0]
	var hit_calls: Array = []
	f.init(null, q0, q1, func(t): hit_calls.append(t), true)
	var d2 := q0.distance_to(q1)
	var lift2 := d2 / (6.0 + 3.0 * r1)
	var dur2 := d2 / 600.0
	check(near(f.position.x, q0.x) and near(f.position.y, q0.y - 7), "fireball starts at (x, y-7)")
	RWTween.step(dur2 * 0.5)
	check(near(f.position.x, 260, 1e-3) and near(f.position.y, 250 - lift2, 1e-3), "fireball midpoint lifted by %.4f: got %s" % [lift2, f.position])
	RWTween.step(dur2 * 0.5 + 0.001)
	check(hit_calls.size() == 1 and f.clip_frame == 7, "fireball hit callback fired, clip jumps to frame 7")
	# 帧 7..13：第 13 帧触发 done -> 回池
	for i in 6:
		f.advance_clip()
	check(f.get_parent() == null, "fireball removed at frame 13 (done)")

func test_visuals_delayed_and_done() -> void:
	var v := TVisual.new()
	v.init()
	var calls: Array = []
	var seed_ := find_seed(func(p): return p[0] <= 0.85 and p[1] <= 0.85 and p[2] > 0.85)
	RWRandom.set_seed(seed_)
	v.added_to_stage(120, 80, func(): calls.append(v.cur_frame), null, false, true)
	check(v.play_head_stance == VisualsTemplate.DELAYED and v.visible == false, "delayed: hidden and DELAYED after added_to_stage")
	check(v.position == Vector2(120, 80) and v.get_parent() == universe.effects_cont, "added to effects_cont at given position")
	universe.update_effects()
	universe.update_effects()
	check(v.play_head_stance == VisualsTemplate.DELAYED and v.cur_frame == -1, "delayed: two rolls <= 0.85 keep waiting")
	universe.update_effects()
	check(v.play_head_stance == VisualsTemplate.PLAYING and v.visible and v.cur_frame == -1, "delayed: third roll > 0.85 starts (no frame advance in the same update)")
	check(RWRandom.get_state() == state_after(seed_, 3), "delayed: one rand per DELAYED update")
	# PLAYING：第 k 次 update 后 cur_frame = k-1；DONE 在下标 10 -> 第 12 次 update（cur 10 -> 11）触发
	for k in range(1, 12):
		universe.update_effects()
		check(v.cur_frame == k - 1, "playing: cur_frame %d after update %d" % [k - 1, k])
	check(v.done_calls == 0 and calls.is_empty(), "no DONE before the DONE frame is left")
	universe.update_effects()
	check(v.cur_frame == 11 and v.done_calls == 1 and calls == [11], "DONE command fires on_play_head_done and the callback once")
	for k in range(13, 21):
		universe.update_effects()
	check(v.cur_frame == 19 and v.end_calls == 0 and v.get_parent() != null, "plays up to the last frame")
	universe.update_effects()
	check(v.end_calls == 1 and v.get_parent() == null and universe.a_effects.find(v) < 0, "last frame -> on_play_head_end -> removed from effects")
	check(v.done_calls == 1, "DONE not fired again")
	v.free()

func test_melee_priority() -> void:
	var m: MeleeFighter = shooter(MeleeFighter, 300, 300)
	m.friendly = false
	m.o_pursue_counter = {}
	LivingObject.a_friend_warriors = []
	LivingObject.a_friend_ranged = []
	LivingObject.v_untouchable_units = []
	var w := LivingObject.new()
	w.friendly = true
	w.position = Vector2(330, 300)
	w.cur_health = 10
	w.cur_armor = 0.4
	var w2 := LivingObject.new()
	w2.friendly = true
	w2.position = Vector2(320, 300)
	w2.cur_health = 10
	w2.cur_armor = 0.1
	LivingObject.a_friend_warriors = [w, w2]
	# 无战斗的单挑堆；rand > 0.7 随机，否则 armorPiercing < 0.2 时按距离升序
	var s_d := find_seed(func(p): return p[0] <= 0.7 and p[1] > 0.0)
	m.search_counter = 9
	RWRandom.set_seed(s_d)
	m.search_target(false)
	check(m.cur_target == w2 and RWRandom.get_state() == state_after(s_d, 1), "melee enemy: single heap by distance ascending (rand0<=0.7)")
	check(int(m.o_pursue_counter.get(LivingObject.pursue_key(w2), 0)) == 1, "melee enemy: pursue counter initialised to 1")
	# 有目标且不是弓手：不重新索敌
	m.search_counter = 9
	var st := RWRandom.get_state()
	m.search_target(false)
	check(m.cur_target == w2 and RWRandom.get_state() == st, "melee: existing non-archer target kept without rand")
	# FIGHTING 阶段不索敌也不计数
	m.cur_target = null
	m.cur_stanse = LivingObject.FIGHTING
	m.search_counter = 9
	m.search_target(false)
	check(m.cur_target == null and m.search_counter == 9, "melee: FIGHTING stance does not search")
	w.free()
	w2.free()
	m.free()
	LivingObject.a_friend_warriors = []

func test_priest_target() -> void:
	var p: PriestClass = shooter(PriestClass, 300, 300)
	p.search_radius_ranged_modifier = 2.1
	var a := enemy(320, 300, 20)
	a.real_friendly = true
	a.health = 20
	a.cur_health = 5
	var b := enemy(340, 300, 20)
	b.real_friendly = true
	b.health = 20
	b.cur_health = 2
	var c := enemy(330, 300, 20)
	c.real_friendly = true
	set_units([a, b, c])
	p.real_friendly = true
	p.search_counter = 29
	p.search_target(false)
	check(p.cur_target == b and p.last_target == b, "priest: most wounded friend (lowest curHealth) chosen; full-health friend skipped")
	check(p.search_counter == 0, "priest: counter period is 30")
	# 优先治疗目标：满血则清空，本轮不再选别人
	p.cur_target = null
	p.sprioritized_healing_target = c
	p.search_counter = 29
	p.search_target(false)
	check(p.sprioritized_healing_target == null and p.cur_target == null, "priest: full-health prioritised target cleared, no other target this round")
	p.sprioritized_healing_target = a
	p.search_counter = 29
	p.search_target(false)
	check(p.cur_target == a, "priest: prioritised wounded target is taken over the weakest one")
	# RANGED_SHOOT 阶段只改 curTarget
	p.cur_stanse = LivingObject.STAND
	p.sprioritized_healing_target = null
	p.search_counter = 28
	p.search_target(false)
	check(p.search_counter == 29, "priest: counter below 30 does nothing")
	for u in [a, b, c]:
		u.free()
	p.free()
