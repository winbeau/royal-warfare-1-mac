extends Node2D
const Soldier = preload("res://game/unit.gd")
const Skills = preload("res://game/specials.gd")
const Achievements = preload("res://game/achievements.gd")
const FAMILIES = [["FR_WARRIOR","FR_SWORDMASTER","FR_KNIGHT"],["FR_ARCHER","FR_SNIPER","FR_CROSSBOW"],["FR_BLUEMAGE","FR_REDMAGE","FR_BLACKMAGE"],["FR_PRIEST","FR_HEALER","FR_BLESSER"],["FR_ROGUE","FR_ASSASIN","FR_SABOTEUR"]]
const CATEGORY_KEYS = ["BUTTON_WARRIORS","BUTTON_ARCHERS","BUTTON_MAGES","BUTTON_PRIESTS","BUTTON_THIEVES"]
var host: Node2D
var mission: Dictionary
var army: Array = []
var selected: Array = []
var groups: Dictionary = {}
var specials: RefCounted
var achievements := Achievements.new()
var units_layer := Node2D.new()
var effects_layer := Node2D.new()
var ui_layer := CanvasLayer.new()
var hud: Control
var money_ui: Control
var lives_ui: Control
var wave_ui: Control
var unit_panel: Control
var recruit_panel := Control.new()
var dialogue: Control
var dialogue_queue: Array = []
var dialogue_text: Label
var paths: Dictionary
var obstacles: Array = []
var gold := 0.0
var lives := 20
var start_lives := 20
var paused := false
var finished := false
var elapsed := 0.0
var frame_counter := 0
var event_index := 0
var event_frames := 0
var wave := 0
var global_wait := 45.0
var global_ready := false
var speed := 1
var active_family := -1
var recruit_cooldown := 0.0
var family_cooldowns := [0.0,0.0,0.0,0.0,0.0]
var recruitment: Dictionary
var arrow_cooldown := 0.0
var arrow_targeting := false
var formation := 0
var attack_mode := false
var show_ranges := false
var dragging := false
var drag_start := Vector2.ZERO
var kills := 0
var lost := 0
var hired := 0
var upgraded := 0
var damage_dealt := 0.0
var damage_received := 0.0
var healed := 0.0
var gold_gained := 0.0
var gold_spent := 0.0
var civilians := 0
var civilian_wave := 0
var tooltip := Label.new()
var audio_pool: Array = []
var last_sound := -20
var effects: Array = []
var projectiles: Array = []
var rebirths: Array = []
var tutorial: Control
var tutorial_page := 0
var arrows_available := false
var navigation: AStarGrid2D
var upgrade_panel: Control
var unit_icon: AnimatedSprite2D
var support_phase := 0
var arrow_definition: Dictionary = {}
var swarm: Dictionary = {}
var flying_arrows: Array = []
var next_wave_ui: Control
var next_wave_timer: Control
var ability_panels: Array = []
var ability_icons: Array = []
var ability_cooldowns: Array = []
var hint_queue: Array = []
var tutorial_keys := {}
var dialogue_icon: AnimatedSprite2D

func find_path(start: Vector2, goal: Vector2) -> PackedVector2Array:
	if navigation == null:
		navigation = AStarGrid2D.new()
		navigation.region = Rect2i(-10,-10,90,80)
		navigation.cell_size = Vector2(10,10)
		navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		navigation.update()
		for y in range(-10,70):
			for x in range(-10,80):
				var p := Vector2(x*10,y*10)
				navigation.set_point_solid(Vector2i(x,y),is_blocked(p) or is_blocked(p+Vector2(4,0)) or is_blocked(p+Vector2(0,4)))
	var first := Vector2i(roundi(start.x/10),roundi(start.y/10))
	var last := Vector2i(roundi(goal.x/10),roundi(goal.y/10))
	if not navigation.is_in_boundsv(first) or not navigation.is_in_boundsv(last): return PackedVector2Array()
	for r in range(1,6):
		if not navigation.is_point_solid(last): break
		var found := false
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				var candidate := last+Vector2i(x,y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate):
					last=candidate; found=true; break
			if found: break
	return navigation.get_point_path(first,last)

func _ready() -> void:
	specials = Skills.new(self)
	recruitment = Content.read_json("data/recruitment.json")
	arrows_available = int(mission.number) in [4,16,17,20]
	arrow_definition=Content.read_json("data/arrows.json").get(str(int(mission.number)),{})
	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = load("res://assets/backgrounds/%s.png" % mission.background)
	bg.scale = Vector2(0.5,0.5)
	add_child(bg)
	paths = Content.geometry[mission.background].routes
	# Obstacle geometry is derived from original authored guide symbols.
	var guides: Array = Content.geometry[mission.background].guides
	for contour in Content.geometry[mission.background].get("obstacle_polygons", []):
		var polygon := PackedVector2Array()
		for point in contour: polygon.append(Vector2(float(point[0]), float(point[1])))
		obstacles.append(polygon)
	add_child(units_layer)
	units_layer.y_sort_enabled = true
	add_child(effects_layer)
	add_child(ui_layer)
	hud = Content.scene(5384)
	ui_layer.add_child(hud)
	hud.activated.connect(func(_id, key): ui_action(key))
	hud.element("bArchers").visible = arrows_available
	hud.conceal(["eMoney","eHp","eWave","eUnitPanel","arrowTargetCircle","eChat","tChatBox","eSubOne","eSubTwo","eSubThree","eSubDown","eFocus","eSensArchers","eNextWavePad","eFader","eHint","eSmallHint","eHoriz","eVert","tPauseMessage","eAttackDef","eDefend","eFormation"])
	money_ui = place_component(hud,"eMoney",5144)
	lives_ui = place_component(hud,"eHp",5146)
	wave_ui = place_component(hud,"eWave",5154)
	unit_panel = place_component(hud,"eUnitPanel",5141)
	next_wave_ui=place_component(hud,"eNextWavePad",5167)
	next_wave_ui.position.y=32
	next_wave_ui.hide()
	next_wave_ui.activated.connect(func(_id,key):
		if key=="bStart" and global_ready: next_event())
	next_wave_ui.conceal(["eAutostartPad"])
	next_wave_timer=place_component(next_wave_ui,"eAutostartPad",5166)
	unit_panel.conceal(["eUnitSelect","eUpgrade","uWarSwordUnit","eOne","eTwo"])
	unit_icon=host.replace_sprite(unit_panel,"eIco")
	for key in ["eOne","eTwo"]:
		var panel:=place_component(unit_panel,key,5019)
		ability_panels.append(panel)
		ability_icons.append(host.replace_sprite(panel,"eAbility"))
		ability_cooldowns.append(host.replace_sprite(panel,"eCoolDown"))
	upgrade_panel=place_component(unit_panel,"eUnitSelect",4843)
	upgrade_panel.hide()
	upgrade_panel.activated.connect(func(_id,key):
		if key=="bClose": upgrade_panel.hide()
		elif key=="bTop" or key=="bDown": promote_selected(key=="bTop"))
	unit_panel.activated.connect(func(_id, key):
		if key == "eUpgrade" or key == "uWarSwordUnit": upgrade_selected())
	ui_layer.add_child(recruit_panel)
	tooltip.position = Vector2(225,535)
	tooltip.add_theme_font_size_override("font_size",14)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_theme_color_override("font_color",Color("f6f581"))
	ui_layer.add_child(tooltip)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -17
		add_child(player)
		audio_pool.append(player)
	if not mission.set_lives_calls.is_empty(): lives = int(mission.set_lives_calls[-1])
	start_lives = lives
	if not mission.set_money_calls.is_empty(): gold = float(mission.set_money_calls[-1])
	for entry in mission.initial_units:
		var route_id := str(int(entry.get("route_ids",[0]).pick_random()))
		var point := route_point(route_id)
		if entry.position != null: point = Vector2(float(entry.position[0]),float(entry.position[1]))
		var unit := spawn(entry.kind, entry.friendly, point, int(entry.level))
		unit.all_abilities = bool(entry.max_abilities)
		if not entry.route.is_empty(): unit.follow_route(entry.route)
		elif not entry.friendly: unit.follow_route(paths.get(route_id,[]))
		unit.sprite.scale.x=float(entry.get("facing",1))
		unit.hold=bool(entry.get("hold",false))
	if int(mission.number) == 0:
		var button := Button.new()
		button.text = "Skip intro"
		button.position = Vector2(600,562)
		button.pressed.connect(func(): host.start_mission(1))
		ui_layer.add_child(button)
	update_hud()

func place_component(parent: Control, key: String, id: int) -> Control:
	var node := Content.scene(id)
	parent.add_child(node)
	for el in Content.scene_data[str(parent.symbol_id)].elements:
		if el.name == key:
			var m: Array = el.matrix
			node.position = Vector2(float(m[4]),float(m[5]))
	return node

func spawn(kind: String, friend: bool, point: Vector2, rank: int = 1) -> RoyalUnit:
	var unit := Soldier.new()
	unit.setup(self, kind, friend, rank)
	unit.position = point
	units_layer.add_child(unit)
	army.append(unit)
	if not friend and not Content.profile.slots[11].has(int(unit.record.id)):
		Content.profile.slots[11].append(int(unit.record.id))
		Content.save_profile()
	return unit

func route_point(id: String) -> Vector2:
	var points: Array = paths.get(id, [])
	return Vector2(float(points[0][0]),float(points[0][1])) if not points.is_empty() else Vector2(-45,300)

func spawn_route(record: Dictionary, friend: bool) -> void:
	var kind := str(record.kind)
	var rank := int(record.get("level",1))
	if not friend:
		var dif := int(Content.profile.slots[12])
		if dif == 2: rank = mini(3,rank+1)
		elif dif == 3: rank = 3
	var id := str(int(record.get("route",0))) if not friend else "0"
	var unit := spawn(kind,friend,route_point(id),rank)
	unit.follow_route(paths.get(id, []))

func is_blocked(point: Vector2) -> bool:
	var inside := false
	for polygon in obstacles:
		if Geometry2D.is_point_in_polygon(point, polygon): inside = not inside
	return inside

func _physics_process(delta: float) -> void:
	if finished: return
	if paused or is_instance_valid(dialogue):
		for unit in army: unit.sprite.pause()
		for item in effects:
			if is_instance_valid(item.node): item.node.pause()
		return
	for step in range(speed): tick(delta)
	queue_redraw()

func tick(delta: float) -> void:
	frame_counter += 1
	elapsed += delta
	recruit_cooldown = maxf(0,recruit_cooldown-delta)
	for i in range(5): family_cooldowns[i] = maxf(0,family_cooldowns[i]-delta)
	arrow_cooldown = maxf(0,arrow_cooldown-delta)
	update_swarm(delta)
	for pending in rebirths.duplicate():
		pending.time -= delta
		if pending.time <= 0:
			if is_instance_valid(pending.unit): pending.unit.revive()
			rebirths.erase(pending)
	for item in effects.duplicate():
		if is_instance_valid(item.node): item.node.speed_scale=speed; item.node.play()
		item.time -= delta
		if item.time <= 0:
			if is_instance_valid(item.node): item.node.queue_free()
			effects.erase(item)
	for shot in projectiles.duplicate():
		if not is_instance_valid(shot.victim) or shot.victim.escaped or shot.victim.dead:
			shot.node.queue_free(); projectiles.erase(shot); continue
		shot.node.position = shot.node.position.move_toward(shot.victim.position + Vector2(0,-25),shot.speed*delta)
		if shot.node.position.distance_to(shot.victim.position + Vector2(0,-25)) < 12:
			resolve_attack(shot.attacker,shot.victim,true)
			shot.node.queue_free(); projectiles.erase(shot)
	for unit in army.duplicate(): unit.tick(delta)
	custom_level_actions()
	if event_index < mission.events.size():
		var event: Dictionary = mission.events[event_index]
		var type := str(event.type)
		if event_frames < int(event.get("time",0))*30:
			if (type != "ENEMY_SPAWN" and int(event.get("no_enemies",0)) == 0) or enemy_count() == 0: event_frames += 1
		else:
			match type:
				"GAME_CHAT":
					dialogue_queue = event.get("data",{}).get("say",[]).duplicate(true)
					next_event()
					show_dialogue()
				"ENEMY_SPAWN", "FRIEND_SPAWN":
					var records: Array = event.get("data",{}).get("unit",[])
					if records.is_empty(): next_event()
					elif randf() > float(records[0].get("spawnProb",0)):
						spawn_route(records[0],type=="FRIEND_SPAWN")
						records[0].number = int(records[0].get("number",1))-1
						if int(records[0].number) <= 0: records.pop_front()
						if records.is_empty():
							if type == "ENEMY_SPAWN": wave += 1
							next_event()
				"SUMMON":
					for record in event.get("data",{}).get("unit",[]): summon_record(record)
					next_event()
				"ARROWS_SWARM":
					if int(mission.number) == 3:
						civilian_wave += 1
						civilians = randi_range(8,16)
					else:
						var enemy: RoyalUnit = first_enemy()
						if enemy: arrow_strike(enemy.position,true)
					next_event()
				"GLOBAL_WAVE":
					if enemy_count()==0:
						global_ready = true
						global_wait -= delta
						if global_wait <= 0: next_event()
	elif enemy_count() == 0 and civilians == 0 and rebirths.is_empty() and not finished:
		if int(mission.number) == 0: host.start_mission(1)
		else: finish(true)
	update_hud()

func next_event() -> void:
	event_index += 1
	event_frames = 0
	global_ready = false
	global_wait = 45

func show_dialogue() -> void:
	if is_instance_valid(dialogue): dialogue.queue_free()
	dialogue = null
	if dialogue_queue.is_empty(): return
	var entry: Dictionary = dialogue_queue.pop_front()
	dialogue = Content.scene(5357)
	ui_layer.add_child(dialogue)
	dialogue.position = Vector2(350,410)
	dialogue.conceal(["eAlternateTextContent"])
	dialogue.set_text("tText",str(entry.text),18)
	dialogue_icon=host.replace_sprite(dialogue,"eIco")
	var speaker: String=str(entry.get("who","FR_WARRIOR"))
	if Content.units.has(speaker): dialogue_icon.frame=int(Content.units[speaker].id)
	dialogue.activated.connect(func(_id,_key): show_dialogue())

func closest(unit: RoyalUnit, friend: bool, radius: float, injured: bool = false) -> RoyalUnit:
	var result: RoyalUnit
	var best := radius
	for other in army:
		if other == unit or other.dead or other.escaped or other.friendly != (unit.friendly if friend else not unit.friendly): continue
		if injured and other.hp >= other.max_hp: continue
		if not friend and other.statuses.has("hide"): continue
		var distance: float = unit.position.distance_to(other.position)
		if distance < best: best = distance; result = other
	return result

func first_enemy() -> RoyalUnit:
	for unit in army:
		if not unit.friendly and not unit.dead and not unit.escaped: return unit
	return null

func enemy_count() -> int:
	var count := 0
	for unit in army:
		if not unit.friendly and not unit.dead and not unit.escaped: count += 1
	return count

func attack(attacker: RoyalUnit, victim: RoyalUnit, ranged: bool) -> void:
	if ranged:
		var node := Content.sprite("smallFireball" if attacker.magic() else "arrow")
		effects_layer.add_child(node)
		node.position = attacker.position + Vector2(0,-25)
		node.rotation = (victim.position-attacker.position).angle() if not attacker.magic() else 0
		projectiles.append({"node":node,"attacker":attacker,"victim":victim,"speed":300.0 if attacker.magic() else 500.0})
	else: resolve_attack(attacker,victim,false)

func resolve_attack(attacker: RoyalUnit, victim: RoyalUnit, ranged: bool) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(victim) or victim.dead: return
	if specials.defend(victim,attacker,ranged): effect("missEffect",victim.position); return
	if ranged and randf() > attacker.stat("accuracy",1): effect("missEffect",victim.position); return
	var defense := maxf(0,victim.stat("Resist")-attacker.stat("magicPierce")) if attacker.magic() else maxf(0,victim.stat("Armor")-victim.armor_damage-attacker.stat("armorPierceRanged" if ranged else "armorPierceMelee"))
	var amount := attacker.stat("damageRanged" if ranged else "damageMelee",1) * (1-clampf(defense,0,0.98))
	if attacker.statuses.has("curse"): amount *= 1.0-float(attacker.statuses.curse.strength)
	if attacker.statuses.has("enchant"): amount *= float(attacker.statuses.enchant.strength)
	amount = specials.strike(attacker,victim,amount,ranged)
	victim.hurt(amount,attacker)
	attacker.successful_hits+=1
	attacker.gain_experience(1)
	if frame_counter - last_sound > 4:
		play_sound("sArrowToGround1" if ranged else "sSwordSwoosh1")
		last_sound = frame_counter

func effect(symbol: String, point: Vector2) -> void:
	if not Content.symbols.has(symbol): return
	var node := Content.sprite(symbol)
	effects_layer.add_child(node)
	node.position = point
	var duration := node.sprite_frames.get_frame_count("default")/30.0 if node.sprite_frames else 0.3
	effects.append({"node":node,"time":maxf(0.2,duration)})

func play_sound(symbol: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if not Content.profile.sound: return
	var stream: AudioStream = host.sound_symbol(symbol)
	if not stream: return
	for player in audio_pool:
		if not player.playing: player.stream=stream; player.play(); return

func unit_died(unit: RoyalUnit, attacker: RoyalUnit) -> void:
	selected.erase(unit)
	if unit.friendly:
		lost += 1
		if unit.kind == "FR_KING": lives -= 20
		elif unit.npc: lives -= 1
	else:
		kills += 1
		achievements.killed(unit,attacker)
		var reward := unit.stat("money",1)
		gold += reward; gold_gained += reward
	if lives <= 0: finish(false)

func corpse_expired(unit: RoyalUnit) -> void:
	if unit.original_friendly and not unit.npc and unit.kind != "FR_KING": lives -= 1
	if lives <= 0: finish(false)

func unit_escaped(unit: RoyalUnit) -> void:
	if not unit.friendly: lives -= 1
	if lives <= 0: finish(false)

func recruit(kind: String) -> bool:
	if mission.locked_units.has(kind): return false
	var family := family_of(kind)
	if family_cooldowns[family] > 0: return false
	if mission.locked_units.has(CATEGORY_KEYS[family]): return false
	var tier: int = FAMILIES[family].find(kind)
	if tier > 0:
		var index: int = [[0,1],[2,3],[4,5],[6,7],[8,9]][family][tier-1]
		if int(Content.profile.slots[1][index])==0: return false
	var cost := recruit_price(kind)
	if gold < cost: tooltip.text = "Not enough gold"; return false
	gold -= cost; gold_spent += cost; hired += 1
	var unit := spawn(kind,true,route_point("0"),1)
	unit.follow_route(paths.get("0",[]))
	var table: Array = recruitment[["A_WARRIOR_COOLDOWN_TAB","A_ARCHER_COOLDOWN_TAB","A_MAGE_COOLDOWN_TAB","A_PRIEST_COOLDOWN_TAB","A_ROGUE_COOLDOWN_TAB"][family]]
	var count := 0
	for soldier in army:
		if soldier.friendly and not soldier.dead and not soldier.escaped and (soldier.kind in FAMILIES[family] or (family==0 and soldier.kind=="FR_KING")): count += 1
	family_cooldowns[family] = float(table[clampi(count-1,0,table.size()-1)])
	close_recruits()
	return true

func family_of(kind: String) -> int:
	for i in range(FAMILIES.size()):
		if kind in FAMILIES[i]: return i
	return 0

func recruit_price(kind: String) -> int:
	var base := float(Content.units[kind].unit_cost)
	if kind != FAMILIES[family_of(kind)][0]: return int(base)
	var count := 0
	for unit in army:
		if unit.friendly and not unit.dead and not unit.escaped and (unit.kind in FAMILIES[family_of(kind)] or (family_of(kind)==0 and unit.kind=="FR_KING")): count += 1
	return int(base*(1.0+0.5*count))

func show_recruits(family: int) -> void:
	active_family = family
	hud.conceal(["e1","e2","e3","e4","e5"])
	hud.element("eSubDown").show()
	for child in recruit_panel.get_children(): child.queue_free()
	var keys := ["eSubOne","eSubTwo","eSubThree"]
	for i in range(3):
		var kind: String = FAMILIES[family][i]
		var control: Control = Content.scene([5284,5287,5290][i])
		for el in Content.scene_data["5384"].elements:
			if el.name==keys[i]:
				control.position=Vector2(float(el.matrix[4]),float(el.matrix[5]))
				control.scale=Vector2(float(el.matrix[0]),float(el.matrix[3]))
		recruit_panel.add_child(control)
		var icon: AnimatedSprite2D=host.replace_sprite(control,"eIco")
		icon.frame=[0,1,3,2,4][family]
		var click := Button.new()
		click.flat=true
		click.name="Hire"
		click.position=control.element("depth_1").position
		click.size=control.element("depth_1").size
		control.add_child(click)
		control.set_meta("unit_kind",kind)
		click.pressed.connect(func(): recruit(kind))
		var tier: int=i
		var unlocked := i==0 or int(Content.profile.slots[1][[[0,1],[2,3],[4,5],[6,7],[8,9]][family][maxi(0,tier-1)]])>0
		click.disabled=mission.locked_units.has(kind) or not unlocked or family_cooldowns[family]>0
		click.tooltip_text="%s — %dg"%[str(Content.units[kind].stats.className),recruit_price(kind)]
		control.modulate=Color.WHITE if not click.disabled else Color(0.5,0.5,0.5)
		var label := Label.new()
		control.element("depth_4").hide()
		label.text = str(recruit_price(kind))
		label.position = control.element("depth_4").position
		label.size = Vector2(45,18)
		label.add_theme_font_size_override("font_size",12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(label)

func close_recruits() -> void:
	active_family = -1
	for child in recruit_panel.get_children(): child.queue_free()
	for key in ["e1","e2","e3","e4","e5"]: hud.element(key).show()
	hud.element("eSubDown").hide()

func upgrade_selected() -> void:
	if int(mission.number)==1: return
	for unit in selected:
		if unit.kind==FAMILIES[family_of(unit.kind)][0] and unit.level==3 and unit.experience>=unit.stat("Experience",30):
			upgrade_panel.show()
			var sprite: AnimatedSprite2D=host.replace_sprite(upgrade_panel,"eSelector")
			sprite.frame=[0,1,3,2,4][family_of(unit.kind)]
			upgrade_panel.conceal(["eUpgradeNotAllowedBottom","eUpgradeNotAllowedTop"])
			return

func promote_selected(top: bool) -> void:
	for unit in selected.duplicate():
		if unit.level < 3 or unit.experience<unit.stat("Experience",30): continue
		var family := family_of(unit.kind)
		var index: int = FAMILIES[family].find(unit.kind)
		if index!=0: continue
		var tier := (2 if top else 1) if family in [0,1] else (1 if top else 2)
		var kind: String = FAMILIES[family][tier]
		var unlock_index: int = [[0,1],[2,3],[4,5],[6,7],[8,9]][family][tier-1]
		if int(Content.profile.slots[1][unlock_index])==0: continue
		var cost := int(Content.units[kind].upgrade_cost)
		if gold < cost or mission.locked_units.has(kind): continue
		gold -= cost; gold_spent += cost; upgraded += 1
		var replacement := spawn(kind,true,unit.position,1)
		replacement.hp = replacement.max_hp*(unit.hp/unit.max_hp)
		replacement.selected = true
		replacement.all_abilities = unit.all_abilities
		selected.erase(unit); selected.append(replacement)
		army.erase(unit); unit.queue_free()
	upgrade_panel.hide()

func arrow_strike(point: Vector2, automatic: bool = false) -> void:
	if not automatic and not arrows_available: return
	if not automatic and arrow_cooldown > 0: return
	if arrow_definition.is_empty(): return
	swarm=arrow_definition.duplicate(true)
	swarm.center=point
	arrow_cooldown=float(arrow_definition.cooldown)
	arrow_targeting = false
	play_sound("sArrowSwarm")

func update_swarm(delta: float) -> void:
	if not swarm.is_empty() and int(swarm.count)>0 and randf()>float(swarm.probability):
		swarm.count-=1
		var node := Content.sprite("arrow",false)
		effects_layer.add_child(node)
		node.position=Vector2(-50 if swarm.side=="left" else 800,randf_range(200,500))
		var target: Vector2=swarm.center+Vector2(randf_range(-swarm.area[0]/2,swarm.area[0]/2),randf_range(-swarm.area[1]/2,swarm.area[1]/2))
		node.rotation=node.position.angle_to_point(target)
		flying_arrows.append({"node":node,"target":target,"damage":float(swarm.damage),"splash":float(swarm.splash)})
	for arrow in flying_arrows.duplicate():
		arrow.node.position=arrow.node.position.move_toward(arrow.target,500*delta)
		if arrow.node.position.distance_to(arrow.target)<5:
			for unit in army:
				if not unit.dead and not unit.escaped and unit.position.distance_to(arrow.target)<arrow.splash:
					unit.hurt(floorf(arrow.damage*(1-clampf(unit.stat("Armor")-unit.armor_damage,0,1))))
			arrow.node.queue_free()
			flying_arrows.erase(arrow)

func summon_record(record: Dictionary) -> void:
	var route_id := str(int(record.get("route",1)))
	var point := route_point(route_id)+Vector2(randf_range(-60,60),randf_range(-60,60))
	var unit := spawn(str(record.kind),false,point,int(record.get("level",1)))
	unit.follow_route(paths.get(route_id,[]))
	unit.apply_status("stun",0.5 if unit.kind=="UNDEAD_VAMPIRE_KING" else 3.0)
	effect("summonAni" if unit.kind=="UNDEAD_VAMPIRE_KING" else "summonSingleAni",point)

func king_support() -> void:
	var waves: Array=Content.read_json("data/boss_support.json")
	if support_phase>=waves.size(): return
	for record in waves[support_phase]:
		if record.summon: summon_record(record)
		else: spawn_route(record,false)
	support_phase+=1

func ui_action(key: String) -> void:
	match key:
		"eMenu": host.show_pause()
		"ePause": paused = not paused
		"eSpeedUp": speed = 2 if speed==1 else 1
		"eNextWavePad": if global_ready: next_event()
		"e1", "e2", "e3", "e4", "e5": show_recruits(int({"e1":0,"e4":1,"e2":2,"e3":3,"e5":4}[key]))
		"eSubDown": close_recruits()
		"eSubOne", "eSubTwo", "eSubThree":
			if active_family >= 0: recruit(FAMILIES[active_family][["eSubOne","eSubTwo","eSubThree"].find(key)])
		"eFormation": formation = (formation+1)%3
		"eDefend":
			for unit in selected: unit.hold=true; unit.moving=false
		"eAttackDef": attack_mode = not attack_mode
		"bArchers": if arrows_available: arrow_targeting = true
		"eHelp": show_tutorial(0)
		"eNewHint":
			if not hint_queue.is_empty(): show_tutorial(int(hint_queue.pop_front()))
		"smallHoriz","eHoriz": formation=2
		"smallVert","eVert": formation=1

func update_hud() -> void:
	next_wave_ui.visible=global_ready
	if global_ready: next_wave_timer.set_text("tCounter",str(ceili(global_wait)),14)
	for key in ["eAttackDef","eDefend","eFormation"]: hud.element(key).visible = not selected.is_empty()
	for key in ["smallHoriz","smallVert"]: hud.element(key).visible=selected.size()>1
	for control in recruit_panel.get_children():
		if not control.has_meta("unit_kind"): continue
		var kind: String=control.get_meta("unit_kind")
		var family:=family_of(kind)
		var tier: int=FAMILIES[family].find(kind)
		var unlocked: bool=tier==0 or int(Content.profile.slots[1][[[0,1],[2,3],[4,5],[6,7],[8,9]][family][maxi(0,tier-1)]])>0
		control.get_node("Hire").disabled=mission.locked_units.has(kind) or not unlocked or family_cooldowns[family]>0 or gold<recruit_price(kind)
		control.modulate=Color(0.5,0.5,0.5) if control.get_node("Hire").disabled else Color.WHITE
	money_ui.set_text("tMoney",str(int(gold)))
	for child in lives_ui.get_children():
		if child.name.begins_with("t"): lives_ui.set_text(str(child.name),str(lives),14)
	for child in wave_ui.get_children():
		if child.name.begins_with("t"):
			var total: int = mission.events.filter(func(e): return e.type=="ENEMY_SPAWN").size()
			wave_ui.set_text(str(child.name),"%d/%d"%[wave,total],14)
	tooltip.text = ""
	hud.element("tPauseMessage").visible=paused
	if not selected.is_empty():
		var unit: RoyalUnit = selected[0]
		unit_panel.visible = true
		unit_icon.frame=int(unit.record.id)
		for i in range(2):
			ability_panels[i].visible=i<unit.record.specials.size()
			if i>=unit.record.specials.size(): continue
			var skill: String=unit.record.specials[i]
			var metadata: Dictionary=specials.parameters[skill]
			var rank: int=specials.rank(unit,skill)
			ability_icons[i].frame=maxi(0,int(metadata.icon)) if rank>=0 else 0
			var cooldown: float=specials.value(unit,skill,"aTimeUntilUpdate",float(metadata.cooldown))
			var fraction: float=clampf(float(unit.special_timers[skill])/cooldown,0,1) if cooldown>0 else 1.0
			ability_cooldowns[i].frame=int(fraction*99)
			ability_panels[i].tooltip_text=str(metadata.get("description",skill))+"\n"+("Locked" if rank<0 else "Rank %d · %.1fs / %.1fs"%[rank+1,minf(float(unit.special_timers[skill]),cooldown),cooldown])
		unit_panel.set_text("tLevelClass","%s\n%s"%[["Novice","Veteran","Elite"][unit.level-1],unit.record.stats.className])
		unit_panel.set_text("tHp","%d / %d"%[int(unit.hp),int(unit.max_hp)])
		unit_panel.set_text("tAttack",str(int(unit.stat("damageRanged" if unit.ranged() or unit.record.base=="priestClass" else "damageMelee"))))
		unit_panel.set_text("tXp","%d/%d"%[mini(int(unit.experience),int(unit.stat("Experience"))),int(unit.stat("Experience"))])
		var attack_speed: float=unit.stat("attackSpeedRanged" if unit.ranged() or unit.record.base=="priestClass" else "attackSpeedMelee")
		unit_panel.set_text("tSpeed","Fast" if attack_speed<35 else ("Slow" if attack_speed>50 else "Normal"))
		unit_panel.set_text("tArmor","%d%%"%int(unit.stat("Armor")*100))
		unit_panel.set_text("tResist","%d%%"%int(unit.stat("Resist")*100))
		unit_panel.set_text("tArmorPiercing","%d%%"%int(unit.stat("armorPierceRanged" if unit.ranged() else "armorPierceMelee")*100))
		unit_panel.set_text("tMagicPiercing","%d%%"%int(unit.stat("magicPierce")*100))
		unit_panel.element("eUpgrade").visible=unit.level==3 and unit.experience>=unit.stat("Experience",30) and unit.kind==FAMILIES[family_of(unit.kind)][0]
	else: unit_panel.hide()

func select_units(list: Array, append: bool = false) -> void:
	upgrade_panel.hide()
	if not append:
		for unit in selected: unit.selected = false
		selected.clear()
	for unit in list:
		if unit.friendly and not unit.dead and not unit.npc and not selected.has(unit):
			selected.append(unit); unit.selected = true

func command_move(point: Vector2) -> void:
	var center:=Vector2.ZERO
	for unit in selected: center+=unit.position
	if not selected.is_empty(): center/=selected.size()
	for i in range(selected.size()):
		var offset := Vector2((i%4)*30,(i/4)*26)-Vector2(40,20)
		if formation==1: offset=Vector2(0,(i-selected.size()/2)*28)
		elif formation==2: offset=Vector2((i-selected.size()/2)*28,0)
		if Input.is_key_pressed(KEY_SHIFT): offset=selected[i].position-center
		selected[i].move_to(point+offset,attack_mode or Input.is_key_pressed(KEY_A))
	effect("moveFlagPlaced",point)

func _unhandled_input(event: InputEvent) -> void:
	if finished: return
	if is_instance_valid(dialogue):
		if event is InputEventMouseButton and event.pressed or event is InputEventKey and event.pressed: show_dialogue()
		return
	if paused:
		if event is InputEventKey and event.pressed and event.keycode==KEY_SPACE: paused=false
		return
	if event is InputEventKey and not event.pressed:
		if event.keycode==KEY_Z: show_ranges=false
		elif event.keycode==KEY_A: attack_mode=false
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: paused=not paused
			KEY_P: paused=not paused
			KEY_N:
				var candidates: Array=army.filter(func(u): return u.friendly and not u.dead and u.level==3 and u.experience>=u.stat("Experience",30) and u.kind==FAMILIES[family_of(u.kind)][0])
				if not candidates.is_empty(): select_units([candidates[0]])
			KEY_S:
				for unit in selected: unit.hold=true; unit.moving=false
			KEY_A: attack_mode=true
			KEY_Z: show_ranges=true
			KEY_X: formation=1
			KEY_C: formation=2
			KEY_F: if arrows_available: arrow_targeting=true
			KEY_U: upgrade_selected()
			KEY_Q,KEY_W,KEY_E,KEY_R,KEY_T:
				var family: int = [KEY_Q,KEY_W,KEY_E,KEY_R,KEY_T].find(event.keycode)
				select_units(army.filter(func(u): return family_of(u.kind)==family))
			_:
				if event.keycode>=KEY_0 and event.keycode<=KEY_9:
					var group := int(event.keycode-KEY_0)
					if event.ctrl_pressed or event.meta_pressed or event.shift_pressed: groups[group]=selected.duplicate()
					elif groups.has(group): select_units(groups[group].filter(func(u): return is_instance_valid(u) and not u.dead))
	elif event is InputEventMouseButton:
		var point := get_global_mouse_position()
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: command_move(point)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					for unit in army:
						if unit.friendly and not unit.dead and (unit.position+Vector2(0,-25)).distance_to(point)<30:
							select_units(army.filter(func(other): return other.kind==unit.kind),event.shift_pressed)
							return
				if arrow_targeting: arrow_strike(point); return
				dragging=true; drag_start=point
			else:
				if not dragging: return
				dragging=false
				if point.distance_to(drag_start)>8:
					var rect := Rect2(drag_start,point-drag_start).abs()
					select_units(army.filter(func(u): return rect.has_point(u.position)),event.shift_pressed)
				else:
					var clicked: RoyalUnit
					for unit in army:
						if not unit.dead and (unit.position+Vector2(0,-25)).distance_to(point)<30: clicked=unit
					if clicked and clicked.friendly: select_units([clicked],event.shift_pressed)
					elif clicked:
						for unit in selected: unit.target=clicked;unit.moving=false
					else: command_move(point)

func custom_level_actions() -> void:
	var number := int(mission.number)
	var hints := {1:{60:0,420:1,3600:2},2:{480:4,2700:6},3:{300:7},4:{300:8},5:{400:10}}
	if hints.has(number) and hints[number].has(frame_counter):
		var index: int=hints[number][frame_counter]
		if number==1 and frame_counter==60 and int(Content.profile.slots[9])==0:
			Content.profile.slots[9]=1
			Content.save_profile()
			show_tutorial(0)
		else: hint_queue.append(index)
	hud.element("eNewHint").visible=not hint_queue.is_empty()
	if number==5 and frame_counter==650:
		for i in range(2):
			var unit:=spawn("FR_ROGUE",true,Vector2(341-i*20,800),3 if i==0 else 1)
			unit.all_abilities=true;unit.move_to(Vector2(348-i*23,500+i*50))
	if number==3 and civilians>0 and randf()>0.98:
		civilians-=1
		var top := civilian_wave in [1,4,7,9,10]
		var entry:=Vector2(-50,234+randi_range(1,40)) if top else Vector2(-52,610+randi_range(1,40))
		var goal:=Vector2(341+randi_range(1,40),237+randi_range(1,40)) if top else Vector2(476+randi_range(1,40),306+randi_range(1,40))
		var unit:=spawn(["NPC_OLDMAN","NPC_MAN","NPC_WOMAN"][randi()%3],true,entry)
		unit.follow_route([[goal.x,goal.y],[775,343]])

func show_tutorial(index: int) -> void:
	paused=true
	if not is_instance_valid(tutorial):
		tutorial=Content.scene(1292)
		ui_layer.add_child(tutorial)
		tutorial.position=Vector2(350,300)
		tutorial.activated.connect(func(_id,key):
			if key=="bClosebtn": tutorial.queue_free();paused=false
			elif key=="bRight": show_tutorial(tutorial_page+1)
			elif key=="bLeft": show_tutorial(tutorial_page-1))
	var contents: Array=[]
	for child in tutorial.get_children():
		if child.name.begins_with("eContent"): contents.append(child)
	tutorial_page=posmod(index,contents.size())
	for i in range(contents.size()): contents[i].visible=i==tutorial_page
	tutorial.set_text("tPicsCounter","%d / %d"%[tutorial_page+1,contents.size()])

func finish(won: bool) -> void:
	if finished:return
	finished=true
	host.battle_finished(won,{"tNumKills":kills,"tNumLost":lost,"tDamageDealt":int(damage_dealt),"tDamageReceived":int(damage_received),"tTimeSpent":"%d:%02d"%[int(elapsed)/60,int(elapsed)%60],"tNumUpgrades":upgraded,"tHired":hired,"tUpgraded":upgraded,"tGotGold":int(gold_gained),"tSpentGold":int(gold_spent),"lives":lives,"start_lives":start_lives})
	achievements.finish(self,won)

func _draw() -> void:
	if dragging: draw_rect(Rect2(drag_start,get_global_mouse_position()-drag_start).abs(),Color(0.7,0.9,0.2,0.75),false,1)
	if show_ranges:
		for unit in selected:
			if unit.ranged(): draw_arc(unit.position,266,0,TAU,64,Color(0.8,0.9,0.3,0.5),1)

func _exit_tree() -> void:
	for player in audio_pool:
		player.stop()
		player.stream = null
