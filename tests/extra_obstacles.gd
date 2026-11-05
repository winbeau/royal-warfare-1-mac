extends SceneTree
# 用户要求的玩法改动（不是还原修复）：每张地图的补充"空气墙" assets/paths_extra/<背景>.png。
# 验证：
#   1) 24 张图的硬约束全部满足——所有路线节点/连线采样点、eDefFlagPlace 位置、各关初始友军/敌军坐标，
#      都不落在补充障碍（assets/paths_extra/，不是合并后的原版+补充掩码——原版障碍是否挡住这些点
#      不属于本次改动范围）上；
#   2) 第 8 关 (level_steppes) 把目的地点在天空（补充障碍）处，单位的实际目的地会被挪到可走区域；
#   3) GameUniverse.USE_EXTRA_OBSTACLES=false 时，行为与原版（只用 assets/paths/ 的掩码）一致。
# 见 docs/verification.md「用户要求的玩法改动」；不改 assets/paths/、data/level_layout.json。

const Harness := preload("res://tests/support/battle_harness.gd")

var failures: Array = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	GameUniverse.USE_EXTRA_OBSTACLES = true
	test_hard_constraints_all_maps()
	await test_destination_moved_out_of_sky()
	test_disabled_matches_original()
	await test_original_mask_blocks_real_click()
	test_random_blocked_points_all_maps()
	print("extra_obstacles: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

## 只加载补充障碍层（不含原版 assets/paths/ 掩码）；没有对应文件时视为全 0（没有补充障碍）。
func _extra_only_mask(bg: String) -> RWBitmapData:
	var path := "res://assets/paths_extra/%s.png" % bg
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return null
	return RWBitmapData.new(path, GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)

## 1) 24 张图的硬约束
func test_hard_constraints_all_maps() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_layout.json"))
	var level_of := _level_of_background()
	var checked := 0
	for bg: String in layout.keys():
		if bg == "_meta" or not level_of.has(bg):
			continue
		checked += 1
		var u := GameUniverse.new()
		PathParser.parse(bg, u)
		var extra := _extra_only_mask(bg)
		if extra == null:
			check(true, "%s: 没有补充障碍层，无需校验" % bg)
			u.free()
			continue
		var bad: Array = []
		# 路线节点 + 连线采样点
		for r: MapRoute in u.a_path_map:
			var pts: Array = r.a_points
			for i in range(pts.size()):
				_sample_segment(pts[i], pts[i] if i == 0 else pts[i - 1], extra, bad, "%s route%d" % [bg, r.numb])
		# eDefFlagPlace：5 个旗子位置，公式与 game_universe.gd 的 _defend_flag_place 放置一致
		if u.def_flag_object != null:
			var d: RWLayoutClip = u.def_flag_object
			for k in range(5):
				var p := Vector2(d.x, d.y + d.height * k / 4.0)
				if _blocked(extra, p):
					bad.append("%s flag(%d) (%.0f,%.0f)" % [bg, k, p.x, p.y])
		# 各关 loadingCompletedHandler 里 add_soldier 后 set_external_position(Vector2(x,y)) 的初始坐标
		for lvl: int in level_of[bg]:
			for p: Vector2 in _unit_points(lvl):
				if _blocked(extra, p):
					bad.append("level_%d unit (%.0f,%.0f)" % [lvl, p.x, p.y])
		check(bad.is_empty(), "%s: %d 处硬约束违规：%s" % [bg, bad.size(), bad.slice(0, 5)])
		u.free()
	check(checked == 24, "24 张背景都检查到了 (got %d)" % checked)

func _sample_segment(p_to: Vector2, p_from: Vector2, bd: RWBitmapData, bad: Array, label: String) -> void:
	if _blocked(bd, p_to):
		bad.append("%s node (%.0f,%.0f)" % [label, p_to.x, p_to.y])
	if p_from == p_to:
		return
	var dist: float = p_from.distance_to(p_to)
	var steps: int = maxi(1, int(dist / 3.0))
	for s in range(1, steps):
		var p: Vector2 = p_from.lerp(p_to, float(s) / float(steps))
		if _blocked(bd, p):
			bad.append("%s segment (%.0f,%.0f)" % [label, p.x, p.y])

func _blocked(bd: RWBitmapData, p: Vector2) -> bool:
	return bd.get_pixel(int(p.x), int(p.y)) != 0

## 背景 -> 使用它的关卡号（一张背景可能被多关复用）
func _level_of_background() -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.new()
	re.compile("level_bg = \"([^\"]+)\"")
	for i in range(1, 25):
		var path := "res://game/levels/level_%d.gd" % i
		if not FileAccess.file_exists(path):
			continue
		var src := FileAccess.get_file_as_string(path)
		var m := re.search(src)
		if m == null:
			continue
		var bg := m.get_string(1)
		if not out.has(bg):
			out[bg] = []
		out[bg].append(i)
	return out

## 从 levelN.gd 的 loadingCompletedHandler 里取出 Vector2(x, y) 字面量（初始友军/敌军坐标）
func _unit_points(level: int) -> Array:
	var path := "res://game/levels/level_%d.gd" % level
	if not FileAccess.file_exists(path):
		return []
	var src := FileAccess.get_file_as_string(path)
	var func_start := src.find("func loading_completed_handler")
	if func_start < 0:
		return []
	var next_func := src.find("\nfunc ", func_start + 1)
	var body := src.substr(func_start, (src.length() if next_func < 0 else next_func) - func_start)
	var re := RegEx.new()
	re.compile("Vector2\\(\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)\\s*\\)")
	var out: Array = []
	for m in re.search_all(body):
		out.append(Vector2(float(m.get_string(1)), float(m.get_string(2))))
	return out

## 补充验证（coordinator 要求）：原版掩码本身的阻挡在移植版里确实生效，不只是补充障碍。
## 用真实输入点击天空/山脊上的一个原版障碍像素（不是补充障碍——这 3 张图没有 assets/paths_extra/ 文件，
## 合并后的 path_bd 就是原版掩码本身），下达移动命令后最终目的地必须落在可走像素上，
## 并在约 300 帧的实际行走过程中，单位所在像素的掩码值全程为 0。
## 本游戏的输入模型只有左键（选中 + 下移动指令，原版同样没有右键语义，见 game_universe.gd 的
## _unhandled_input_impl/_input_impl），所以用真实左键点击复刻"点地面下达移动指令"。
func test_original_mask_blocks_real_click() -> void:
	# (level 号, 0 基下标, 背景名)：第 2/10/23 关，三张画面里有天空/远山/城墙的图，原版障碍形状没有
	# 被挪到屏幕外（和 level_steppes 等 4 张不同），(350,5) 落在原版障碍（天空/墙/山脊）里。
	var cases := [[2, 1, "level9bg_swamp2"], [10, 9, "level_castle"], [23, 22, "level_montTwo"]]
	for c: Array in cases:
		await _check_real_click_blocked(c[0], c[1], c[2])

func _check_real_click_blocked(level_num: int, level_idx: int, bg: String) -> void:
	root.size = Vector2i(700, 600)  # 舞台固定 700x600，点击坐标即舞台坐标（同 input_e2e.gd）
	var h := Harness.new(self)
	h.boot()
	var gu := h.start_level(level_idx, 54321, 1)
	h.dismiss_chat()
	await process_frame
	var extra := _extra_only_mask(bg)
	check(extra == null, "level_%d (%s): 没有补充障碍层，这次只测原版掩码本身" % [level_num, bg])
	var blocked := Vector2(350, 5)
	check(gu.path_bd != null and gu.path_bd.get_pixel(int(blocked.x), int(blocked.y)) != 0,
		"level_%d (%s): (350,5) 落在原版障碍里（测试前提）" % [level_num, bg])
	var friends: Array = h.friends()
	if friends.is_empty():
		# 这一关的 loadingCompletedHandler 没有放置初始友军（例如第 23 关），招募一个替代——
		# 和用户实际玩法一样，只要场上有友军就能点地面下移动命令。
		var recruited: LivingObject = h.recruit(LivingObject.FR_WARRIOR)
		if recruited != null:
			await process_frame
			friends = h.friends()
	check(not friends.is_empty(), "level_%d (%s): 场上有可操作的友军（含招募）" % [level_num, bg])
	if friends.is_empty():
		h.shutdown()
		return
	var u: LivingObject = friends[0]
	# 真实点击：先点单位选中它（左键 down+up），再点天空/山脊上的目标像素下达移动命令（同样是左键，
	# ground_clicked 分支）——这就是原版唯一的"点地面移动"输入路径。
	await _click_at(Vector2(u.sens.global_position.x, u.sens.global_position.y))
	check(u.selected, "level_%d (%s): 点击单位后处于选中状态" % [level_num, bg])
	await _click_at(blocked)
	for i in 3:
		h.frame()
		await process_frame
	var dest: Vector2 = u.dest_point
	check(gu.path_bd.get_pixel(int(dest.x), int(dest.y)) == 0,
		"level_%d (%s): 最终目的地 (%.0f,%.0f) 必须落在可走像素上" % [level_num, bg, dest.x, dest.y])
	check(dest != blocked, "level_%d (%s): 目的地确实从天空/山脊被挪走" % [level_num, bg])
	# 逐帧推进约 300 帧，期间单位位置的掩码值必须始终为 0（原版 checkObstacles 的不变量）。
	var violations := 0
	for i in range(300):
		h.frame()
		var p: Vector2 = u.position
		if gu.path_bd.get_pixel(int(p.x), int(p.y)) != 0:
			violations += 1
	check(violations == 0,
		"level_%d (%s): 300 帧行走期间单位进入了障碍像素 %d 次" % [level_num, bg, violations])
	h.shutdown()

func _click_at(pos: Vector2) -> void:
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

## 补充验证（coordinator 要求）：对 24 张图都做一遍——从合并后的掩码（原版 + 补充，USE_EXTRA_OBSTACLES
## 保持默认 true）里用固定种子随机取若干个被挡点作为 set_destination 的目标，断言落点可走。
## 不经过完整 Harness（不需要真实点击/HUD），直接用最小的探测单位调用 set_destination，和
## living_core.gd 的 TestUnit 做法一致，覆盖面更广、更快。
class ProbeUnit extends LivingObject:
	func on_play_head_done() -> void: pass
	func on_play_head_action() -> void: pass
	func on_play_head_stopped() -> void: pass
	func got_experience(_p: float) -> void: pass
	func enemy_hit_sound() -> void: pass
	func bring_damage(_p1: int, _p2: LivingObject, _p3: bool = false, _p4: bool = true) -> void: pass

func test_random_blocked_points_all_maps() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_layout.json"))
	var checked := 0
	for bg: String in layout.keys():
		if bg == "_meta":
			continue
		checked += 1
		var gu := GameUniverse.new()
		PathParser.parse(bg, gu)
		GameUniverse.inst = gu
		if gu.path_bd == null:
			check(true, "%s: 合并后没有障碍层，无需校验" % bg)
			gu.free()
			continue
		# 出发位置必须是这张图上一个确定可走的点（有些图中部大面积被原版障碍覆盖，(350,300) 不一定可走）：
		# 栅格扫描找第一个可走像素。
		var start := Vector2(350, 300)
		if gu.path_bd.get_pixel(int(start.x), int(start.y)) != 0:
			var found := false
			for sy in range(0, 600, 20):
				for sx in range(0, 700, 20):
					if gu.path_bd.get_pixel(sx, sy) == 0:
						start = Vector2(sx, sy)
						found = true
						break
				if found:
					break
			check(found, "%s: 找到了一个确定可走的出发点" % bg)
		RWRandom.set_seed(20261105 + checked)  # 固定种子，逐图不同以覆盖更多像素，但每次运行可复现
		var picked := 0
		var attempts := 0
		var bad := 0
		while picked < 8 and attempts < 400:
			attempts += 1
			var x: int = RWRandom.rand_range(0, 699)
			var y: int = RWRandom.rand_range(0, 599)
			if gu.path_bd.get_pixel(x, y) == 0:
				continue
			picked += 1
			var u := ProbeUnit.new()
			u._instance = u
			u.position = start
			u.walk_speed = 5.0
			u.set_destination(Vector2(x, y))
			if gu.path_bd.get_pixel(int(u.dest_point.x), int(u.dest_point.y)) != 0:
				bad += 1
			u.free()
		check(picked > 0, "%s: 随机采样找到了被挡点 (attempts=%d)" % [bg, attempts])
		check(bad == 0, "%s: %d/%d 个随机被挡点的 set_destination 落点仍在障碍上" % [bg, bad, picked])
		gu.free()
	GameUniverse.inst = null
	check(checked == 24, "24 张背景都检查到了 (got %d)" % checked)

## 2) 第 8 关把目的地点在天空（补充障碍）处，单位的实际目的地应被挪到可走区域
func test_destination_moved_out_of_sky() -> void:
	var h := Harness.new(self)
	h.boot()
	var gu := h.start_level(7, 12345, 1)  # 第 8 关 = level_steppes，0 基下标
	await process_frame
	check(gu.path_bd != null, "level_steppes with USE_EXTRA_OBSTACLES=true has a non-null path_bd")
	# (350, 5)：补充的上边缘空气墙内，明显在天空里
	var sky := Vector2(350, 5)
	check(gu.path_bd.get_pixel(int(sky.x), int(sky.y)) != 0, "(350,5) 落在补充的边缘空气墙内（测试前提）")
	var friends: Array = h.friends()
	check(not friends.is_empty(), "level_steppes 的 loadingCompletedHandler 已放置初始友军")
	if not friends.is_empty():
		var u: LivingObject = friends[0]
		u.set_destination(sky)
		check(gu.path_bd.get_pixel(int(u.dest_point.x), int(u.dest_point.y)) == 0,
			"目的地被挪出补充障碍，落点 (%.0f,%.0f) 应可走" % [u.dest_point.x, u.dest_point.y])
		check(u.dest_point != sky, "目的地确实被改写，不再是天空里的原始点")
	h.shutdown()

## 3) USE_EXTRA_OBSTACLES=false 时与原版行为一致：path_bd 只反映 assets/paths/ 的原版掩码
func test_disabled_matches_original() -> void:
	GameUniverse.USE_EXTRA_OBSTACLES = false
	var gu := GameUniverse.new()
	PathParser.parse("level_steppes", gu)
	# level_steppes 本来就有 obstacle 层（assets/paths/level_steppes.png），只是障碍形状被挪到屏幕外，
	# 所以 path_bd 本身不为 null，但画面内（边缘空气墙原本所在处）应该和原版一样完全可走。
	check(gu.path_bd != null, "level_steppes 原版就有障碍层（形状在屏幕外）")
	check(gu.path_bd.get_pixel(5, 5) == 0 and gu.path_bd.get_pixel(350, 5) == 0,
		"USE_EXTRA_OBSTACLES=false 时边缘空气墙原本所在处与原版一样可走")
	var gu2 := GameUniverse.new()
	PathParser.parse("level_field_road", gu2)
	check(gu2.path_bd != null, "USE_EXTRA_OBSTACLES=false 时 level_field_road 仍用原版 assets/paths/ 掩码")
	var orig := RWBitmapData.new("res://assets/paths/level_field_road.png", GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
	var same := true
	for i in range(0, 700, 37):
		for j in range(0, 600, 41):
			if gu2.path_bd.get_pixel(i, j) != orig.get_pixel(i, j):
				same = false
	check(same, "USE_EXTRA_OBSTACLES=false 时掩码逐像素等于 assets/paths/level_field_road.png")
	GameUniverse.USE_EXTRA_OBSTACLES = true
	gu.free()
	gu2.free()
