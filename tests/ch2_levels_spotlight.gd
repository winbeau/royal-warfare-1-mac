extends SceneTree
# WP-D3 验证：第 11（Siege at Stone Wharf）、23（Ride to West Cape）关的专项检查，
# 补充 tests/ch2_levels_data.gd 的通用检查里没覆盖到的点：
#   - 开局单位的 "weapon" 字段能在 data/ch2/weapons.json 里查到，且职业（class）与 kind 对应；
#   - 第 23 关达思重骑（CH2_DARTH_LANCER）三轮冲锋的整队点（route[1]）必须画面内可见（y<=560），
#     且离玩家开局位置（开局单位质心）至少 220px；
#   - 两关地图的关键障碍种类（见 docs/ch2-spotlight-spec.md WP-D3）确实出现在 data/ch2/maps/*.json 里；
#   - 掩码文件已生成。
# 不重复 ch2_levels_data.gd 已经覆盖的字段齐全性 / 文本 id / 可达性检查。

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
	_check_level_11()
	_check_level_23()
	print("ch2_levels_spotlight: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## 开局单位（start.units）的 "weapon" 字段若存在，必须能在 weapons.json 查到，
## 且该武器的 "class" 与 kind 对应的职业一致（CH2_WARDEN -> "warden"、CH2_MUSKETEER -> "musketeer"）。
func _check_weapons(path: String, data: Dictionary, weapons: Dictionary) -> void:
	var kind_class := {"CH2_WARDEN": "warden", "CH2_MUSKETEER": "musketeer"}
	for u: Dictionary in data.get("start", {}).get("units", []):
		var kind_name: String = str(u.get("kind", ""))
		if not kind_class.has(kind_name):
			continue
		check(u.has("weapon"), "%s start unit %s specifies a weapon" % [path, kind_name])
		if not u.has("weapon"):
			continue
		var wid: String = str(u["weapon"])
		check(weapons.has(wid), "%s weapon id %s exists in data/ch2/weapons.json" % [path, wid])
		if weapons.has(wid):
			check(str(weapons[wid].get("class", "")) == kind_class[kind_name],
				"%s weapon %s belongs to the %s class" % [path, wid, kind_class[kind_name]])


func _check_level_11() -> void:
	var path := "res://data/ch2/levels/11.json"
	var data: Dictionary = _load_json(path)
	check(not data.is_empty(), "%s parses" % path)
	if data.is_empty():
		return
	var weapons: Dictionary = _load_json("res://data/ch2/weapons.json")
	_check_weapons(path, data, weapons)

	# 用户 2026-11-06 追加：开局多数直接拿高级武器，只留个别基础武器。
	var units11: Array = data.get("start", {}).get("units", [])
	var weapon_count11: Dictionary = {}
	for u: Dictionary in units11:
		var w: String = str(u.get("weapon", u.get("kind", "")))
		weapon_count11[w] = int(weapon_count11.get(w, 0)) + 1
	check(int(weapon_count11.get("five_thunders", 0)) == 4, "ch2_11 has 4 five_thunders musketeers (got %s)" % weapon_count11.get("five_thunders", 0))
	check(int(weapon_count11.get("heavy_musket", 0)) == 4, "ch2_11 has 4 heavy_musket musketeers (got %s)" % weapon_count11.get("heavy_musket", 0))
	check(int(weapon_count11.get("matchlock", 0)) == 2, "ch2_11 has 2 matchlock musketeers (got %s)" % weapon_count11.get("matchlock", 0))
	check(int(weapon_count11.get("great_glaive", 0)) == 2, "ch2_11 has 2 great_glaive wardens (got %s)" % weapon_count11.get("great_glaive", 0))
	check(int(weapon_count11.get("horse_cleaver", 0)) == 1, "ch2_11 has 1 horse_cleaver warden (got %s)" % weapon_count11.get("horse_cleaver", 0))
	check(int(weapon_count11.get("dao_shield", 0)) == 1, "ch2_11 has 1 dao_shield warden (got %s)" % weapon_count11.get("dao_shield", 0))
	check(int(weapon_count11.get("FR_HEALER", 0)) == 2, "ch2_11 has 2 FR_HEALER (got %s)" % weapon_count11.get("FR_HEALER", 0))

	var map_id: String = str(data.get("background", ""))
	check(map_id == "11-stone-wharf", "%s background is 11-stone-wharf" % path)
	var map_data: Dictionary = _load_json("res://data/ch2/maps/%s.json" % map_id)
	check(not map_data.is_empty(), "map data for %s exists" % map_id)
	var kinds: Array = []
	for o: Dictionary in map_data.get("obstacles", []):
		kinds.append(str(o.get("kind", "")))
	for expect in ["water", "crane", "warehouse", "supply_shed", "workshop_wall"]:
		check(kinds.find(expect) >= 0, "%s map has an obstacle of kind %s" % [map_id, expect])
	check(FileAccess.file_exists("res://data/ch2/masks/%s.png" % map_id), "%s has a baked mask" % map_id)
	check(FileAccess.file_exists("res://build/ch2_masks_debug/%s.png" % map_id), "%s has a debug overlay for review" % map_id)

	# 中央卸货场（约 x150-470,y130-420）完全开阔：四角 + 中心都不落在障碍里。
	var mask := RWBitmapData.new("res://data/ch2/masks/%s.png" % map_id, GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
	for p: Vector2 in [Vector2(150, 130), Vector2(470, 130), Vector2(150, 420), Vector2(470, 420), Vector2(310, 275)]:
		check(mask.get_pixel(int(p.x), int(p.y)) == 0, "%s plaza point %s stays open" % [map_id, p])

	# 用户 2026-11-06 追加：开局站位移到卸货场西半部，不在掩码障碍上。范围框按阵型实际间距
	# （两列火铳 30px 列距 + 镇戍卫东侧 34px + 治疗者西侧 30px，纵向跨度含错开半格与 32px 镇戍卫间距）放宽。
	for u: Dictionary in data.get("start", {}).get("units", []):
		var at: Array = u.get("at", [0, 0])
		var pt := Vector2(float(at[0]), float(at[1]))
		check(mask.get_pixel(int(pt.x), int(pt.y)) == 0, "%s start unit %s at %s is not on an obstacle" % [map_id, u.get("kind", "?"), pt])
		check(pt.x >= 150.0 and pt.x <= 260.0 and pt.y >= 235.0 and pt.y <= 380.0,
			"%s start unit %s at %s sits in the west half of the unloading yard (~150-260,235-380)" % [map_id, u.get("kind", "?"), pt])


func _check_level_23() -> void:
	var path := "res://data/ch2/levels/23.json"
	var data: Dictionary = _load_json(path)
	check(not data.is_empty(), "%s parses" % path)
	if data.is_empty():
		return
	var weapons: Dictionary = _load_json("res://data/ch2/weapons.json")
	_check_weapons(path, data, weapons)

	# 用户 2026-11-06 追加的开局编制：镇戍卫 6（陌刀 4、斩马刀 1、刀盾 1）、火铳卫 4（重管 2、制式 2）、治疗者 1。
	var units: Array = data.get("start", {}).get("units", [])
	var weapon_count: Dictionary = {}
	for u: Dictionary in units:
		var w: String = str(u.get("weapon", u.get("kind", "")))
		weapon_count[w] = int(weapon_count.get(w, 0)) + 1
	check(int(weapon_count.get("great_glaive", 0)) == 4, "ch2_23 has 4 great_glaive wardens (got %s)" % weapon_count.get("great_glaive", 0))
	check(int(weapon_count.get("horse_cleaver", 0)) == 1, "ch2_23 has 1 horse_cleaver warden (got %s)" % weapon_count.get("horse_cleaver", 0))
	check(int(weapon_count.get("dao_shield", 0)) == 1, "ch2_23 has 1 dao_shield warden (got %s)" % weapon_count.get("dao_shield", 0))
	check(int(weapon_count.get("heavy_musket", 0)) == 2, "ch2_23 has 2 heavy_musket musketeers (got %s)" % weapon_count.get("heavy_musket", 0))
	check(int(weapon_count.get("five_thunders", 0)) == 1, "ch2_23 has 1 five_thunders musketeer (got %s)" % weapon_count.get("five_thunders", 0))
	check(int(weapon_count.get("matchlock", 0)) == 1, "ch2_23 has 1 matchlock musketeer (got %s)" % weapon_count.get("matchlock", 0))
	check(int(weapon_count.get("FR_HEALER", 0)) == 1, "ch2_23 has 1 FR_HEALER (got %s)" % weapon_count.get("FR_HEALER", 0))

	# 第 5 阶段（主攻）6 骑之后的步行达思骑士（下马）由 4 改为 2。
	var p5: Dictionary = {}
	for ph: Dictionary in data.get("phases", []):
		if str(ph.get("id", "")) == "p5":
			p5 = ph
	check(not p5.is_empty(), "ch2_23 has phase p5")
	var darth_knight_count := 0
	for action: Dictionary in p5.get("do", []):
		if action.has("spawn"):
			for row: Array in action["spawn"]:
				if str(row[0]) == "RW_DARTH_KNIGHT":
					darth_knight_count += int(row[2])
	check(darth_knight_count == 2, "ch2_23 phase p5 follows the 6 lancers with 2 dismounted darth knights (got %d)" % darth_knight_count)

	# 玩家开局位置质心
	var centroid := Vector2.ZERO
	var n := 0
	for u: Dictionary in units:
		var at: Array = u.get("at", [0, 0])
		centroid += Vector2(float(at[0]), float(at[1]))
		n += 1
	if n > 0:
		centroid /= float(n)

	var map_id: String = str(data.get("background", ""))
	check(map_id == "23-west-cape", "%s background is 23-west-cape" % path)
	var map_data: Dictionary = _load_json("res://data/ch2/maps/%s.json" % map_id)
	check(not map_data.is_empty(), "map data for %s exists" % map_id)
	var kinds: Array = []
	for o: Dictionary in map_data.get("obstacles", []):
		kinds.append(str(o.get("kind", "")))
	for expect in ["fence_west", "fence_east", "nw_rocks", "east_cliff"]:
		check(kinds.find(expect) >= 0, "%s map has an obstacle of kind %s" % [map_id, expect])
	check(FileAccess.file_exists("res://data/ch2/masks/%s.png" % map_id), "%s has a baked mask" % map_id)
	check(FileAccess.file_exists("res://build/ch2_masks_debug/%s.png" % map_id), "%s has a debug overlay for review" % map_id)

	# 质量要求 3：重骑（CH2_DARTH_LANCER）每轮冲锋的整队点 route[numb-1][1] 必须画面内可见
	# （y<=560）且离玩家开局质心至少 220px。按 spawn 动作引用的 route 号逐个检查。
	var enemies: Array = map_data.get("enemies", [])
	var cavalry_routes: Dictionary = {}  # route numb -> true
	for ph: Dictionary in data.get("phases", []):
		for action: Dictionary in ph.get("do", []):
			if action.has("spawn"):
				for row: Array in action["spawn"]:
					if str(row[0]) == "CH2_DARTH_LANCER":
						cavalry_routes[int(action.get("route", 1))] = true
	check(not cavalry_routes.is_empty(), "ch2_23 has at least one cavalry spawn route")
	for numb: int in cavalry_routes.keys():
		var idx: int = numb - 1
		check(idx >= 0 and idx < enemies.size(), "ch2_23 map has a route %d for the cavalry spawn" % numb)
		if idx < 0 or idx >= enemies.size():
			continue
		var route: Array = enemies[idx]
		check(route.size() >= 2, "ch2_23 route %d has a rally point (second point)" % numb)
		if route.size() < 2:
			continue
		var rally: Array = route[1]
		var rally_pt := Vector2(float(rally[0]), float(rally[1]))
		check(rally_pt.y <= 560.0, "ch2_23 route %d rally point %s is on-screen (y<=560)" % [numb, rally_pt])
		check(rally_pt.distance_to(centroid) >= 220.0,
			"ch2_23 route %d rally point %s is at least 220px from the player start centroid %s (got %.1f)" % [numb, rally_pt, centroid, rally_pt.distance_to(centroid)])

	# 港门热区（hold_gate）不落在栅栏障碍里，门洞确实留空。
	var mask := RWBitmapData.new("res://data/ch2/masks/%s.png" % map_id, GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
	for o: Dictionary in data.get("objectives", []):
		if str(o.get("type", "")) == "protect":
			var rect: Array = o.get("rect", [0, 0, 0, 0])
			var center := Vector2(float(rect[0]) + float(rect[2]) / 2.0, float(rect[1]) + float(rect[3]) / 2.0)
			check(mask.get_pixel(int(center.x), int(center.y)) == 0, "%s objective %s hit-zone %s is not inside an obstacle" % [map_id, o.get("id", "?"), center])
	# 两条南路与中央平地完全开阔。
	for p: Vector2 in [Vector2(200, 400), Vector2(500, 400), Vector2(350, 400), Vector2(350, 300)]:
		check(mask.get_pixel(int(p.x), int(p.y)) == 0, "%s south roads / central flat point %s stays open" % [map_id, p])
