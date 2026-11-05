# 移植自 S/gameCore/ifaces/healthBar_ex.as
# 单位头顶血条：top 为血量条（scaleX = 当前/最大，0.4 秒缓动），eLevelup 为等级星标，tGroup 为编队号，
# cont 放最多 3 个状态小图标（MiniIcons）。构造时 alpha=0，之后每帧由 update() 按鼠标距离淡入淡出。
class_name HealthBarEx
extends FlashClip

const SCENE := "res://scenes/ifaces/health_bar_ex.tscn"

var friendly: bool = false

var health: int = 0
var top_max_width: float = 0.0
var last_cur_health: int = 0
var cur_level: int = -1
var a_current_icons: Array = []  # 原版在 resetIcons 前为 null；这里初始为空数组（原版未先 resetIcons 会抛错）
var show_stars: bool = false

var top: FlashClip
var e_levelup: FlashClip
var t_group: FlashText
var cont: FlashClip

## 测试钩子：非 null 时代替 mouseX/mouseY（本地坐标）。
var mouse_override: Variant = null

func _init(param1: int = 0) -> void:
	health = param1
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "healthBar")
	_construct(param1)

static func create(param1: int) -> HealthBarEx:
	var n := IfaceUtil.instantiate(SCENE) as HealthBarEx
	n._construct(param1)
	return n

func _construct(param1: int) -> void:
	top = get_node("top")
	e_levelup = get_node("eLevelup")
	t_group = get_node("tGroup")
	cont = get_node("cont")
	cur_level = -1
	health = param1
	top_max_width = top.data.rect.size.x * top.scale.x if top.data != null else 0.0
	last_cur_health = param1
	IfaceUtil.goto_and_stop(e_levelup, 1)
	modulate.a = 0.0
	mouse_enabled = false
	mouse_children = false

func _local_mouse() -> Vector2:
	if mouse_override != null:
		return mouse_override
	return get_local_mouse_position() if is_inside_tree() else Vector2.ZERO

func update(param1: int, param2: int, param3: bool = false, param4: bool = false) -> void:
	var _loc5_: float
	show_stars = param3
	if cur_level != param2:
		cur_level = param2
		IfaceUtil.goto_and_stop(e_levelup, cur_level)
	if param3 == true:
		IfaceUtil.goto_and_stop(e_levelup, cur_level + 1)
	if param1 > 0:
		if param4 == true:
			modulate.a = 1.0
		else:
			# 原版如此：非友军用本条自身的 (x, y)（父坐标）与本地鼠标比距离；友军用 (0, 0)
			if not friendly:
				_loc5_ = position.distance_to(_local_mouse())
			else:
				_loc5_ = Vector2.ZERO.distance_to(_local_mouse())
			if _loc5_ <= 200:
				# Flash 的 alpha 夹在 0..1
				modulate.a = clampf((200 - _loc5_) / 100.0, 0.0, 1.0)
			elif modulate.a != 0:
				modulate.a = 0.0
	if last_cur_health != param1:
		last_cur_health = param1
		RWTween.to(top, 0.4, {"scaleX": float(last_cur_health) / health})
		if param1 == 0:
			RWTween.to(self, 0.2, {"alpha": 0})

func reset_health(param1: int, param2: int) -> void:
	health = param2
	last_cur_health = param1
	RWTween.kill_tweens_of(top)
	IfaceUtil.when_ready(self, func() -> void: top.scale.x = float(last_cur_health) / health)

func reset_level_bar() -> void:
	cur_level = -1
	IfaceUtil.goto_and_stop(e_levelup, 1)

func set_group(param1: float) -> void:
	IfaceUtil.when_ready(self, func() -> void:
		if param1 < 0:
			t_group.visible = false
		else:
			t_group.visible = true
			t_group.text = IfaceUtil.num_to_str(param1))

## cont 里除 FlashClip 自带的两层位图外，只有 MiniIcons 是原版意义上的子对象。
func _icons() -> Array:
	var out: Array = []
	for c in cont.get_children():
		if c is MiniIcons:
			out.append(c)
	return out

func remove_icon(param1: int) -> void:
	var _loc3_: MiniIcons
	var _loc4_: int
	var _loc2_: int = a_current_icons.find(param1)
	if _loc2_ < 0:
		return
	a_current_icons.remove_at(_loc2_)
	var icons := _icons()
	while icons.size() > 0:
		_loc3_ = icons.pop_front()
		cont.remove_child(_loc3_)
		_loc3_.return_to_cache()
	_loc4_ = 0
	while _loc4_ < a_current_icons.size():
		param1 = int(a_current_icons[_loc4_])
		add_icon(param1, true)
		_loc4_ += 1

func add_icon(param1: int, param2: bool = false) -> void:
	var _loc3_: int = a_current_icons.find(param1)
	if _loc3_ >= 0:
		if param2 == false:
			return
	else:
		a_current_icons.append(param1)
		if _icons().size() >= 3:
			return
	if MiniIcons.cached_unit_data == null:
		MiniIcons.cache(150)  # 原版由 Main 在装载阶段调用 miniIcons.cache(150)
	var _loc4_: SimpleCache = MiniIcons.cached_unit_data
	var _loc5_: MiniIcons = _loc4_.get_data() as MiniIcons
	match _icons().size():
		0:
			_loc5_.position = Vector2(0, -10)
		1:
			_loc5_.position = Vector2(-14, -10)
		2:
			_loc5_.position = Vector2(14, -10)
	cont.add_child(_loc5_)
	_loc5_.draw_data(param1)

func reset_icons() -> void:
	a_current_icons = []
	for c in _icons():
		cont.remove_child(c)
		(c as MiniIcons).return_to_cache()
