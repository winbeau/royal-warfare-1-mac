# 移植自 S/gameCore/specials/specEnchantWeapon.as
class_name SpecEnchantWeapon
extends SpecialTemplate

var a_curse_time: Array = []  # private（原版未使用）
var a_bless_time: Array = []  # private
var max_curse_time: float = 0.0  # private（原版未使用）
var max_bless_time: float = 0.0  # private
var area: float = 0.0  # private（原版未使用）
var a_area: Array = []  # private（原版未使用）
var a_bonus_ap: Array = []  # private
var bonus_ap: float = 0.0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Enchant weapon</font></p>" + "<p>Blesses target's melee weapon, increasing damage.</p>"
	number_in_panel = 44
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_ENCHANT)
	a_time_until_update = [30, 26, 22]
	a_bless_time = [10, 11, 12]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	max_bless_time = a_bless_time[cur_spec_level] * 30
	a_bonus_ap = [2, 2.3, 2.5]
	bonus_ap = a_bonus_ap[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(max_bless_time / 30.0) + "s</font>, " + "bouns DMG: <font color='#F6F581'>" + SpecFmt.n(bonus_ap * 100) + "%</font>"

# 反编译破损，按 P-code 重建（specEnchantWeapon.pcode checkEnchant）：
# param2 为 null 时从周围战斗中的友军里随机选一个（无音效）；否则要求目标
# !isMage && !isPriest && !isArcher && getCurTarget !== null && curHealth > 0 && isEnchanted == false
# （反编译源码丢失了 !isPriest 这一项），并播放 MAGE_CAST1。
# param1 为 priestClass（untyped）
func check_enchant(param1, param2: LivingObject, param3: float) -> bool:
	if not can_use_special():
		return false
	var loc4: LivingObject = null
	if param2 == null:
		var loc8: Array = GameUniverse.inst.get_all_fighting_friends_in_area(Vector2(param1.position.x, param1.position.y), param1.friendly, param3)
		var loc9: bool = false
		if loc8.size() > 1:
			GameUniverse._random_sort(loc8)  # Array.sort(Utility.randomSort)
			loc4 = loc8[0]
			loc9 = true
		elif loc8.size() == 1:
			loc4 = loc8[0]
			loc9 = true
		elif loc8.size() == 0:
			loc9 = false
		if loc9 == true:
			reset_counter()
			loc4.enchant_weapon(int(max_bless_time), bonus_ap)
			var loc5: SimpleCache = EnchantVisual.cached_data
			var loc6: EnchantVisual = loc5.get_data() as EnchantVisual
			loc6.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
			param1.set_casting_stance()
			param1.turn_to_unit(loc4)
			return true
		return false
	if not param2.is_mage and not param2.is_priest and not param2.is_archer:
		if param2.get_cur_target != null:
			if param2.cur_health > 0 and param2.is_enchanted == false:
				loc4 = param2
				reset_counter()
				loc4.enchant_weapon(int(max_bless_time), bonus_ap)
				var loc5b: SimpleCache = EnchantVisual.cached_data
				var loc6b: EnchantVisual = loc5b.get_data() as EnchantVisual
				loc6b.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
				var loc7: SoundLibrary = SoundLibrary.inst
				Sounds.inst.play(loc7.get_sound(SoundLibrary.MAGE_CAST1), false, 0, 0.5, loc4.position.x)
				param1.set_casting_stance()
				param1.turn_to_unit(loc4)
				return true
			return false
		return false
	return false
