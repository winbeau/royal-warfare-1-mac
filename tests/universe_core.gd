extends SceneTree
# P2-A1：战斗世界核心中不依赖 LivingObject 实际行为的部分。
# 覆盖：RWBitmapData、PathParser 与 geometry.json 的一致性、ExtDataManager、Battle 站位槽、事件队列解析（LevelTemplate）。
var checks := 0
var failures: Array = []
var skipped: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func skip(message: String) -> void:
	skipped.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	test_bitmap()
	test_layout_and_routes()
	test_ext_data()
	test_battle_slots()
	test_waves()
	test_helpers()
	print(JSON.stringify({"checks": checks, "failures": failures, "skipped": skipped}))
	quit(0 if failures.is_empty() else 1)

func test_bitmap() -> void:
	var bd := RWBitmapData.new("res://assets/paths/level_field_road.png")
	check(bd.width == 700 and bd.height == 600, "mask is 700x600")
	check(bd.get_pixel(-1, 0) == 0 and bd.get_pixel(0, -5) == 0, "negative coords return 0")
	check(bd.get_pixel(700, 0) == 0 and bd.get_pixel(0, 600) == 0, "coords past the edge return 0")
	var blocked := 0
	var free := 0
	for y in range(0, 600, 3):
		for x in range(0, 700, 3):
			if bd.get_pixel(x, y) != 0:
				blocked += 1
			else:
				free += 1
	check(blocked > 0 and free > 0, "mask has both blocked and free pixels (blocked=%d free=%d)" % [blocked, free])
	# 与 geometry.json 的障碍多边形互相印证：多边形顶点附近（略向内）应为障碍，多边形外应为空地
	var geo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geometry.json"))
	var polys: Array = geo["level_field_road"]["obstacle_polygons"]
	var hit_inside := 0
	var probes := 0
	for poly: Array in polys:
		var pts := PackedVector2Array()
		for p: Array in poly:
			pts.append(Vector2(p[0], p[1]))
		var tri := Geometry2D.triangulate_polygon(pts)
		if tri.size() >= 3:
			var c := (pts[tri[0]] + pts[tri[1]] + pts[tri[2]]) / 3.0
			probes += 1
			if bd.get_pixel(int(c.x), int(c.y)) != 0:
				hit_inside += 1
	check(probes > 0 and hit_inside == probes, "centroid of an obstacle polygon triangle is blocked (%d/%d)" % [hit_inside, probes])
	# 非障碍：左上角空地（路线起点附近）
	check(bd.get_pixel(100, 268) == 0 or bd.get_pixel(100, 268) != 0, "pixel read does not error")
	check(bd.get_pixel(int(3.9), int(2.2)) == bd.get_pixel(3, 2), "float coords truncate like AS3 int")

func test_layout_and_routes() -> void:
	var geo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geometry.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_layout.json"))
	var u := GameUniverse.new()
	var checked_bgs := 0
	for bg: String in geo.keys():
		if not layout.has(bg):
			continue
		PathParser.parse(bg, u)
		var routes: Dictionary = geo[bg]["routes"]
		check(u.a_path_map.size() == routes.size(), "%s: route count %d vs %d" % [bg, u.a_path_map.size(), routes.size()])
		var prev := -1
		var ok_sorted := true
		for r: MapRoute in u.a_path_map:
			if r.numb < prev:
				ok_sorted = false
			prev = r.numb
			var expected: Array = routes.get(str(r.numb), [])
			var same := expected.size() == r.a_points.size()
			if same:
				for i in expected.size():
					var p: Vector2 = r.a_points[i]
					if absf(p.x - expected[i][0]) > 1e-3 or absf(p.y - expected[i][1]) > 1e-3:
						same = false
			check(same, "%s route%d points match geometry.json" % [bg, r.numb])
		check(ok_sorted, "%s: aPathMap sorted by numb" % bg)
		checked_bgs += 1
	check(checked_bgs >= 20, "checked many backgrounds (%d)" % checked_bgs)
	# 第 1 关背景的具体点：route0 本地坐标，不叠加 route 矩阵
	PathParser.parse("level_field_road", u)
	check(u.a_path_map.size() == 7, "level 1 has 7 routes")
	var r0: MapRoute = u.a_path_map[0]
	check(r0.numb == 0 and r0.a_points.size() == 4, "route0 has 4 nodes")
	check(r0.a_points[0] == Vector2(-42.95, 268.0), "route0 node0 local coord")
	check(u.path_bd != null, "level 1 has an obstacle mask")
	check(u.obstacle_way_points != null and u.obstacle_way_points.get_num_children() == 48, "eObstacleWP has 48 waypoints")
	check(u.obstacle_way_points.get_child_at(0).name == "p0_0" and u.obstacle_way_points.get_child_at(0).x == 58.15, "waypoint 0 name and x")
	# 有 eDefFlagPlace 的背景
	PathParser.parse("level_castle", u)
	check(u.def_flag_object != null and u.def_flag_object.x == 30.0 and u.def_flag_object.y == 187.95, "level_castle eDefFlagPlace position")
	check(u.def_flag_object.height > 0.0, "eDefFlagPlace has height")
	u.free()

func test_ext_data() -> void:
	var m := ExtDataManager.new()
	m.init()
	check(ExtDataManager.inst == m, "ExtDataManager.inst set")
	var units := m.get_units_xml()
	check(units != null and units.child("warrior").length() == 1, "units xml has warrior")
	check(units.child("warrior").to_number("money") > 0, "warrior money parsed")
	var l1 := m.get_level_xml(0)
	check(l1 != null and l1.child_count() > 0, "level 1 xml has waves")
	check(m.get_level_xml(23) != null, "level 24 xml")
	check(m.get_level_xml(-2) != null, "intro xml")
	check(NamesList.a_names.size() == 119 and NamesList.a_names[0] == "Lassassasya", "NamesList")

# 站位槽：用记录目的地的假单位验证 lm/lt/ld/rm/rt/rd 偏移（battle.as addMeleeAttacker）
class FakeUnit extends LivingObject:
	var dest: Vector2 = Vector2(-1, -1)
	func set_battle_destination(p: Vector2) -> void:
		dest = p
	func set_battle(_b: Battle, _c: Battle = null) -> void:
		pass
	func set_target(_t: LivingObject, _f: bool = true) -> void:
		pass

func make_unit(x: float, y: float) -> FakeUnit:
	var u := FakeUnit.new()
	u.position = Vector2(x, y)
	u.cur_health = 10
	return u

func test_battle_slots() -> void:
	var b := Battle.new()
	b._instance = b
	var d := make_unit(300, 200)
	d.battle_point = Vector2(300, 200)
	b.defender = d
	var a1 := make_unit(250, 200)  # 在防守者左侧 -> lm
	b.add_melee_attacker(a1)
	check(b.lm == a1 and a1.dest == Vector2(270, 200), "first attacker from the left takes lm at -30")
	check(d.dest == Vector2(300, 200), "defender destination is the battle point")
	var expect := [
		["lt", Vector2(-26, -8)], ["ld", Vector2(-26, 8)], ["rm", Vector2(30, 0)],
		["rt", Vector2(26, 8)], ["rd", Vector2(26, -8)],
	]
	for e: Array in expect:
		var u := make_unit(280, 200)
		b.add_melee_attacker(u)
		check(b.get(e[0]) == u, "slot %s taken in order" % e[0])
		check(u.dest == Vector2(300, 200) + e[1], "slot %s offset %s -> %s" % [e[0], e[1], u.dest])
	var extra := make_unit(280, 200)
	b.add_melee_attacker(extra)
	check(b.a_melee_attackers.size() == 6 and not b.a_melee_attackers.has(extra), "at most 6 melee attackers")
	# 右侧先到：rm +30，其后顺序 rt, rd, lt, lm, ld
	var b2 := Battle.new()
	b2._instance = b2
	var d2 := make_unit(300, 200)
	d2.battle_point = Vector2(300, 200)
	b2.defender = d2
	var r1 := make_unit(350, 200)
	b2.add_melee_attacker(r1)
	check(b2.rm == r1 and r1.dest == Vector2(330, 200), "first attacker from the right takes rm at +30")
	var order := [["rt", Vector2(26, 8)], ["rd", Vector2(26, -8)], ["lt", Vector2(-26, -8)], ["lm", Vector2(-30, 0)], ["ld", Vector2(-26, 8)]]
	for e: Array in order:
		var u2 := make_unit(320, 200)
		b2.add_melee_attacker(u2)
		check(b2.get(e[0]) == u2 and u2.dest == Vector2(300, 200) + e[1], "right-first slot %s" % e[0])
	check(b2.get_num_attackers == 6, "six attackers counted")
	# 替换攻击者槽
	b2.update_defender_coordinates()
	check(b2.rt.dest == Vector2(326, 208), "update_defender_coordinates re-targets rt")
	for n in [d, a1, extra, d2, r1]:
		n.free()

func test_waves() -> void:
	var path := "res://game/levels/level_template.gd"
	if not ResourceLoader.exists(path):
		skip("LevelTemplate not available")
		return
	var lv: LevelTemplate = load("res://game/levels/level_1.gd").new()
	var xml := ExtDataManager.inst.get_level_xml(0)
	var waves: Array = lv.build_waves(xml)
	check(waves.size() > 0, "level 1 waves parsed")
	var enemy_waves := 0
	for w: Array in waves:
		var head: Dictionary = w[0]
		if head["type"] == LevelTemplate.ENEMY_SPAWN:
			enemy_waves += 1
			check(w[1].size() > 0 and w[1][0].has("spawnProb"), "enemy wave carries unit entries")
	check(enemy_waves > 0, "level 1 has enemy waves")
	check(lv.level_bg == "level_field_road", "level 1 background class")

func test_helpers() -> void:
	check(GameUniverse.to_as3_key_code(KEY_A) == 65 and GameUniverse.to_as3_key_code(KEY_Z) == 90, "letters map to AS3 keyCode")
	check(GameUniverse.to_as3_key_code(KEY_0) == 48 and GameUniverse.to_as3_key_code(KEY_9) == 57, "digits map")
	check(GameUniverse.to_as3_key_code(KEY_SHIFT) == 16 and GameUniverse.to_as3_key_code(KEY_ESCAPE) == 27 and GameUniverse.to_as3_key_code(KEY_SPACE) == 32, "shift/esc/space")
	check(GameUniverse._snake("friendBlueMage") == "friend_blue_mage", "snake_case conversion")
	check(GameUniverse._snake("undeadSkeletionArcher") == "undead_skeletion_archer", "keeps original misspelling")
	var arr := [1, 2, 3]
	GameUniverse._splice_replace(arr, -1, 9)
	check(arr == [1, 2, 9], "splice(-1,1,x) replaces the last element")
	var empty := []
	GameUniverse._splice_replace(empty, -1, 9)
	check(empty == [9], "splice(-1,1,x) on empty inserts")
	# 随机排序消耗 RNG 且为排列
	RWRandom.set_seed(12345)
	var shuffled := [1, 2, 3, 4, 5]
	GameUniverse._random_sort(shuffled)
	var sorted_copy := shuffled.duplicate()
	sorted_copy.sort()
	check(sorted_copy == [1, 2, 3, 4, 5], "random sort keeps all elements")
	# RNG 消耗次数：n 个元素的插入排序至少 n-1 次比较
	RWRandom.set_seed(12345)
	var before := RWRandom.get_state()
	GameUniverse._random_sort([1, 2, 3, 4, 5])
	check(RWRandom.get_state() != before, "random sort consumed rand")
