# 移植自 S/gameCore/specials/specCurseBless.as
class_name SpecCurseBless
extends SpecialTemplate

var a_curse_time: Array = []  # private（原版未使用）
var a_bless_time: Array = []  # private
var max_curse_time: float = 0.0  # private（原版未使用）
var max_bless_time: float = 0.0  # private
var area: float = 0.0  # private
var a_area: Array = []  # private
var a_curse_bless_power: Array = []  # private
var cur_curse_bless_power: float = 0.0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Bless</font></p>" + "<p>Blesses friendly units in area, increasing their attack abilities</p>"
	number_in_panel = 11
	a_time_until_update = [40, 35, 30]
	a_bless_time = [10, 12, 14]
	a_area = [100, 120, 140]
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_CURSEBLESS)
	time_until_update = a_time_until_update[cur_spec_level] * 30
	max_bless_time = a_bless_time[cur_spec_level] * 30
	area = a_area[cur_spec_level]
	a_curse_bless_power = [0.25, 0.35, 0.45]
	cur_curse_bless_power = a_curse_bless_power[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(max_bless_time / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>, " + "bonus attack speed: <font color='#F6F581'>" + SpecFmt.n(cur_curse_bless_power * 100) + "%</font>"

# param1 为 priestClass（untyped）
func check_curse_bless(param1) -> bool:
	if can_use_special():
		var loc2: Array = GameUniverse.inst.get_all_friends_not_priests_in_area(Vector2(param1.position.x, param1.position.y), param1.friendly, area)
		if loc2.size() > 1:
			reset_counter()
			var loc4: LivingObject = null
			while loc2.size() > 0:
				loc4 = loc2.pop_back()
				if loc4.friendly == param1.friendly:
					loc4.blessed(int(max_bless_time), cur_curse_bless_power)
					var loc5: SimpleCache = BlessVisual.cached_data
					var loc6: BlessVisual = loc5.get_data() as BlessVisual
					loc6.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
			param1.set_casting_stance()
			param1.turn_to_unit(loc4)
			var loc3: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc3.get_sound(SoundLibrary.MAGE_CAST2), false, 0, 0.5, param1.position.x)
			return true
		return false
	return false
