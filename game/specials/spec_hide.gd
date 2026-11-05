# 移植自 S/gameCore/specials/specHide.as
class_name SpecHide
extends SpecialTemplate

var me: LivingObject = null  # private

func _init(param1: bool, param2: LivingObject = null) -> void:
	me = param2
	special_description = "<p><font size='18' color='#F6F581'>Hide</font></p>" + "<p>Hides in shadows, no one can attack hidden unit.</p>"
	number_in_panel = 39
	set_params(param1)

func set_params(param1: bool = true) -> void:
	if param1:
		cur_spec_level = get_spec_level(param1, StoredData.A_HIDE)
	else:
		cur_spec_level = 1
	a_time_until_update = [12, 8, 5]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>"

# 反编译源码含 while(true)/§§goto，P-code 确认为：inHide == false 时，战斗中 resetCounter，
# 否则 canUseSpecial 则 hide()，再否则计数 +1。
func update() -> void:
	if me.in_hide == false:
		if me.get_stance == LivingObject.FIGHTING:
			reset_counter()
		elif can_use_special():
			hide()
		else:
			super.update()

# 反编译源码含 while(true){...break;}，P-code 确认为 if/else：
# inHide = true；非友方 setAlpha(0.4)；友方 setAlpha(0.5)、standStill = true、播放 HIDESPY。
func hide() -> void:
	me.in_hide = true
	if me.friendly != true:
		me.set_alpha(0.4)
	else:
		me.set_alpha(0.5)
		me.stand_still = true
		var loc1: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc1.get_sound(SoundLibrary.HIDESPY), false, 0, 0.4, me.position.x)

func check_hide(_param1: LivingObject) -> bool:
	return false

func disable_hide() -> void:
	reset_counter()
	me.in_hide = false
	me.set_alpha(1)
