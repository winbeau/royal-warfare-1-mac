extends SceneTree
var failures: Array=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content:=root.get_node("Content")
	if not content.isolated_profile: quit(2);return
	content.profile.slots[2].fill(3)
	var main: Node2D=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	main.intro_played=true;main.start_mission(2)
	var battle: Node2D=main.world;battle.set_physics_process(false)
	for unit in battle.army: unit.queue_free()
	battle.army.clear()
	var soldier: Node2D=battle.spawn("FR_WARRIOR",true,Vector2(300,300))
	var health: float=soldier.max_hp
	soldier.hp=health/2
	soldier.apply_status("curse",2,0.25)
	check(soldier.max_hp==floorf(health*0.75) and soldier.hp==floorf(soldier.max_hp/2),"Curse reduces maximum and current health proportionally")
	soldier.tick(2.01)
	check(soldier.max_hp==health and soldier.hp==health/2,"Curse expiry restores maximum health proportionally")
	soldier.apply_status("harm_resist",2)
	var before: float=soldier.hp
	soldier.hurt(30)
	check(soldier.hp==before-1,"Protection limits each positive hit to one HP")
	soldier.statuses.clear()
	var healer: Node2D=battle.spawn("FR_HEALER",true,Vector2(300,310),3)
	var ally: Node2D=battle.spawn("FR_ARCHER",true,Vector2(310,300),1)
	soldier.hurt(10000);ally.hurt(10000)
	soldier.tick(3.1);ally.tick(3.1)
	healer.special_timers.specRessurect=200
	battle.specials.update(healer,1.0/30)
	check(not soldier.dead and not ally.dead,"Healer resurrection restores all eligible corpses in range")
	check(battle.lost==0,"Resurrected soldiers no longer count as battle losses")
	var archer: Node2D=battle.spawn("FR_ARCHER",true,Vector2(300,350),3)
	archer.special_timers.specSuppress=200
	var zombie: Node2D=battle.spawn("UNDEAD_ZOMBIE",false,Vector2(320,350),1)
	battle.specials.strike(archer,zombie,1,true)
	check(zombie.statuses.has("suppress") and zombie.statuses.suppress.strength==2.5,"Rank-three suppression applies its original multiplier")
	var crossbow: Node2D=battle.spawn("FR_CROSSBOW",true,Vector2(300,330),3)
	crossbow.special_timers.specCorrupt=200
	battle.specials.strike(crossbow,zombie,1,true)
	check(is_equal_approx(zombie.armor_damage,0.7),"Rank-three armor corruption subtracts 0.7")
	zombie.tick(8.01)
	check(zombie.armor_damage==0,"Armor corruption expires after the original duration")
	main.clear_screen();main.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
