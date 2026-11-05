# 移植自 S/gameCore/specials/specFlash.as
class_name SpecFlash
extends SpecialTemplate

var damage: int = 0  # private
var a_damage: Array = []  # private
var num_flash: int = 0  # private
var a_num_flash: Array = []  # private
var temp_counter: int = 0  # private（原版未使用）
var a_units_to_hit: Array = []  # private，Vector.<livingObject>
var me = null  # private，mageClass（untyped）

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Lightning strike</font></p>" + "<p>Shoot a number of flashes on the battlefield</p>"
	number_in_panel = 13
	temp_counter = 0
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_FLASH)
	a_damage = [70, 80, 90]
	damage = a_damage[cur_spec_level]
	a_num_flash = [1, 2, 3]
	num_flash = a_num_flash[cur_spec_level]
	a_time_until_update = [46, 43, 40]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "<p>Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "damage: <font color='#F6F581'>" + SpecFmt.n(damage) + "</font>,</p>" + "number of charges: <font color='#F6F581'>" + SpecFmt.n(num_flash) + "</font></p>"

# 注意（原版行为，保留）：循环内先用上一轮（首轮为第一段循环最后遍历到的）loc2 判断 a16_killFlash，再取 loc5[loc8]。
func set_flash() -> void:
	var loc2: LivingObject = null
	var loc3: int = num_flash
	var loc5: Array = []
	var loc6: int = 0
	while loc6 < a_units_to_hit.size():
		if loc5.size() >= loc3:
			break
		loc2 = a_units_to_hit[loc6]
		if loc2.cur_health > 0:
			loc5.append(loc2)
		loc6 += 1
	if loc5.size() > 0:
		var loc7: int
		if loc5.size() > loc3:
			loc7 = loc3
		else:
			loc7 = loc5.size()
		var loc8: int = 0
		while loc8 < loc7:
			if damage >= loc2.cur_health:
				GlobalData.inst.a16_kill_flash += 1
			loc2 = loc5[loc8]
			loc2.bring_damage(damage, me, false, true)
			var loc9: SimpleCache = FlashVisual.cached_data
			var loc10: FlashVisual = loc9.get_data() as FlashVisual
			loc10.added_to_stage(loc2.position.x + loc2.sens.position.x, loc2.position.y + loc2.sens.position.y)
			var loc11: int = 1
			if RWRandom.rand() > 0.5:
				loc11 = -1
			loc10.scale.x = loc11
			loc8 += 1

# 反编译破损，按 P-code 重建（specFlash.pcode checkFlash）：
# canUseSpecial -> 取 getAllEnemies(friendly) 并随机排序；把当前目标移到队首；
# 筛选屏幕内（20 < x < MaxScreenWidth-20 且 20 < y < MaxScreenHeight-20）的敌人放入 aUnitsToHit；
# 找到后：rand > 0.5 播 SPEC_FLASH1，否则 SPEC_FLASH2（音量 0.9，无位置）；resetCounter；turnToUnit(第一个)；
# 无当前目标则 setTarget(第一个)；setCastingStance。
# param1 为 mageClass（untyped）
func check_flash(param1) -> bool:
	me = param1
	if can_use_special():
		var loc2: bool = param1.friendly
		a_units_to_hit = []
		var loc3: Array = GameUniverse.inst.get_all_enemies(loc2)
		GameUniverse._random_sort(loc3)  # Array.sort(Utility.randomSort)；RNG 消耗次数与 Flash 排序不保证一致
		var loc4: LivingObject = param1.get_cur_target
		if loc4 != null:
			var loc6: int = loc3.find(loc4)
			_splice_remove(loc3, loc6)
			loc3.insert(0, loc4)
		var loc5: bool = false
		if loc3.size() > 0:
			var loc7: int = 0
			while loc7 < loc3.size():
				var loc8: LivingObject = loc3[loc7]
				if loc8.position.x > 20 and loc8.position.x < GameUniverse.MAX_SCREEN_WIDTH - 20 and loc8.position.y > 20 and loc8.position.y < GameUniverse.MAX_SCREEN_HEIGHT - 20:
					a_units_to_hit.append(loc8)
					loc5 = true
				loc7 += 1
			if loc5 == true:
				var loc9: SoundLibrary = SoundLibrary.inst
				if RWRandom.rand() > 0.5:
					Sounds.inst.play(loc9.get_sound(SoundLibrary.SPEC_FLASH1), false, 0, 0.9)
				else:
					Sounds.inst.play(loc9.get_sound(SoundLibrary.SPEC_FLASH2), false, 0, 0.9)
				reset_counter()
				param1.turn_to_unit(a_units_to_hit[0])
				if param1.get_cur_target == null:
					param1.set_target(a_units_to_hit[0])
				param1.set_casting_stance()
				return true
			return false
		return false
	return false

# AS3 Array.splice(index, 1)：index 为 -1（indexOf 未命中）时从末尾起算，等价于删掉最后一个元素。
func _splice_remove(arr: Array, index: int) -> void:
	if index < 0:
		index += arr.size()
		if index < 0:
			index = 0
	if index < arr.size():
		arr.remove_at(index)
