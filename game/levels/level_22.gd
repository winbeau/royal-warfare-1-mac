# 移植自 S/gameCore/levels/level22.as
class_name Level22
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
func _init() -> void:
	level_bg = "level_field"
	level_caption = "Northen fields."
	level_description = "Yes, we've done it. The portal lies in ruins. Again. And now we march to the south to help our forces destroy the last Darth portal and eliminate the remaining undead - and to face the Undead King."
	level_xml_path = "data/levels/level22.xml"

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
		ar_swarm.add_swarm(ar_swarm.LEFT, 60, 0.88, 11, 14, _loc2_.position.x, _loc2_.position.y, 170, 150)

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(6000)
	ar_swarm = ArrowSwarm.inst
