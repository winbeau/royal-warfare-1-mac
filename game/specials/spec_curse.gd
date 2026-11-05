# 移植自 S/gameCore/specials/specCurse.as
class_name SpecCurse
extends SpecialTemplate

var a_curse_time: Array = []  # private
var a_bless_time: Array = []  # private（原版未使用）
var max_curse_time: float = 0.0  # private
var max_bless_time: float = 0.0  # private（原版未使用）
var area: float = 0.0  # private
var a_area: Array = []  # private
var a_curse_bless_power: Array = []  # private
var cur_curse_bless_power: float = 0.0  # private
var kd_counter: int = 0  # private
var cast_coordinates: Vector2 = Vector2.ZERO  # private（原版为 null，check_curse_bless 先赋值）
var friendly: bool = false  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Curse</font></p>" + "<p>Curses enemies, lowering their maximum health</p>"
	number_in_panel = 36
	kd_counter = 0
	set_params(param1)

func set_params(param1: bool = true) -> void:
	friendly = param1
	cur_spec_level = get_spec_level(param1, StoredData.A_CURSE_BLACK)
	a_time_until_update = [28, 24, 20]
	a_curse_time = [6, 8, 10]
	a_area = [60, 75, 90]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	max_curse_time = a_curse_time[cur_spec_level] * 30
	area = a_area[cur_spec_level]
	a_curse_bless_power = [0.25, 0.35, 0.45]
	cur_curse_bless_power = a_curse_bless_power[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(max_curse_time / 30.0) + "s</font>, " + "HP ratio: <font color='#F6F581'>-" + SpecFmt.n(cur_curse_bless_power * 100) + "%</font>"

func set_curse(param1: LivingObject) -> void:
	var loc2: Array = GameUniverse.inst.get_all_friends_in_area(cast_coordinates, not param1.friendly, area)
	if loc2.size() > 1:
		reset_counter()
		while loc2.size() > 0:
			var loc4: LivingObject = loc2.pop_back()
			if loc4.is_cursed == false:
				GlobalData.inst.a45_curse_enemies += 1
				loc4.cursed(int(max_curse_time), cur_curse_bless_power)
				var loc5: SimpleCache = CurseVisual.cached_data
				var loc6: CurseVisual = loc5.get_data() as CurseVisual
				loc6.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
		var loc3: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc3.get_sound(SoundLibrary.MAGE_CAST2), false, 0, 0.5, param1.position.x)

# param1 为 mageClass（untyped，避免对 C 的 mage_class 产生编译期依赖）
func check_curse_bless(param1, param2: LivingObject) -> bool:
	if can_use_special():
		if kd_counter == 90:
			kd_counter = 0
			cast_coordinates = Vector2(param2.position.x, param2.position.y)
			var loc3: Array = GameUniverse.inst.get_all_friends_in_area(cast_coordinates, not param1.friendly, area)
			if loc3.size() > 1:
				var loc4: LivingObject = loc3.pop_back()
				param1.set_casting_stance()
				param1.turn_to_unit(loc4)
				return true
			return false
		kd_counter += 1
		return false
	return false
