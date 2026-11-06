"""一代风格图标处理（docs/ch2-art-pipeline.md 第 5 节）。"""
from __future__ import annotations

import os
import re
import numpy as np

import common


def to_snake(name: str) -> str:
	s = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")
	return s.lower()


def purple_halo_cleanup(cell: np.ndarray, alpha_max: float = 230.0) -> np.ndarray:
	"""紫色光晕处理：min(R,B)-G>40 且 alpha<alpha_max 的像素改成暗色投影 (24,22,26)，alpha 不变。

	第 5 节的一代风格图标（rw1style_icons_v1.png）光晕的 alpha 大多在 230 以下，
	用 230 能干净地把光晕和主体内部的紫色像素（alpha>=230）分开。第 5b 节的武器
	图标（rw1style_weapon_icons_v1.png）光晕明显更"实"，alpha 能到 245-250，
	逼近主体本身的不透明度，所以武器图标那边调用时传更高的 alpha_max（见
	run_weapon_icons）；物体内部真正带紫色调的像素只占极少数，且多是描边/
	抗锯齿过渡色，一起压成暗色投影不会破坏造型。
	"""
	out = cell.copy()
	r, g, b = out[..., 0], out[..., 1], out[..., 2]
	a = out[..., 3]
	mask = (np.minimum(r, b) - g > 40) & (a < alpha_max)
	out[..., 0] = np.where(mask, 24.0, r)
	out[..., 1] = np.where(mask, 22.0, g)
	out[..., 2] = np.where(mask, 26.0, b)
	return out


def resize_to_edge(cell: np.ndarray, target: int, by: str):
	bbox = common.bbox_of_alpha(cell)
	if bbox is None:
		return cell
	x0, y0, x1, y1 = bbox
	trimmed = cell[y0:y1, x0:x1]
	h, w = trimmed.shape[:2]
	if by == "height":
		scale = target / h
	else:
		scale = target / max(w, h)
	return common.resize_lanczos(trimmed, scale)


def run_all(report: list) -> dict:
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	cfg = src["icons"]
	raw_path = common.repo_path("build", "ch2_art", "raw", cfg["raw"])
	img = common.load_rgba(raw_path)
	rows, cols = cfg["rows"], cfg["cols"]
	cells = common.grid_cells(img, rows, cols)
	by_pos = {(r, c): cl for r, c, cl, _ in cells}

	units_cfg = common.load_json(common.repo_path("data", "ch2", "text", "units.json"))
	skill_names = {}
	for s in units_cfg["skills"]:
		skill_names.setdefault(s["weapon_id"], []).append(s["name"])

	index = {"portraits": {}, "skills": {}}

	for col, pid in enumerate(cfg["portraits"]):
		cell = by_pos[(0, col)]
		placeholder = np.zeros(cell.shape[:2], dtype=bool)
		clean = common.clean_cell(cell, placeholder, min_area_ratio=0.002)
		clean = purple_halo_cleanup(clean)
		out = resize_to_edge(clean, cfg["portrait_height"], by="height")
		out_path = common.repo_path("assets", "ch2", "icons", "portraits", f"{pid}.png")
		common.save_rgba(out, out_path)
		fringe = common.fringe_pixel_count(out)
		report.append(f"[icon] portrait {pid}: {out.shape[1]}x{out.shape[0]}, 毛边像素 {fringe}")
		index["portraits"][pid] = f"portraits/{pid}.png"

	for row_idx, row_spec in enumerate(cfg["skill_rows"]):
		for col, key in enumerate(row_spec):
			weapon_id, skill_idx = key.split(":")
			skill_idx = int(skill_idx)
			name = skill_names[weapon_id][skill_idx]
			fname = to_snake(name)
			cell = by_pos[(row_idx + 1, col)]
			placeholder = np.zeros(cell.shape[:2], dtype=bool)
			clean = common.clean_cell(cell, placeholder, min_area_ratio=0.002)
			clean = purple_halo_cleanup(clean)
			out = resize_to_edge(clean, cfg["skill_max_edge"], by="max_edge")
			out_path = common.repo_path("assets", "ch2", "icons", "skills", f"{fname}.png")
			common.save_rgba(out, out_path)
			fringe = common.fringe_pixel_count(out)
			report.append(f"[icon] skill {weapon_id}:{skill_idx} {name} -> {fname}.png: "
				f"{out.shape[1]}x{out.shape[0]}, 毛边像素 {fringe}")
			index["skills"][fname] = {"weapon_id": weapon_id, "skill_index": skill_idx, "path": f"skills/{fname}.png"}

	common.save_json(common.repo_path("assets", "ch2", "icons", "icons.json"), index)
	return index


def run_weapon_icons(icons_index: dict, report: list) -> dict:
	"""第 5b 节：武器图标（三格面板用）。"""
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	cfg = src["weapon_icons"]
	raw_path = common.repo_path("build", "ch2_art", "raw", cfg["raw"])
	img = common.load_rgba(raw_path)
	rows, cols = cfg["rows"], cfg["cols"]
	cells = common.grid_cells(img, rows, cols)
	by_pos = {(r, c): cl for r, c, cl, _ in cells}

	weapon_icons = {}

	def process(cell, wid, alpha_max):
		placeholder = np.zeros(cell.shape[:2], dtype=bool)
		clean = common.clean_cell(cell, placeholder, min_area_ratio=0.002)
		clean = purple_halo_cleanup(clean, alpha_max=alpha_max)
		out = resize_to_edge(clean, cfg["max_edge"], by="max_edge")
		out_path = common.repo_path("assets", "ch2", "icons", "weapons", f"{wid}.png")
		common.save_rgba(out, out_path)
		fringe = common.fringe_pixel_count(out)
		report.append(f"[icon] weapon {wid}: {out.shape[1]}x{out.shape[0]}, 毛边像素 {fringe}")
		weapon_icons[wid] = f"weapons/{wid}.png"

	ids = cfg["ids"]
	for i, wid in enumerate(ids):
		if wid is None:
			continue
		row, col = divmod(i, cols)
		# 这套武器图标的紫色光晕比第 5 节的更"实"（alpha 能到 251-252），
		# 230 的默认阈值截不干净，这里放宽到 253。
		process(by_pos[(row, col)], wid, alpha_max=253.0)

	for wid, ov in cfg.get("overrides", {}).items():
		raw2 = common.load_rgba(common.repo_path("build", "ch2_art", "raw", ov["sheet"]))
		cells2 = common.grid_cells(raw2, ov["rows"], ov["cols"])
		by_pos2 = {(r, c): cl for r, c, cl, _ in cells2}
		# five_thunders_v6.png 里备用的两格背景是一整块几乎不透明的紫色卡片
		# （alpha 最高到 253，物体本身的像素在同样高饱和紫色下 alpha 从不到
		# 254），阈值要提到 254 才能把卡片整块识别出来。
		process(by_pos2[(ov["row"], ov["col"])], wid, alpha_max=254.0)

	icons_index["weapons"] = weapon_icons
	common.save_json(common.repo_path("assets", "ch2", "icons", "icons.json"), icons_index)
	return weapon_icons


if __name__ == "__main__":
	rep: list = []
	idx = run_all(rep)
	run_weapon_icons(idx, rep)
	for line in rep:
		print(line)
