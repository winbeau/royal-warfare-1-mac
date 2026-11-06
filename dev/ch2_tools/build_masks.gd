## 离线工具（headless 专用，不参与导出）：把 data/ch2/maps/<id>.json 的障碍多边形烘焙成
## data/ch2/masks/<id>.png（700x600 RGB8，非 0 为障碍），并输出带标注的检查图到
## build/ch2_masks_debug/<id>.png，供人眼核对多边形和底图是否吻合。
## 运行：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##     --script dev/ch2_tools/build_masks.gd -- --ch2-map=01-mist-bay[,02-...]
## 不带 --ch2-map 参数时处理 data/ch2/maps/*.json 里的全部地图。
extends SceneTree

const MAPS_DIR := "res://data/ch2/maps/"
const MASKS_DIR := "res://data/ch2/masks/"
const DEBUG_DIR := "res://build/ch2_masks_debug/"
const BG_DIR := "res://assets/backgrounds/ch2/"
const W := 700
const H := 600


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MASKS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEBUG_DIR))
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ch2-map="):
			only = arg.substr(10).split(",")
	var dir := DirAccess.open(MAPS_DIR)
	var ids: Array = []
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".json"):
				ids.append(f.get_basename())
			f = dir.get_next()
		dir.list_dir_end()
	ids.sort()
	for id in ids:
		if not only.is_empty() and only.find(id) < 0:
			continue
		_build_one(id)
	print("ch2 build_masks done: ", ids if only.is_empty() else only)
	quit(0)


func _build_one(id: String) -> void:
	var map_path := MAPS_DIR + id + ".json"
	var f := FileAccess.open(map_path, FileAccess.READ)
	if f == null:
		push_error("build_masks: cannot open %s" % map_path)
		return
	var map_data: Variant = JSON.parse_string(f.get_as_text())
	if not (map_data is Dictionary):
		push_error("build_masks: bad json %s" % map_path)
		return
	_write_mask(id, map_data)
	_write_debug(id, map_data)


func _write_mask(id: String, map_data: Dictionary) -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	for obs: Dictionary in map_data.get("obstacles", []):
		if str(obs.get("kind", "")) == "bridge_override":
			continue
		_fill_polygon(img, _poly(obs.get("polygon", [])), Color.WHITE)
	for obs: Dictionary in map_data.get("obstacles", []):
		if str(obs.get("kind", "")) == "bridge_override":
			_fill_polygon(img, _poly(obs.get("polygon", [])), Color.BLACK)
	var out_path := MASKS_DIR + id + ".png"
	var err := img.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		push_error("build_masks: cannot save %s (%d)" % [out_path, err])
	else:
		print("mask -> ", out_path)


static func _poly(raw: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for pt: Array in raw:
		p.append(Vector2(float(pt[0]), float(pt[1])))
	return p


## 逐像素点在多边形测试；地图数量小、离线工具跑一次即可，不追求速度。
static func _fill_polygon(img: Image, poly: PackedVector2Array, color: Color) -> void:
	if poly.size() < 3:
		return
	var min_x := W
	var max_x := 0
	var min_y := H
	var max_y := 0
	for p in poly:
		min_x = mini(min_x, int(floor(p.x)))
		max_x = maxi(max_x, int(ceil(p.x)))
		min_y = mini(min_y, int(floor(p.y)))
		max_y = maxi(max_y, int(ceil(p.y)))
	min_x = maxi(min_x, 0)
	min_y = maxi(min_y, 0)
	max_x = mini(max_x, W - 1)
	max_y = mini(max_y, H - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, color)


func _write_debug(id: String, map_data: Dictionary) -> void:
	var bg_path := BG_DIR + id + ".png"
	var canvas: Image
	if ResourceLoader.exists(bg_path):
		var tex := load(bg_path) as Texture2D
		canvas = tex.get_image()
		canvas.convert(Image.FORMAT_RGBA8)
		canvas.resize(W, H, Image.INTERPOLATE_BILINEAR)
	else:
		canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0.2, 0.2, 0.2))
	# 半透明红色叠障碍（桥面仍是红色的"洞"，不叠色，方便看出挖空范围）
	for obs: Dictionary in map_data.get("obstacles", []):
		var is_bridge: bool = str(obs.get("kind", "")) == "bridge_override"
		_overlay_polygon(canvas, _poly(obs.get("polygon", [])), Color(1, 0, 0, 0.0 if is_bridge else 0.45))
	# 敌路：蓝线
	for route: Array in map_data.get("enemies", []):
		_draw_polyline(canvas, _poly(route), Color.DODGER_BLUE)
	# 护送/友军路线：绿线
	if map_data.has("escort"):
		_draw_polyline(canvas, _poly(map_data["escort"]), Color.LIME_GREEN)
	# 锚点：黄点
	for key in ["start", "target", "recruit"]:
		if map_data.has(key):
			var pt: Array = map_data[key]
			_draw_dot(canvas, Vector2(float(pt[0]), float(pt[1])), Color.YELLOW)
	for p: Array in map_data.get("points", []):
		if p.size() >= 3:
			_draw_dot(canvas, Vector2(float(p[1]), float(p[2])), Color.YELLOW)
	var out_path := DEBUG_DIR + id + ".png"
	var err := canvas.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		push_error("build_masks: cannot save debug %s (%d)" % [out_path, err])
	else:
		print("debug -> ", out_path)


static func _overlay_polygon(img: Image, poly: PackedVector2Array, color: Color) -> void:
	if poly.size() < 3 or color.a <= 0.0:
		return
	var min_x := maxi(0, int(floor(_min_x(poly))))
	var max_x := mini(W - 1, int(ceil(_max_x(poly))))
	var min_y := maxi(0, int(floor(_min_y(poly))))
	var max_y := mini(H - 1, int(ceil(_max_y(poly))))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				var base := img.get_pixel(x, y)
				img.set_pixel(x, y, base.lerp(color, color.a))


static func _min_x(p: PackedVector2Array) -> float:
	var m := INF
	for v in p: m = minf(m, v.x)
	return m


static func _max_x(p: PackedVector2Array) -> float:
	var m := -INF
	for v in p: m = maxf(m, v.x)
	return m


static func _min_y(p: PackedVector2Array) -> float:
	var m := INF
	for v in p: m = minf(m, v.y)
	return m


static func _max_y(p: PackedVector2Array) -> float:
	var m := -INF
	for v in p: m = maxf(m, v.y)
	return m


static func _draw_polyline(img: Image, pts: PackedVector2Array, color: Color) -> void:
	for i in pts.size() - 1:
		_draw_line(img, pts[i], pts[i + 1], color)


static func _draw_line(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps: int = maxi(1, int(a.distance_to(b)))
	for s in steps + 1:
		var p: Vector2 = a.lerp(b, float(s) / float(steps))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = int(p.x) + dx
				var y: int = int(p.y) + dy
				if x >= 0 and x < W and y >= 0 and y < H:
					img.set_pixel(x, y, color)


static func _draw_dot(img: Image, p: Vector2, color: Color) -> void:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var x: int = int(p.x) + dx
			var y: int = int(p.y) + dy
			if x >= 0 and x < W and y >= 0 and y < H and dx * dx + dy * dy <= 9:
				img.set_pixel(x, y, color)
