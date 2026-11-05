# 移植自 S/gameCore/ifaces/canUpgrade_ex.as
# 单位头顶"可升级"提示：进入舞台时 eLevelup 停在第 4 帧，时间轴播完（"done"）后自行移除。
class_name CanUpgradeEx
extends FlashClip

const SCENE := "res://scenes/ifaces/can_upgrade_ex.tscn"

@onready var e_levelup: FlashClip = $eLevelup

var _instance: CanUpgradeEx

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "canUpgrade")

static func create() -> CanUpgradeEx:
	return IfaceUtil.instantiate(SCENE) as CanUpgradeEx

# 原版 added(Event.ADDED_TO_STAGE)；监听在第一次进入舞台时摘掉，实际只执行一次。
func _ready() -> void:
	super._ready()  # GDScript 不会自动调用基类的 _ready
	e_levelup.goto_and_stop(4)
	_instance = self
	done.connect(destroy)

func destroy() -> void:
	# try { _instance.parent.removeChild(_instance) } catch
	if _instance != null and _instance.get_parent() != null:
		_instance.get_parent().remove_child(_instance)
	if done.is_connected(destroy):
		done.disconnect(destroy)
	queue_free()  # 原版靠 GC 回收；Godot 节点需显式释放
