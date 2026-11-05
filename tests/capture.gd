extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	root.size=Vector2i(700,600)
	var main: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.intro_played=true
	await snap("menu-native")
	main.show_map(false)
	await snap("map-native")
	main.show_upgrades()
	await snap("upgrades-native")
	main.start_mission(1)
	main.world.paused=true
	await snap("battle-native")
	main.world.select_units([main.world.army[0]])
	main.world.update_hud()
	await snap("selected-native")
	main.world.show_recruits(0)
	await snap("recruit-native")
	main.show_comic(0)
	await snap("comic-native")
	main.comic=-1
	main.show_help()
	await snap("book-native")
	main.show_help_page(49)
	await snap("enemy-book-native")
	main.show_mission(1)
	await snap("mission-native")
	main.clear_screen()
	main.queue_free()
	await process_frame
	quit()
