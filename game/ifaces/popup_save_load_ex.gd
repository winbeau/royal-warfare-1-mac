# 移植自 S/gameCore/ifaces/popupSaveLoad_ex.as（"保存/读取到站点账号"弹窗）
# 与 popup_reset_ex.gd 同样的结构（独立 Control，非符号子类）；相同的偏离/缺陷说明见该文件头注释。
#
# 偏离：bSave/bLoad 原版分别调用 Main.self.onlineSave()/onlineLoad()，两者都只是转调
# storedData.onlineSave()/onlineLoad()，而这两个方法只在 Main.isArmor（ArmorGames 站点）下通过
# Main.self.agi（站内存档 SDK）提交/读取数据——纯站点在线存档功能，按任务要求不移植，这里留注释占位。
# 关闭弹窗、回到地图（bSave）的本地行为照常保留。
class_name PopupSaveLoadEx
extends Control

const SCENE := "res://scenes/ifaces/popup_save_load_ex.tscn"

var big_shadow: FlashClip  # mapBlack (character 5978)
var popup: FlashClip
var pos: int = 0  # 原版字段，全工程未见读取，原样保留
var _instance: PopupSaveLoadEx
var _attached: bool = false


static func create() -> PopupSaveLoadEx:
	return (load(SCENE) as PackedScene).instantiate() as PopupSaveLoadEx


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_shadow = (load("res://scenes/clips/mapBlack.tscn") as PackedScene).instantiate()
	big_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big_shadow)
	big_shadow.modulate.a = 0.35
	popup = (load("res://scenes/clips/popupSaveLoad.tscn") as PackedScene).instantiate() as FlashClip
	add_child(popup)
	popup.child_clip("bLoad").stop()
	popup.child_clip("bSave").stop()
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
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bSave"), button_clicked)
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bLoad"), button_clicked)
	ButtonClass.add_button_on_frames_rd(popup.child_clip("bClose"), button_clicked)


func button_clicked(e: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = e.target
	if target == popup.child_clip("bSave"):
		_destroy()
		# Main.self.onlineSave()：站点在线存档，不移植（见文件头注释）。
		IfaceUtil.main().load_map()
	elif target == popup.child_clip("bLoad"):
		_destroy()
		# Main.self.onlineLoad()：站点在线存档，不移植（见文件头注释）。
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
	ButtonClass.remove_button_on_frames(popup.child_clip("bSave"), button_clicked)
	ButtonClass.remove_button_on_frames(popup.child_clip("bLoad"), button_clicked)
	ButtonClass.remove_button_on_frames(popup.child_clip("bClose"), button_clicked)
