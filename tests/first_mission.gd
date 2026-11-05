extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var content:=root.get_node("Content")
	if not content.isolated_profile: quit(2);return
	seed(137)
	var main: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.intro_played=true
	main.start_mission(1)
	var battle: Node2D=main.world
	battle.set_physics_process(false)
	var ticks:=0
	while not battle.finished and ticks<27000:
		ticks+=1
		while is_instance_valid(battle.dialogue): battle.show_dialogue()
		if is_instance_valid(battle.tutorial): battle.tutorial.queue_free();battle.tutorial=null
		battle.paused=false
		if ticks%90==0:
			battle.recruit("FR_WARRIOR")
			for unit in battle.army:
				if unit.friendly and not unit.npc and not unit.dead and unit.position.x<150:
					unit.move_to(Vector2(290,340)+Vector2(randf_range(-45,45),randf_range(-50,50)),true)
		if battle.global_ready: battle.next_event()
		battle.tick(1.0/30)
		if ticks%900==0: await process_frame
	var report:={"test":"first_mission_with_simple_recruitment_bot","ticks":ticks,"elapsed":battle.elapsed,"finished":battle.finished,"lives":battle.lives,"events":battle.event_index,"kills":battle.kills,"hired":battle.hired,"lost":battle.lost,"stars":content.profile.slots[0][0]}
	var file:=FileAccess.open("res://build/first-mission.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report))
	main.clear_screen();main.queue_free();await process_frame
	quit(0 if bool(report.finished) else 1)
