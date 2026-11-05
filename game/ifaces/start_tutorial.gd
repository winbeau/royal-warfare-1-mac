# 移植自 S/gameCore/ifaces/startTutorial.as
# 战内教学幻灯片：12 组内容（eContentWarr1 ... eContentSpies）里选一组，左右翻页、关闭。
# 进入舞台时 GameUniverse.pause()，关闭时 unpause() 并淡出后从父节点移除。
class_name StartTutorial
extends FlashClip

const SCENE := "res://scenes/ifaces/start_tutorial.tscn"

static var inst: StartTutorial  # 原版 private static var self

var cur_frame: int = 0
var a_contents: Array = []
var e_content: FlashClip
var s: SoundLibrary
var _listening: bool = false

var b_left: FlashClip
var b_right: FlashClip
var b_closebtn: FlashClip
var t_pics_counter: FlashText

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "startTutorialMC")
	_construct()

static func create() -> StartTutorial:
	var n := IfaceUtil.instantiate(SCENE) as StartTutorial
	n._construct()
	return n

func _construct() -> void:
	b_left = get_node("bLeft")
	b_right = get_node("bRight")
	b_closebtn = get_node("bClosebtn")
	t_pics_counter = get_node("tPicsCounter")
	a_contents = []
	for n in ["eContentWarr1", "eContentWarr2", "eContentGroupsManagement", "eContentHireHint", "eContentArchers",
			"eContent_upgrade", "eContent_formation", "eContentPriests", "eContentMages", "eContent_strike",
			"eContentThieves", "eContentSpies"]:
		a_contents.append(get_node(n))
	for c: FlashClip in a_contents:
		c.stop()
	e_content = a_contents[0]
	b_left.stop()
	b_right.stop()
	inst = self
	# Rasterizer.rasterize(eBg)：无需处理

func init(param1: float) -> void:
	# 子节点的可见性在 FlashClip._ready 里按时间轴重设；未就绪时推迟。
	IfaceUtil.when_ready(self, func() -> void:
		for c: FlashClip in a_contents:
			c.visible = false
		e_content = a_contents[int(param1) - 1]
		e_content.visible = true
		cur_frame = 1
		show_slide())

# 原版 added(Event.ADDED_TO_STAGE)：removed 里重新挂监听，所以每次进入舞台都会执行。
func _enter_tree() -> void:
	_listening = true
	modulate.a = 1.0
	RWTween.from(inst, 0.4, {"alpha": 0})
	ButtonClass.add_button_scale(b_left, clicked)
	ButtonClass.add_button_scale(b_right, clicked)
	ButtonClass.add_button_scale(b_closebtn, clicked)
	s = SoundLibrary.inst
	GameUniverse.inst.pause()

func clicked(param1: ButtonClass.ButtonEvent) -> void:
	var _loc2_: FlashClip = param1.target
	match _loc2_:
		b_left:
			IfaceUtil.play_sound(SoundLibrary.IFACE_PAPER_SMALL, 0, 0.3)
			cur_frame -= 1
			show_slide()
		b_right:
			IfaceUtil.play_sound(SoundLibrary.IFACE_PAPER_SMALL, 0, 0.3)
			cur_frame += 1
			show_slide()
		b_closebtn:
			close()

func close() -> void:
	GameUniverse.inst.unpause()
	RWTween.to(inst, 0.3, {"alpha": 0, "onComplete": remover})

func remover() -> void:
	inst.get_parent().remove_child(inst)

# 原版 removed(Event.REMOVED_FROM_STAGE)
func _exit_tree() -> void:
	if not _listening:
		return
	_listening = false
	ButtonClass.remove_button_scale(b_left, clicked)
	ButtonClass.remove_button_scale(b_right, clicked)
	ButtonClass.remove_button_scale(b_closebtn, clicked)
	# Main.self.stage.focus = Main.self.stage：键盘焦点，Godot 无对应

func show_slide() -> void:
	if cur_frame <= 1:
		cur_frame = 1
		b_left.modulate.a = 0.2
		b_left.mouse_enabled = false
	else:
		b_left.modulate.a = 1.0
		b_left.mouse_enabled = true
	if cur_frame >= e_content.total_frames:
		cur_frame = e_content.total_frames
		b_right.modulate.a = 0.2
		b_right.mouse_enabled = false
	else:
		b_right.modulate.a = 1.0
		b_right.mouse_enabled = true
	e_content.goto_and_stop(cur_frame)
	RWTween.from_to(e_content, 0.4, {"colorMatrixFilter": {"brightness": 1.5}}, {"colorMatrixFilter": {"brightness": 1}})
	t_pics_counter.text = "%d / %d" % [cur_frame, e_content.total_frames]
