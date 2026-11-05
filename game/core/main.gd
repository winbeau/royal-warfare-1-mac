# STUB: 待移植（P3/P5）
# 移植自 S/Main.as；站点 API（Kong、GlobalTracker、sendKongData）不移植。
class_name Main
extends Node2D

const GAME_WIDTH := 700
const GAME_HEIGHT := 600
const DEBUG_MODE := false

static var inst: Main

func _init() -> void:
	inst = self

# --- 由 P2-A2 追加（关卡类用到的成员） ---
func add_tutorial(_n: float) -> void:
	pass


# --- 界面层（IfaceUtil.main()）调用到的 Main 方法：占位，待 Main 移植时实现。签名取自 S/Main.as ---
func stop_music_ingame() -> void:
	pass

func pause_music(_music = null) -> void:
	pass

func unpause_music(_music = null) -> void:
	pass

func play_map_music() -> void:
	pass

func add_unit_hint(_n: int) -> void:
	pass

func load_game(_level: int = -1, _play_music: bool = true) -> void:
	pass

func load_main_menu(_e = null) -> void:
	pass

func load_map() -> void:
	pass

func load_upgrade_panel() -> void:
	pass

func load_more_games(_e = null) -> void:
	pass
