extends Node
## 自动加载 Content：资源索引与启动参数，不含任何游戏逻辑。
## 战斗、关卡、界面和存档都在移植后的原生类里（game/core、game/living、game/ifaces、game/memory 等）。
## 仍使用本节点的地方：BmpFrames 取 symbols/bounds，测试检查 resources 与 isolated_profile。

var symbols: Dictionary  ## 符号类名 -> characterId（data/symbols.json）
var bounds: Dictionary  ## characterId -> 包围盒偏移（data/bounds.json）
var resources: Dictionary = {}  ## characterId -> 资源记录（data/resources.json）
## 测试用：带 --isolated-profile 或以 --script 运行时为真；StoredData 据此不读写 user://。
var isolated_profile := false
## 二次开发调试参数 --ch2-unlock：一代未通关也显示东渡船。
var ch2_debug_unlock := false


func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://" + path))


func _ready() -> void:
	isolated_profile = OS.get_cmdline_user_args().has("--isolated-profile") or OS.get_cmdline_args().has("--script")
	ch2_debug_unlock = OS.get_cmdline_user_args().has("--ch2-unlock") or OS.get_cmdline_args().has("--ch2-unlock")
	symbols = read_json("data/symbols.json")
	bounds = read_json("data/bounds.json")
	for record in read_json("data/resources.json").resources:
		resources[int(record.id)] = record
