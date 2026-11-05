# 移植自 S/gameCore/specials/arrowSwarm.as
class_name ArrowSwarm
extends RefCounted

static var inst: ArrowSwarm = null  # 原版 arrowSwarm.self

var swarm_cont: Dictionary = {}  # private，原版为匿名 Object
var got_swarm: bool = false  # private
var shoot_point: Vector2 = Vector2.ZERO  # private
var ar: ArrowEx = null  # private
var goto_point: Vector2 = Vector2.ZERO  # private
var gameuni: GameUniverse = null  # private
var all_units: Array = []  # private，Vector.<livingObject>
var i: int = 0  # private
var unit: LivingObject = null  # private
var calculated_armor: float = 0.0  # private
var res_damage: int = 0  # private
var s: SoundLibrary = null  # private
var counter: int = 0  # private
var proc: int = 0  # private
var cool_down_counter: int = 0
const LEFT: String = "left"
const RIGHT: String = "right"

func _init() -> void:
	inst = self
	swarm_cont = {
		"direction": "",
		"amount": 0,
		"probability": 0,
	}
	got_swarm = false
	shoot_point = Vector2(0, 0)
	goto_point = Vector2(0, 0)

func reset() -> void:
	got_swarm = false
	gameuni = GameUniverse.inst
	s = SoundLibrary.inst

# P-code 核实（arrowSwarm.pcode addSwarm / updateArrowSwarm）：addSwarm 的签名是 param3:int = 0，
# AVM2 在方法入口按声明类型把实参 convert_i（ToInt32，向零截断），所以关卡传入 0.88 得到 0；
# 方法体里 `swarmCont.probability = param3` 存的就是 0。updateArrowSwarm 中
# `getlex Utility.rand; getproperty swarmCont.probability; ifngt -> 跳过` 即 `if (rand > probability)` 才放箭，
# probability = 0 时 rand > 0 恒成立（xorshift 不产生 0），因此每次调用必放一支箭、amount 每帧减 1，
# 不会出现 0.88 本意的"12% 概率放箭"。保持原版行为。
# （构造函数里 swarmCont 的初值是类对象 String/int 本身，addSwarm 之前 gotSwarm 为 false，不会被读到。）
# 其余整型参数同理按 int 截断。
func add_swarm(param1: String, param2: int = 50, param3: int = 0, param4: int = 10, param5: int = 9, param6: int = 350, param7: int = 300, param8: int = 600, param9: int = 500) -> void:
	got_swarm = true
	swarm_cont["direction"] = param1
	swarm_cont["amount"] = int(param2)
	swarm_cont["probability"] = int(param3)
	swarm_cont["damage"] = int(param4)
	swarm_cont["splash"] = int(param5)
	swarm_cont["centerX"] = int(param6)
	swarm_cont["centerY"] = int(param7)
	swarm_cont["aoeX"] = int(param8)
	swarm_cont["aoeY"] = int(param9)
	counter = 0
	Sounds.inst.play(s.get_sound(SoundLibrary.ARROW_SWARM), false, 0, 0.45)

# 反编译破损，按 P-code 重建（arrowSwarm.pcode updateArrowSwarm）：
# gotSwarm 为真时：amount > 0 则以 rand > probability 的概率放一支箭（每支箭依次消耗 4 次 rand：
# 判定、起点 y、落点 x、落点 y），amount-1；amount <= 0 则 gotSwarm = false。
# 无论 gotSwarm 与否，随后都执行：proc = 100；若 counter < coolDownCounter 则 counter+1，
# proc = counter / coolDownCounter * 100（int 截断）；最后返回 proc。
func update_arrow_swarm() -> int:
	if got_swarm == true:
		if swarm_cont["amount"] > 0:
			if RWRandom.rand() > swarm_cont["probability"]:
				shoot_point.y = 200 + floor(300 * RWRandom.rand())
				if swarm_cont["direction"] == LEFT:
					shoot_point.x = -50
				else:
					shoot_point.x = 800
				goto_point.x = swarm_cont["centerX"] - swarm_cont["aoeX"] / 2.0 + floor(swarm_cont["aoeX"] * RWRandom.rand())
				goto_point.y = swarm_cont["centerY"] - swarm_cont["aoeY"] / 2.0 + floor(swarm_cont["aoeY"] * RWRandom.rand())
				ar = ArrowEx.cached_data.get_data() as ArrowEx
				GameUniverse.inst.add_arrow(ar)
				ar.init(null, shoot_point, goto_point, missile_hit_handler, true, false, true)
				swarm_cont["amount"] = swarm_cont["amount"] - 1
		else:
			got_swarm = false
	proc = 100
	if counter < cool_down_counter:
		counter += 1
		proc = int(float(counter) / cool_down_counter * 100)
	return proc

func set_cool_down(param1: int) -> void:
	cool_down_counter = param1 * 30
	counter = 0

func missile_hit_handler(param1: ArrowEx, _param2: LivingObject) -> void:
	goto_point.x = param1.position.x
	goto_point.y = param1.position.y - 12
	all_units = gameuni.get_all_units_in_area(goto_point, swarm_cont["splash"])
	if all_units.size() > 0:
		i = 0
		while i < all_units.size():
			unit = all_units[i]
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.ARROW_IMPACT), false, 0, 0.3, param1.position.x, SoundLibrary.ARROW_IMPACT)
			calculated_armor = unit.cur_armor
			res_damage = int(floor(swarm_cont["damage"] * (1 - calculated_armor)))
			unit.bring_damage(res_damage, null)
			i += 1
		param1.set_hit()
	else:
		param1.set_missed()
	unit = null
	all_units.clear()
