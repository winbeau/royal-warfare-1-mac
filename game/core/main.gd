# STUB: 待移植（P3/P5）
# 移植自 S/Main.as；站点 API（Kong、GlobalTracker、sendKongData）不移植。
class_name Main
extends Node2D

const GAME_WIDTH := 700
const GAME_HEIGHT := 600
const DEBUG_MODE := false

static var inst: Main

# --- 由 P2-A2 追加（关卡类用到的成员） ---
func add_tutorial(_n: float) -> void:
	pass

