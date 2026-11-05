# 移植自 S/gameCore/levels/levelIntro.as
# 注意：原版 levelIntro 并非交互式教学关，而是开场过场：聊天（XML 4 句）+ 一群友军行军 + 右下“点击跳过”按钮，
# 没有兵种锁定、高亮、等待玩家操作的步骤。教学提示由 Main.addTutorial / 关卡 1 处理，不在此类。
# 41 处 do{...}while(false) 为反编译垃圾结构，语义即顺序执行，直接展开（P-code 已核对无 §§goto）。
# 单位表保持原版 addSoldier 顺序（影响 uid 与 RNG 消耗顺序）：
#   [kind, 位置, setExtRoute 路点(空=不调用), 是否 changeSpeed(0.9), zeroPoint(null=不设置)]
class_name LevelIntro
extends LevelTemplate

static var is_shown: bool = false
static var can_end_intro: bool = false

var game_uni: GameUniverse
var counter: float = NAN  # AS3 Number 默认 NaN；got_text 命中最后一句时置 0
var skip_button: FlashClip = null


func _init() -> void:
	level_bg = "level_field_road"
	level_xml_path = "data/levels/levelIntro.xml"
	level_caption = "Intro"
	level_description = "The journey begins."
	game_uni = GameUniverse.inst


func _units() -> Array:
	return [
	[LivingObject.FR_KING, Vector2(228, 350), [], false, null],
	[LivingObject.FR_SWORDMASTER, Vector2(400, 379), [Vector2(276, 352)], true, Vector2(276, 352)],
	[LivingObject.FR_KNIGHT, Vector2(395, 417), [Vector2(267, 372)], true, Vector2(267, 372)],
	[LivingObject.FR_ASSASIN, Vector2(65, 170), [Vector2(-153, 189)], true, null],
	[LivingObject.FR_BLESSER, Vector2(271, 154), [Vector2(65, 170), Vector2(-153, 189)], true, null],
	[LivingObject.FR_PRIEST, Vector2(444, 182), [Vector2(271, 154), Vector2(65, 170), Vector2(-153, 189)], true, null],
	[LivingObject.FR_SABOTEUR, Vector2(648, 250), [Vector2(444, 182), Vector2(271, 154), Vector2(65, 170), Vector2(-153, 189)], true, null],
	[LivingObject.FR_BLACKMAGE, Vector2(452, 338), [Vector2(334, 304), Vector2(187, 299), Vector2(-127, 328)], true, null],
	[LivingObject.FR_REDMAGE, Vector2(544, 355), [Vector2(452, 338), Vector2(334, 304), Vector2(187, 299), Vector2(-127, 328)], true, null],
	[LivingObject.FR_SNIPER, Vector2(102, 347), [Vector2(-127, 328)], true, null],
	[LivingObject.FR_BLACKMAGE, Vector2(592, 458), [], false, null],
	[LivingObject.FR_CROSSBOW, Vector2(551, 479), [], false, null],
	[LivingObject.FR_CROSSBOW, Vector2(12, 240), [Vector2(-153, 257)], true, null],
	[LivingObject.FR_CROSSBOW, Vector2(17, 281), [Vector2(-153, 290)], true, null],
	[LivingObject.FR_CROSSBOW, Vector2(56, 232), [Vector2(-153, 257)], true, null],
	[LivingObject.FR_CROSSBOW, Vector2(60, 277), [Vector2(-153, 290)], true, null],
	[LivingObject.FR_CROSSBOW, Vector2(105, 223), [Vector2(-153, 257)], true, null],
	[LivingObject.FR_CROSSBOW, Vector2(104, 268), [Vector2(-153, 290)], true, null],
	[LivingObject.FR_SWORDMASTER, Vector2(193, 221), [Vector2(-153, 257)], true, null],
	[LivingObject.FR_SWORDMASTER, Vector2(198, 266), [Vector2(-153, 290)], true, null],
	[LivingObject.FR_SWORDMASTER, Vector2(242, 227), [Vector2(-153, 257)], true, null],
	[LivingObject.FR_SWORDMASTER, Vector2(244, 264), [Vector2(-153, 290)], true, null],
	[LivingObject.FR_SWORDMASTER, Vector2(292, 233), [Vector2(-153, 257)], true, null],
	[LivingObject.FR_SWORDMASTER, Vector2(291, 271), [Vector2(-153, 290)], true, null],
	[LivingObject.FR_WARRIOR, Vector2(380, 243), [Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_WARRIOR, Vector2(380, 277), [Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_WARRIOR, Vector2(425, 256), [Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_WARRIOR, Vector2(423, 290), [Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_WARRIOR, Vector2(472, 272), [Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_WARRIOR, Vector2(472, 306), [Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_ARCHER, Vector2(543, 283), [Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_ARCHER, Vector2(543, 313), [Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_ARCHER, Vector2(588, 303), [Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_ARCHER, Vector2(591, 333), [Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_ARCHER, Vector2(633, 316), [Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_ARCHER, Vector2(636, 346), [Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_KNIGHT, Vector2(700, 332), [Vector2(543, 283), Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_KNIGHT, Vector2(696, 366), [Vector2(543, 313), Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_KNIGHT, Vector2(737, 342), [Vector2(543, 283), Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_KNIGHT, Vector2(733, 376), [Vector2(543, 313), Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_KNIGHT, Vector2(773, 355), [Vector2(543, 283), Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_KNIGHT, Vector2(769, 389), [Vector2(543, 313), Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	[LivingObject.FR_HEALER, Vector2(848, 377), [Vector2(543, 283), Vector2(380, 243), Vector2(292, 233), Vector2(193, 221), Vector2(-153, 257)], true, null],
	[LivingObject.FR_HEALER, Vector2(848, 414), [Vector2(543, 313), Vector2(380, 277), Vector2(292, 267), Vector2(193, 255), Vector2(-153, 290)], true, null],
	]


func loading_completed_handler() -> void:
	can_end_intro = false
	LevelIntro.is_shown = true
	var ui: MainGameUIEx = MainGameUIEx.inst
	ui.e_fader.visible = true
	ui.e_fader.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.e_fader.get_node("eTop").position.y = 0
	ui.e_fader.get_node("eBottom").position.y = 608
	RWTween.from(ui.e_fader.get_node("eTop"), 0.4, {"y": "-100"})
	RWTween.from(ui.e_fader.get_node("eBottom"), 0.4, {"y": "100"})
	# clickToSkipMC 符号（assets.swf symbol5727）：场景由剪辑管线提供；缺失时跳过按钮不创建。
	var skip_scene := "res://scenes/clips/clickToSkipMC.tscn"
	if ResourceLoader.exists(skip_scene):
		skip_button = load(skip_scene).instantiate()
		ui.add_child(skip_button)
		skip_button.position.x = 610
		skip_button.position.y = 572
		ButtonClass.add_button_scale(skip_button, clicked_skip)
	for row in _units():
		var _loc1_: LivingObject = game_uni.add_soldier(row[0], null, 3, true)
		_loc1_.set_external_position(row[1])
		if not row[2].is_empty():
			_loc1_.set_ext_route(row[2])
		if row[3]:
			_loc1_.change_speed(0.9)
		if row[4] != null:
			_loc1_.zero_point = row[4]
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(400)


func clicked_skip(_param1 = null) -> void:
	Sounds.inst.play(SoundLibrary.inst.get_sound(SoundLibrary.inst.CLICK1), false, 0, 0.35)
	can_end_intro = true
	Main.inst.load_game(0, false)


func get_chat_bounds() -> bool:
	return true


func got_text(param1: String) -> void:
	if param1 == "Taggart: Yes, your Majesty.":
		can_end_intro = true
		counter = 0


func clear_data() -> void:
	if skip_button != null:
		ButtonClass.remove_button_scale(skip_button, clicked_skip)
		MainGameUIEx.inst.remove_child(skip_button)


func level_custom_actions() -> void:
	if can_end_intro:
		counter += 1
		if counter > 50:
			counter = 0
			Main.inst.load_game(0, false)
