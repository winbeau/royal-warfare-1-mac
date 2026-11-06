"""战场底图处理：按比例缩放后居中裁成 1400x1200，不做调色。"""
from __future__ import annotations

import os
from PIL import Image

import common

TARGET_W, TARGET_H = 1400, 1200


def process_background(raw_name: str, out_name: str, report: list) -> None:
	raw_path = common.repo_path("build", "ch2_art", "raw", raw_name)
	img = Image.open(raw_path).convert("RGB")
	w, h = img.size
	scale = max(TARGET_W / w, TARGET_H / h)
	nw, nh = int(round(w * scale)), int(round(h * scale))
	resized = img.resize((nw, nh), Image.LANCZOS)
	x0 = (nw - TARGET_W) // 2
	y0 = (nh - TARGET_H) // 2
	cropped = resized.crop((x0, y0, x0 + TARGET_W, y0 + TARGET_H))
	out_path = common.repo_path("assets", "backgrounds", "ch2", out_name)
	os.makedirs(os.path.dirname(out_path), exist_ok=True)
	cropped.save(out_path)
	report.append(f"[bg] {raw_name} -> {out_name}: 原图 {w}x{h}, 缩放到 {nw}x{nh}, 裁成 {TARGET_W}x{TARGET_H}")


def run_all(report: list) -> None:
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	for entry in src.get("backgrounds", []):
		process_background(entry["raw"], entry["out"], report)


if __name__ == "__main__":
	rep: list = []
	run_all(rep)
	for line in rep:
		print(line)
