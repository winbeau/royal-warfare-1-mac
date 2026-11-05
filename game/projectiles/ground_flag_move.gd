# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/projectiles/groundFlagMove.as
class_name GroundFlagMove
extends VisualsTemplate

static var cached_data: SimpleCache = null

static func cache(param1: int = 50) -> void:
	cached_data = SimpleCache.new(GroundFlagMove, param1, true)
