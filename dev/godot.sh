#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
    for candidate in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
        if [[ -x "$candidate" ]]; then godot_bin="$candidate"; break; fi
    done
fi
if [[ -z "$godot_bin" ]]; then
    godot_bin="$(command -v godot || command -v godot4 || true)"
fi
if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
    echo '请安装 Godot 4.7.2，或将 GODOT_BIN 指向 Godot 可执行文件。' >&2
    exit 1
fi
action="${1:-run}"
case "$action" in
    run) exec "$godot_bin" --path "$project_dir" ;;
    editor) exec "$godot_bin" --editor --path "$project_dir" ;;
    test)
        mkdir -p "$project_dir/build"
        touch "$project_dir/build/.gdignore"
        "$godot_bin" --headless --editor --path "$project_dir" --import --quit
        for t in smoke rw_runtime sounds_runtime levels_data universe_core living_core class_bases friend_units enemy_units visual_effects specials_rules as3_abort clips_runtime menu_screens upgrade_panel comics battle_ifaces main_game_ui level_intro main_flow input_e2e input_e2e_new_save living_units_audit f2_core ifaces_f3 extra_obstacles input_battle_flow; do
            "$godot_bin" --headless --path "$project_dir" --script "tests/$t.gd" -- --isolated-profile
        done
        # battle_level1 / battle_all_levels 放在最后：已知 game/ifaces/hints_manager.gd 在关卡结束清理时与
        # main_game_ui_ex.gd 的 _exit_tree 存在一个 remove_child 时序冲突（详见 docs/verification.md「测试运行中
        # 已知问题」），不属于本次改动范围；放在最后可以让前面的测试（含 main_flow）不被这个已知问题挡住。
        "$godot_bin" --headless --path "$project_dir" --script tests/battle_level1.gd -- --isolated-profile
        exec "$godot_bin" --headless --path "$project_dir" --script tests/battle_all_levels.gd -- --isolated-profile
        ;;
    export)
        mkdir -p "$project_dir/build"
        touch "$project_dir/build/.gdignore"
        "$godot_bin" --headless --editor --path "$project_dir" --import --quit
        exec "$godot_bin" --headless --path "$project_dir" --export-release macOS "$project_dir/build/Royal Warfare 1.app"
        ;;
    *) echo '用法：dev/godot.sh [run|editor|test|export]' >&2; exit 2 ;;
esac
