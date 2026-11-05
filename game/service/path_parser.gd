# 移植自 S/gameCore/serviceUtils/pathParser.as
# 原版遍历背景 MovieClip 的子剪辑；这里改读 data/level_layout.json（原始布局，子剪辑按显示列表顺序）
# 和 assets/paths/<背景>.png（等价于 pathBD.draw(obstacle) 的 700x600 掩码）。
# 坐标语义与原版一致：route 的 node 坐标是相对其父 route 的本地 x/y，不叠加 route 自身的摆放矩阵。
class_name PathParser
extends RefCounted

const LAYOUT_PATH := "res://data/level_layout.json"
const MASK_DIR := "res://assets/paths/"

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
	# aPathMap.sortOn("numb", Array.NUMERIC)；GDScript 的 sort_custom 不稳定，同 numb 的相对次序原版也未定义
	param2.a_path_map.sort_custom(func(a: MapRoute, b: MapRoute) -> bool: return a.numb < b.numb)

## AS3 int("12") / int("") 语义
static func _as_int(s: String) -> int:
	if s.is_valid_int():
		return s.to_int()
	return 0
