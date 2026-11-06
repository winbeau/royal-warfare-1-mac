"""武器图处理（docs/ch2-art-pipeline.md 第 3 节）。"""
from __future__ import annotations

import os
import numpy as np
from scipy import ndimage

import common


def demagenta(cell: np.ndarray) -> np.ndarray:
	"""品红底抠除，带渐变过渡：按与 (255,0,255) 的距离设 alpha。"""
	out = cell.copy()
	r, g, b = out[..., 0], out[..., 1], out[..., 2]
	# 距离品红越近，越透明；用 G 通道作为主要判据（品红 G=0，主体通常 G 较高）
	# 同时要求 R、B 都偏高、彼此接近，才判定为品红系
	dist = np.sqrt((r - 255.0) ** 2 + g ** 2 + (b - 255.0) ** 2)
	magenta_like = (np.abs(r - b) < 40) & (g < np.minimum(r, b) - 20)
	alpha = out[..., 3].copy()
	# 渐变过渡：dist 越小越透明
	fade = np.clip(dist / 90.0, 0.0, 1.0)
	alpha = np.where(magenta_like, np.minimum(alpha, fade * 255.0), alpha)
	out[..., 3] = alpha
	return out


def process_weapon(cfg: dict, sheets_cfg: dict, report: list):
	sheet_name = cfg["sheet"]
	sheet_cfg = sheets_cfg[sheet_name]
	raw_path = common.repo_path("build", "ch2_art", "raw", sheet_name)
	img = common.load_rgba(raw_path)
	cells = common.grid_cells(img, sheet_cfg["rows"], sheet_cfg["cols"])
	cell = None
	for r, c, cl, _ in cells:
		if r == cfg["row"] and c == cfg["col"]:
			cell = cl
			break
	if cell is None:
		raise RuntimeError(f"weapon {cfg['id']}: 格子 ({cfg['row']},{cfg['col']}) 不存在")

	placeholder = np.zeros(cell.shape[:2], dtype=bool)
	if sheet_cfg.get("magenta_bg"):
		cell = demagenta(cell)
	clean = common.clean_cell(cell, placeholder, min_area_ratio=0.004)

	opaque = clean[..., 3] > 0
	if not opaque.any():
		raise RuntimeError(f"weapon {cfg['id']}: 清理后为空")

	kind = cfg["kind"]
	if kind == "shield":
		ys, xs = np.nonzero(opaque)
		cx, cy = float(xs.mean()), float(ys.mean())
		radius = float(max(xs.max() - xs.min(), ys.max() - ys.min())) / 2.0
		scale = (cfg["logical_length"] * 2.0) / (radius * 2.0)
		entry = {"center_raw": (cx, cy), "radius_raw": radius, "scale": scale}
	else:
		ys, xs = np.nonzero(opaque)
		x_min, x_max = int(xs.min()), int(xs.max())
		# 握端：最左侧不透明列，y 中点；尖端：最右侧不透明列，y 中点
		left_col_ys = ys[xs == x_min]
		right_col_ys = ys[xs == x_max]
		butt = (float(x_min), float((left_col_ys.min() + left_col_ys.max()) / 2.0))
		tip = (float(x_max), float((right_col_ys.min() + right_col_ys.max()) / 2.0))
		length = abs(tip[0] - butt[0])
		scale = (cfg["logical_length"] * 2.0) / length if length > 0 else 1.0
		entry = {"butt_raw": butt, "tip_raw": tip, "scale": scale}

	scaled = common.resize_lanczos(clean, entry["scale"])
	bbox = common.bbox_of_alpha(scaled)
	x0, y0, x1, y1 = bbox
	trimmed = scaled[y0:y1, x0:x1]
	out_path = common.repo_path("assets", "ch2", "weapons", f"{cfg['id']}.png")
	common.save_rgba(trimmed, out_path)

	fringe = common.fringe_pixel_count(trimmed)
	report.append(f"[weapon] {cfg['id']}: 尺寸 {trimmed.shape[1]}x{trimmed.shape[0]}, 毛边像素 {fringe}")

	# 注意：butt_raw/tip_raw/center_raw 是清理前原生分辨率格子里的坐标，
	# 而 x0/y0 是缩放后 (scaled) 图像里的包围盒偏移，两者单位不同，
	# 必须先把 raw 坐标乘 scale 换到缩放后的空间，再减掉 x0/y0，不能颠倒顺序。
	meta = {"size": [int(trimmed.shape[1]), int(trimmed.shape[0])]}
	if kind == "shield":
		cx = entry["center_raw"][0] * entry["scale"] - x0
		cy = entry["center_raw"][1] * entry["scale"] - y0
		meta["center"] = [cx, cy]
		meta["radius"] = entry["radius_raw"] * entry["scale"]
	else:
		bx = entry["butt_raw"][0] * entry["scale"] - x0
		by = entry["butt_raw"][1] * entry["scale"] - y0
		tx = entry["tip_raw"][0] * entry["scale"] - x0
		ty = entry["tip_raw"][1] * entry["scale"] - y0
		meta["butt"] = [bx, by]
		meta["tip"] = [tx, ty]
		if kind == "gun":
			meta["muzzle"] = [tx, ty]
		if kind == "bell":
			# 铃身中心：最右侧连通大块的中心
			labels, n = ndimage.label(trimmed[..., 3] > 0)
			if n > 0:
				sizes = ndimage.sum(np.ones_like(labels), labels, index=np.arange(1, n + 1))
				# 取 x 质心最靠右的较大连通块
				best_i, best_x = None, -1.0
				for i in range(1, n + 1):
					if sizes[i - 1] < sizes.max() * 0.15:
						continue
					ys2, xs2 = np.nonzero(labels == i)
					mx = float(xs2.mean())
					if mx > best_x:
						best_x = mx
						best_i = i
				if best_i is not None:
					ys2, xs2 = np.nonzero(labels == best_i)
					meta["head"] = [float(xs2.mean()), float(ys2.mean())]
	return cfg["id"], meta


def run_all(report: list) -> dict:
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	sheets_cfg = src["weapon_sheets"]
	out = {}
	for cfg in src["weapons"]:
		wid, meta = process_weapon(cfg, sheets_cfg, report)
		out[wid] = meta
	common.save_json(common.repo_path("assets", "ch2", "weapons", "weapons.json"), out)
	return out


if __name__ == "__main__":
	rep: list = []
	run_all(rep)
	for line in rep:
		print(line)
