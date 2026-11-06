## 二次开发：一代地图东侧海面上的「东渡」船按钮（也用于二章地图左下的返回船，水平翻转）。
## 原生 Control：贴图是 2 倍图，显示时缩放 0.5；以帧计时上下浮动 ±2 px；悬停提亮并换手形光标。
class_name Ch2ShipButton
extends Control

const TEXTURE_PATH := "res://assets/ch2/ui/ship_east.png"
const BOB_AMPLITUDE := 2.0
const BOB_PERIOD_FRAMES := 60.0
const HOVER_BRIGHTNESS := 1.15

## 点击时调用的 Main 方法名（load_ch2_map / load_ch1_map）。
var target_method: StringName = &"load_ch2_map"

var _tex: Texture2D
var _flip: bool = false
var _base_y: float = 0.0
var _frame: int = 0


## center 为逻辑坐标（700x600）下的中心点。
static func create(center: Vector2, method: StringName, flip: bool = false) -> Ch2ShipButton:
	var b := Ch2ShipButton.new()
	b.name = "Ch2ShipButton"
	b.target_method = method
	b._flip = flip
	b._tex = load(TEXTURE_PATH) as Texture2D
	var sz := b._tex.get_size() * 0.5 if b._tex != null else Vector2(65, 42)
	b.size = sz
	b.position = center - sz * 0.5
	b._base_y = b.position.y
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: modulate = Color(HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, 1.0))
	mouse_exited.connect(func() -> void: modulate = Color.WHITE)
	set_physics_process(true)


## 物理帧固定 30 tps，对应 Flash 的 30 fps，浮动幅度按帧数计。
func _physics_process(_delta: float) -> void:
	_frame += 1
	position.y = _base_y + sin(TAU * float(_frame) / BOB_PERIOD_FRAMES) * BOB_AMPLITUDE


func _draw() -> void:
	if _tex == null:
		return
	if _flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			accept_event()
			var m: Variant = IfaceUtil.main()
			if m != null and m.has_method(target_method):
				m.call(target_method)
