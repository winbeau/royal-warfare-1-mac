extends Node
## Content is data; all game behavior is implemented in native GDScript.
var units: Dictionary
var campaign: Array
var geometry: Dictionary
var symbols: Dictionary
var bounds: Dictionary
var resources: Dictionary = {}
var scene_data: Dictionary
var save_schema: Dictionary
var upgrades: Dictionary
var bonuses: Dictionary
var story: Array
var frame_cache: Dictionary = {}
var profile: Dictionary
var isolated_profile := false
signal profile_changed

func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://" + path))

func _ready() -> void:
	isolated_profile=OS.get_cmdline_user_args().has("--isolated-profile") or OS.get_cmdline_args().has("--script")
	units = read_json("data/units.json").units
	campaign = read_json("data/campaign.json").campaign
	geometry = read_json("data/geometry.json")
	symbols = read_json("data/symbols.json")
	bounds = read_json("data/bounds.json")
	scene_data = read_json("assets/ui/scenes.json").scenes
	save_schema = read_json("data/save_schema.json")
	upgrades = read_json("data/upgrades.json").buttons
	bonuses = read_json("data/bonuses.json")
	story = read_json("data/story.json")
	for record in read_json("data/resources.json").resources:
		resources[int(record.id)] = record
	load_profile()
	unlock_progression()

func frames(symbol: String) -> SpriteFrames:
	var id := int(symbols.get(symbol, -1))
	if id < 0: return null
	if not frame_cache.has(id):
		frame_cache[id] = load("res://assets/library/sprites/%d/frames.tres" % id)
	return frame_cache[id]

func sprite(symbol: String, animated: bool = true) -> AnimatedSprite2D:
	var node := AnimatedSprite2D.new()
	node.sprite_frames = frames(symbol)
	node.centered = false
	var b: Array = bounds.get(str(int(symbols.get(symbol, -1))), [0, 0, 1, 1])
	node.offset = Vector2(float(b[0]), float(b[1]))
	if node.sprite_frames and animated: node.play()
	return node

func load_profile() -> void:
	if isolated_profile:
		reset_profile()
		return
	if FileAccess.file_exists("user://campaign.json"):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://campaign.json"))
		if saved is Dictionary and saved.get("version", 0) == 1:
			profile = saved
	if profile.is_empty(): reset_profile()

func reset_profile() -> void:
	profile = {"version":1, "slots": save_schema.initial_slots.duplicate(true),
		"sound":true, "music":true, "autopause":true, "intro_seen":false}
	save_profile()

func save_profile() -> void:
	if isolated_profile: return
	var file := FileAccess.open("user://campaign.json.tmp", FileAccess.WRITE)
	if file == null:
		push_error("Unable to save campaign: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	DirAccess.rename_absolute("user://campaign.json.tmp", "user://campaign.json")
	profile_changed.emit()

func stars() -> int:
	var gained := total_stars()
	for value in profile.slots[2]: gained -= int(value)
	for value in profile.slots[6]: gained -= int(value)
	return gained

func total_stars() -> int:
	var gained:=0
	for value in profile.slots[0]: gained+=int(value)
	for value in profile.slots[4]: gained+=int(value)
	return gained

func next_mission() -> int:
	for i in range(24):
		if int(profile.slots[0][i]) == 0: return i + 1
	return 24

func unlock_progression() -> void:
	var passed := 0
	for stars in profile.slots[0]:
		if int(stars) > 0: passed += 1
	for pair in [[7,1],[8,3],[9,5],[10,7],[11,9]]:
		if passed >= pair[0]: profile.slots[1][pair[1]] = 1

func ability_level(key: String) -> int:
	var index := int(save_schema.constants.get(key, -1))
	return int(profile.slots[2][index]) if index >= 0 else 0

func scene(id: int) -> Control:
	return load("res://scenes/ui/%d.tscn" % id).instantiate()
