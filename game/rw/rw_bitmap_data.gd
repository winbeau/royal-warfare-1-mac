# 原版 flash.display.BitmapData 的只读子集：障碍掩码 pathBD（700x600，不透明）。
# 掩码来自 assets/paths/<背景>.png（P0 导出，等价于原版 pathBD.draw(obstacle)）；getPixel != 0 即障碍。
class_name RWBitmapData
extends RefCounted

var width: int = 0
var height: int = 0
var _data: PackedByteArray = PackedByteArray()  # RGB8，行优先

## path 为空时构造全黑（0）位图，大小用 w/h。
func _init(path: String = "", w: int = 700, h: int = 600) -> void:
	if path == "":
		width = w
		height = h
		_data.resize(w * h * 3)
		_data.fill(0)
		return
	var img := _load_image(path)
	if img == null:
		push_error("RWBitmapData: cannot load %s" % path)
		width = w
		height = h
		_data.resize(w * h * 3)
		_data.fill(0)
		return
	img.convert(Image.FORMAT_RGB8)
	width = img.get_width()
	height = img.get_height()
	_data = img.get_data()

static func _load_image(path: String) -> Image:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex.get_image()
	var img := Image.load_from_file(path)
	if img != null and not img.is_empty():
		return img
	return null

## getPixel(x, y)：RGB 整数 0xRRGGBB；越界返回 0。坐标按 AS3 int 截断。
func get_pixel(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return 0
	var i := (y * width + x) * 3
	return (_data[i] << 16) | (_data[i + 1] << 8) | _data[i + 2]
