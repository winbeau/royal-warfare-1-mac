# 移植自 S/gameCore/specials/specStun.as
class_name SpecStun
extends SpecialTemplate

var a_stun_time: Array = []  # private
var max_stun_time: int = 0  # private
var friendly: bool = false  # private

func _init(param1: bool) -> void:
	friendly = param1
	special_description = "<p><font size='18' color='#F6F581'>Stun</font></p>" + "<p>Stuns current target</p>"
	number_in_panel = 28
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_STUN)
	a_stun_time = [2, 3, 4]
	a_time_until_update = [24, 19, 14]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	max_stun_time = a_stun_time[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "stun time: <font color='#F6F581'>" + SpecFmt.n(max_stun_time / 30.0) + "s</font>"

func check_wave(param1: LivingObject) -> void:
	if can_use_special():
		var loc2: SimpleCache = StunnedSmallWaveVisual.cached_data
		var loc3: StunnedSmallWaveVisual = loc2.get_data() as StunnedSmallWaveVisual
		loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y + param1.sens_height / 2, Callable(), param1)
		loc3.scale.x = param1.get_view_direction

func check_stun(param1: LivingObject) -> void:
	if can_use_special():
		reset_counter()
		if friendly:
			GlobalData.inst.a41_stun_enemies += 1
		param1.stunned(max_stun_time)
		var loc2: SimpleCache = StunnedEffectVisual.cached_data
		var loc3: StunnedEffectVisual = loc2.get_data() as StunnedEffectVisual
		loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		var loc4: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc4.get_sound(SoundLibrary.STUNNED), false, 0, 0.5, param1.position.x, SoundLibrary.STUNNED)
