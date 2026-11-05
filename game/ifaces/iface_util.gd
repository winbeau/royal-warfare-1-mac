# 界面类公用的 Godot 适配辅助（原版没有对应类）。
#
# 1. 界面类既可以 `XxxEx.create()` 从 scenes/ifaces/*.tscn 实例化（docs/port-plan.md 第 2 节的做法），
#    也可以 `XxxEx.new()`：核心（LivingObject、GameUniverse）仍按 AS3 的 `new xxx_ex()` 写法调用。
#    后一种情况在 _init 中调用 adopt()，把 scenes/clips/<符号>.tscn 的数据与子节点并入自身，等价于
#    符号类构造函数建出子对象。create() 期间 instantiating 为真，_init 因此跳过 adopt。
# 2. 取 Main 用动态访问：game/core/main.gd 仍是占位，缺方法时只在调用处报错，不影响本目录脚本的编译。
# 3. 声音播放对 Sounds / SoundLibrary 尚未建立的情形（无头测试）静默跳过。
class_name IfaceUtil
extends RefCounted

static var instantiating: bool = false


## 原版 Main.self。
static func main() -> Variant:
	return Main.inst


## 从继承场景创建界面对象（根节点脚本即调用方的类）。
static func instantiate(scene_path: String) -> Node:
	instantiating = true
	var node: Node = (load(scene_path) as PackedScene).instantiate()
	instantiating = false
	return node


## `new xxx_ex()` 的路径：把符号类场景的剪辑数据和子节点移入 node。
static func adopt(node: FlashClip, clip_name: String) -> void:
	var base := (load("res://scenes/clips/%s.tscn" % clip_name) as PackedScene).instantiate() as FlashClip
	node.data = base.data
	node.character_id = base.character_id
	node.total_frames = base.total_frames
	node.mouse_filter = base.mouse_filter
	for c in base.get_children():
		base.remove_child(c)
		_clear_owner_recursive(c)  # 场景实例化时整棵子树的 owner 都是 base，并入新父节点前要递归清掉
		node.add_child(c)
	base.free()


## owner 不清会导致后续 add_child 报 "owner inconsistent"：
## 场景实例化把整个子场景的后代节点 owner 都设成根节点（这里是 base），remove_child/add_child 只搬动了
## 直接子节点，孙辈节点的 owner 仍然指向已经不是其祖先的 base，所以要递归清到整棵子树。
static func _clear_owner_recursive(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_clear_owner_recursive(c)


## flash.events.MouseEvent.target。
static func target_of(e: Variant) -> FlashClip:
	if e is FlashClip:
		return e
	return e.target


static func play_sound(sound_name: String, delay: float = 0.0, volume: float = 1.0, pan: float = 350, type: String = "") -> void:
	if Sounds.inst == null or SoundLibrary.inst == null:
		return
	var stream := SoundLibrary.inst.get_sound(sound_name)
	if type == "":
		Sounds.inst.play(stream, false, delay, volume, pan)
	else:
		Sounds.inst.play(stream, false, delay, volume, pan, type)


## 从当前帧的可见内容估计 DisplayObject.getBounds / width / height（不含旋转）。
## FlashClip.data.rect 是所有帧的并集，不能代表当前帧。
static func clip_bounds(clip: FlashClip) -> Rect2:
	var r := Rect2()
	var has := false
	for layer: Sprite2D in [clip.get("_back"), clip.get("_front")]:
		if layer == null or not layer.visible or layer.texture == null:
			continue
		var tr := Rect2(layer.position, layer.texture.get_size() * layer.scale).abs()
		r = tr if not has else r.merge(tr)
		has = true
	for c in clip.get_children():
		if not (c is Control) or not c.visible:
			continue
		var cr: Rect2
		if c is FlashClip:
			var b := clip_bounds(c)
			if b.size == Vector2.ZERO and b.position == Vector2.ZERO:
				continue
			cr = Rect2(c.position + b.position * c.scale, b.size * c.scale)
		elif c is FlashText:
			cr = Rect2(c.position + c.box.position * c.scale, c.box.size * c.scale)
		else:
			continue
		cr = cr.abs()  # 子节点可能负缩放（Flash 镜像），Rect2.merge 要求两边 size 非负
		r = cr if not has else r.merge(cr)
		has = true
	if not has and clip.data != null and clip.data.rect.size != Vector2.ZERO:
		# 纯"命中形状"符号（没有自己的位图、没有子节点，只有一个非零的声明包围盒，见
		# FlashClip._has_point 同一处注释）：退回符号自己声明的 rect，而不是报一个全零的包围盒。
		return clip.data.rect
	return r


static func clip_width(clip: FlashClip) -> float:
	var w := clip_bounds(clip).size.x
	if w == 0.0 and clip.data != null:
		w = clip.data.rect.size.x  # 当前帧没有可见位图（透明热区）时退回符号包围盒
	return w * absf(clip.scale.x)


## TextField.numLines。
static func num_lines(text: FlashText) -> int:
	var rtl: RichTextLabel = text.get("_rtl")
	if rtl == null:
		return 1
	return maxi(1, rtl.get_line_count())


## Number.toString：整数值不带小数点。
static func num_to_str(v: float) -> String:
	if is_equal_approx(v, floorf(v)) and absf(v) < 1e15:
		return str(int(v))
	return str(v)


## 取 class_name 对应脚本（用于尚未移植、其他代理负责的类，避免本目录脚本因其缺失而无法编译）。
static func global_script(cls: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return load(c["path"])
	return null


## 在节点离开树之前调用 goto_and_stop 会因 FlashClip 尚未建好图层而出错；未就绪时推迟到 ready 之后。
static func goto_and_stop(clip: FlashClip, frame: int) -> void:
	if clip.is_node_ready():
		clip.goto_and_stop(frame)
	else:
		clip.ready.connect(func() -> void: clip.goto_and_stop(frame), CONNECT_ONE_SHOT)


## 对应"对象构造后立刻改子节点属性"：FlashClip 在 _ready 里会按时间轴状态重设命名子节点的可见性、位置和缩放，
## 尚未就绪时先改的值会被覆盖，所以推迟到 ready 之后。
static func when_ready(node: Node, callback: Callable) -> void:
	if node.is_node_ready():
		callback.call()
	else:
		node.ready.connect(callback, CONNECT_ONE_SHOT)
