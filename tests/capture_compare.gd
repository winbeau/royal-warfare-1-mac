extends SceneTree
## Renders a clip scene with the documented default-hidden overlay children concealed (same list as
## game/original_scene.gd's _ready conceal set) for apples-to-apples comparison with the old flat scenes/ui/<id>.tscn.
func _initialize() -> void: call_deferred("run")
const CONCEAL := ["eHint", "eNewHint", "eStorageFailure", "eFader", "eFocus", "eNewEnemy", "eSmallHint",
	"eGotUpgrade", "eGamePausedMessage", "eSubDown", "eUnitUnlockedBar", "tPauseMessage", "tChatBox",
	"eBg", "eAchievement", "eAchievementFinal", "tHintText"]
func grab() -> Image:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	root.size = Vector2i(700, 600)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clips/index.json")).clips
	for i in range(1, args.size()):
		var id := args[i]
		var neu: Control = load("res://" + index[id].scene).instantiate()
		root.add_child(neu)
		for name in CONCEAL:
			var c := neu.get_node_or_null(NodePath(name))
			if c: c.visible = false
		var img := await grab()
		img.save_png("%s/%s_new_clean.png" % [out, id])
		neu.queue_free()
		await process_frame
	quit()
