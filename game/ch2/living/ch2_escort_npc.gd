## 二次开发（第二章护送目标）：NpcMan 的子类，加入"倒地"状态。
## 继承 NpcMan 以复用一代的受击/动画/回收路径（NPC_MAN 已在 LivingObject.add_to_game 的
## friendly_kinds 列表里，search_target 继承自 LivingObject 的空实现，NPC 本身不主动参战）。
## 倒地期间复用 LivingObject.in_hide（一代已有的"不是有效攻击目标"开关，search_target_* 系列
## 都会检查 enemy.in_hide == false）：不新增共享字段，living_object.gd 不改一行。
class_name Ch2EscortNpc
extends NpcMan

## 倒地后不致死：受到会使血量<=0 的伤害时转入倒地，不走 LivingObject.bring_damage 的死亡分支。
var is_downed: bool = false

## bring_damage 的参数语义见 LivingObject：param1 伤害、param2 攻击者、param3 近战、param4 是否溅血特效。
## 这里只在"本次会打死"或"已经倒地"时改变行为，其余按原版 bring_damage 处理（保留溅血、经验、音效）。
func bring_damage(param1: int, param2: LivingObject, param3: bool = false, param4: bool = true) -> void:
	if is_downed:
		return
	if param1 >= cur_health:
		enter_downed()
		return
	super.bring_damage(param1, param2, param3, param4)


func enter_downed() -> void:
	is_downed = true
	in_hide = true
	cur_health = 1
	set_stance(STAND)


## 救助成功：按满血比例恢复到 ratio（护送目标用 0.3），清除倒地标记，原地待命，
## 由 EscortObjective 在下一帧重新发出移动指令。
func revive(ratio: float) -> void:
	is_downed = false
	in_hide = false
	cur_health = maxi(1, int(health * ratio))


## 救助窗口超时：真正走到死亡流程。注意必须用 super.bring_damage，不能用 self.bring_damage——
## 本类重写的 bring_damage 只要「这一下会打到 0 血」就转去 enter_downed()，用 self 调用会把超时击杀
## 也重新打成"倒地"，永远死不掉；super. 绕开这层重写，直接执行 LivingObject 的真实死亡分支。
func timeout_death() -> void:
	is_downed = false
	in_hide = false
	super.bring_damage(health + 1, null, false, true)
