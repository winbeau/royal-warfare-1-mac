"""特效图处理（docs/ch2-art-pipeline.md 第 4 节）。"""
from __future__ import annotations

import os
import numpy as np

import common


def process_row(img: np.ndarray, rows: int, cols: int, row: int, blend: str, anchor: str, report: list,
		color: tuple = (200.0, 196.0, 188.0), trim_bottom: float = 0.0):
	cells = common.grid_cells(img, rows, cols)
	frame_cells = [cl for r, c, cl, _ in sorted(
		(cl2 for cl2 in cells if cl2[0] == row), key=lambda t: t[1]
	)]
	# frame_cells 排序：按列
	frame_cells = []
	for r, c, cl, _ in cells:
		if r == row:
			frame_cells.append((c, cl))
	frame_cells.sort(key=lambda t: t[0])
	frame_cells = [cl for _, cl in frame_cells]

	if trim_bottom > 0:
		# 有些行的格子底部会漏进下一行特效的光晕（原图生成时行与行之间没有
		# 完全分开），裁掉格子底部一块能干净地去掉这团串色。
		frame_cells = [cl[: int(cl.shape[0] * (1.0 - trim_bottom))] for cl in frame_cells]

	cleaned = []
	for cl in frame_cells:
		placeholder = np.zeros(cl.shape[:2], dtype=bool)
		cleaned.append(common.clean_cell(cl, placeholder, min_area_ratio=0.001))

	# 缩小到原图格子的一半（docs 要求：尺寸按原图格子缩小到一半）
	scale = 0.5
	scaled = [common.resize_lanczos(cl, scale) for cl in cleaned]

	# 公共最大包围盒
	boxes = [common.bbox_of_alpha(cl) for cl in scaled]
	valid_boxes = [b for b in boxes if b is not None]
	if not valid_boxes:
		raise RuntimeError("vfx row 全空")
	max_w = max(b[2] - b[0] for b in valid_boxes)
	max_h = max(b[3] - b[1] for b in valid_boxes)
	frame_w, frame_h = max_w, max_h

	strip_rgb = np.zeros((frame_h, frame_w * len(scaled), 3), dtype=np.float32)
	strip_alpha = np.zeros((frame_h, frame_w * len(scaled)), dtype=np.float32)
	if blend == "add":
		# docs 要求加色特效整帧输出不透明 RGB（黑底也算数），不能只在每帧自己的
		# 包围盒内才不透明——小包围盒的帧（比如起始/收尾帧）如果只在内容范围
		# 填 alpha=255，帧内其余区域会变成透明，在某些不按加色混合处理透明度
		# 的场合看起来像一块白板，而不是融入黑底。
		strip_alpha[:] = 255.0

	fringe_total = 0
	for i, cl in enumerate(scaled):
		box = boxes[i]
		if box is None:
			continue
		x0, y0, x1, y1 = box
		w, h = x1 - x0, y1 - y0
		ox = (frame_w - w) // 2
		oy = (frame_h - h) // 2
		sub = cl[y0:y1, x0:x1]
		dst_x0 = i * frame_w + ox
		dst_y0 = oy
		if blend == "add":
			# 合成到纯黑底，输出不透明 RGB
			rgb = sub[..., :3] * (sub[..., 3:4] / 255.0)
			strip_rgb[dst_y0:dst_y0 + h, dst_x0:dst_x0 + w] = rgb
			strip_alpha[dst_y0:dst_y0 + h, dst_x0:dst_x0 + w] = 255.0
		else:
			# alpha 混合特效（硝烟、马蹄扬尘等）：alpha 取亮度，颜色统一成指定色
			luma = np.max(sub[..., :3], axis=-1) * (sub[..., 3] / 255.0)
			strip_alpha[dst_y0:dst_y0 + h, dst_x0:dst_x0 + w] = luma
			strip_rgb[dst_y0:dst_y0 + h, dst_x0:dst_x0 + w] = np.array(color, dtype=np.float32)
		fringe_total += common.fringe_pixel_count(cl)

	if blend == "add":
		out = np.concatenate([strip_rgb, strip_alpha[..., None]], axis=-1)
	else:
		out = np.concatenate([strip_rgb, strip_alpha[..., None]], axis=-1)

	if anchor == "left":
		anchor_xy = [0.0, frame_h / 2.0]
	else:
		anchor_xy = [frame_w / 2.0, frame_h / 2.0]

	report.append(f"[vfx] row {row}: frame {frame_w}x{frame_h}, blend={blend}, 毛边像素 {fringe_total}")
	return out, [frame_w, frame_h], anchor_xy


def run_sheet(vfx_cfg: dict, index: dict, report: list) -> None:
	raw_path = common.repo_path("build", "ch2_art", "raw", vfx_cfg["raw"])
	img = common.load_rgba(raw_path)
	for entry in vfx_cfg["entries"]:
		color = tuple(entry["color"]) if "color" in entry else (200.0, 196.0, 188.0)
		trim_bottom = float(entry.get("trim_bottom", 0.0))
		out, frame_size, anchor_xy = process_row(
			img, vfx_cfg["rows"], vfx_cfg["cols"], entry["row"], entry["blend"], entry["anchor"], report,
			color=color, trim_bottom=trim_bottom,
		)
		out_path = common.repo_path("assets", "ch2", "vfx", f"{entry['name']}.png")
		common.save_rgba(out, out_path)
		index[entry["name"]] = {
			"frame_size": frame_size,
			"frames": 6,
			"anchor": anchor_xy,
			"blend": entry["blend"],
		}


def run_all(report: list) -> dict:
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	index: dict = {}
	run_sheet(src["vfx"], index, report)
	if "vfx2" in src:
		run_sheet(src["vfx2"], index, report)
	common.save_json(common.repo_path("assets", "ch2", "vfx", "vfx.json"), index)
	return index


if __name__ == "__main__":
	rep: list = []
	run_all(rep)
	for line in rep:
		print(line)
