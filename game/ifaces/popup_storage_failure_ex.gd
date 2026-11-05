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


## 原版 init()：只注册 ADDED_TO_STAGE；这里保留为空函数，实际建立逻辑见 _ready。
func init() -> void:
	pass


## 用 _ready（子树全部就绪后自底向上触发）而不是 _enter_tree（自顶向下，子节点此时还没 ready）：
## popup 的 FlashClip 子节点此时才真正建好图层，可以安全 goto_and_stop。
func _ready() -> void:
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
