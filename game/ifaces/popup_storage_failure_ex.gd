# 移植自 S/gameCore/ifaces/popupStorageFailure_ex.as（"本地存档失败"提示弹窗，建议看教程视频清理 Flash 存储权限）
# 与 popup_reset_ex.gd 同样的结构（独立 Control，非符号子类）；相同的偏离/缺陷说明见该文件头注释。
#
# bVideo 对应原版 navigateToURL(new URLRequest(...), "_blank")：在系统默认浏览器打开外部链接，
# 不是站点存档 API，照原样移植为 OS.shell_open（会真的拉起浏览器，测试里不要点这个按钮）。
class_name PopupStorageFailureEx
extends Control

const SCENE := "res://scenes/ifaces/popup_storage_failure_ex.tscn"
const _VIDEO_URL := "http://www.youtube.com/watch?v=_lxB-ydp8ew"

var big_shadow: FlashClip  # mapBlack (character 5978)
var popup: FlashClip
var pos: int = 0  # 原版字段，全工程未见读取，原样保留
var _instance: PopupStorageFailureEx
var _attached: bool = false


static func create() -> PopupStorageFailureEx:
	return (load(SCENE) as PackedScene).instantiate() as PopupStorageFailureEx


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_shadow = (load("res://scenes/clips/mapBlack.tscn") as PackedScene).instantiate()
	big_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big_shadow)
	big_shadow.modulate.a = 0.35
	popup = (load("res://scenes/clips/popupSaveFailure.tscn") as PackedScene).instantiate() as FlashClip
	add_child(popup)
	popup.child_clip("bVideo").stop()
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
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bVideo"), button_clicked)
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bClose"), button_clicked)


func button_clicked(e: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = e.target
	if target == popup.child_clip("bVideo"):
		OS.shell_open(_VIDEO_URL)
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
	ButtonClass.remove_button_on_frames(popup.child_clip("bVideo"), button_clicked)
	ButtonClass.remove_button_on_frames(popup.child_clip("bClose"), button_clicked)
