"""第二章美术处理管线共用工具。

只依赖 pillow / numpy / scipy，通过
    uv run --with pillow --with numpy --with scipy python ...
运行，不在仓库里建虚拟环境。
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field

import numpy as np
from PIL import Image
from scipy import ndimage


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def repo_path(*parts: str) -> str:
	return os.path.join(REPO_ROOT, *parts)


def load_rgba(path: str) -> np.ndarray:
	"""读取图片为 float32 RGBA numpy 数组，形状 (H, W, 4)，取值 0..255。"""
	img = Image.open(path).convert("RGBA")
	return np.asarray(img).astype(np.float32)


def save_rgba(arr: np.ndarray, path: str) -> None:
	os.makedirs(os.path.dirname(path), exist_ok=True)
	arr = np.clip(arr, 0, 255).astype(np.uint8)
	Image.fromarray(arr, mode="RGBA").save(path)


def load_json(path: str) -> dict:
	with open(path, "r", encoding="utf-8") as f:
		return json.load(f)


def save_json(path: str, data) -> None:
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w", encoding="utf-8") as f:
		json.dump(data, f, ensure_ascii=False, indent=1)
		f.write("\n")


def load_overrides() -> dict:
	path = repo_path("dev", "ch2_art", "overrides.json")
	if os.path.exists(path):
		return load_json(path)
	return {}


# ---------------------------------------------------------------------------
# 占位物掩码（绿杆 / 蓝盘）
# ---------------------------------------------------------------------------

def rod_mask(cell: np.ndarray) -> np.ndarray:
	"""绿杆掩码：G>=170, R<=110, B<=110, G-max(R,B)>=90。"""
	r, g, b = cell[..., 0], cell[..., 1], cell[..., 2]
	return (g >= 170) & (r <= 110) & (b <= 110) & (g - np.maximum(r, b) >= 90)


def disc_mask(cell: np.ndarray) -> np.ndarray:
	"""蓝盘掩码：B>=170, R<=110, G<=110, B-max(R,G)>=90。"""
	r, g, b = cell[..., 0], cell[..., 1], cell[..., 2]
	return (b >= 170) & (r <= 110) & (g <= 110) & (b - np.maximum(r, g) >= 90)


# ---------------------------------------------------------------------------
# 清理
# ---------------------------------------------------------------------------

def clean_cell(cell: np.ndarray, placeholder_mask: np.ndarray, min_area_ratio: float = 0.004) -> np.ndarray:
	"""清理一格：alpha 阈值、腐蚀、去小连通域、边缘去溢色。

	placeholder_mask: 绿杆/蓝盘像素（True 处不参与主体面积与溢色判断，
	    后续会在 strip_placeholder 中单独抠除）。
	"""
	out = cell.copy()
	alpha = out[..., 3]
	alpha = np.where(alpha < 128, 0.0, alpha)
	out[..., 3] = alpha

	opaque = alpha > 0
	# 腐蚀 1px（不动占位物像素，占位物单独处理）
	body_opaque = opaque & ~placeholder_mask
	eroded = ndimage.binary_erosion(opaque, iterations=1)
	# 只腐蚀主体，不腐蚀占位物，避免杆/盘被误删
	keep = eroded | placeholder_mask
	out[..., 3] = np.where(keep, out[..., 3], 0.0)
	opaque = out[..., 3] > 0

	# 去掉小连通域（以主体面积，即非占位物不透明像素面积为基准）
	body_opaque = opaque & ~placeholder_mask
	body_area = float(body_opaque.sum())
	if body_area > 0:
		labels, n = ndimage.label(opaque)
		if n > 0:
			sizes = ndimage.sum(np.ones_like(labels), labels, index=np.arange(1, n + 1))
			min_area = body_area * min_area_ratio
			for i, sz in enumerate(sizes, start=1):
				if sz < min_area:
					out[..., 3] = np.where(labels == i, 0.0, out[..., 3])
	opaque = out[..., 3] > 0

	# 边缘 3px 内的溢色清理：红/品红/黄/绿色相明显偏离主体的像素
	border = opaque & ~ndimage.binary_erosion(opaque, iterations=3)
	border = border & ~placeholder_mask
	r, g, b = out[..., 0], out[..., 1], out[..., 2]
	# 红/品红溢色：R 明显高于 G、B
	red_spill = (r - np.maximum(g, b) > 60) & border
	# 黄色溢色：R、G 都明显高于 B
	yellow_spill = (np.minimum(r, g) - b > 60) & border
	# 绿色溢色：G 明显高于 R、B（不是占位绿杆，已被 placeholder_mask 排除）
	green_spill = (g - np.maximum(r, b) > 60) & border
	spill = red_spill | yellow_spill | green_spill

	# 把超出的通道压回另外两个通道的最大值
	cap = np.maximum(np.maximum(r, 0), 0)
	rb = r.copy(); gb = g.copy(); bb = b.copy()
	other_max_rg = np.maximum(g, b)
	rb = np.where(red_spill, other_max_rg, rb)
	other_max_y = b
	rb = np.where(yellow_spill, np.minimum(rb, np.maximum(other_max_y, 0) + 40), rb)
	gb = np.where(yellow_spill, np.minimum(gb, np.maximum(other_max_y, 0) + 40), gb)
	other_max_gr = np.maximum(r, b)
	gb = np.where(green_spill, other_max_gr, gb)
	out[..., 0] = rb
	out[..., 1] = gb
	out[..., 2] = bb

	# 仍然突兀（压回后仍然高饱和）的直接删掉
	r2, g2, b2 = out[..., 0], out[..., 1], out[..., 2]
	still_bad = spill & (
		(r2 - np.maximum(g2, b2) > 60) | (g2 - np.maximum(r2, b2) > 60)
	)
	out[..., 3] = np.where(still_bad, 0.0, out[..., 3])
	return out


def strip_placeholder(cell: np.ndarray, placeholder_mask: np.ndarray, tint: str) -> np.ndarray:
	"""抠掉占位物像素及周围 3px 内偏色的溢色像素。tint 为 'green' 或 'blue'。

	占位物的填充色去掉后，原画里那根杆/盘本身的深色描边还会留在带状区域里
	（一条贴着原来杆/盘走向的暗线）。这里额外在膨胀带内删除"暗且低饱和"的
	像素（描边色），同时用较高的亮度下限避免误删肤色、浅色衣物；描边本身
	通常明显暗于相邻的衣服/皮肤底色，用亮度 + 饱和度的组合阈值区分。
	"""
	out = cell.copy()
	dilated = ndimage.binary_dilation(placeholder_mask, iterations=3)
	r, g, b = out[..., 0], out[..., 1], out[..., 2]
	if tint == "green":
		spill = dilated & (g - np.maximum(r, b) > 25)
	else:
		spill = dilated & (b - np.maximum(r, g) > 25)

	ring = dilated & ~placeholder_mask
	brightness = np.maximum(np.maximum(r, g), b)
	saturation = brightness - np.minimum(np.minimum(r, g), b)
	outline = ring & (brightness < 72) & (saturation < 28)

	kill = placeholder_mask | spill | outline
	out[..., 3] = np.where(kill, 0.0, out[..., 3])
	return out


# ---------------------------------------------------------------------------
# PCA
# ---------------------------------------------------------------------------

@dataclass
class PcaResult:
	center: tuple
	axis: tuple  # 主方向单位向量 (dx, dy)
	min_proj: float
	max_proj: float
	count: int


def pca_mask(mask: np.ndarray) -> PcaResult | None:
	ys, xs = np.nonzero(mask)
	n = xs.size
	if n == 0:
		return None
	pts = np.stack([xs.astype(np.float64), ys.astype(np.float64)], axis=1)
	center = pts.mean(axis=0)
	centered = pts - center
	cov = np.cov(centered.T)
	if cov.shape == ():
		cov = np.array([[cov, 0], [0, 0]])
	eigvals, eigvecs = np.linalg.eigh(cov)
	axis = eigvecs[:, np.argmax(eigvals)]
	proj = centered @ axis
	return PcaResult(
		center=(float(center[0]), float(center[1])),
		axis=(float(axis[0]), float(axis[1])),
		min_proj=float(proj.min()),
		max_proj=float(proj.max()),
		count=n,
	)


def _largest_component(mask: np.ndarray) -> np.ndarray:
	labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
	if n == 0:
		return mask
	if n == 1:
		return mask
	sizes = ndimage.sum(np.ones_like(labels), labels, index=np.arange(1, n + 1))
	best = int(np.argmax(sizes)) + 1
	return labels == best


def _robust_axis_fit(pts: np.ndarray):
	"""对一组点做 PCA，并迭代剔除偏离主轴较远的离群点（比如手部抗锯齿产生的
	杂色团块），返回最终的 (center, axis, min_proj, max_proj)。"""
	cur = pts
	for _ in range(3):
		center = cur.mean(axis=0)
		centered = cur - center
		cov = np.cov(centered.T)
		if cov.shape == ():
			cov = np.array([[cov, 0.0], [0.0, 0.0]])
		eigvals, eigvecs = np.linalg.eigh(cov)
		axis = eigvecs[:, np.argmax(eigvals)]
		normal = np.array([-axis[1], axis[0]])
		perp = centered @ normal
		thresh = max(2.5, float(np.median(np.abs(perp))) * 3.0 + 1.5)
		keep = np.abs(perp) <= thresh
		if keep.sum() < 10 or keep.all():
			cur = cur[keep] if keep.sum() >= 10 else cur
			break
		cur = cur[keep]
	center = cur.mean(axis=0)
	centered = cur - center
	cov = np.cov(centered.T)
	if cov.shape == ():
		cov = np.array([[cov, 0.0], [0.0, 0.0]])
	eigvals, eigvecs = np.linalg.eigh(cov)
	axis = eigvecs[:, np.argmax(eigvals)]
	proj = centered @ axis
	return center, axis, float(proj.min()), float(proj.max())


def rod_endpoints(mask: np.ndarray, body_centroid: tuple, rule: str = "tip_far") -> dict | None:
	"""求绿杆的 butt / tip。

	绿杆掩码常常在握持处和抗锯齿边缘上粘连一小团杂色（比如和肤色/衣服混出的
	像素），直接对全部像素做 PCA 会被这团偏离主轴的像素带偏，所以先取最大连
	通域，再做一次鲁棒的主轴拟合（剔除偏离主轴较远的点）。

	哪一端是 tip（武器头）哪一端是 butt（握端）默认按"离身体质心更远的是
	tip"判断，但这条规则在一些动作行里不成立（比如瞄准/倒提着的枪），可以按
	(body_id, action) 在 overrides.json 里配置成下列规则之一：
	  - tip_far（默认）：离身体质心更远的端点是 tip；
	  - tip_right：x 较大的端点是 tip；
	  - tip_left：x 较小的端点是 tip；
	  - tip_up：y 较小（更靠上）的端点是 tip。
	"""
	if int(mask.sum()) < 30:
		return None
	main = _largest_component(mask)
	ys, xs = np.nonzero(main)
	if xs.size < 30:
		return None
	pts = np.stack([xs.astype(np.float64), ys.astype(np.float64)], axis=1)
	center, axis, min_proj, max_proj = _robust_axis_fit(pts)
	cx, cy = center
	ax, ay = axis
	p1 = (cx + ax * min_proj, cy + ay * min_proj)
	p2 = (cx + ax * max_proj, cy + ay * max_proj)
	if rule == "tip_right":
		tip, butt = (p1, p2) if p1[0] >= p2[0] else (p2, p1)
	elif rule == "tip_left":
		tip, butt = (p1, p2) if p1[0] <= p2[0] else (p2, p1)
	elif rule == "tip_up":
		tip, butt = (p1, p2) if p1[1] <= p2[1] else (p2, p1)
	else:
		bx, by = body_centroid
		d1 = (p1[0] - bx) ** 2 + (p1[1] - by) ** 2
		d2 = (p2[0] - bx) ** 2 + (p2[1] - by) ** 2
		tip, butt = (p1, p2) if d1 >= d2 else (p2, p1)
	return {"tip": tip, "butt": butt}


def marker_centroid(mask: np.ndarray, min_px: int = 10) -> tuple | None:
	"""点状占位物（比如铁骷髅马鞍上代表髋部接点的实心方块）的质心。

	取最大连通域再求质心，避免抗锯齿杂色把质心带偏；像素数低于 min_px 时
	记 None（比如死亡动画后几帧方块可能被身体遮住或帧为空）。
	"""
	if int(mask.sum()) < min_px:
		return None
	main = _largest_component(mask)
	ys, xs = np.nonzero(main)
	if xs.size < min_px:
		return None
	return (float(xs.mean()), float(ys.mean()))


def disc_params(mask: np.ndarray) -> dict | None:
	if int(mask.sum()) < 30:
		return None
	mask = _largest_component(mask)
	ys, xs = np.nonzero(mask)
	pts = np.stack([xs.astype(np.float64), ys.astype(np.float64)], axis=1)
	center = pts.mean(axis=0)
	centered = pts - center
	cov = np.cov(centered.T)
	eigvals, eigvecs = np.linalg.eigh(cov)
	order = np.argsort(eigvals)[::-1]
	eigvals = eigvals[order]
	eigvecs = eigvecs[:, order]
	major_axis = eigvecs[:, 0]
	# 轴长按投影范围估计（约等于 2*sqrt(2)*std，这里直接用投影极差更稳）
	proj_major = centered @ eigvecs[:, 0]
	proj_minor = centered @ eigvecs[:, 1]
	a = float(proj_major.max() - proj_major.min()) / 2.0
	b = float(proj_minor.max() - proj_minor.min()) / 2.0
	angle = float(np.degrees(np.arctan2(major_axis[1], major_axis[0])))
	return {
		"center": (float(center[0]), float(center[1])),
		"axes": (a, b),
		"angle": angle,
	}


def body_centroid(cell: np.ndarray, placeholder_mask: np.ndarray) -> tuple:
	opaque = (cell[..., 3] > 0) & ~placeholder_mask
	ys, xs = np.nonzero(opaque)
	if xs.size == 0:
		h, w = cell.shape[:2]
		return (w / 2.0, h / 2.0)
	return (float(xs.mean()), float(ys.mean()))


def grid_cells(img: np.ndarray, rows: int, cols: int):
	"""按实际宽高均分网格，返回 [(row, col, cell_array, (x0,y0))]。"""
	h, w = img.shape[:2]
	cw = w / cols
	ch = h / rows
	out = []
	for row in range(rows):
		for col in range(cols):
			x0 = int(round(col * cw))
			x1 = int(round((col + 1) * cw))
			y0 = int(round(row * ch))
			y1 = int(round((row + 1) * ch))
			out.append((row, col, img[y0:y1, x0:x1].copy(), (x0, y0)))
	return out


def rightmost_point(cell: np.ndarray) -> tuple | None:
	"""最右侧不透明列的 y 中点。用于没有占位物、只能从身体本身的轮廓里取
	骑枪尖端（比如 darth_lancer 的 lance_tip）的情况。"""
	opaque = cell[..., 3] > 0
	ys, xs = np.nonzero(opaque)
	if xs.size == 0:
		return None
	x_max = int(xs.max())
	col_ys = ys[xs == x_max]
	return (float(x_max), float((col_ys.min() + col_ys.max()) / 2.0))


def bbox_of_alpha(cell: np.ndarray):
	opaque = cell[..., 3] > 0
	ys, xs = np.nonzero(opaque)
	if xs.size == 0:
		return None
	return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def resize_lanczos(cell: np.ndarray, scale: float) -> np.ndarray:
	h, w = cell.shape[:2]
	nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
	img = Image.fromarray(np.clip(cell, 0, 255).astype(np.uint8), mode="RGBA")
	img = img.resize((nw, nh), resample=Image.LANCZOS)
	return np.asarray(img).astype(np.float32)


def fringe_pixel_count(cell: np.ndarray) -> int:
	"""边缘 3px 内高饱和红/绿/品红像素数，用于质量指标。"""
	opaque = cell[..., 3] > 0
	if not opaque.any():
		return 0
	border = opaque & ~ndimage.binary_erosion(opaque, iterations=3)
	r, g, b = cell[..., 0], cell[..., 1], cell[..., 2]
	red = (r - np.maximum(g, b) > 60) & border
	green = (g - np.maximum(r, b) > 60) & border
	magenta = (np.minimum(r, b) - g > 60) & border
	return int((red | green | magenta).sum())
