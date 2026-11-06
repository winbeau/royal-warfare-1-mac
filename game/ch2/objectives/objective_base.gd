## 二次开发（第二章）：目标对象公共接口。具体类型见 escort_objective.gd / evac_objective.gd /
## protect_objective.gd / pickup_objective.gd / reach_objective.gd。由 Ch2Director 持有并逐帧 update()。
class_name Ch2ObjectiveBase
extends RefCounted

const STATE_ACTIVE := "active"
const STATE_COMPLETE := "complete"
const STATE_FAILED := "failed"

var id: String = ""
var optional: bool = false
var state: String = STATE_ACTIVE
var director: Ch2Director


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	id = str(data.get("id", ""))
	optional = bool(data.get("optional", false))
	director = p_director


## 每个逻辑帧调用一次（director.update() 转发）。
func update() -> void:
	pass


## 目标栏一行文字（已套用 Ch2Text.objective 的 {n}/{min}/{total} 替换）。
func hud_text() -> String:
	return id


## 目标栏是否要变红预警（接近失败）。
func is_warning() -> bool:
	return false


func is_complete() -> bool:
	return state == STATE_COMPLETE


func is_failed() -> bool:
	return state == STATE_FAILED


## objective_state 动作：具体子类解释 state 字符串的含义（如 evac 的 "release_batch"）。
func apply_state_action(_action_state: String) -> void:
	pass


## 关卡结束、关卡切出时调用，供子类释放场上单位引用（不负责 free，单位的生死仍由 GameUniverse 管理）。
func clear() -> void:
	pass
