# 移植自 S/gameCore/ifaces/ramka_ex.as
# 框选框。width/height 是 DisplayObject 的包围盒尺寸，设置时改的是 scale（Flash 语义），
# 这里 natural 取 FlashClip.data.rect（符号 5976 的 1x 包围盒，-0.5,-0.5 起 104x104）。
class_name RamkaEx
extends FlashClip

const SCENE := "res://scenes/ifaces/ramka_ex.tscn"

var _instance: RamkaEx

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "ramka")

static func create() -> RamkaEx:
	return IfaceUtil.instantiate(SCENE) as RamkaEx

## 包围盒（父坐标系），供 gameUniverse 做 sens.hitTestObject(selectionRamka)。
var rect: Rect2:
	get:
		if data == null:
			return Rect2(position, Vector2.ZERO)
		return Rect2(position + data.rect.position * scale, data.rect.size * scale)

## DisplayObject.width / height
var width: float:
	get:
		return data.rect.size.x * scale.x if data != null else 0.0
	set(value):
		if data != null and data.rect.size.x > 0.0:
			scale.x = value / data.rect.size.x

var height: float:
	get:
		return data.rect.size.y * scale.y if data != null else 0.0
	set(value):
		if data != null and data.rect.size.y > 0.0:
			scale.y = value / data.rect.size.y

# 原版 added：每次进入舞台都执行（removed 里重新挂监听）。
func _enter_tree() -> void:
	mouse_enabled = false
	mouse_children = false
	_instance = self
	modulate.a = 1.0
	RWTween.from(_instance, 0.2, {"alpha": 0})

func set_coords_and_size(param1: Vector2, param2: Vector2) -> void:
	position.x = param1.x
	position.y = param1.y
	var _loc3_ := param1.x - param2.x
	var _loc4_ := param1.y - param2.y
	width = absf(_loc3_)
	height = absf(_loc4_)
	if _loc3_ > 0:
		position.x = param2.x
	if _loc4_ > 0:
		position.y = param2.y

func destroy() -> void:
	RWTween.delayed_call(0.05, GameUniverse.inst.add_click_handler)
	var r := func() -> void:
		# try { _instance.parent.removeChild(_instance) } catch
		if _instance != null and _instance.get_parent() != null:
			_instance.get_parent().remove_child(_instance)
	RWTween.to(_instance, 0.2, {"alpha": 0, "onComplete": r})
