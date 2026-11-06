## WP-D1：火铳卫“特殊弹”技能的通用冷却壳。六个技能（steady_aim/rending_shot/scattershot/
## concussion_round/heartpiercer/burst_shell）结构相同——冷却好、满足前置条件时把下一发普通射击
## 替换成特殊弹，效果在 Ch2Musketeer.throw_ranged 里按 skill_id 分发（见 game/ch2/units/ch2_musketeer.gd）。
## 冷却在“装上特殊弹”的那一刻开始算（Ch2Musketeer 调 reset_counter 的时机即是那一刻）。
class_name Ch2SpecialAmmo
extends SpecialTemplate

var skill_id: String = ""

func _init(id: String) -> void:
	skill_id = id
	special_description = id
	refresh_cooldown()

## 冷却进度按百分比继承换装时调用：ratio 为 0..1（旧技能的 get_count_percent/100）。
func refresh_cooldown(progress_ratio: float = 0.0) -> void:
	time_until_update = Ch2SkillLevels.cooldown_frames(skill_id, int(Ch2WeaponDef.skill(skill_id).get("cooldown_frames", 300)))
	counter = int(round(time_until_update * progress_ratio))
