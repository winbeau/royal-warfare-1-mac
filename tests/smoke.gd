extends SceneTree
# 资源完整性检查（不依赖任何游戏逻辑）：data/resources.json 的每个记录都有对应文件，精灵帧数一致，
# 每关背景图与障碍几何齐全，主场景指向移植后的 Main。必须带 -- --isolated-profile。
var checks := 0
var failures: Array = []
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	check(content.isolated_profile, "smoke must run with --isolated-profile")
	check(content.symbols.size() > 0 and content.bounds.size() > 0, "symbols and bounds are loaded")
	var campaign: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")).campaign
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geometry.json"))
	check(campaign.size() == 25, "Intro and all 24 campaign levels must be available")
	var events := 0
	for level in campaign:
		events += level.events.size()
		check(geometry.has(level.background), "Geometry " + str(level.background))
		check(ResourceLoader.exists("res://assets/backgrounds/%s.png" % level.background), "Background " + str(level.background))
	check(events == 313, "All original events are present")
	for id in content.resources:
		var record: Dictionary = content.resources[id]
		for path in record.paths:
			check(FileAccess.file_exists("res://" + path) or ResourceLoader.exists("res://" + path), "Missing resource " + path)
		if record.type == "sprite":
			var frames: SpriteFrames = load("res://" + record.resource)
			check(frames != null and frames.get_frame_count("default") == int(record.frame_count), "Missing frames %d" % id)
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "main scene loads")
	if scene != null:
		var main := scene.instantiate()
		check(main is Main, "main scene root is the ported Main")
		main.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
