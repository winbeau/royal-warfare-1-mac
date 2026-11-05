# 移植自 S/gameCore/levels/level16.as
class_name Level16
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
var cd_status: int
func _init() -> void:
	level_bg = "level_sandy_rocky_road"
	level_caption = "Finding Fortius"
	level_description = "Fortius was here. But he left the island before we arrived, and now we have to deal with something even bigger than normal undead."
	level_xml_path = "data/levels/level16.xml"

func b_archers_clicked() -> void:
	ar_swarm.add_swarm(ar_swarm.RIGHT, 56, 0.88, 17, 17, game_uni.mouse_x, game_uni.mouse_y, 150, 150)

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	ar_swarm = ArrowSwarm.inst
	ar_swarm.set_cool_down(28)
	GameUniverse.inst.set_lives(16)
	GameUniverse.inst.reset_money(6000)
	game_uni.ingame_ui.enable_archers_button()

func level_custom_actions() -> void:
	cd_status = ar_swarm.update_arrow_swarm()
	game_uni.ingame_ui.update_b_archers_cooldown(cd_status)
