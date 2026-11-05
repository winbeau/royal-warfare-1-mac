# 移植自 S/gameCore/projectiles/iceVisual.as
class_name IceVisual
extends VisualsTemplate

static var bmp_data: BmpFrames
static var _cached_data: SimpleCache
# 原版在 Main.loadResources 中预建；此处首次访问时懒加载（等效）。
static var cached_data: SimpleCache:
	get:
		if _cached_data == null:
			init_resources()
		return _cached_data
	set(v):
		_cached_data = v

var freeze_counter: int = 1000
var enemy: LivingObject
var released: bool

## 对应 Main.as loadResources：iceVisual.bmpData = BmpFrames.createBmpFramesFromMC(iceAni); iceVisual.cache();
static func init_resources() -> void:
	bmp_data = BmpFrames.from_symbol("iceAni")
	cache()

static func cache(param1: int = 15) -> void:
	_cached_data = SimpleCache.new(IceVisual, param1, true)

func on_play_head_end() -> void:
	cached_data.set_data(_instance)
	super.on_play_head_end()

func on_play_head_done() -> void:
	play_head_stance = STOPPED

func release_ice() -> void:
	if released == false:
		released = true
		var _loc1_: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(_loc1_.get_sound(SoundLibrary.ICE_BREAK), false, 0, 0.45, position.x)
		play_head_stance = PLAYING

func init() -> void:
	bmp_list = bmp_data
	super.init()

func update() -> void:
	freeze_counter -= 1
	if freeze_counter <= 0:
		release_ice()
	elif enemy == null:
		# 原版 enemy.curHealth 在 enemy 为 null 时抛 TypeError #1009：异常穿透 update -> updateEffects -> globalUpdate，
		# super.update()（帧推进）不执行，本帧监听中止（见 game/rw/as3.gd；updateEffects 在循环里检查标志）。
		AS3.throw_error("TypeError #1009: IceVisual.update enemy is null")
		return
	elif enemy.cur_health <= 0:
		if cur_frame < 40:
			cur_frame = 40
		release_ice()
	super.update()

func external_remover() -> void:
	on_play_head_end()

func set_counter(param1: int, param2: LivingObject) -> void:
	enemy = param2
	freeze_counter = param1
	var _loc3_: SoundLibrary = SoundLibrary.inst
	Sounds.inst.play(_loc3_.get_sound(SoundLibrary.ICE_MAKE), false, 0, 0.5, position.x)
	released = false
