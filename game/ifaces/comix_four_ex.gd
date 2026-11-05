# 移植自 S/gameCore/ifaces/comixFour_ex.as（符号类 S/comixFour.as）
# 章节漫画 4：共 2 页（eOne, eTwo），bRight 翻页、bSkip 跳过。
# 进入舞台时写入已看标志 COMIX_WATCHED {comixNumber: 4}，依次翻页，播完或跳过后移出舞台并调用 Main.loadMap。
# 每页翻入用 TweenMax.from(0.5s) 从右上方飞入并旋转（x/y/rotation 取 Utility.rand 三次，求值顺序保持）。
#
# 反编译破损，按 P-code 重建：buttonClicked 的 switch 内 §§goto 只是 break 伪影。P-code lookupswitch：
#   target == bRight -> ++pageCounter; 若 pageCounter >= aPages.length 则 endShow() 否则 loadPage(pageCounter)；
#   target == bSkip  -> endShow()；其他目标无动作。init()/added() 中的 do{...}while(false) 只是语句分组。
# 生命周期：原版 init() 里注册 ADDED_TO_STAGE（首次之后每次 removed 又重新注册）。FlashClip._ready 会按时间轴第 1 帧
# 重置子节点可见性和位置，所以首次 added() 放在 _ready 之后，之后每次重新入树（_enter_tree）再执行；离树（_exit_tree）执行 removed()。
# 偏离：Rasterizer.bgRaster / rasterize 只是位图缓存，不移植。
class_name ComixFourEx
extends FlashClip

const SCENE := "res://scenes/ifaces/comix_four_ex.tscn"
const COMIX_NUMBER := 4

var page_counter: int = 0
var a_pages: Array = []
var a_pages_coords: Array = []
var self_: ComixFourEx  # 原版 private var self

var e_one: FlashClip
var e_two: FlashClip
var e_bg: FlashClip
var b_right: FlashClip
var b_skip: FlashClip

var _init_called: bool = false
var _comic_ready: bool = false
var _attached: bool = false

func _init() -> void:
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "comixFour")
	_construct()

static func create() -> ComixFourEx:
	var n := IfaceUtil.instantiate(SCENE) as ComixFourEx
	n._construct()
	return n

## 符号类构造函数建出的实例字段。
func _construct() -> void:
	e_one = get_node("eOne")
	e_two = get_node("eTwo")
	e_bg = get_node("eBg")
	b_right = get_node("bRight")
	b_skip = get_node("bSkip")

func _ready() -> void:
	super._ready()
	if data == null:
		return
	_comic_ready = true
	if _init_called and not _attached:
		_added()

func _enter_tree() -> void:
	# 首次进入时 _ready 尚未执行（FlashClip 还没建好图层），由 _ready 调用 _added()
	if _comic_ready and _init_called and not _attached:
		_added()

func _exit_tree() -> void:
	if _attached:
		_removed()

func init() -> void:
	b_right.stop()
	b_skip.stop()
	_init_called = true
	self_ = self
	# Rasterizer.rasterize(eOne.getChildAt(0))：位图缓存，无需处理
	# Rasterizer.rasterize(eTwo.getChildAt(0))：位图缓存，无需处理
	a_pages = [e_one, e_two]
	a_pages_coords = []
	for i in a_pages.size():
		var _loc2_: FlashClip = a_pages[i]
		_loc2_.visible = false
		a_pages_coords.append(Vector2(_loc2_.position.x, _loc2_.position.y))

func load_page(param1: int) -> void:
	var _loc2_: FlashClip = a_pages[param1]
	_loc2_.visible = true
	# 对象字面量属性按 x、y、rotation 顺序求值，各取一次 Utility.rand
	var fx: float = 700 + 100 * RWRandom.rand()
	var fy: float = -50 - 50 * RWRandom.rand()
	var fr: float = 20 - 40 * RWRandom.rand()
	RWTween.from(_loc2_, 0.5, {"x": fx, "y": fy, "rotation": fr})
	IfaceUtil.play_sound(SoundLibrary.PAPER_MOVE_NEW, 0, 0.45)

func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var _loc2_: FlashClip = param1.target
	if _loc2_ == b_right:
		page_counter += 1
		if page_counter >= a_pages.size():
			end_show()
		else:
			load_page(page_counter)
	elif _loc2_ == b_skip:
		end_show()

func end_show() -> void:
	if self_.get_parent() != null:
		self_.get_parent().remove_child(self_)
	IfaceUtil.main().load_map()

## 原版 added()（ADDED_TO_STAGE）。
func _added() -> void:
	_attached = true
	StoredData.save_data(StoredData.COMIX_WATCHED, {"comixNumber": COMIX_NUMBER})
	page_counter = 0
	for i in a_pages.size():
		var _loc3_: FlashClip = a_pages[i]
		_loc3_.visible = false
		_loc3_.position = Vector2(a_pages_coords[i].x, a_pages_coords[i].y)
		_loc3_.rotation_degrees = 0
	ButtonClass.add_button_on_frames_rd(b_right, button_clicked)
	ButtonClass.add_button_on_frames_rd(b_skip, button_clicked)
	load_page(0)

## 原版 removed()（REMOVED_FROM_STAGE）。
func _removed() -> void:
	_attached = false
	ButtonClass.remove_button_on_frames(b_right, button_clicked)
	ButtonClass.remove_button_on_frames(b_skip, button_clicked)
