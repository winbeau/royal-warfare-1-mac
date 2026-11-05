# 移植自 S/gameCore/ifaces/miniIcons.as
# 血条上的状态小图标：Sprite 里放一个 Bitmap，位图取自 BmpFrames（miniIconsAni）的第 curNumber 帧。
class_name MiniIcons
extends Node2D

# 原版 public static var BMPFrame / cachedUnitData
static var bmp_frame: BmpFrames
static var cached_unit_data: SimpleCache

const cSTUN := 0
const cWEAK := 1
const cBREAKARROW := 2
const cCORRUPT := 3
const cSLOW := 4
const cRESIST := 5
const cPOISON := 6
const cWEAPONBUFF := 7
const cMINDCONTROL := 8
const cCURSE := 9
const cFOCUSSHOOT := 10
const cBLESSBUFF := 11

var sprite_bm: Sprite2D
var self_: MiniIcons  # 原版 private var self
var cur_number: int = 0

func _init() -> void:
	sprite_bm = Sprite2D.new()
	add_child(sprite_bm)
	self_ = self

static func cache(param1: float) -> void:
	cached_unit_data = SimpleCache.new(MiniIcons, int(param1), false)

func return_to_cache() -> void:
	cached_unit_data.set_data(self_)

func draw_data(param1: int) -> void:
	cur_number = param1
	# Main 在装载阶段做 miniIcons.BMPFrame = createBmpFramesFromMC(miniIconsAni)；Main 尚未移植，首次使用时取。
	if bmp_frame == null:
		bmp_frame = BmpFrames.from_symbol("miniIconsAni")
	bmp_frame.apply_frame(sprite_bm, param1)
