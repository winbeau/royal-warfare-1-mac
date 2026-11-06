"""一代达思骑士上半身切割数据（docs 之外，主会话追加的任务）。

不复制一代的图，只记切割参数：运行时直接用一代 BmpFrames 纹理（
assets/library/sprites/<id>/frames.tres + 0.png）做区域裁剪。
"""
from __future__ import annotations

import re

import numpy as np

import common

SPRITE_IDS = ["821", "3382", "2311"]


def parse_regions(frames_tres_path: str) -> list[tuple[int, int, int, int]]:
	"""按声明顺序解析 frames.tres 里所有 AtlasTexture 的 region，顺序与
	f0..fN 一致（也就是动画帧顺序）。"""
	text = open(frames_tres_path, "r", encoding="utf-8").read()
	regions = []
	for m in re.finditer(r"region = Rect2\(([^)]*)\)", text):
		x, y, w, h = (float(v.strip()) for v in m.group(1).split(","))
		regions.append((int(x), int(y), int(w), int(h)))
	return regions


def compute_frame_cut(cell: np.ndarray) -> dict:
	"""feet_y：最低的、alpha>=200 的不透明行（排除半透明灰色阴影）。
	cut_y = feet_y - 10。hip：cut_y 以上 3 行内不透明像素的质心 x，配 cut_y。"""
	alpha = cell[..., 3]
	solid = alpha >= 200
	ys, xs = np.nonzero(solid)
	if ys.size == 0:
		return {"cut_y": 0, "hip": [cell.shape[1] / 2.0, 0]}
	feet_y = int(ys.max())
	cut_y = feet_y - 10
	band_lo = max(0, cut_y - 3)
	band = solid[band_lo:cut_y + 1, :]
	bys, bxs = np.nonzero(band)
	if bxs.size == 0:
		# 退化情况：带状区域内没有不透明像素，往上找最近的一行
		bys2, bxs2 = np.nonzero(solid[:cut_y + 1, :])
		hip_x = float(bxs2[-50:].mean()) if bxs2.size else cell.shape[1] / 2.0
	else:
		hip_x = float(bxs.mean())
	return {"cut_y": cut_y, "hip": [hip_x, float(cut_y)]}


def run_all(report: list) -> dict:
	out: dict = {}
	for sid in SPRITE_IDS:
		frames_tres = common.repo_path("assets", "library", "sprites", sid, "frames.tres")
		png_path = common.repo_path("assets", "library", "sprites", sid, "0.png")
		regions = parse_regions(frames_tres)
		sheet = common.load_rgba(png_path)
		entries = []
		for (x, y, w, h) in regions:
			cell = sheet[y:y + h, x:x + w]
			entries.append(compute_frame_cut(cell))
		out[sid] = entries
		report.append(f"[darth_rider] {sid}: {len(entries)} 帧，第0帧 cut_y={entries[0]['cut_y']}, "
			f"hip={entries[0]['hip']}")
	out_path = common.repo_path("assets", "ch2", "units", "darth_rider", "rider.json")
	common.save_json(out_path, out)
	return out


if __name__ == "__main__":
	rep: list = []
	run_all(rep)
	for line in rep:
		print(line)
