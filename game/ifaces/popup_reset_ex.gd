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
# - 原版 init() 只注册 ADDED_TO_STAGE 监听，真正的建立逻辑在 added() 里；这里直接用 _enter_tree/_exit_tree
#   驱动 _added()/_removed()（同 MainGameUIEx 的写法），init() 保留为空函数，兼容"构造后调用 .init()"的原版调用方式。
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
