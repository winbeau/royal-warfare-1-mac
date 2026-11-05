# 移植自 S/gameCore/ifaces/unitTutorial.as
# 战内"新敌人"说明面板（unitHintMC）：显示单位图标、描述和 12 项属性，悬停属性图标出现小提示。
# 进入舞台时 GameUniverse.pause()，关闭时 unpause() 并淡出后从父节点移除。
#
# 偏离：howtoPlayScreen_ex（aUnitsNumbers / aUnitsDescription）由界面移植的其他部分负责，这里按 class_name
# 动态取；GameUniverse.aUnitsXMLParams 的元素是 RWXml 节点，`.Health.one` 写成 child("Health").text("one")。
class_name UnitTutorial
extends FlashClip

const SCENE := "res://scenes/ifaces/unit_tutorial.tscn"
const HINT_NAMES := ["Health", "Speed", "Melee damage", "Melee attack speed", "Armor piercing", "Armor",
		"Ranged damage", "Ranged attack speed", "Accuracy", "Magic protection", "Magic piercing", "Reward"]

static var inst: UnitTutorial  # 原版 private static var self

var cur_frame: int = 0
var a_contents: Array = []
var e_content: FlashClip
var s: SoundLibrary
var ico: FlashClip  # unitIcons
var e_hint: FlashClip  # hintAchivesStats
var a_sensors: Array = []
var start_hint_text_coords_3line: Vector2
var start_hint_text_coords_2line: Vector2
var start_hint_text_coords_1line: Vector2
var _listening: bool = false

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "unitHintMC")
	_construct()

static func create() -> UnitTutorial:
	var n := IfaceUtil.instantiate(SCENE) as UnitTutorial
	n._construct()
	return n

func _construct() -> void:
	inst = self
	# Rasterizer.rasterize(eBg)：无需处理
	ico = (load("res://scenes/clips/unitIcons.tscn") as PackedScene).instantiate()
	add_child(ico)
	ico.stop()
	var pic_cont: Control = get_node("ePicCont")
	ico.position.x = pic_cont.position.x + 5
	ico.position.y = pic_cont.position.y + 5
	ico.scale = Vector2(0.75, 0.75)
	e_hint = (load("res://scenes/clips/hintAchivesStats.tscn") as PackedScene).instantiate()
	add_child(e_hint)
	e_hint.visible = false
	e_hint.mouse_children = false
	e_hint.mouse_enabled = false
	var t_text: FlashText = e_hint.get_node("tText")
	t_text.auto_size = "center"
	# TextFormat.align = CENTER
	t_text.align = "center"
	a_sensors = []
	for i in range(1, 13):
		a_sensors.append(get_node("s%d" % i))
	start_hint_text_coords_3line = Vector2(-21, 21)
	start_hint_text_coords_2line = Vector2(-21, 28)
	start_hint_text_coords_1line = Vector2(-21, 32)

func rout(_param1: Variant = null) -> void:
	e_hint.visible = false

func rover(param1: ButtonClass.ButtonEvent) -> void:
	var _loc3_: String = ""
	var _loc2_: FlashClip = param1.target
	if StoredData.main_params.get("hints", false):
		e_hint.visible = true
	else:
		e_hint.visible = false
	var idx := a_sensors.find(_loc2_)
	if idx >= 0:
		_loc3_ = HINT_NAMES[idx]
	var t_text: FlashText = e_hint.get_node("tText")
	t_text.text = _loc3_
	match IfaceUtil.num_lines(t_text):
		3:
			t_text.position.y = start_hint_text_coords_3line.y
		2:
			t_text.position.y = start_hint_text_coords_2line.y
		1:
			t_text.position.y = start_hint_text_coords_1line.y
	e_hint.position.x = _loc2_.position.x - IfaceUtil.clip_width(_loc2_) / 2 + 10
	e_hint.position.y = _loc2_.position.y + 3

func _enter_tree() -> void:
	_listening = true
	for sensor: FlashClip in a_sensors:
		sensor.mouse_children = false
		ButtonClass.add_event_listener(sensor, ButtonClass.ROLL_OVER, rover)
		ButtonClass.add_event_listener(sensor, ButtonClass.ROLL_OUT, rout)
	modulate.a = 1.0
	RWTween.from(inst, 0.4, {"alpha": 0})
	ButtonClass.add_button_scale(get_node("bClosebtn"), clicked)
	s = SoundLibrary.inst
	GameUniverse.inst.pause()

func init(param1: float) -> void:
	IfaceUtil.goto_and_stop(ico, int(param1) + 1)
	var howto := IfaceUtil.global_script("HowtoPlayScreenEx")
	var howto_inst: Variant = howto.get("inst") if howto != null else null
	var _loc2_: int = -1
	var _loc3_: String = ""
	if howto_inst != null:
		_loc2_ = howto_inst.a_units_numbers.find(int(param1))
		_loc3_ = howto_inst.a_units_description[_loc2_]
	(get_node("tDescr") as FlashText).text = _loc3_
	var _loc4_: RWXml = GameUniverse.inst.a_units_xml_params[_loc2_]
	var _loc5_: String = _loc4_.text("className")
	var _loc6_: String = _loc4_.child("Health").text("one")
	var _loc7_: String = _loc4_.child("walkSpeed").text("one")
	var _loc8_: String = _loc4_.child("damageMelee").text("one")
	var _loc9_: String = _loc4_.child("attackSpeedMelee").text("one")
	var _loc10_: float = RWXml.as_number(_loc4_.child("armorPierceMelee").text("one"))
	var _loc11_: float = RWXml.as_number(_loc4_.child("Armor").text("one"))
	var _loc12_: String = _loc4_.child("damageRanged").text("one")
	var _loc13_: String = _loc4_.child("attackSpeedRanged").text("one")
	var _loc14_: float = RWXml.as_number(_loc4_.child("accuracy").text("one"))
	var _loc15_: float = RWXml.as_number(_loc4_.child("Resist").text("one"))
	var _loc16_: float = RWXml.as_number(_loc4_.child("magicPierce").text("one"))
	var _loc17_: String = _loc4_.text("money")
	(get_node("tUnitName") as FlashText).text = _loc5_
	(get_node("tHealth") as FlashText).text = _loc6_
	(get_node("tSpeed") as FlashText).text = _loc7_
	(get_node("tDam") as FlashText).text = _loc8_
	(get_node("tAtSpd") as FlashText).text = _loc9_
	(get_node("tPierce") as FlashText).text = str(int(_loc10_ * 100)) + "%"
	(get_node("tArmor") as FlashText).text = str(int(_loc11_ * 100)) + "%"
	(get_node("tShootDam") as FlashText).text = _loc12_
	(get_node("tShootSpeed") as FlashText).text = _loc13_
	(get_node("tAccuracy") as FlashText).text = str(int(_loc14_ * 100)) + "%"
	(get_node("tProtection") as FlashText).text = str(int(_loc15_ * 100)) + "%"
	(get_node("tMagicPierce") as FlashText).text = str(int(_loc16_ * 100)) + "%"
	(get_node("tCost") as FlashText).text = _loc17_ + "g"

func clicked(_param1: Variant = null) -> void:
	IfaceUtil.play_sound(SoundLibrary.CLICK1, 0, 0.3)
	close()

func close() -> void:
	GameUniverse.inst.unpause()
	RWTween.to(inst, 0.3, {"alpha": 0, "onComplete": remover})

func remover() -> void:
	inst.get_parent().remove_child(inst)

func _exit_tree() -> void:
	if not _listening:
		return
	_listening = false
	for sensor: FlashClip in a_sensors:
		ButtonClass.remove_event_listener(sensor, ButtonClass.ROLL_OVER, rover)
		ButtonClass.remove_event_listener(sensor, ButtonClass.ROLL_OUT, rout)
	ButtonClass.remove_button_scale(get_node("bClosebtn"), clicked)
	# Main.self.stage.focus = Main.self.stage：键盘焦点，Godot 无对应
