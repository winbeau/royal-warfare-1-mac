# 移植自 S/gameCore/ifaces/ringSelector_ex.as
# 选中单位脚下的圈：第 1 帧起播放；"done" 到达时通知单位 killRing()。
class_name RingSelectorEx
extends FlashClip

const SCENE := "res://scenes/ifaces/ring_selector_ex.tscn"

var _instance: RingSelectorEx
var warrior: Object  # livingObject；不写类型以免与 LivingObject 互相引用

func _init(param1: Object = null) -> void:
	warrior = param1
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "ringSelector")

static func create(param1: Object) -> RingSelectorEx:
	var n := IfaceUtil.instantiate(SCENE) as RingSelectorEx
	n.warrior = param1
	return n

func _ready() -> void:
	super._ready()  # GDScript 不会自动调用基类的 _ready
	_instance = self
	done.connect(destroy)
	mouse_enabled = false
	mouse_children = false

func destroy() -> void:
	warrior.kill_ring()

func start_removing() -> void:
	goto_and_play(8)

func reset_ring() -> void:
	goto_and_play(1)
