# 移植自 S/gameCore/ifaces/popupReset_ex.as（"重置所有加点"确认弹窗）
#
# 与升级面板不同：原版这个类直接 `extends MovieClip`，不是某个导出符号的子类（没有 popupReset_ex 符号），
# 弹窗内容（popupReset）和背景遮罩（mapBlack）都是构造函数里手工 addChild 出来的两个独立子对象。
# 所以这里不走 IfaceUtil.adopt 的"符号继承"套路：本类是普通 Control，scenes/ifaces/popup_reset_ex.tscn
# 只是个空壳场景（根节点挂本脚本），两个子节点在 _init() 里按原版构造函数的顺序建出来。
#
# 偏离/缺陷：
# - 背景遮罩使用真实符号 mapBlack（character 5978，scenes/clips/mapBlack.tscn），透明度动画与原版一致。
# - DropShadowFilter（popup 的投影）不移植：Control 没有对应滤镜，纯视觉效果。
# - 原版 init() 只注册 ADDED_TO_STAGE 监听，真正的建立逻辑在 added() 里；这里 init() 通过 IfaceUtil.when_ready
#   安排 _added()（同 PopupMissionEx），_exit_tree 对应原版 removed()。
class_name PopupResetEx
extends Control

const SCENE := "res://scenes/ifaces/popup_reset_ex.tscn"

var big_shadow: FlashClip  # mapBlack (character 5978)
var popup: FlashClip
var pos: int = 0  # 原版字段，全工程未见读取，原样保留
var _instance: PopupResetEx
var _attached: bool = false


static func create() -> PopupResetEx:
	return (load(SCENE) as PackedScene).instantiate() as PopupResetEx


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_shadow = (load("res://scenes/clips/mapBlack.tscn") as PackedScene).instantiate()
	big_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big_shadow)
	big_shadow.modulate.a = 0.35
	popup = (load("res://scenes/clips/popupReset.tscn") as PackedScene).instantiate() as FlashClip
	add_child(popup)
	popup.child_clip("bReset").stop()
	popup.child_clip("bClose").stop()


## 原版 init()：每次展示前调用一次，注册一次性的 ADDED_TO_STAGE 监听，added() 里再摘掉。
## 同一个弹窗实例会被地图反复 init() + addChild 复用（关闭时只是 removeChild，不销毁），所以每次
## init() 都要重新安排一次 _added()：首次等 ready（子树建好图层）后触发，之后节点已 ready，立即执行。
## 以前只在 _ready() 里做一次，第二次打开时按钮监听已被 _exit_tree 摘掉且不会再挂，弹窗打开后点不动。
func init() -> void:
	IfaceUtil.when_ready(self, _added)


func _added() -> void:
	if _attached:
		return
	_attached = true
	_instance = self
	IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0, 0.25)
	big_shadow.modulate.a = 1.0
	popup.modulate.a = 1.0
	RWTween.from(big_shadow, 0.9, {"alpha": 0})
	popup.position = Vector2(Main.GAME_WIDTH / 2.0, Main.GAME_HEIGHT / 2.0)
	RWTween.from(popup, 0.3, {"y": "-300", "alpha": 0})
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bReset"), button_clicked)
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bClose"), button_clicked)


func button_clicked(e: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = e.target
	if target == popup.child_clip("bReset"):
		_destroy()
		StoredData.ext_reset()
		IfaceUtil.main().load_map()
	elif target == popup.child_clip("bClose"):
		IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0, 0.25)
		RWTween.to(popup, 0.3, {"y": "-500", "alpha": 0, "onComplete": _destroy})
		RWTween.to(big_shadow, 0.3, {"alpha": 0})


func _destroy() -> void:
	if _instance.get_parent() != null:
		_instance.get_parent().remove_child(_instance)


func _exit_tree() -> void:
	if not _attached:
		return
	_attached = false
	ButtonClass.remove_button_on_frames(popup.child_clip("bReset"), button_clicked)
	ButtonClass.remove_button_on_frames(popup.child_clip("bClose"), button_clicked)
