## WP-D1：第二章单位共用的小工具——命中热区贴图、脚下影子、按包围盒的热区判定。
## 一代用 sens_class 符号 + alpha 缓存（LivingObject._sens_alpha_cache）判定命中；二章单位改用一块
## 整体不透明的矩形贴图（不经过 Content/symbols），命中判定也相应改成包围盒判定（Ch2*.hit_test_sens 重写），
## 不改 living_object.gd 的 sens/_sens_alpha_cache 写法。
class_name Ch2Paperdoll
extends RefCounted

static var _sens_textures: Dictionary = {}  # "wxh" -> ImageTexture

## 生成（并缓存）一块 w x h、alpha 全 255 的纹理，仅用于让 sens.texture != null（从不显示，sens.visible 恒 false）。
static func sens_texture(w: int, h: int) -> ImageTexture:
	var key := "%dx%d" % [w, h]
	if _sens_textures.has(key):
		return _sens_textures[key]
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	_sens_textures[key] = tex
	return tex

## 在 unit.init()（super.init() 之后）调用：覆盖一代 init() 按 sens_class 设好的 sens 尺寸/位置。
static func setup_sens(unit: LivingObject, w: float, h: float) -> void:
	unit.sens.texture = sens_texture(int(w), int(h))
	unit.sens_width = w
	unit.sens_height = h
	unit.sens.position.y = -h / 2
	unit.ui_health_bar.position.x = unit.sens.position.x
	unit.ui_health_bar.position.y = unit.sens.position.y - h / 2 - 8

## 包围盒命中判定，供 Ch2* 单位重写 hit_test_sens 时直接调用（替代一代基于像素 alpha 的判定）。
static func hit_test_bbox(unit: LivingObject, stage_point: Vector2) -> bool:
	if unit.sens == null or unit.sens.texture == null or not unit.sens_mouse_enabled or not unit.is_visible_in_tree():
		return false
	var local: Vector2 = unit.to_local(stage_point) - unit.sens.position
	return local.x >= 0 and local.y >= 0 and local.x < unit.sens_width and local.y < unit.sens_height

## 脚下影子（半透明深色椭圆）。放在 sprite 之前（先加入的子节点先绘制，显示在 sprite 之下）。
static func add_shadow(unit: LivingObject, w: float, h: float, alpha: float = 0.35) -> void:
	var img := Image.create(maxi(int(w), 1), maxi(int(h), 1), false, Image.FORMAT_RGBA8)
	var cx: float = w / 2.0
	var cy: float = h / 2.0
	for y in int(h):
		for x in int(w):
			var nx: float = (x + 0.5 - cx) / cx
			var ny: float = (y + 0.5 - cy) / cy
			img.set_pixel(x, y, Color(0, 0, 0, alpha if nx * nx + ny * ny <= 1.0 else 0.0))
	var shadow := Sprite2D.new()
	shadow.name = "ch2_shadow"
	shadow.centered = true
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.position = Vector2(0, 2)
	unit.add_child(shadow)
	unit.move_child(shadow, 0)
