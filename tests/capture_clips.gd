extends SceneTree
## Renders the new hierarchical clip scenes next to the old flat scenes/ui/<id>.tscn for visual comparison.
## Run (needs a real renderer): Godot --path . --script tests/capture_clips.gd -- <out_dir> <id> [<id>...]
func _initialize() -> void:
	call_deferred("run")

func grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(700, 600)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.25, 0.3)
	bg.size = Vector2(700, 600)
	root.add_child(bg)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clips/index.json")).clips
	for i in range(1, args.size()):
		var id := args[i]
		var old: Control = load("res://scenes/ui/%s.tscn" % id).instantiate()
		root.add_child(old)
		var a := await grab()
		old.queue_free()
		await process_frame
		var neu: Control = load("res://" + index[id].scene).instantiate()
		root.add_child(neu)
		var b := await grab()
		neu.queue_free()
		await process_frame
		a.save_png("%s/%s_old.png" % [out, id])
		b.save_png("%s/%s_new.png" % [out, id])
		var diff := Image.create(700, 600, false, Image.FORMAT_RGBA8)
		var n := 0
		for y in 600:
			for x in 700:
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var d := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
				if d > 0.15:
					n += 1
					diff.set_pixel(x, y, Color(1, 0, 0))
				else:
					diff.set_pixel(x, y, Color(cb.r * 0.4, cb.g * 0.4, cb.b * 0.4))
		diff.save_png("%s/%s_diff.png" % [out, id])
		print("%s: %d differing pixels of 420000" % [id, n])
	quit()
