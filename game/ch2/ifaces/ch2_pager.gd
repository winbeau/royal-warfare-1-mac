# 二次开发：翻页小控件（左箭头 · 页码 · 右箭头）。
# 一代没有可复用的翻页剪辑（bLeft / bRight 只在成就页场景里），按规格用同风格的原生小按钮：
# 深褐底、金色描边、金色三角，悬停提亮。点任一侧箭头发出 flipped(delta)，delta 为 -1 / +1。
class_name Ch2Pager
extends Control

signal flipped(delta: int)

const FONT_PATH := "res://assets/library/font/5596_Minion Pro.ttf"
const BG := Color(0.16, 0.10, 0.06, 0.95)
const EDGE := Color(0.78, 0.62, 0.29, 1.0)
const GOLD := Color(0.96, 0.82, 0.45, 1.0)
const ARROW_W := 22.0

var page: int = 1
var pages: int = 2
var _hover: int = 0   # -1 左 / 0 无 / 1 右
var _font: Font


static func create(size_: Vector2 = Vector2(88, 20)) -> Ch2Pager:
	var p := Ch2Pager.new()
	p.size = size_
	p.custom_minimum_size = size_
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists(FONT_PATH):
		p._font = load(FONT_PATH)
	return p


func set_page(p: int, total: int = 2) -> void:
	page = p
	pages = total
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BG)
	draw_rect(r, EDGE, false, 1.0)
	var h := size.y
	_draw_arrow(Rect2(0, 0, ARROW_W, h), -1)
	_draw_arrow(Rect2(size.x - ARROW_W, 0, ARROW_W, h), 1)
	if _font != null:
		var txt := "%d/%d" % [page, pages]
		var fs := int(h * 0.62)
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2((size.x - w) * 0.5, h * 0.5 + fs * 0.34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD)


func _draw_arrow(box: Rect2, dir: int) -> void:
	var lit := _hover == dir
	if lit:
		draw_rect(box.grow(-1), Color(1, 1, 1, 0.12))
	var c := box.get_center()
	var a := 4.0
	var pts := PackedVector2Array()
	if dir < 0:
		pts = PackedVector2Array([c + Vector2(a * 0.6, -a), c + Vector2(-a * 0.8, 0), c + Vector2(a * 0.6, a)])
	else:
		pts = PackedVector2Array([c + Vector2(-a * 0.6, -a), c + Vector2(a * 0.8, 0), c + Vector2(-a * 0.6, a)])
	draw_colored_polygon(pts, Color(1, 0.92, 0.6) if lit else GOLD)


func _side_at(x: float) -> int:
	if x < ARROW_W:
		return -1
	if x > size.x - ARROW_W:
		return 1
	return 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var side := _side_at((event as InputEventMouseMotion).position.x)
		if side != _hover:
			_hover = side
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var side := _side_at(mb.position.x)
			if side != 0:
				accept_event()
				flipped.emit(side)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != 0:
		_hover = 0
		queue_redraw()
