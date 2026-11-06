## WP-D1：镇戍卫自动技能的通用冷却壳（hold_fast/shield_bash/wide_sweep/sunder/follow_through/horsebreaker）。
## 效果与触发条件在 Ch2Warden 里按 skill_id 分发；window_counter 只给 hold_fast 用（“6 秒内伤害减半”的窗口），
## brace_counter 只给 horsebreaker 用（支势计时），其余技能不用这两个字段，留着无副作用。
class_name Ch2SpecMeleeAuto
extends SpecialTemplate

var skill_id: String = ""
var window_counter: int = 0
var brace_counter: int = 0

func _init(id: String) -> void:
	skill_id = id
	special_description = id
	refresh_cooldown()

func refresh_cooldown(progress_ratio: float = 0.0) -> void:
	time_until_update = Ch2SkillLevels.cooldown_frames(skill_id, int(Ch2WeaponDef.skill(skill_id).get("cooldown_frames", 300)))
	counter = int(round(time_until_update * progress_ratio))

func update() -> void:
	super.update()
	if window_counter > 0:
		window_counter -= 1
