# 移植自 S/Preloader.as（只保留与画面有关的部分）
# 原版 Preloader 是 SWF 的文档类：先显示 preloaderAsset，等资源下载完后创建 Main 并把它放在自己的最底层。
# 这里 Main 是场景根，Preloader 作为 Main 的最上层子节点。
#
# 不移植：stage.scaleMode / align、GlobalTracker 统计、loaderInfo 字节进度（资源是本地文件，进度直接视为 100%）、
# stageMasker、ePrelPads 的 20 块进度砖（导出的 Symbol_16__f1 里没有逐块子剪辑，砖块的亮起和下沉动画无法逐块还原）。
# 保留：加载文字及其各阶段文案（cacheUpdated）、cacheDone 的文字淡出、removeElementsToShowIntro 的 logo 淡出、
# removeBG 的黑幕、更多游戏链接。
class_name Preloader
extends Node2D

const PRELOADER_ASSET := "res://scenes/clips/preloaderAsset.tscn"

static var inst: Preloader  # 原版 Preloader.self

var prel: FlashClip  # preloaderAsset
var coords: Vector2  # bPlayCoords 的位置：开始按钮放在这里
var _black: ColorRect  # 原版 removeBG 里的 sprite（700x600 黑位图）


func _init() -> void:
	inst = self
	prel = (load(PRELOADER_ASSET) as PackedScene).instantiate() as FlashClip
	add_child(prel)
	prel.get_node("bSound").stop()
	prel.get_node("bSound").visible = false
	prel.get_node("bMusic").stop()
	prel.get_node("bMusic").visible = false
	var b_play_coords: Control = prel.get_node("bPlayCoords")
	b_play_coords.visible = false
	coords = b_play_coords.position
	prel.remove_child(b_play_coords)
	b_play_coords.free()
	RWTween.from(prel.get_node("tLoadingText"), 0.3, {"delay": 0.2, "alpha": 0})
	RWTween.from(prel.get_node("bPrelBar"), 0.2, {"delay": 0.1, "alpha": 0})
	ButtonClass.add_event_listener(prel.get_node("eMaxLogo"), ButtonClass.CLICK, load_more_games)
	var t_text: FlashText = prel.get_node("tLoadingText/tText")
	t_text.auto_size = "center"
	var t_loading: Control = prel.get_node("tLoadingText")
	t_loading.position.y -= 15


func _exit_tree() -> void:
	if inst == self:
		inst = null


## 原版在 ENTER_FRAME 里随下载字节推进；本地资源直接视为已加载。
func loading_finished() -> void:
	(prel.get_node("tLoadingText/tText") as FlashText).html_text = "Loading finished." + "\n" + "Caching resources... "


func remove_bg() -> void:
	RWTween.delayed_call(0.5, remove_prel)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = Vector2(Main.GAME_WIDTH, Main.GAME_HEIGHT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	prel.add_child(_black)
	RWTween.to(_black, 0.5, {"alpha": 1})


func remove_prel() -> void:
	if prel != null and is_instance_valid(prel):
		remove_child(prel)
		prel.queue_free()
	prel = null
	_black = null
	queue_free()


func cache_done() -> void:
	RWTween.to(prel.get_node("tLoadingText"), 0.3, {"alpha": 0})


func cache_updated(param1: int) -> void:
	var t_text: FlashText = prel.get_node("tLoadingText/tText")
	var head := "Loading finished." + "\n"
	if param1 < 10:
		t_text.text = head + "Caching resources... " + "\n" + str(param1) + " %  "
	elif param1 < 25:
		t_text.text = head + "Preparing animations... " + "\n" + str(param1) + " % "
	elif param1 < 45:
		t_text.text = head + "Preparing visual effects... " + "\n" + str(param1) + " % "
	elif param1 < 60:
		t_text.text = head + "Preparing maps... " + "\n" + str(param1) + " % "
	elif param1 < 80:
		t_text.text = head + "Managing special abilities... " + "\n" + str(param1) + " % "
	elif param1 < 85:
		t_text.text = head + "Managing interfaces... " + "\n" + str(param1) + " % "
	elif param1 < 98:
		t_text.text = head + "Preparing sound effects... " + "\n" + str(param1) + " % "
	else:
		t_text.text = head + "Final preparations... " + "\n" + str(param1) + " % "
	# 原版此后每 5% 点亮一块进度砖（moveCachePad）：砖块无独立子剪辑，不移植。


func load_more_games(_e: Variant = null) -> void:
	OS.shell_open("http://maxgames.com")


func remove_elements_to_show_intro() -> void:
	ButtonClass.remove_event_listener(prel.get_node("eMaxLogo"), ButtonClass.CLICK, load_more_games)
	RWTween.to(prel.get_node("eMaxLogo"), 0.5, {"y": "-50", "alpha": 0})
	RWTween.to(prel.get_node("eMainLogo"), 0.5, {"alpha": 0})
	# 原版此处让 20 块进度砖随机延迟下沉 30 像素（Elastic.easeInOut）：见文件头说明，不移植。
