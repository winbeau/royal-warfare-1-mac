# 移植自 S/gameCore/levels/level3.as
class_name Level3
extends LevelTemplate

var game_uni: GameUniverse
var amount_of_civils: float = NAN  # AS3 Number 默认 NaN；loading_completed_handler 中置 0
var cur_strike_number: int

func _init() -> void:
	level_bg = "level11bg_elki2"
	level_caption = "Healers"
	level_description = "The next step was to find healers - no one can survive in a war without proper healing. We found a few priests on the crossroad."
	level_xml_path = "data/levels/level3.xml"
	game_uni = GameUniverse.inst

func loading_completed_handler() -> void:
	amount_of_civils = 0
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_HEALER, null, 3, true)
	_loc1_.set_external_position(Vector2(440, 236))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_PRIEST, null, 3, true)
	_loc1_.set_external_position(Vector2(426, 333))
	_loc1_.unlock_abils_set_max_level()
	cur_strike_number = 0
	game_uni.set_lives(20)
	game_uni.reset_money(1100)

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_MAGES, LivingObject.BUTTON_THIEVES, LivingObject.FR_KNIGHT, LivingObject.FR_SNIPER, LivingObject.FR_CROSSBOW, LivingObject.FR_BLESSER])

# 反编译破损，按 P-code 重建：
# 反编译把 `curStrikeNumber == 1 || 4 || 7 ...` 的第一段写成了 §§push/while(true)，并丢掉了 `== 8`。
# P-code 的比较链依次是 1、4、7、8、9、10，所以出口 A 的条件是 {1, 4, 7, 8, 9, 10}（含 8）。
# 出口 B 的条件 {2, 3, 5, 6}。两者都不满足时 _loc1_ 为 null，原版在 setExternalPosition(null) 处抛 TypeError
# （addSoldier 已执行），这里在 add_soldier 之后直接 return。
# RNG 调用顺序：rand > 0.98 -> [出口点 y 的 randRange -> 目标点 x、y 的 randRange] -> rand（类型）。
func level_custom_actions() -> void:
	var _loc1_ = null  # Point
	var _loc2_ = null  # Point
	var _loc3_: LivingObject = null
	var _loc4_: int = 0
	var _loc5_: float = NAN
	if game_uni.global_counter == 300:
		HintsManager.need_to_show_hint(8)
	if amount_of_civils > 0:
		if RWRandom.rand() > 0.98:
			amount_of_civils -= 1
			if cur_strike_number == 1 or cur_strike_number == 4 or cur_strike_number == 7 or cur_strike_number == 8 or cur_strike_number == 9 or cur_strike_number == 10:
				_loc1_ = Vector2(-50, 234 + RWRandom.rand_range(1, 40))
				_loc2_ = Vector2(341 + RWRandom.rand_range(1, 40), 237 + RWRandom.rand_range(1, 40))
			if cur_strike_number == 2 or cur_strike_number == 3 or cur_strike_number == 5 or cur_strike_number == 6:
				_loc1_ = Vector2(-52, 610 + RWRandom.rand_range(1, 40))
				_loc2_ = Vector2(476 + RWRandom.rand_range(1, 40), 306 + RWRandom.rand_range(1, 40))
			_loc5_ = RWRandom.rand()
			if _loc5_ < 0.33:
				_loc4_ = LivingObject.NPC_OLDMAN
			elif _loc5_ > 0.66:
				_loc4_ = LivingObject.NPC_MAN
			else:
				_loc4_ = LivingObject.NPC_WOMAN
			_loc3_ = game_uni.add_soldier(_loc4_, null, 1, true)
			if _loc1_ == null:
				return  # 原版此处抛 TypeError
			_loc3_.set_external_position(_loc1_)
			_loc3_.set_ext_route([_loc2_, Vector2(775, 343)])
			_loc3_.remove_after_move = true

func arrow_strike_called() -> void:
	cur_strike_number += 1
	amount_of_civils = RWRandom.rand_range(8, 16)
