extends SceneTree
var checks := 0
var failures: Array = []
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	check(content.units.size()==46,"All 46 units must be available")
	check(content.campaign.size()==25,"Intro and all 24 campaign levels must be available")
	var events := 0
	for level in content.campaign:
		events += level.events.size()
		check(content.geometry.has(level.background),"Geometry "+str(level.background))
		check(ResourceLoader.exists("res://assets/backgrounds/%s.png"%level.background),"Background "+str(level.background))
	check(events==313,"All original events are present")
	for id in content.resources:
		var record: Dictionary = content.resources[id]
		for path in record.paths:
			check(FileAccess.file_exists("res://"+path) or ResourceLoader.exists("res://"+path),"Missing resource "+path)
		if record.type=="sprite":
			var frames: SpriteFrames = load("res://"+record.resource)
			check(frames!=null and frames.get_frame_count("default")==int(record.frame_count),"Missing frames %d"%id)
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.intro_played=true
	main.show_map(false)
	main.show_mission(24)
	check(main.popup.labels.tMissionName.text=="Undead King's chambers","Final mission caption")
	main.show_upgrades()
	main.show_achievements()
	main.show_achievements_page(3)
	main.show_help()
	main.show_help_page(20)
	for i in range(1,25):
		main.start_mission(i)
		var battle: Node2D=main.world
		check(battle.army.size()==content.campaign[i].initial_units.size(),"Initial roster level %d"%i)
		check(battle.gold==float(content.campaign[i].set_money_calls[-1]),"Initial gold level %d"%i)
		battle.tick(1.0/30)
	main.start_mission(1)
	var battle: Node2D=main.world
	var warrior: Node2D=battle.spawn("FR_WARRIOR",true,Vector2(320,350),1)
	var zombie: Node2D=battle.spawn("UNDEAD_ZOMBIE",false,Vector2(340,350),1)
	var initial_hp: float=zombie.hp
	battle.attack(warrior,zombie,false)
	check(zombie.hp<initial_hp,"Melee attack damages the enemy")
	warrior.apply_status("stun",2)
	warrior.move_to(Vector2(400,350))
	var point: Vector2=warrior.position
	warrior.tick(1.0/30)
	check(warrior.position==point,"Stun prevents movement")
	warrior.statuses.clear()
	warrior.hp=1
	warrior.heal(5)
	check(warrior.hp==6,"Healing restores HP")
	battle.gold=10000
	check(battle.recruit("FR_WARRIOR"),"Recruit during a mission")
	check(battle.hired==1,"Recruit updates mission statistics")
	main.clear_screen()
	main.queue_free()
	await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
