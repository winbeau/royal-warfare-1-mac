# 移植自 S/gameCore/specials/specPoisonRogue.as
class_name SpecPoisonRogue
extends SpecialTemplate

var a_time_to_poison: Array = []  # private
var cur_timeto_poison: float = 0.0  # private
var a_poison_strength: Array = []  # private
var cur_poison_strength: int = 0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Poison</font></p>" + "<p>Poisoned enemy loses health over time</p>"
	number_in_panel = 37
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_POISON_THIEF)
	a_time_to_poison = [10, 10, 10]
	cur_timeto_poison = a_time_to_poison[cur_spec_level] * 30
	a_poison_strength = [3, 5, 8]
	cur_poison_strength = a_poison_strength[cur_spec_level]
	a_time_until_update = [26, 22, 18]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "Poison strength: <font color='#F6F581'>" + SpecFmt.n(cur_poison_strength) + "HP/s</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(cur_timeto_poison / 30.0) + "</font>"

# 反编译破损，按 P-code 重建（specPoisonRogue.pcode checkPoison）：
# 反编译源码丢失了 "param1.getKind !== UNDEAD_GHOST" 这一项，完整条件为
# canUseSpecial && param1 !== null && param1.isPoisoned == false && param1.getKind !== UNDEAD_GHOST。
# 命中后顺序：resetCounter、poisoned、a9_poisoned++、特效、音效；a9_poisoned 不判断是否友方。
func check_poison(param1: LivingObject) -> bool:
	if not can_use_special():
		return false
	if param1 == null:
		return false
	if param1.is_poisoned == false and param1.get_kind != LivingObject.UNDEAD_GHOST:
		reset_counter()
		param1.poisoned(int(cur_timeto_poison), cur_poison_strength)
		GlobalData.inst.a9_poisoned += 1
		var loc2: SimpleCache = PoisonEffectVisual.cached_data
		var loc3: PoisonEffectVisual = loc2.get_data() as PoisonEffectVisual
		loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		var loc4: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc4.get_sound(SoundLibrary.POISON), false, 0, 0.3)
		return true
	return false
