# 移植自 S/gameCore/specials/specBlock.as
class_name SpecBlock
extends SpecialTemplate

var a_probability: Array = []  # private（原版未使用）
var cur_probability: float = NAN  # private（原版未使用）

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Block</font></p>" + "<p>Blocks incoming melee or ranged attack</p>"
	number_in_panel = 5
	time_until_update = -10
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_BLOCK)
	a_time_until_update = [8, 6, 4]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>"

func is_blocked(param1: LivingObject) -> bool:
	var loc2: bool = false
	if can_use_special():
		reset_counter()
		var loc3: SimpleCache = BlockedVisual.cached_data
		var loc4: BlockedVisual = loc3.get_data() as BlockedVisual
		loc4.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		loc2 = true
		var loc5: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc5.get_sound_from_stack(SoundLibrary.BLOCK), false, 0, 0.33, param1.position.x, SoundLibrary.BLOCK)
	return loc2
