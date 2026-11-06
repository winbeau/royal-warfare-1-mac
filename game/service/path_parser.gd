# 移植自 S/gameCore/serviceUtils/pathParser.as
# 原版遍历背景 MovieClip 的子剪辑；这里改读 data/level_layout.json（原始布局，子剪辑按显示列表顺序）
# 和 assets/paths/<背景>.png（等价于 pathBD.draw(obstacle) 的 700x600 掩码）。
# 坐标语义与原版一致：route 的 node 坐标是相对其父 route 的本地 x/y，不叠加 route 自身的摆放矩阵。
class_name PathParser
extends RefCounted

const LAYOUT_PATH := "res://data/level_layout.json"
const MASK_DIR := "res://assets/paths/"
# 用户要求的玩法改动（不是原版数据，和 assets/paths/ 分开存放）：地图的补充"空气墙"，
# 见 docs/verification.md「用户要求的玩法改动」。由 GameUniverse.USE_EXTRA_OBSTACLES 控制是否生效。
const EXTRA_MASK_DIR := "res://assets/paths_extra/"

static var _layout: Dictionary = {}

static func _get_layout() -> Dictionary:
	if _layout.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
		if parsed is Dictionary:
			_layout = parsed
		else:
			push_error("PathParser: bad layout %s" % LAYOUT_PATH)
	return _layout

## 原版 parse(bgMc, universe)：bgMc 的类名即 bg_name（levelTemplate.levelBg 的类名，如 "level_field_road"）。
static func parse(bg_name: String, param2: GameUniverse) -> void:
	param2.a_path_map = []
	param2.a_obstacles = []
	var layout: Dictionary = _get_layout()
	var entry: Dictionary = layout.get(bg_name, {})
	if entry.is_empty():
		push_error("PathParser: no layout for background %s" % bg_name)
	var has_obstacle := false
	for item: Dictionary in entry.get("items", []):
		var n: String = item.get("name", "")
		var clip := RWLayoutClip.from_item(item)
		if n.substr(0, 5) == "route":
			var r := MapRoute.new()
			r.numb = _as_int(n.substr(5))
			r.a_points = []
			var count := clip.get_num_children()
			var i := 0
			while count > 0:  # 原版：while(numChildren--) 取 "node" + i
				count -= 1
				var node := clip.get_child_by_name("node%d" % i)
				if node == null:
					push_error("PathParser: %s/%s missing node%d" % [bg_name, n, i])
				else:
					r.a_points.append(Vector2(node.x, node.y))
				i += 1
			param2.a_path_map.append(r)
		elif n == "obstacle":
			has_obstacle = true
			var mask := MASK_DIR + bg_name + ".png"
			param2.path_bd = RWBitmapData.new(mask, GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
		elif n == "eObstacleWP":
			param2.obstacle_way_points = clip
		elif n == "eDefFlagPlace":
			param2.def_flag_object = clip
	if not has_obstacle:
		param2.path_bd = null
	# 用户要求的玩法改动：按像素把补充障碍（空气墙）和原版障碍"或"合并，USE_EXTRA_OBSTACLES=false 时
	# 完全跳过，行为与原版一致。原版没有障碍层（path_bd 为 null）的背景，若补充层存在也要能正确建出掩码。
	if GameUniverse.USE_EXTRA_OBSTACLES:
		var extra_path := EXTRA_MASK_DIR + bg_name + ".png"
		if ResourceLoader.exists(extra_path) or FileAccess.file_exists(extra_path):
			var extra_bd := RWBitmapData.new(extra_path, GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
			param2.path_bd = MergedMask.new(GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT, param2.path_bd, extra_bd)
	# aPathMap.sortOn("numb", Array.NUMERIC)；GDScript 的 sort_custom 不稳定，同 numb 的相对次序原版也未定义
	param2.a_path_map.sort_custom(func(a: MapRoute, b: MapRoute) -> bool: return a.numb < b.numb)

## AS3 int("12") / int("") 语义
static func _as_int(s: String) -> int:
	if s.is_valid_int():
		return s.to_int()
	return 0

# ---------------------------------------------------------------------------
# 二次开发（第二章）：地图几何不再来自 level_layout.json / assets/paths，而是
# data/ch2/maps/<id>.json（粗略设计意图，经 dev/ch2_tools/build_masks.gd 转成掩码）。
# ---------------------------------------------------------------------------

const CH2_MAPS_DIR := "res://data/ch2/maps/"
const CH2_MASKS_DIR := "res://data/ch2/masks/"

## GameUniverse.continue_loading_level_data 在 chapter == 2 时调用，取代 parse()。
## bg 由 level_info.map_id 给出（关卡 JSON "background" 去掉 "ch2/" 前缀后的地图 id）。
static func parse_ch2(level_info: LevelCh2, gu: GameUniverse) -> void:
	gu.a_path_map = []
	gu.a_obstacles = []
	gu.def_flag_object = null
	var map_id: String = level_info.map_id
	var map_data: Dictionary = get_ch2_map(map_id)
	if map_data.is_empty():
		push_error("PathParser: no ch2 map data for %s" % map_id)
	# 敌路：enemies[i] 是一条折线，编号 numb = i + 1
	var enemies: Array = map_data.get("enemies", [])
	for i in enemies.size():
		var r := MapRoute.new()
		r.numb = i + 1
		r.a_points = []
		for pt: Array in enemies[i]:
			r.a_points.append(Vector2(float(pt[0]), float(pt[1])))
		gu.a_path_map.append(r)
	# 友军入场路线 0：关卡 JSON 的 friendly_route；缺省时用 [recruit + (-40, 0), recruit]，
	# 对应一代 addSoldier -> addToGame(0, 0) -> setRoute(0) 从该路线第一个点附近入场的用法。
	var r0 := MapRoute.new()
	r0.numb = 0
	if level_info.friendly_route.size() > 0:
		for pt: Array in level_info.friendly_route:
			r0.a_points.append(Vector2(float(pt[0]), float(pt[1])))
	else:
		var recruit: Array = map_data.get("recruit", [0, 0])
		var recruit_pt := Vector2(float(recruit[0]), float(recruit[1]))
		r0.a_points = [recruit_pt + Vector2(-40, 0), recruit_pt]
	gu.a_path_map.append(r0)
	gu.a_path_map.sort_custom(func(a: MapRoute, b: MapRoute) -> bool: return a.numb < b.numb)
	# 掩码：预烘焙的 700x600 PNG（build_masks.gd 由障碍多边形生成），非 0 即障碍
	gu.path_bd = RWBitmapData.new(CH2_MASKS_DIR + map_id + ".png", GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)
	# 绕障路点：运行时由障碍多边形生成（桥面多边形不生成环，只用来在掩码里挖空，由 build_masks.gd 处理）
	gu.obstacle_way_points = build_ch2_obstacle_way_points(map_data)


## 供 build_masks.gd 复用的同一份地图读取逻辑。
static func get_ch2_map(map_id: String) -> Dictionary:
	var f := FileAccess.open(CH2_MAPS_DIR + map_id + ".json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## 按 LivingObject.check_obstacles 的解析规则构造 eObstacleWP：每个非 bridge_override 障碍是一环，
## 环号 = 该障碍去掉 bridge_override 后的序号（0 基，必须 ≤ 9——超过要合并小障碍或在报告里说明）。
## 点沿 Geometry2D.offset_polygon(poly, 18) 外扩后的边界采样，间距约 25 px，子节点命名 "p{环号}_{序号}"，
## 与 LivingObject.check_obstacles 读取的 "第 2 个字符是环号，从第 4 个字符起是序号" 一致。
static func build_ch2_obstacle_way_points(map_data: Dictionary) -> RWLayoutClip:
	var root := RWLayoutClip.new()
	root.name = "eObstacleWP"
	var ring_no := 0
	for obs: Dictionary in map_data.get("obstacles", []):
		if str(obs.get("kind", "")) == "bridge_override":
			continue
		if ring_no > 9:
			push_error("PathParser: ch2 map %s has more than 10 obstacle rings; merge small obstacles" % map_data.get("id", "?"))
			break
		var poly := PackedVector2Array()
		for pt: Array in obs.get("polygon", []):
			poly.append(Vector2(float(pt[0]), float(pt[1])))
		if poly.size() < 3:
			continue
		var offset: Array = Geometry2D.offset_polygon(poly, 18.0)
		if offset.is_empty():
			ring_no += 1
			continue
		var outline: PackedVector2Array = offset[0]
		var sampled := _sample_polygon_edge(outline, 25.0)
		for j in sampled.size():
			var wp := RWLayoutClip.new()
			wp.name = "p%d_%d" % [ring_no, j]
			wp.x = sampled[j].x
			wp.y = sampled[j].y
			root.children.append(wp)
		ring_no += 1
	return root


## 沿闭合多边形边界按约 spacing 像素的间距均匀采样（首点为 poly[0]，不重复终点）。
static func _sample_polygon_edge(poly: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	if n < 3:
		return out
	var perim := 0.0
	for i in n:
		perim += poly[i].distance_to(poly[(i + 1) % n])
	if perim <= 0:
		return out
	var steps: int = maxi(3, int(round(perim / spacing)))
	var step_len: float = perim / steps
	var seg := 0
	var acc := 0.0
	var seg_len: float = poly[0].distance_to(poly[1 % n])
	var next_target := 0.0
	for _k in steps:
		while acc + seg_len < next_target and seg < n - 1:
			acc += seg_len
			seg += 1
			seg_len = poly[seg % n].distance_to(poly[(seg + 1) % n])
		var t: float = 0.0 if seg_len <= 0 else (next_target - acc) / seg_len
		out.append(poly[seg % n].lerp(poly[(seg + 1) % n], clampf(t, 0.0, 1.0)))
		next_target += step_len
	return out

## 用户要求的玩法改动专用：把原版障碍（可能为 null）和补充障碍按像素"或"合并成一张新的只读掩码。
## 不改 RWBitmapData 本体（它是原版 pathBD 的等价实现），避免混入原版数据与玩法改动的数据。
class MergedMask extends RWBitmapData:
	var _or_data: PackedByteArray

	func _init(w: int, h: int, base: RWBitmapData, extra: RWBitmapData) -> void:
		super("", w, h)
		_or_data = PackedByteArray()
		_or_data.resize(w * h * 3)
		for y in range(h):
			for x in range(w):
				var base_px := 0 if base == null else base.get_pixel(x, y)
				var extra_px := 0 if extra == null else extra.get_pixel(x, y)
				var v: int = 0 if (base_px == 0 and extra_px == 0) else 255
				var i := (y * w + x) * 3
				_or_data[i] = v
				_or_data[i + 1] = v
				_or_data[i + 2] = v

	func get_pixel(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= width or y >= height:
			return 0
		var i := (y * width + x) * 3
		return (_or_data[i] << 16) | (_or_data[i + 1] << 8) | _or_data[i + 2]
