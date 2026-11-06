extends SceneTree
# WP-B 验证：data/ch2/levels/*.json 的静态数据检查（字段齐全、id 存在、kind 能映射、
# 敌路几何、锚点不落在障碍里、腐蚀后掩码上全部关键锚点互相可达）。不需要 GameUniverse。

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
	var dir := DirAccess.open("res://data/ch2/levels/")
	var ids: Array = []
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".json"):
				ids.append(int(f.get_basename()))
			f = dir.get_next()
		dir.list_dir_end()
	ids.sort()
	check(ids.size() >= 2, "at least levels 01 and 02 exist (got %s)" % [ids])
	var levels_text: Dictionary = _load_json("res://data/ch2/text/levels.json")
	var dialogue_text: Dictionary = _load_json("res://data/ch2/text/dialogue.json")
	var dialogue_ids: Array = []
	for e: Dictionary in dialogue_text.get("events", []):
		dialogue_ids.append(str(e.get("id", "")))
	for n in ids:
		_check_level(n, levels_text, dialogue_ids)
	print("ch2_levels_data: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _check_level(n: int, levels_text: Dictionary, dialogue_ids: Array) -> void:
	var path := "res://data/ch2/levels/%02d.json" % n
	var data: Dictionary = _load_json(path)
	check(not data.is_empty(), "%s parses as a dictionary" % path)
	if data.is_empty():
		return
	for field in ["id", "name", "background", "start", "objectives", "phases", "victory", "failure", "stars"]:
		check(data.has(field), "%s has field %s" % [path, field])

	# 目标 id 必须在 data/ch2/text/levels.json 对应关卡的 objectives[] 里
	var text_level: Dictionary = {}
	for l: Dictionary in levels_text.get("levels", []):
		if int(l.get("number", 0)) == n:
			text_level = l
			break
	check(not text_level.is_empty(), "levels.json has text for level %d" % n)
	var text_obj_ids: Array = []
	for o: Dictionary in text_level.get("objectives", []):
		text_obj_ids.append(str(o.get("id", "")))
	var obj_ids: Array = []
	for o: Dictionary in data.get("objectives", []):
		var oid: String = str(o.get("id", ""))
		obj_ids.append(oid)
		check(text_obj_ids.find(oid) >= 0, "%s objective id %s exists in levels.json text" % [path, oid])
		check(["escort", "evac", "protect", "pickup", "reach", "kill"].find(str(o.get("type", ""))) >= 0, "%s objective %s has a known type" % [path, oid])

	# 对白 id 必须存在于 dialogue.json
	for ev in data.get("dialogue", []):
		check(dialogue_ids.find(str(ev)) >= 0, "%s dialogue id %s exists in dialogue.json" % [path, ev])

	# 敌人 kind 都能映射到一代常量（spawn 动作里出现的 kind 字符串）
	for ph: Dictionary in data.get("phases", []):
		for action: Dictionary in ph.get("do", []):
			if action.has("spawn"):
				for row: Array in action["spawn"]:
					var kind_name := str(row[0])
					check(Ch2Kinds.is_enemy(kind_name), "%s phase %s spawns a known enemy kind %s" % [path, ph.get("id", "?"), kind_name])

	# 开局兵力 / 盟军 kind 都能解析
	for u: Dictionary in data.get("start", {}).get("units", []):
		check(Ch2Kinds.resolve(str(u.get("kind", ""))) != -1, "%s start unit kind %s resolves" % [path, u.get("kind", "")])
	for a: Dictionary in data.get("start", {}).get("allies", []):
		check(Ch2Kinds.resolve(str(a.get("kind", ""))) != -1, "%s ally kind %s resolves" % [path, a.get("kind", "")])
	for lk in data.get("locked", []):
		check(Ch2Kinds.resolve_lock(str(lk)) != -1, "%s locked name %s resolves" % [path, lk])

	# 地图几何：敌路起点在画面外，第二个点在画面内；关键锚点不落在障碍里；可达性
	var map_id: String = str(data.get("background", ""))
	var map_data: Dictionary = PathParser.get_ch2_map(map_id)
	check(not map_data.is_empty(), "%s has map data %s" % [path, map_id])
	if map_data.is_empty():
		return
	var mask := RWBitmapData.new("res://data/ch2/masks/%s.png" % map_id, GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
	var enemies: Array = map_data.get("enemies", [])
	for i in enemies.size():
		var route: Array = enemies[i]
		check(route.size() >= 2, "%s enemy route %d has at least 2 points" % [map_id, i])
		if route.size() < 2:
			continue
		var p0: Array = route[0]
		var p1: Array = route[1]
		var outside: bool = float(p0[0]) < 0 or float(p0[0]) > GameUniverse.MAX_SCREEN_WIDTH or float(p0[1]) < 0 or float(p0[1]) > GameUniverse.MAX_SCREEN_HEIGHT
		check(outside, "%s enemy route %d starts off-screen %s" % [map_id, i, p0])
		var inside: bool = float(p1[0]) >= 0 and float(p1[0]) <= GameUniverse.MAX_SCREEN_WIDTH and float(p1[1]) >= 0 and float(p1[1]) <= GameUniverse.MAX_SCREEN_HEIGHT
		check(inside, "%s enemy route %d's second point is on-screen %s" % [map_id, i, p1])

	var anchors: Array = []  # Array[Vector2]，供可达性检查
	var recruit: Array = map_data.get("recruit", [0, 0])
	anchors.append(Vector2(float(recruit[0]), float(recruit[1])))
	for o: Dictionary in data.get("objectives", []):
		match str(o.get("type", "")):
			"escort":
				for pt: Array in o.get("path", []):
					anchors.append(Vector2(float(pt[0]), float(pt[1])))
			"evac":
				if o.has("path"):
					for pt: Array in o["path"]:
						anchors.append(Vector2(float(pt[0]), float(pt[1])))
				else:
					anchors.append(Vector2(float(o.get("from", [0, 0])[0]), float(o.get("from", [0, 0])[1])))
					anchors.append(Vector2(float(o.get("to", [0, 0])[0]), float(o.get("to", [0, 0])[1])))
			"protect":
				var rect: Array = o.get("rect", [0, 0, 0, 0])
				anchors.append(Vector2(float(rect[0]) + float(rect[2]) / 2.0, float(rect[1]) + float(rect[3]) / 2.0))
			"pickup", "reach":
				var at: Array = o.get("at", [0, 0])
				anchors.append(Vector2(float(at[0]), float(at[1])))
	for a: Vector2 in anchors:
		check(mask.get_pixel(int(a.x), int(a.y)) == 0, "%s anchor %s is not inside an obstacle" % [map_id, a])

	var friendly_end: Vector2 = Vector2(float(recruit[0]), float(recruit[1]))
	if data.get("friendly_route", []).size() > 0:
		var fr: Array = data["friendly_route"]
		var last: Array = fr[fr.size() - 1]
		friendly_end = Vector2(float(last[0]), float(last[1]))
	_check_reachability(map_id, mask, enemies, anchors, [Vector2(float(recruit[0]), float(recruit[1])), friendly_end])


## 把掩码按 8px 腐蚀成通行图，从每条敌路进画面的第一个点、recruit 锚点和友军路线终点出发做 BFS，
## 必须能到达全部关键锚点。
func _check_reachability(map_id: String, mask: RWBitmapData, enemies: Array, anchors: Array, extra_seeds: Array) -> void:
	const W := 700
	const H := 600
	const CELL := 4  # 腐蚀+BFS 按 4px 网格近似，足够判断连通性且比逐像素快
	const ERODE := 8
	var passable := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= W or y >= H:
			return false
		for dy in range(-ERODE, ERODE + 1, ERODE):
			for dx in range(-ERODE, ERODE + 1, ERODE):
				if mask.get_pixel(clampi(x + dx, 0, W - 1), clampi(y + dy, 0, H - 1)) != 0:
					return false
		return true
	var cols := W / CELL
	var rows := H / CELL
	var visited := {}
	var queue: Array = []
	var seeds: Array = extra_seeds.duplicate()
	for route: Array in enemies:
		if route.size() < 2:
			continue
		seeds.append(Vector2(float(route[1][0]), float(route[1][1])))  # 第二个点（画面内第一个落点）
	for entry: Vector2 in seeds:
		var gx: int = clampi(int(entry.x) / CELL, 0, cols - 1)
		var gy: int = clampi(int(entry.y) / CELL, 0, rows - 1)
		var key := gy * cols + gx
		if not visited.has(key):
			visited[key] = true
			queue.append(Vector2i(gx, gy))
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = c.x + d.x
			var ny: int = c.y + d.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var k: int = ny * cols + nx
			if visited.has(k):
				continue
			if passable.call(nx * CELL + CELL / 2, ny * CELL + CELL / 2):
				visited[k] = true
				queue.append(Vector2i(nx, ny))
	for a: Vector2 in anchors:
		var gx: int = clampi(int(a.x) / CELL, 0, cols - 1)
		var gy: int = clampi(int(a.y) / CELL, 0, rows - 1)
		check(visited.has(gy * cols + gx), "%s anchor %s is reachable from the enemy entry points" % [map_id, a])
