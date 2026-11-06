## 保护设施目标：静态设施，有血量和血条，敌人会攻击它，玩家不能选中，不画精灵（画在底图里）。
## 复用 NpcMan（NPC_MAN 已在 friendly_kinds 里，会被敌人搜索算法当作有效目标），只是隐藏其位图、
## 关掉选中（ch2_uncontrollable=true，是 GameUniverse 选中入口统一跳过的开关），并强制显示血条。
## 命中热区由 JSON 的 rect 给出（仅用于定位：设施是一个点，敌人按距离索敌，不做真正的矩形碰撞）。
## JSON 字段：{id, type:"protect", optional, rect:[x,y,w,h], health}
class_name Ch2ProtectObjective
extends Ch2ObjectiveBase

var facility: LivingObject
var _max_health: int = 1


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	super(data, p_director)
	var rect: Array = data.get("rect", [0, 0, 0, 0])
	var center := Vector2(float(rect[0]) + float(rect[2]) / 2.0, float(rect[1]) + float(rect[3]) / 2.0)
	_max_health = int(data.get("health", 500))
	var gu: GameUniverse = director.gu
	facility = gu.add_soldier(LivingObject.NPC_MAN, null, 1, true)
	facility.ch2_uncontrollable = true
	facility.set_external_position(center)
	facility.sprite.visible = false
	facility.ui_health_bar.visible = true
	facility.health = _max_health  # health 的 setter 同时把 cur_health 置满（见 LivingObject）
	# HealthBarEx 自己另记一份 health 作血条缩放的分母（构造时按 NPC_MAN 创建瞬间的占位值 0 初始化，
	# 见 LivingObject.init() 的 HealthBarEx.new(health)）；上面那行只改了单位自己的 health，不会同步
	# 过去。不补这一步，血条的 scaleX = cur_health / 0 = inf，画出来就是贯穿全图的一条长色块
	# （用户 2026-11-06 容器截图发现：第 11 关补给棚附近横跨约 500px 的绿色长条，即此处）。
	facility.ui_health_bar.reset_health(facility.cur_health, facility.health)


func update() -> void:
	if state != STATE_ACTIVE:
		return
	if not is_instance_valid(facility) or facility.cur_health <= 0:
		state = STATE_FAILED


func hud_text() -> String:
	var n: int = maxi(0, facility.cur_health) if is_instance_valid(facility) else 0
	return Ch2Text.objective(director.level_number, id).format({"n": n, "min": _max_health, "total": _max_health})


func is_warning() -> bool:
	return is_instance_valid(facility) and float(facility.cur_health) / float(maxi(1, _max_health)) < 0.3
