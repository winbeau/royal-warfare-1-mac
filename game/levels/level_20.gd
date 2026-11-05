# 移植自 S/gameCore/levels/level20.as
class_name Level20
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
var cd_status: int
func _init() -> void:
	level_bg = "level_23greenroad"
	level_caption = "Vampires"
	level_description = "There was no option to go on foot, so we crossed the bay on the fishing boats. The closer we were to the Darth Portal, the fiercer became our foes. And today we met the first vampires."
	level_xml_path = "data/levels/level20.xml"

func b_archers_clicked() -> void:
	ar_swarm.add_swarm(ar_swarm.RIGHT, 60, 0.88, 20, 18, game_uni.mouse_x, game_uni.mouse_y, 150, 150)

func level_custom_actions() -> void:
	cd_status = ar_swarm.update_arrow_swarm()
	game_uni.ingame_ui.update_b_archers_cooldown(cd_status)

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	ar_swarm = ArrowSwarm.inst
	ar_swarm.set_cool_down(30)
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(6000)
	game_uni.ingame_ui.enable_archers_button()
