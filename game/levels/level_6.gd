# 移植自 S/gameCore/levels/level6.as
class_name Level6
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
func _init() -> void:
	level_bg = "level_pierce"
	level_caption = "Southern Keep"
	level_description = "The Southen Keep, our ticket from this land, full of the walking dead. Undead forces surrounded it, but we fought our way into the keep and met Faddey."
	level_xml_path = "data/levels/level6.xml"
	game_uni = GameUniverse.inst

func level_custom_actions() -> void:
	ar_swarm.update_arrow_swarm()

func arrow_strike_called() -> void:
	var _loc2_: LivingObject = null
	var _loc1_: Array = game_uni.get_all_enemies(false)
	if _loc1_.size() > 0:
		# 原版 Vector.sort(Utility.randomSort)：Flash 排序算法调用比较函数的次数不可复现，这里用 LevelTemplate.random_sort_array（插入排序）近似；
		# 只用 [0] 号元素，分布仍为随机，但 RNG 消耗次数与原版可能不同。
		random_sort_array(_loc1_)
		_loc2_ = _loc1_[0]
		ar_swarm.add_swarm(ar_swarm.RIGHT, 50, 0.88, 7, 10, _loc2_.position.x, _loc2_.position.y, 150, 150)

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.FR_KNIGHT, LivingObject.FR_CROSSBOW, LivingObject.FR_BLESSER, LivingObject.FR_BLACKMAGE, LivingObject.FR_SABOTEUR])

func loading_completed_handler() -> void:
	game_uni.set_lives(20)
	game_uni.reset_money(1500)
	ar_swarm = ArrowSwarm.inst
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_KNIGHT, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(100, 405))
