# 移植自 S/gameCore/specials/specCollectMoney.as
class_name SpecCollectMoney
extends SpecialTemplate

var a_money_prop: Array = []  # private
var money: float = 0.0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Steal</font></p>" + "<p>Each attack steals money from enemy.</p>"
	number_in_panel = 8
	time_until_update = -10
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_COLLECTMONEY)
	a_money_prop = [3, 6, 9]
	money = a_money_prop[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "<font color='#F6F581'>Passive</font>, " + "Money each strike: <font color='#F6F581'>" + SpecFmt.n(money) + "g</font>"

func get_money_from_enemy(param1: LivingObject) -> void:
	if can_use_special():
		GlobalData.inst.a40_steal_gold += int(money)
		var loc2: SimpleCache = CoinVisual.cached_data
		var loc3: CoinVisual = loc2.get_data() as CoinVisual
		loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		GameUniverse.inst.set_money(money)
