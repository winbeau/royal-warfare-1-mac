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
        "$godot_bin" --headless --path "$project_dir" --script tests/smoke.gd -- --isolated-profile
        "$godot_bin" --headless --path "$project_dir" --script tests/combat_rules.gd -- --isolated-profile
        "$godot_bin" --headless --path "$project_dir" --script tests/rw_runtime.gd -- --isolated-profile
        "$godot_bin" --headless --path "$project_dir" --script tests/sounds_runtime.gd -- --isolated-profile
        exec "$godot_bin" --headless --path "$project_dir" --script tests/campaign_flow.gd -- --isolated-profile
        ;;
    export)
        mkdir -p "$project_dir/build"
        touch "$project_dir/build/.gdignore"
        "$godot_bin" --headless --editor --path "$project_dir" --import --quit
        exec "$godot_bin" --headless --path "$project_dir" --export-release macOS "$project_dir/build/Royal Warfare 1.app"
        ;;
    *) echo '用法：dev/godot.sh [run|editor|test|export]' >&2; exit 2 ;;
esac
