# 移植自 S/bmpani/BmpFrames.as（运行时数据结构；位图不在运行时烘焙，复用 Content.frames 的图集与 data/bounds.json 偏移）
class_name BmpFrames
extends RefCounted

const NOTHING := 0
const STOP := 1
const DONE := 2
const ACTION := 3

const COMMANDS_PATH := "res://data/anim_commands.json"

static var _by_id: Dictionary = {}
static var _commands: Dictionary = {}
static var _commands_loaded := false

var id := -1
var frames: SpriteFrames
var animation: StringName = &"default"
## 对应 totalFrames
var num_frames := 0
## 对应 frameCommands（每帧一个码，NOTHING/STOP/DONE/ACTION）
var frame_commands := PackedInt32Array()
## 对应 frameXs/frameYs。现有导出每个符号只有一个包围盒偏移，对所有帧相同。
var offset := Vector2.ZERO

static func _content() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Content")

static func _load_commands() -> void:
	if _commands_loaded:
		return
	_commands_loaded = true
	if not FileAccess.file_exists(COMMANDS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMMANDS_PATH))
	if parsed is Dictionary:
		_commands = parsed

static func from_symbol(class_name_str: String) -> BmpFrames:
	var content := _content()
	var symbol_id := int(content.symbols.get(class_name_str, -1))
	if symbol_id < 0:
		push_error("BmpFrames: unknown symbol %s" % class_name_str)
		return null
	return from_id(symbol_id)

static func from_id(symbol_id: int) -> BmpFrames:
	if _by_id.has(symbol_id):
		return _by_id[symbol_id]
	var content := _content()
	var path := "res://assets/library/sprites/%d/frames.tres" % symbol_id
	if not ResourceLoader.exists(path):
		push_error("BmpFrames: no frames for id %d" % symbol_id)
		return null
	var result := BmpFrames.new()
	result.id = symbol_id
	result.frames = load(path)
	result.num_frames = result.frames.get_frame_count(result.animation)
	var b: Array = content.bounds.get(str(symbol_id), [0, 0, 1, 1])
	result.offset = Vector2(float(b[0]), float(b[1]))
	result.frame_commands.resize(result.num_frames)  # 默认全 0
	_load_commands()
	var record: Variant = _commands.get(str(symbol_id))
	if record is Dictionary:
		var commands: Array = record.get("commands", [])
		for i in mini(commands.size(), result.num_frames):
			result.frame_commands[i] = int(commands[i])
	_by_id[symbol_id] = result
	return result

## 第 i 帧（0 起）纹理。
func get_frame_texture(i: int) -> Texture2D:
	return frames.get_frame_texture(animation, i)

func get_command(i: int) -> int:
	return frame_commands[i]

## 与原版 Bitmap 加 (frameXs[i], frameYs[i]) 偏移的显示等价：centered=false，offset 为包围盒左上角。
func apply_frame(sprite: Sprite2D, i: int) -> void:
	sprite.centered = false
	sprite.texture = frames.get_frame_texture(animation, i)
	sprite.offset = offset
