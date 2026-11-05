# 移植自 S/gameCore/ifaces/howtoPlayScreen_ex.as（howtoPlayScreen_ex extends howtoPlayScreen）
# 手册：eContent 共 62 页（totalFrames），1..49 是固定图文页，50..62 是"已遭遇敌人"图鉴（每页两个单位，
# aRevealedUnits 来自存档 NUMPAN_REVEALED_ENEMY，未遭遇的敌人显示占位文本和 "???" 属性）。
# bContents 打开的 eMenu 九个章节按钮跳到对应页（1/2/12/18/27/46/31/35/40/50），bLeft/bRight 循环翻页。
#
# HUD-2（UnitTutorial）通过 IfaceUtil.global_script("HowtoPlayScreenEx") 动态取静态 inst 及其
# a_units_numbers / a_units_description，这里原样保留字段名与顺序。
class_name HowtoPlayScreenEx
extends FlashClip

const SCENE := "res://scenes/ifaces/howto_play_screen_ex.tscn"

static var inst: HowtoPlayScreenEx  # 原版 public static var self

const HINT_NAMES := ["Health", "Speed", "Melee damage", "Melee attack speed", "Armor piercing", "Armor",
		"Ranged damage", "Ranged attack speed", "Accuracy", "Magic protection", "Magic piercing", "Reward"]

static var cached_unit_data: SimpleCache  # 原版声明但未使用，仅保持 API 对齐

var current_list: int = 1
var s: SoundLibrary

var a_units_description: Array = []
var a_units_numbers: Array = []
var a_revealed_units: Array = []

var ico1: FlashClip  # unitIcons
var ico2: FlashClip  # unitIcons
var t1_coord_y: float = 0.0
var t2_coord_y: float = 0.0
var t12_height: float = 0.0

var ingame: bool = false

var b_more: FlashClip
var b_menu: FlashClip
var b_left: FlashClip
var b_right: FlashClip
var b_contents: FlashClip
var e_content: FlashClip
var e_menu: FlashClip
var t1: FlashText
var t2: FlashText
var p1: FlashClip
var p2: FlashClip
var t_ico1: FlashClip  # tutorialHintsPad
var t_ico2: FlashClip  # tutorialHintsPad
var t_pics_counter: FlashText

var _bound: bool = false
var _attached: bool = false
var _first_ready_done: bool = false


func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "howtoPlayScreen")
	_bind()


static func create() -> HowtoPlayScreenEx:
	var n := IfaceUtil.instantiate(SCENE) as HowtoPlayScreenEx
	n._bind()
	return n


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bind()


func _bind() -> void:
	if _bound:
		return
	b_more = get_node("bMore")
	b_menu = get_node("bMenu")
	b_left = get_node("bLeft")
	b_right = get_node("bRight")
	b_contents = get_node("bContents")
	e_content = get_node("eContent")
	e_menu = get_node("eMenu")
	t1 = get_node("t1")
	t2 = get_node("t2")
	p1 = get_node("p1")
	p2 = get_node("p2")
	t_ico1 = get_node("tIco1")
	t_ico2 = get_node("tIco2")
	t_pics_counter = get_node("tPicsCounter")
	_bound = b_more != null


## 原版构造函数。
func _construct() -> void:
	inst = self
	b_more.stop()
	b_menu.stop()
	b_left.stop()
	b_right.stop()
	b_contents.stop()
	IfaceUtil.goto_and_stop(e_content, 1)
	a_units_numbers = [LivingObject.UNDEAD_ZOMBIE, LivingObject.UNDEAD_SKELETON, LivingObject.UNDEAD_SKELETON_ARM,
		LivingObject.UNDEAD_SKELETON_CAPITAN, LivingObject.UNDEAD_SKELETON_ARCHER, LivingObject.UNDEAD_DARTH_KNIGHT,
		LivingObject.UNDEAD_GRAY_ZOMBIE, LivingObject.MONSTER_OGRE, LivingObject.UNDEAD_WITCH,
		LivingObject.UNDEAD_VAMPIRE, LivingObject.MONSTER_KAMIKAZE, LivingObject.UNDEAD_SHAMAN,
		LivingObject.UNDEAD_STORMGUARDIAN, LivingObject.UNDEAD_STORMTROOPER, LivingObject.UNDEAD_STORMARCHER,
		LivingObject.UNDEAD_SEEKER, LivingObject.MONSTER_GREEN_HOUND, LivingObject.MONSTER_HOUND,
		LivingObject.UNDEAD_PLAGUE_ZOMBIE, LivingObject.UNDEAD_RANGER, LivingObject.MONSTER_TROLL,
		LivingObject.UNDEAD_SUMMONER, LivingObject.UNDEAD_GHOST, LivingObject.MONSTER_KAMI_SHIELD,
		LivingObject.UNDEAD_VAMPIRE_LORD, LivingObject.UNDEAD_VAMPIRE_KING]
	a_units_description = [
		"Slow, weak creature. Can be dangerous only in great numbers. Has some magic protection.",
		"Moves fast, inflicts low damage. Can overrun mages and priests. Like all skeletons, can deflect some arrows.",
		"This one wears some armor, moves a bit slower than a regular skeleton, and can deflect some arrows.",
		"Heavilly armored skeleton warrior. Can handle moderate damage and can deflect some arrows.",
		"Weak and slow ranged warrior. Uses bow and arrows and can be dangerous for your casters and archers. Like all skeletons, can deflect some arrows.",
		"Wears heavy armor and carries broadsword. Can handle enough damage and even stun your warriors with a fierceful strike.",
		"Wears an axe and a helmet. These zombies are slow and weak, but their axes can penetrate medium armor and inflict some real damage.",
		"Very tough creature. Slow, has lots of HP, no armor. He uses no weapon, but his heavy fists deal great damage, and every punch stuns everyone in range.",
		"Strikes over a distance and penetrates any armor. Can use magic spells, so kill them before they are able to use them.",
		"Fast and deadly enemy in one-to-one combat. Regenerates health with each hit it makes. Has moderate amount of HP.",
		"This small and weak creature wears a heavy bomb and will detonate it if it comes too close. Shoot it as fast as you can.",
		"This one has no weapon and will not engage your troops in combat, but can heal his allies, and even resurrect fallen undead soldiers.",
		"Heavilly armored unit, wears monstrous sword. Each hit breaks its target's armor.",
		"Quick and deadly, these guys are experts in close combat. Can inflict great damage in a few moments, but lacks armor and HP.",
		"Accurate and deadly ranged warrior. Shoots fast, hits hard. Can poison his targets.",
		"This creatures can hide in the shadows and cannot be hit until they strike their attack. Seekers will target your casters and archers, have low damage, but moderate HP.",
		"Bigger and tougher than green hounds. This creature moves a bit slower, but can handle much more damage. Very dangerous in large groups.",
		"Little creature with sharp teeth. Hounds move very quickly and can overrun your defenders.",
		"Unlike other zombies, this one has moderate HP and magic resistance. Strikes with his own hands and can't inflict great damage, but plague weakens your soldiers, lowering attack speed.",
		"Shoots arrows over a great distance and can be a real danger to your troops. Can inflict moderate damage but shoots infrequently.",
		"Fierce close combat fighter, lacks HP, but quickly regenerates health over time. Dangerous in one-on-one combat.",
		"Well-armored, undead mage, dangerous both in ranged combat and in melee. Summoner shoots magic bolts, which penetrate any armor, and can summon a group of skeletons.",
		"Bodiless being, restless soul. Receives almost no damage by swords and arrows. Ghost's only weakness is magic.",
		"This creature wears a bomb and heavy shield. Don't forget about them in battle. They can inflict great damage to your troops. Their shield grants them strong protection from arrows.",
		"These creatures are the commanders of the undead army. They wear heavy armor, have lots of HPs, can weaken your soldiers and, like vampires, restore HP with every hit.",
		"Absolute evil, the toughtest enemy you can meet. Has the best armor, magic protection, uses large two-handed sword, restores HP with every hit. Can ressurect himself after death.",
	]
	p1.visible = false
	p2.visible = false
	t_ico1.visible = false
	t_ico2.visible = false
	ico1 = (load("res://scenes/clips/unitIcons.tscn") as PackedScene).instantiate()
	ico1.stop()
	ico2 = (load("res://scenes/clips/unitIcons.tscn") as PackedScene).instantiate()
	ico2.stop()
	add_child(ico1)
	add_child(ico2)
	ico1.position = Vector2(p1.position.x + 5, p1.position.y + 5)
	ico1.scale = Vector2(0.75, 0.75)
	ico2.position = Vector2(p2.position.x + 5, p2.position.y + 5)
	ico2.scale = Vector2(0.75, 0.75)
	t1_coord_y = t1.position.y - 5
	t2_coord_y = t2.position.y - 5
	t12_height = t1.box.size.y
	t1.auto_size = "center"
	t2.auto_size = "center"
	ico1.visible = false
	ico2.visible = false


func _ready() -> void:
	super._ready()
	if data == null or not _bound:
		return
	_construct()
	_first_ready_done = true
	_added()


func _enter_tree() -> void:
	if _first_ready_done and not _attached:
		_added()


func _exit_tree() -> void:
	if _attached:
		_removed()


func _added() -> void:
	_attached = true
	s = SoundLibrary.inst
	IfaceUtil.goto_and_stop(e_content, 1)
	ButtonClass.add_button_on_frames_rd(b_more, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_menu, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_left, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_right, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_contents, button_clicked)
	for name_ in ["i2", "i3", "i4", "i5", "i6", "i7", "i8", "i9", "i10"]:
		ButtonClass.add_button_scale(e_menu.get_node(name_), button_clicked)
	# Main.debugMode 分支（从本地文件读 XML）不移植：始终经 ExtDataManager.inst.get_units_xml() 取 RWXml，
	# 效果等价于非调试模式分支 extDataManager.self.getUnitsXML()。
	var units_xml: RWXml = ExtDataManager.inst.get_units_xml() if ExtDataManager.inst != null else null
	if units_xml != null and GameUniverse.inst != null:
		GameUniverse.inst.set_loaded_units_parameters(units_xml)
	a_revealed_units = StoredData.local_game_data[StoredData.NUMPAN_REVEALED_ENEMY].duplicate()
	current_list = 1
	set_cur_list_visible()


func set_cur_list_visible() -> void:
	if current_list == 1:
		e_menu.visible = true
		RWTween.from_to(e_menu, 0.4, {"colorMatrixFilter": {"brightness": 1.5}}, {"colorMatrixFilter": {"brightness": 1}})
	else:
		e_menu.visible = false
	RWTween.from_to(e_content, 0.4, {"colorMatrixFilter": {"brightness": 1.5}}, {"colorMatrixFilter": {"brightness": 1}})
	IfaceUtil.play_sound(SoundLibrary.IFACE_PAPER_SMALL, 0.1, 0.25)
	t_pics_counter.text = "%d / %d" % [current_list, e_content.total_frames]
	t_ico1.visible = false
	t_ico2.visible = false
	p1.visible = false
	p2.visible = false
	t1.visible = false
	t1.text = ""
	t2.visible = false
	t2.text = ""
	ico1.visible = false
	ico2.visible = false
	if current_list > 49:
		t1.visible = true
		t2.visible = true
		p1.visible = true
		p2.visible = true
		var base := (current_list - 50) * 2  # case 50 -> 0, 51 -> 2, ... 62 -> 24
		if a_revealed_units.size() > base:
			show_unit(ico1, t1, int(a_revealed_units[base]), t_ico1)
		else:
			hide_unit(ico1, t1, t_ico1)
		if a_revealed_units.size() > base + 1:
			show_unit(ico2, t2, int(a_revealed_units[base + 1]), t_ico2)
		else:
			hide_unit(ico2, t2, t_ico2)


func hide_unit(icon: FlashClip, text: FlashText, pad: FlashClip) -> void:
	icon.goto_and_stop(47)
	icon.visible = true
	text.text = "This enemy has not been encountered yet.\n Information will be added as soon as you meet it in battle."
	pad.visible = true
	for field in ["tHealth", "tSpeed", "tDam", "tAtSpd", "tPierce", "tArmor", "tShootDam", "tShootSpeed",
			"tAccuracy", "tProtection", "tMagicPierce", "tCost"]:
		(pad.get_node(field) as FlashText).text = "???"
	set_text_coord(text)


func show_unit(icon: FlashClip, text: FlashText, unit_number: int, pad: FlashClip) -> void:
	var idx := a_units_numbers.find(unit_number)
	icon.visible = true
	pad.visible = true
	if idx < 0 or GameUniverse.inst == null or idx >= GameUniverse.inst.a_units_xml_params.size():
		set_text_coord(text)
		return
	var x: RWXml = GameUniverse.inst.a_units_xml_params[idx]
	var class_name_: String = x.text("className")
	var health: String = x.child("Health").text("one")
	var speed: String = x.child("walkSpeed").text("one")
	var dam: String = x.child("damageMelee").text("one")
	var at_spd: String = x.child("attackSpeedMelee").text("one")
	var pierce: float = RWXml.as_number(x.child("armorPierceMelee").text("one"))
	var armor: float = RWXml.as_number(x.child("Armor").text("one"))
	var shoot_dam: String = x.child("damageRanged").text("one")
	var shoot_speed: String = x.child("attackSpeedRanged").text("one")
	var accuracy: float = RWXml.as_number(x.child("accuracy").text("one"))
	var protection: float = RWXml.as_number(x.child("Resist").text("one"))
	var magic_pierce: float = RWXml.as_number(x.child("magicPierce").text("one"))
	var cost: String = x.text("money")
	(pad.get_node("tHealth") as FlashText).text = health
	(pad.get_node("tSpeed") as FlashText).text = speed
	(pad.get_node("tDam") as FlashText).text = dam
	(pad.get_node("tAtSpd") as FlashText).text = at_spd
	(pad.get_node("tPierce") as FlashText).text = str(int(pierce * 100)) + "%"
	(pad.get_node("tArmor") as FlashText).text = str(int(armor * 100)) + "%"
	(pad.get_node("tShootDam") as FlashText).text = shoot_dam
	(pad.get_node("tShootSpeed") as FlashText).text = shoot_speed
	(pad.get_node("tAccuracy") as FlashText).text = str(int(accuracy * 100)) + "%"
	(pad.get_node("tProtection") as FlashText).text = str(int(protection * 100)) + "%"
	(pad.get_node("tMagicPierce") as FlashText).text = str(int(magic_pierce * 100)) + "%"
	(pad.get_node("tCost") as FlashText).text = cost + "g"
	icon.goto_and_stop(unit_number + 1)
	text.html_text = "<font color='#E8F38B' size='24'>%s</font> \n%s" % [class_name_, a_units_description[idx]]
	set_text_coord(text)


func set_text_coord(text: FlashText) -> void:
	if text.box.size.y < t12_height:
		if text == t1:
			text.position.y = t1_coord_y + t12_height / 2.0 - text.box.size.y / 2.0 - 10.0
		elif text == t2:
			text.position.y = t2_coord_y + t12_height / 2.0 - text.box.size.y / 2.0 - 10.0


func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var jump := {"i2": 2, "i3": 12, "i4": 18, "i5": 27, "i6": 46, "i7": 31, "i8": 35, "i9": 40, "i10": 50}
	for key in jump:
		if target == e_menu.get_node(key):
			current_list = jump[key]
			e_content.goto_and_stop(current_list)
			set_cur_list_visible()
			return
	if target == b_menu:
		if ingame:
			if get_parent() != null:
				get_parent().remove_child(self)
			if GameUniverse.inst != null:
				GameUniverse.inst.unpause()
		else:
			_main_call(&"load_main_menu")
	elif target == b_contents:
		current_list = 1
		e_content.goto_and_stop(current_list)
		set_cur_list_visible()
	elif target == b_more:
		_main_call(&"load_more_games")
	elif target == b_left:
		current_list -= 1
		if current_list < 1:
			current_list = e_content.total_frames
		e_content.goto_and_stop(current_list)
		set_cur_list_visible()
	elif target == b_right:
		current_list += 1
		if current_list > e_content.total_frames:
			current_list = 1
		e_content.goto_and_stop(current_list)
		set_cur_list_visible()


func _removed() -> void:
	_attached = false
	ButtonClass.remove_button_on_frames(b_more, button_clicked)
	ButtonClass.remove_button_on_frames(b_menu, button_clicked)
	ButtonClass.remove_button_on_frames(b_left, button_clicked)
	ButtonClass.remove_button_on_frames(b_right, button_clicked)
	ButtonClass.remove_button_on_frames(b_contents, button_clicked)
	for name_ in ["i2", "i3", "i4", "i5", "i6", "i7", "i8", "i9", "i10"]:
		ButtonClass.remove_button_scale(e_menu.get_node(name_), button_clicked)


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)
