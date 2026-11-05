extends Node2D
const Battle = preload("res://game/battle.gd")
var screen: Control
var popup: Control
var world: Node2D
var overlay := CanvasLayer.new()
var music := AudioStreamPlayer.new()
var page := 0
var help_sprite: AnimatedSprite2D
var achievement_panel: Control
var mission := 1
var last_screen := 4278
var comic := -1
var book_icons: Array = []
var book_pads: Array = []
var book_contents: Control
var intro_played := false
var upgrade_visuals: Dictionary={}

func _ready() -> void:
	add_child(overlay)
	add_child(music)
	music.volume_db = -13
	music.finished.connect(func(): music.play())
	show_menu()

func sound_symbol(symbol: String) -> AudioStream:
	var id := int(Content.symbols.get("gameCore.serviceUtils.soundLibrary_" + symbol, -1))
	if id < 0: return null
	for path in Content.resources[id].paths:
		if str(path).ends_with(".mp3") or str(path).ends_with(".wav"): return load("res://" + path)
	return null

func play_music(symbol: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var stream := sound_symbol(symbol)
	if stream != music.stream:
		music.stream = stream
		if music.stream: music.play()
	music.stream_paused = not Content.profile.music

func clear_popup() -> void:
	if is_instance_valid(popup):
		popup.get_parent().remove_child(popup)
		popup.queue_free()
	popup = null

func clear_screen() -> void:
	clear_popup()
	if is_instance_valid(screen):
		screen.get_parent().remove_child(screen)
		screen.queue_free()
	screen = null
	if is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.queue_free()
	world = null

func make_scene(id: int, parent: Node) -> Control:
	var node := Content.scene(id)
	parent.add_child(node)
	node.activated.connect(on_action)
	return node

func base_screen(id: int) -> void:
	clear_screen()
	screen = make_scene(id, overlay)
	last_screen = id
	page = 0

func show_menu() -> void:
	base_screen(4278)
	var anim := Content.sprite("mmAnimSoldiers")
	screen.add_child(anim)
	screen.move_child(anim, 1)
	play_music("sMenuMusic")

func show_map(check_story: bool = true) -> void:
	if check_story:
		for i in range(Content.story.size()):
			if int(Content.profile.slots[7][Content.story[i].flag]) == 0:
				show_comic(i)
				return
	base_screen(5556)
	var markers := make_scene(5700, screen)
	var next := Content.next_mission()
	for i in range(1, 25):
		markers.element("f%d" % i).visible = i <= next
		markers.element("r%d" % i).visible = int(Content.profile.slots[0][i - 1]) > 0
		if i <= next:
			var original: Control = markers.element("f%d" % i)
			original.self_modulate.a = 0
			var flag := make_scene(int(Content.symbols.flagMap), markers)
			for el in Content.scene_data["5700"].elements:
				if el.name == "f%d" % i: flag.position = Vector2(float(el.matrix[4]),float(el.matrix[5]))
			flag.set_text("tLevelName", "Level %d" % i)
			flag.element("eVisited").visible = int(Content.profile.slots[0][i-1]) > 0
			flag.element("eUnvisited").visible = int(Content.profile.slots[0][i-1]) == 0
	var stars_panel := place_component(markers, "eStarPlask")
	for child in stars_panel.get_children():
		if child.name.begins_with("t"): stars_panel.set_text(str(child.name), "%d / 120" % Content.total_stars())
	var upgrade_button := place_component(markers,"bUpgrades")
	upgrade_button.mouse_filter=Control.MOUSE_FILTER_IGNORE
	upgrade_button.conceal(["eGotFree","eLight"])
	var free_stars:=place_component(upgrade_button,"eGotFree")
	free_stars.visible=Content.stars()>0
	free_stars.set_text("tMore","+%d"%Content.stars())
	markers.conceal(["r0", "bOnline", "eStorageFailure"])
	for i in range(6):
		var act: Control = markers.element("a%d" % (i+1))
		if act: act.visible = next >= [1,7,13,19,22,25][i] or (i==5 and int(Content.profile.slots[0][23])>0)
	play_music("sMapMusic")

func show_comic(index: int) -> void:
	comic = index
	base_screen(int(Content.story[index].symbol))
	for key in Content.story[index].pages: screen.element(key).hide()
	screen.element(Content.story[index].pages[0]).show()
	play_music("sMapMusic")

func next_comic_page(skip: bool = false) -> void:
	page += 1
	var record: Dictionary = Content.story[comic]
	if skip or page >= record.pages.size():
		Content.profile.slots[7][record.flag] = 1
		Content.save_profile()
		comic = -1
		show_map()
	else: screen.element(record.pages[page]).show()

func show_mission(number: int) -> void:
	clear_popup()
	mission = number
	popup = make_scene(6045, overlay)
	popup.position = Vector2(350, 300)
	var record: Dictionary = Content.campaign[number]
	popup.set_text("tMissionName", record.caption)
	popup.set_text("tMissionDesc", record.description)

func replace_sprite(parent: Control, key: String) -> AnimatedSprite2D:
	var child := parent.get_node_or_null(NodePath(key))
	if not child: return null
	var id := int(child.get_meta("character_id", -1))
	var node := AnimatedSprite2D.new()
	node.sprite_frames = load("res://assets/library/sprites/%d/frames.tres" % id)
	node.centered = false
	var b: Array = Content.bounds.get(str(id), [0, 0, 1, 1])
	node.offset = Vector2(float(b[0]), float(b[1]))
	for el in Content.scene_data[str(parent.symbol_id)].elements:
		if el.name != key: continue
		var m: Array = el.matrix
		node.transform = Transform2D(Vector2(float(m[0]),float(m[1])),Vector2(float(m[2]),float(m[3])),Vector2(float(m[4]),float(m[5])))
	child.hide()
	parent.add_child(node)
	parent.move_child(node, child.get_index() + 1)
	return node

func show_help() -> void:
	base_screen(4731)
	screen.conceal(["t1", "t2", "tIco1", "tIco2", "p1", "p2", "eMenu"])
	help_sprite = replace_sprite(screen, "eContent")
	book_icons.clear()
	book_pads.clear()
	for i in range(2):
		var icon := Content.sprite("unitIcons",false)
		var placeholder: Control = screen.element("p%d" % (i+1))
		icon.position = placeholder.position + Vector2(5,5)
		icon.scale = Vector2(0.75,0.75)
		screen.add_child(icon)
		book_icons.append(icon)
		book_pads.append(place_component(screen,"tIco%d" % (i+1)))
	book_contents = place_component(screen,"eMenu")
	book_contents.activated.connect(func(_id,key):
		var pages := {"i2":2,"i3":12,"i4":18,"i5":27,"i6":46,"i7":31,"i8":35,"i9":40,"i10":50}
		if pages.has(key): show_help_page(int(pages[key])-1))
	show_help_page(0)

func show_help_page(number: int) -> void:
	var count := help_sprite.sprite_frames.get_frame_count("default")
	page = posmod(number, count)
	help_sprite.frame = page
	screen.set_text("tPicsCounter", "%d / %d" % [page + 1, count])
	book_contents.visible = page==0
	var book: Dictionary = Content.read_json("data/encyclopedia.json")
	for i in range(2):
		var shown := page>=49
		book_icons[i].visible=shown
		book_pads[i].visible=shown
		if screen.labels.has("t%d" % (i+1)): screen.labels["t%d" % (i+1)].visible=shown
		if not shown: continue
		var index := (page-49)*2+i
		if index>=book.enemy_kinds.size(): continue
		var kind: String = book.enemy_kinds[index]
		var unit: Dictionary = Content.units[kind]
		var revealed: bool = Content.profile.slots[11].has(int(unit.id))
		book_icons[i].frame=int(unit.id) if revealed else 46
		var label: Label = screen.set_text("t%d" % (i+1),str(unit.stats.className)+"\n"+str(book.enemy_descriptions[index]) if revealed else "This enemy has not been encountered yet.\nInformation will be added as soon as you meet it in battle.",16)
		label.show()
		var fields := {"tHealth":"Health","tSpeed":"walkSpeed","tDam":"damageMelee","tAtSpd":"attackSpeedMelee","tPierce":"armorPierceMelee","tArmor":"Armor","tShootDam":"damageRanged","tShootSpeed":"attackSpeedRanged","tAccuracy":"accuracy","tProtection":"Resist","tMagicPierce":"magicPierce","tCost":"money"}
		for field in fields:
			var value: Variant=unit.stats.get(fields[field],0)
			if value is Dictionary: value=value.get("one",0)
			book_pads[i].set_text(field,("%d%%"%int(float(value)*100) if fields[field] in ["armorPierceMelee","Armor","accuracy","Resist","magicPierce"] else str(value)) if revealed else "???",12)

func show_achievements() -> void:
	base_screen(3263)
	screen.conceal(["eAchives"])
	achievement_panel = make_scene(3262, screen)
	for el in Content.scene_data["3263"].elements:
		if el.name == "eAchives": achievement_panel.position = Vector2(float(el.matrix[4]), float(el.matrix[5]))
	show_achievements_page(0)

func show_achievements_page(number: int) -> void:
	page = posmod(number, 4)
	var encyclopedia: Dictionary = Content.read_json("data/encyclopedia.json")
	for i in range(1, 5): achievement_panel.element("l%d" % i).visible = i == page + 1
	for i in range(1, 13):
		var index := page * 12 + i - 1
		achievement_panel.set_text("t%d" % i, str(encyclopedia.achievement_descriptions[index]), 14)
		achievement_panel.element("m%d" % i).visible = int(Content.profile.slots[4][index]) > 0

func show_upgrades() -> void:
	base_screen(658)
	upgrade_visuals.clear()
	for key in Content.upgrades:
		var record: Dictionary=Content.upgrades[key]
		if not record.has("type") or record.type=="unit": continue
		var button: Control=screen.element(key)
		var visual:=place_component(screen,key)
		visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
		visual.conceal(["eLock"])
		var lock: AnimatedSprite2D=replace_sprite(visual,"eLock")
		button.self_modulate.a=0
		upgrade_visuals[key]={"panel":visual,"lock":lock}
	screen.conceal(["zanavesWarriors", "zanavesArchers", "zanavesMages", "zanavesPriests", "zanavesThieves", "eUnitUnlockedBar"])
	refresh_upgrades()
	for key in Content.upgrades:
		var button := screen.get_node_or_null(NodePath(key))
		if not button: continue
		button.mouse_entered.connect(func():
			var record: Dictionary = Content.upgrades[key]
			var hint: String = key.trim_prefix("u").replace("Attack"," attack").replace("Defend"," defense")
			if record.get("type","")=="ability":
				for skill in Content.read_json("data/special_parameters.json").values():
					if skill.key==record.key: hint=str(skill.get("description",hint))+"\n"+"Each rank costs one star. Shift-click to refund."
			screen.set_text("tHintText",hint,14))

func show_credits() -> void:
	base_screen(763)
	var text_panel := place_component(screen,"eText")
	text_panel.activated.connect(func(_id,key):
		if key=="eMessage":
			Content.profile.slots[4][41]=1
			Content.save_profile()
			OS.shell_open("mailto:platon.sk@gmail.com")
		elif key=="eFb": OS.shell_open("https://www.facebook.com/groups/idengames")
		elif key=="eMaxGames": OS.shell_open("https://redpalettegames.com/"))

func refresh_upgrades() -> void:
	Content.unlock_progression()
	screen.set_text("tFreeStars", str(Content.stars()))
	var passed := Content.next_mission() - 1
	for key in {"zanavesWarriors":0,"zanavesArchers":2,"zanavesPriests":3,"zanavesMages":4,"zanavesThieves":5}:
		screen.element(key).visible = passed < int({"zanavesWarriors":0,"zanavesArchers":2,"zanavesPriests":3,"zanavesMages":4,"zanavesThieves":5}[key])
	for key in Content.upgrades:
		var record: Dictionary = Content.upgrades[key]
		var button := screen.get_node_or_null(NodePath(key))
		if not button or not record.has("type"): continue
		var slot := 2 if record.type == "ability" else (6 if record.type == "bonus" else 1)
		var rank := int(Content.profile.slots[slot][int(record.index)])
		button.modulate = Color.WHITE if rank > 0 else Color(0.72, 0.72, 0.72)
		if upgrade_visuals.has(key):
			var required:=0
			if key.begins_with("uArch"): required=2
			elif key.begins_with("uPriest"): required=3
			elif key.begins_with("uMage"): required=4
			elif key.begins_with("uThief") or key.begins_with("uRogue"): required=5
			upgrade_visuals[key].panel.visible=passed>=required
			upgrade_visuals[key].lock.frame=clampi(rank+1,0,4)
			for pair in [["uWarKnight",1],["uArchCrossb",3],["uMageBlack",5],["uPriestBlesser",7],["uThiefSabot",9]]:
				if key.begins_with(pair[0]) and int(Content.profile.slots[1][pair[1]])==0: upgrade_visuals[key].lock.frame=0
		button.tooltip_text = "%s  %d/%d" % [key, rank, int(record.max)]

func buy_upgrade(key: String) -> void:
	var record: Dictionary = Content.upgrades.get(key, {})
	if not record.has("type"): return
	if record.type == "unit": return
	var required := 0
	if key.begins_with("uArch"): required=2
	elif key.begins_with("uPriest"): required=3
	elif key.begins_with("uMage"): required=4
	elif key.begins_with("uThief") or key.begins_with("uRogue"): required=5
	if Content.next_mission()-1 < required: return
	for pair in [["uWarKnight",1],["uArchCrossb",3],["uMageBlack",5],["uPriestBlesser",7],["uThiefSabot",9]]:
		if key.begins_with(pair[0]) and int(Content.profile.slots[1][pair[1]])==0: return
	var slot := 2 if record.type == "ability" else (6 if record.type == "bonus" else 1)
	var index := int(record.index)
	var rank := int(Content.profile.slots[slot][index])
	if Input.is_key_pressed(KEY_SHIFT) and record.type != "unit":
		Content.profile.slots[slot][index] = maxi(0, rank - 1)
	elif rank < int(record.max) and Content.stars() >= int(record.cost):
		Content.profile.slots[slot][index] = rank + 1
	Content.save_profile()
	var families := ["uWar","uArch","uMage","uThief","uPriest"]
	for family in families:
		var complete := true
		for button in Content.upgrades:
			var upgrade: Dictionary=Content.upgrades[button]
			var matches: bool=button.begins_with(family) or (family=="uThief" and button.begins_with("uRogue"))
			if not matches or not upgrade.has("type") or upgrade.type=="unit": continue
			var saved_slot := 2 if upgrade.type=="ability" else 6
			if int(Content.profile.slots[saved_slot][int(upgrade.index)])<3: complete=false
		if complete: Content.profile.slots[4][16]=1
	Content.save_profile()
	refresh_upgrades()

func start_mission(number: int) -> void:
	if number==1 and not intro_played:
		intro_played=true
		start_mission(0)
		return
	clear_screen()
	mission = number
	world = Battle.new()
	world.host = self
	world.mission = Content.campaign[number].duplicate(true)
	add_child(world)
	play_music("sBattleMusic")

func battle_finished(won: bool, result: Dictionary) -> void:
	clear_popup()
	popup = make_scene(5967 if won else 5974, overlay)
	popup.position = Vector2(350, 300)
	for key in result: popup.set_text(key, str(result[key]))
	play_music("sWinMusic" if won else "sLosMusic")
	if won:
		var spent := int(result.start_lives)-int(result.lives)
		var stars := 3 if spent<=2 else (2 if spent<=floori((int(result.start_lives)-2)/2.0) else 1)
		Content.profile.slots[0][mission - 1] = maxi(stars, int(Content.profile.slots[0][mission - 1]))
		var dif := int(Content.profile.slots[12])
		if dif > 1: Content.profile.slots[11 + dif][mission - 1] = stars
		for chapter in Content.story:
			if mission == int(chapter.after_mission) and int(Content.profile.slots[7][chapter.flag])<0: Content.profile.slots[7][chapter.flag]=0
		Content.unlock_progression()
		Content.save_profile()

func show_pause() -> void:
	clear_popup()
	world.paused = true
	popup = make_scene(5907, overlay)
	popup.position = Vector2(350, 300)

func on_action(id: int, key: String) -> void:
	if comic>=0 and id==int(Content.story[comic].symbol):
		if key=="bRight" or key=="bSkip": next_comic_page(key=="bSkip")
		return
	if id == 6045:
		if key == "bPlaybtn": start_mission(mission)
		elif key == "bClosebtn": clear_popup()
		elif key in ["d1", "d2", "d3"]:
			Content.profile.slots[12] = int(key.substr(1))
			Content.save_profile()
		return
	if id == 5907:
		match key:
			"bClose": clear_popup(); world.paused = false
			"bToMap": show_map()
			"bRestart": start_mission(mission)
			"bMenu": show_menu()
			"bSound": Content.profile.sound = not Content.profile.sound; Content.save_profile()
			"bMusic": Content.profile.music = not Content.profile.music; Content.save_profile(); music.stream_paused = not Content.profile.music
			"bAutopause": Content.profile.autopause = not Content.profile.autopause; Content.save_profile()
		return
	if id in [5967, 5974]:
		match key:
			"bRestart": start_mission(mission)
			"bMenu", "bMap": show_map()
			"bNext": show_mission(mini(24, mission + 1))
		return
	if id == 6012:
		if key == "bClose": clear_popup()
		elif key == "bReset": Content.reset_profile(); show_map()
		return
	if id == 5384 and is_instance_valid(world):
		world.ui_action(key)
		return
	match key:
		"bPlay": show_map()
		"bAchieves", "bAchives": show_achievements()
		"bHowTo", "bHelp": show_help()
		"bCredits": show_credits()
		"bMenu": show_menu()
		"bMore", "eMaxGames", "eHostIt", "eStrategyGuide": OS.shell_open("https://redpalettegames.com/")
		"bUpgrades": show_upgrades()
		"bNext":
			if id == 658: show_map()
			else: show_mission(Content.next_mission())
		"bSound": Content.profile.sound = not Content.profile.sound; Content.save_profile()
		"bMusic": Content.profile.music = not Content.profile.music; Content.save_profile(); music.stream_paused = not Content.profile.music
		"bReset":
			if id == 658:
				Content.profile.slots[2].fill(0); Content.profile.slots[6].fill(0)
				Content.save_profile(); refresh_upgrades()
			else:
				clear_popup(); popup = make_scene(6012, overlay); popup.position = Vector2(350, 300)
		"bContents": show_help_page(0)
		"bRight":
			if last_screen == 4731: show_help_page(page + 1)
			elif last_screen == 3263: show_achievements_page(page + 1)
		"bLeft":
			if last_screen == 4731: show_help_page(page - 1)
			elif last_screen == 3263: show_achievements_page(page - 1)
		_:
			if key.begins_with("a") and key.substr(1).is_valid_int(): show_comic(int(key.substr(1))-1)
			elif key.begins_with("f") and key.substr(1).is_valid_int(): show_mission(int(key.substr(1)))
			elif key.begins_with("u"): buy_upgrade(key)
			elif key.begins_with("bDot"): show_achievements_page(int(key.substr(4)) - 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(world):
			if is_instance_valid(popup): clear_popup(); world.paused = false
			else: show_pause()
		elif is_instance_valid(popup): clear_popup()
		else: show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(world) and Content.profile.autopause:
		world.paused = true

func _exit_tree() -> void:
	music.stop()
	music.stream = null

func place_component(parent: Control, key: String) -> Control:
	var old := parent.get_node_or_null(NodePath(key))
	var node := Content.scene(int(old.get_meta("character_id")))
	parent.add_child(node)
	old.hide()
	for el in Content.scene_data[str(parent.symbol_id)].elements:
		if el.name == key: node.position = Vector2(float(el.matrix[4]),float(el.matrix[5]))
	return node
