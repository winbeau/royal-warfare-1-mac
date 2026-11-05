class_name RoyalUnit
extends Node2D
var battle: Node2D
var kind := ""
var record: Dictionary
var friendly := false
var original_friendly := false
var level := 1
var hp := 1.0
var max_hp := 1.0
var experience := 0.0
var selected := false
var dead := false
var escaped := false
var all_abilities := false
var hold := false
var attack_move := false
var npc := false
var target: RoyalUnit
var destination := Vector2.ZERO
var moving := false
var route: Array = []
var route_index := 0
var cooldown := 0.0
var death_time := 0.0
var animation_time := 0.0
var state := ""
var sprite: AnimatedSprite2D
var statuses: Dictionary = {}
var special_timers: Dictionary = {}
var armor_damage := 0.0
var king_rebirth := 0
var damage_flash := 0.0
var navigation := PackedVector2Array()
var path_goal := Vector2(INF,INF)
var path_retry := 0.0
var support_called := false
var successful_hits := 0

func setup(owner_battle: Node2D, unit_kind: String, friend: bool, rank: int) -> void:
	battle = owner_battle
	kind = unit_kind
	record = Content.units[kind]
	friendly = friend
	original_friendly = friend
	npc = kind.begins_with("NPC_")
	level = clampi(rank, 1, 3)
	max_hp = stat("Health", 1)
	hp = max_hp
	sprite = AnimatedSprite2D.new()
	sprite.centered = false
	add_child(sprite)
	for spec in record.specials: special_timers[spec] = 0.0
	play_state("Stay")

func stat(key: String, fallback: float = 0.0) -> float:
	var value: Variant = record.stats.get(key, fallback)
	if value is Dictionary:
		value = value.get(["one", "two", "three"][level - 1], fallback)
	var result := float(value) if str(value).is_valid_float() or value is float or value is int else fallback
	var fields := {"Health":"bonusHP","damageMelee":"bonusDamage","damageRanged":"bonusDamage","Armor":"bonusArmor","Resist":"bonusResist","armorPierceMelee":"bonusArmorPierce","armorPierceRanged":"bonusArmorPierce","magicPierce":"bonusMagicPierce","walkSpeed":"bonusMoveSpeed"}
	if original_friendly and Content.bonuses.has(kind) and fields.has(key):
		var bonus: Dictionary = Content.bonuses[kind]
		for category in ["attack","defense"]:
			var index := int(bonus[category + "_index"])
			var rank := clampi(int(Content.profile.slots[6][index]),0,3)
			result += float(bonus[category][rank].get(fields[key],0))
	return result

func play_state(next: String) -> void:
	if next == state: return
	var symbol := str(record.animations.get(next, record.animations.get("Stay", "")))
	if symbol.is_empty(): return
	state = next
	sprite.sprite_frames = Content.frames(symbol)
	var b: Array = Content.bounds.get(str(int(Content.symbols.get(symbol, -1))), [0,0,1,1])
	sprite.offset = Vector2(float(b[0]), float(b[1]))
	sprite.play()
	animation_time = 0

func move_to(point: Vector2, attacking: bool = false) -> void:
	destination = point
	moving = true
	attack_move = attacking
	hold = false
	target = null
	route.clear()

func follow_route(points: Array) -> void:
	route = points.duplicate(true)
	route_index = 0
	if not route.is_empty():
		destination = Vector2(float(route[0][0]), float(route[0][1]))
		moving = true

func apply_status(key: String, duration: float, strength: float = 1.0, source: RoyalUnit = null) -> void:
	if key == "stun" and statuses.has("harm_resist"): return
	statuses[key] = {"time": duration, "strength": strength, "source": source}

func tick(delta: float) -> void:
	if escaped: return
	animation_time += delta
	damage_flash = maxf(0, damage_flash - delta)
	path_retry = maxf(0,path_retry-delta)
	for key in special_timers: special_timers[key] += delta
	for key in statuses.keys():
		statuses[key].time -= delta
		if key in ["poison","ice"] and not dead: hurt(float(statuses[key].strength) * delta, statuses[key].source, true)
		if float(statuses[key].time) <= 0:
			statuses.erase(key)
			if key == "betray": friendly = original_friendly
			if key == "corrupt": armor_damage = 0
	if dead:
		death_time += delta
		if death_time >= 10 and not escaped:
			escaped = true
			visible = false
			battle.corpse_expired(self)
		if sprite.sprite_frames and animation_time >= sprite.sprite_frames.get_frame_count("default") / 30.0: sprite.stop()
		queue_redraw()
		return
	if statuses.has("stun") or statuses.has("ice"):
		sprite.pause()
		queue_redraw()
		return
	if not sprite.is_playing(): sprite.play()
	sprite.speed_scale = battle.speed
	cooldown = maxf(0, cooldown - delta)
	battle.specials.update(self, delta)
	if dead: return
	if npc:
		walk(delta)
		return
	if is_instance_valid(target) and (target.dead or target.escaped or target.friendly == friendly): target = null
	var healer: bool = record.base == "priestClass"
	if healer:
		target = battle.closest(self, true, 266.0, true)
	elif not moving or attack_move or not friendly:
		if not is_instance_valid(target): target = battle.closest(self, false, 266.0 if ranged() else 85.0)
	if is_instance_valid(target):
		var distance := position.distance_to(target.position)
		var attack_range := 250.0 if ranged() or healer else 28.0
		if distance <= attack_range:
			if cooldown <= 0:
				face(target.position)
				if healer:
					play_state("Cast")
					target.heal(stat("damageRanged", 3))
					battle.specials.support(self, target)
				else:
					play_state("Ranged" if ranged() else "Attack")
					battle.attack(self, target, ranged())
				cooldown = maxf(0.15, stat("attackSpeedRanged" if ranged() or healer else "attackSpeedMelee", 40) / 30.0)
				if statuses.has("weakness"): cooldown *= 1.5
				if statuses.has("suppress"): cooldown *= float(statuses.suppress.strength)
				if statuses.has("bless"): cooldown *= 1.0-float(statuses.bless.strength)
			return
		elif not hold and (not friendly or not moving or attack_move):
			step_toward(target.position, delta)
			return
	if moving: walk(delta)
	elif animation_time > 0.6: play_state("Stay")
	queue_redraw()

func ranged() -> bool:
	return record.base in ["rangedFighter", "mageClass"] or stat("damageRanged") > 0 and stat("damageRanged") > stat("damageMelee")

func magic() -> bool:
	return record.base in ["mageClass", "priestClass"]

func face(point: Vector2) -> void:
	if absf(point.x - position.x) > 1: sprite.scale.x = 1 if point.x > position.x else -1

func step_toward(point: Vector2, delta: float) -> void:
	if navigation.size()>0 and point.distance_to(path_goal)>25: navigation.clear()
	while navigation.size()>0 and position.distance_to(navigation[0])<8: navigation.remove_at(0)
	var goal := navigation[0] if navigation.size()>0 else point
	face(goal)
	var speed := stat("walkSpeed", 1) * 30.0
	if statuses.has("slow"): speed *= 0.5
	if statuses.has("flee"): speed *= 2
	var direction := position.direction_to(goal)
	var next := position + direction * minf(speed * delta, position.distance_to(goal))
	if not battle.is_blocked(next) or not Rect2(0,0,700,600).has_point(position):
		position = next
	else:
		if path_retry<=0 and navigation.is_empty():
			navigation=battle.find_path(position,point)
			path_goal=point
			path_retry=1.0
		for angle in [0.7, -0.7, 1.4, -1.4]:
			var candidate := position + direction.rotated(angle) * speed * delta
			if not battle.is_blocked(candidate): position = candidate; break
	play_state("Walk")
	queue_redraw()

func walk(delta: float) -> void:
	if position.distance_to(destination) <= 4:
		if route_index + 1 < route.size():
			route_index += 1
			destination = Vector2(float(route[route_index][0]), float(route[route_index][1]))
		else:
			moving = false
			if not friendly or npc:
				escaped = true
				visible = false
				battle.unit_escaped(self)
			return
	step_toward(destination, delta)

func hurt(amount: float, attacker: RoyalUnit = null, direct: bool = false) -> void:
	if dead or escaped: return
	if statuses.has("harm_resist"): amount *= 0.2
	if statuses.has("weak_spot"): amount *= float(statuses.weak_spot.strength)
	amount = maxf(0, amount)
	hp -= amount
	if kind=="UNDEAD_VAMPIRE_KING" and hp<650 and not support_called:
		support_called=true
		battle.king_support()
	damage_flash = 0.1
	if attacker and not is_instance_valid(target) and not moving: target = attacker
	if friendly: battle.damage_received += amount
	else: battle.damage_dealt += amount
	if hp <= 0:
		dead = true
		death_time = 0
		selected = false
		play_state("Dead")
		battle.unit_died(self, attacker)
	queue_redraw()

func heal(amount: float) -> void:
	if dead: return
	var restored := minf(amount, max_hp - hp)
	hp += restored
	if friendly: battle.healed += restored
	queue_redraw()

func revive() -> void:
	if dead and original_friendly and not npc: battle.lost=maxi(0,battle.lost-1)
	dead = false
	escaped = false
	visible = true
	death_time = 0
	hp = max_hp
	statuses.clear()
	state = ""
	play_state("Stay")

func gain_experience(amount: float) -> void:
	if not friendly or dead: return
	experience += amount
	if level < 3 and experience >= stat("Experience", 20):
		experience -= stat("Experience", 20)
		level += 1
		if level==3: battle.achievements.add("a48_getElite")
		max_hp = stat("Health", max_hp)
		hp = max_hp
	queue_redraw()

func _draw() -> void:
	if dead: return
	if selected: draw_selection_ellipse(Vector2(0,-3), Vector2(17,6), Color(0.65,0.9,0.25,0.8))
	if selected or hp < max_hp:
		draw_rect(Rect2(-15,-60,30,3),Color(0.12,0.12,0.1))
		draw_rect(Rect2(-15,-60,30*maxf(0,hp/max_hp),3),Color(0.5,0.85,0.2) if friendly else Color(0.9,0.15,0.1))
	if statuses.has("ice"): draw_circle(Vector2(0,-25),20,Color(0.3,0.7,1,0.25))
	if statuses.has("poison"): draw_circle(Vector2(0,-40),4,Color(0.3,0.85,0.1))
	if statuses.has("hide"): modulate.a = 0.35
	else: modulate.a = 1
	if damage_flash > 0: sprite.modulate = Color(1.8,1.1,1.1)
	else: sprite.modulate = Color.WHITE

func draw_selection_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(33): points.append(center + Vector2(cos(i*TAU/32.0)*radius.x,sin(i*TAU/32.0)*radius.y))
	draw_polyline(points,color,1.5,true)
