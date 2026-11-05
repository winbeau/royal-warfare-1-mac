extends SceneTree
var failures: Array=[]
var checks:=0
var results: Array=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var content:=root.get_node("Content")
	check(content.isolated_profile,"Run with -- --isolated-profile")
	if not content.isolated_profile: quit(2);return
	var main: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.intro_played=true
	# Exercise every comic and book page, including dynamically revealed enemy statistics.
	for chapter in range(6):
		main.show_comic(chapter)
		var sid: int=main.screen.symbol_id
		for page in range(content.story[chapter].pages.size()): main.next_comic_page()
		check(int(content.profile.slots[7][content.story[chapter].flag])==1,"Comic %d completes"%sid)
	for record in content.units.values():
		if not content.profile.slots[11].has(int(record.id)): content.profile.slots[11].append(int(record.id))
	main.show_help()
	for page in range(62): main.show_help_page(page)
	check(main.screen.labels.t2.text.contains("Vampire King"),"Last encyclopedia spread includes Vampire King")
	main.show_credits()
	# Test event dispatch with waits bypassed and spawn probability fixed to one spawn per tick.
	# This verifies scripting integrity, independently of combat balance or real-time playthroughs.
	var event_total:=0
	for number in range(25):
		content.reset_profile()
		main.start_mission(number)
		var battle: Node2D=main.world
		battle.set_physics_process(false)
		battle.lives=100000
		var expected: int=battle.mission.events.size()
		var dispatched: Dictionary={}
		for event in battle.mission.events:
			for record in event.get("data",{}).get("unit",[]): record.spawnProb=-1
		var steps:=0
		while battle.event_index<expected and steps<12000:
			steps+=1
			if is_instance_valid(battle.dialogue):
				while is_instance_valid(battle.dialogue): battle.show_dialogue()
			for unit in battle.army.duplicate():
				if not unit.original_friendly and not unit.dead: unit.hurt(unit.max_hp*100)
				if unit.dead: unit.death_time=10
			if battle.event_index<expected:
				dispatched[battle.event_index]=true
				battle.event_frames=int(battle.mission.events[battle.event_index].get("time",0))*30
				battle.global_wait=0
			battle.tick(1.0/30)
			# Retired bodies no longer affect the script exercise; remove them to keep it bounded.
			for unit in battle.army.duplicate():
				if unit.escaped:
					battle.army.erase(unit)
					unit.queue_free()
		check(battle.event_index==expected,"All events dispatch in level %d"%number)
		check(dispatched.size()==expected,"All event indices visited in level %d"%number)
		event_total+=dispatched.size()
		results.append({"level":number,"events":dispatched.size(),"simulation_steps":steps})
		main.clear_screen()
		await process_frame
	check(event_total==313,"All 313 events executed")
	# Isolated contracts for bonuses, projectile travel, corpse expiry, resurrection and promotion.
	content.reset_profile()
	main.start_mission(2)
	var battle: Node2D=main.world
	battle.set_physics_process(false)
	battle.mission.events=[{"type":"GLOBAL_WAVE","time":9999}]
	var soldier: Node2D=battle.spawn("FR_WARRIOR",true,Vector2(350,300))
	var hp: float=soldier.max_hp
	content.profile.slots[6][1]=3
	check(soldier.stat("Health")==hp+20,"Exact rank-three HP bonus")
	content.profile.slots[6][1]=0
	var lives: int=battle.lives
	soldier.hurt(10000)
	soldier.tick(9.99)
	check(battle.lives==lives,"Corpse grace period preserves lives")
	soldier.revive()
	check(not soldier.dead and battle.lives==lives,"Resurrection preserves a life")
	soldier.hurt(10000)
	soldier.tick(10.01)
	check(battle.lives==lives-1,"Expired allied corpse deducts one life")
	var archer: Node2D=battle.spawn("FR_ARCHER",true,Vector2(300,350))
	archer.record=archer.record.duplicate(true)
	archer.record.stats.accuracy.one=1
	var enemy: Node2D=battle.spawn("UNDEAD_ZOMBIE",false,Vector2(400,350))
	var enemy_hp: float=enemy.hp
	battle.attack(archer,enemy,true)
	check(enemy.hp==enemy_hp and battle.projectiles.size()>0,"Ranged damage waits for projectile arrival")
	for shot in battle.projectiles: shot.node.position=enemy.position+Vector2(0,-25)
	battle.tick(1.0/30)
	check(enemy.hp<enemy_hp,"Projectile impact deals damage")
	battle.gold=10000
	var trainee: Node2D=battle.spawn("FR_WARRIOR",true,Vector2(350,350),3)
	trainee.experience=100
	battle.select_units([trainee])
	battle.promote_selected(false)
	check(battle.selected[0].kind=="FR_SWORDMASTER","Promotion chooses the Swordmaster branch")
	main.clear_screen()
	main.queue_free()
	await process_frame
	var report:={"checks":checks,"events_executed":event_total,"levels":results,"failures":failures}
	var file:=FileAccess.open("res://build/campaign-flow.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
