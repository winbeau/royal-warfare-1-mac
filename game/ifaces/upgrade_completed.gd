# 移植自 S/gameCore/ifaces/upgradeCompleted.as
# 升级完成特效：eLevelup 停在 curLevel+1 帧，时间轴播完（"done"）后自行移除。
class_name UpgradeCompleted
extends FlashClip

const SCENE := "res://scenes/ifaces/upgrade_completed.tscn"

@onready var e_levelup: FlashClip = $eLevelup

var _instance: UpgradeCompleted
var cur_level: int = 0

func _init(param1: int = 0) -> void:
	cur_level = param1
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "upgradeCompleted_mc")

static func create(param1: int) -> UpgradeCompleted:
	var n := IfaceUtil.instantiate(SCENE) as UpgradeCompleted
	n.cur_level = param1
	return n

func _ready() -> void:
	super._ready()  # GDScript 不会自动调用基类的 _ready
	e_levelup.goto_and_stop(cur_level + 1)
	_instance = self
	done.connect(destroy)

func destroy() -> void:
	if _instance != null and _instance.get_parent() != null:
		_instance.get_parent().remove_child(_instance)
	if done.is_connected(destroy):
		done.disconnect(destroy)
	queue_free()
