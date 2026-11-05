# 移植自 S/gameCore/specials/specHarmResist.as
class_name SpecHarmResist
extends SpecialTemplate

var a_curse_time: Array = []  # private（原版未使用）
var a_harm_resist_time: Array = []  # private
var max_curse_time: float = 0.0  # private（原版未使用）
var max_harm_resist_time: float = 0.0  # private
var area: float = 0.0  # private
var a_area: Array = []  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Defence sphere</font></p>" + "<p>Protects friendly units from almost any harm</p>"
	number_in_panel = 15
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_HARMRESIST)
	a_harm_resist_time = [6, 8, 10]
	a_time_until_update = [40, 33, 25]
	a_area = [125, 125, 125]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	max_harm_resist_time = a_harm_resist_time[cur_spec_level] * 30
	area = a_area[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(max_harm_resist_time / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>"

# param1 为 priestClass（untyped）
func check_harm_resist(param1) -> bool:
	if can_use_special():
		var loc2: Array = GameUniverse.inst.get_all_friends_in_area(Vector2(param1.position.x, param1.position.y), param1.friendly, area)
		if loc2.size() > 1:
			GlobalData.inst.a38_protection += 1
			reset_counter()
			var loc3: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc3.get_sound(SoundLibrary.MAGIC_SHIELD), false, 0, 0.45, param1.position.x)
			var loc4: LivingObject = null
			while loc2.size() > 0:
				loc4 = loc2.pop_back()
				if loc4 != param1:
					loc4.harm_resisted(max_harm_resist_time)
					var loc5: SimpleCache = HarmResistVisual.cached_data
					var loc6: HarmResistVisual = loc5.get_data() as HarmResistVisual
					loc6.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
			param1.set_casting_stance()
			param1.turn_to_unit(loc4)
			return true
		return false
	return false
