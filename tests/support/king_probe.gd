extends UndeadVampireKing
# 测试探针：把 call_support 替换为计数器，避免依赖完整 GameUniverse
var calls := 0

func call_support() -> void:
	calls += 1
