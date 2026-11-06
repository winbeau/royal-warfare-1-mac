#!/bin/bash
# 视觉工作台入口：./dev/screens/shot.sh <截图清单，逗号分隔> [输出目录] [额外用户参数...]
# 例：./dev/screens/shot.sh ch2_map,upgrade2 build/screens --ch2-dev
#
# 在 Linux 容器（Xvfb 虚拟显示 + Mesa 软件渲染）里跑同版本 Godot 截图，用户桌面上不会出现任何窗口、
# 也不会抢焦点或切换桌面（用户 2026-11-06 要求；在 macOS 本机开窗口的办法都会被 Godot 主动激活）。
# 前提：colima/docker 在运行，镜像 rw1-shot:4.7.2 已按 dev/screens/docker/Dockerfile 构建
#      （构建上下文 ~/.cache/rw1-shot，内含 Godot_v4.7.2-stable_linux.arm64，不入库）。
# 带 --isolated-profile，不读写玩家存档。完成后写 <输出目录>/done.txt 并打印结果。
set -e
project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
shots="$1"; shift || true
out="${1:-build/screens}"; shift || true
mkdir -p "$project_dir/$out"
rm -f "$project_dir/$out/done.txt"
docker run --rm --init -e HOME=/tmp -e DISPLAY=:99 -v "$project_dir":"$project_dir" -w "$project_dir" rw1-shot:4.7.2 \
    sh -c 'Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp >/dev/null 2>&1 & sleep 1; exec godot "$@"' godot \
        --path "$project_dir" --rendering-driver opengl3 --resolution 1050x900 \
        --audio-driver Dummy --log-file "$project_dir/$out/godot.log" \
        --script res://dev/screens/shot.gd -- --isolated-profile --shots="$shots" --out="$project_dir/$out" "$@" \
    > "$project_dir/$out/run.log" 2>&1 || true
cat "$project_dir/$out/done.txt" 2>/dev/null || { echo "FAILED, see $out/run.log"; tail -20 "$project_dir/$out/run.log"; }
