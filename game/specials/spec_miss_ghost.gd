# 移植自 S/gameCore/specials/specMissGhost.as
class_name SpecMissGhost
extends SpecialTemplate

var a_probability: Array = []  # private（原版未使用）
var cur_probability: float = NAN  # private；原版 set_params 为空，Number 默认 NaN，描述文本会显示 "NaN%"

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Evasion</font></p>" + "<p>Gives a chance to evade enemy damage</p>"
	number_in_panel = 42
	time_until_update = -10
	set_params(param1)

func set_params(_param1: bool = true) -> void:
	pass

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "<font color='#F6F581'>Passive</font>, " + "chance: <font color='#F6F581'>" + SpecFmt.n(cur_probability * 100) + "%</font>"

func update() -> void:
	pass

# 原版：canUseSpecial 为真（timeUntilUpdate = -10，counter 恒为 -1）即必定闪避，不消耗随机数。
func is_missed(param1: LivingObject) -> bool:
	var loc2: bool = false
	if can_use_special():
		var loc3: SimpleCache = MissVisual.cached_data
		var loc4: MissVisual = loc3.get_data() as MissVisual
		loc4.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		loc2 = true
	return loc2
