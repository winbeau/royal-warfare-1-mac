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
