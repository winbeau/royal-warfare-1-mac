## 二次开发（第二章）：目标栏。挂在 GameUniverse 下、ingame_ui 之上，mouse_filter = IGNORE，
## 不挡任何点击。每行一个目标，完成的变暗打勾，接近失败的变红。
## 字体用一代字体库里的 "Minion Pro"（assets/clips/fonts.json），不新建字体资源。
## 用户 2026-11-06（容器截图自查后）反馈：原先的顶部居中布局会和一代顶部中央的"出下一波/Autostart"
## 面板重叠，改放左上角——一代骷髅计数/金币那一行（eHp 在 (50, 12)、eWave 在 (98, 12)）下方，
## 且不能挡住左侧竖排的设置按钮（eMenu，(15, 14)）和加速按钮（eSpeedUp，(15, 47)）：两个按钮的
## 列宽约到 x=40，所以目标栏从 x=48 起（与 eHp 左边界对齐），y=34（紧贴那一行下方）。
class_name Ch2ObjectiveHud
extends Control

const PANEL_X := 48.0
const PANEL_Y := 34.0
const LINE_HEIGHT := 15.0
const LINE_WIDTH := 260.0
const PADDING := 4.0

var director: Ch2Director
var _labels: Array = []  # Array[FlashText]
var _bg: ColorRect


func _init(p_director: Ch2Director) -> void:
	director = p_director
	name = "ch2_objective_hud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(GameUniverse.MAX_SCREEN_WIDTH, GameUniverse.MAX_SCREEN_HEIGHT)

	var n: int = director.objectives.size()
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.05, 0.05, 0.05, 0.45)
	_bg.position = Vector2(PANEL_X - PADDING, PANEL_Y - PADDING)
	_bg.size = Vector2(LINE_WIDTH + PADDING * 2.0, float(n) * LINE_HEIGHT + PADDING * 2.0)
	add_child(_bg)

	for i in n:
		var lbl := FlashText.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.font_face = "Minion Pro"
		lbl.font_size = 12.0
		lbl.align = "left"
		lbl.box = Rect2(PANEL_X, PANEL_Y + i * LINE_HEIGHT, LINE_WIDTH, LINE_HEIGHT)
		lbl.shadow_color = Color(0, 0, 0, 0.8)
		lbl.shadow_offset = Vector2(1, 1)
		add_child(lbl)
		_labels.append(lbl)


func refresh() -> void:
	for i in director.objectives.size():
		var obj: Ch2ObjectiveBase = director.objectives[i]
		var lbl: FlashText = _labels[i]
		var line := obj.hud_text()
		if obj.is_complete():
			line = "✓ " + line
			lbl.color = Color(0.7, 0.7, 0.7, 0.85)
		elif obj.is_warning():
			lbl.color = Color(1.0, 0.3, 0.3, 1.0)
		else:
			lbl.color = Color(1.0, 0.95, 0.8, 1.0)
		lbl.text = line
