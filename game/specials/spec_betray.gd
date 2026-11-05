# 移植自 S/gameCore/specials/specBetray.as
class_name SpecBetray
extends SpecialTemplate

var enemy: LivingObject = null  # private
var friendly: bool = false  # private
var a_time_to_possess: Array = []  # private
var cur_time_to_possess: int = 0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Mind Control</font></p>" + "<p>Target turns to your side for some time</p>"
	number_in_panel = 4
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_BETRAY)
	a_time_until_update = [70, 65, 60]
	a_time_to_possess = [12, 20, 26]
	cur_time_to_possess = a_time_to_possess[cur_spec_level] * 30
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>. " + "Time: <font color='#F6F581'>" + SpecFmt.n(cur_time_to_possess / 30.0) + "s</font>"

# param1 为 mageClass（untyped）
func check_betray(param1, param2: LivingObject) -> bool:
	if can_use_special():
		if param2.will_be_soon_possessed == false:
			if param2.health > 70 or param2.get_kind == LivingObject.MONSTER_KAMIKAZE or param2.get_kind == LivingObject.MONSTER_KAMI_SHIELD or param2.get_kind == LivingObject.UNDEAD_WITCH:
				if param2.get_kind != LivingObject.UNDEAD_VAMPIRE_KING and param2.get_kind != LivingObject.UNDEAD_SEEKER and param2.get_kind != LivingObject.UNDEAD_SUMMONER:
					if float(param2.cur_health) / param2.health > 0.5:
						reset_counter()
						enemy = param2
						friendly = param1.friendly
						param1.set_casting_stance()
						param2.will_be_soon_possessed = true
						return true
					return false
				return false
			return false
		return false
	return false

func set_betray() -> void:
	if enemy.cur_health > 0:
		enemy.friendly = friendly
		if friendly:
			GlobalData.inst.a13_mind_control += 1
		var loc1: SimpleCache = BetrayVisual.cached_data
		var loc2: BetrayVisual = loc1.get_data() as BetrayVisual
		loc2.added_to_stage(enemy.sens.position.x, enemy.sens.position.y, Callable(), enemy)
		if enemy.get_cur_battle != null:  # 原版 while(...){...; break;}
			enemy.get_cur_battle.remove_from_battle(enemy)
			enemy.set_battle(null)
		var loc3: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc3.get_sound(SoundLibrary.MAGE_CAST_NEW1), false, 0, 0.4, enemy.position.x)
		enemy.will_be_soon_possessed = false
		enemy.set_target(null)
		enemy.set_stance_after_upgrade(LivingObject.STAND)
		enemy.add_betray_icon(cur_time_to_possess)
