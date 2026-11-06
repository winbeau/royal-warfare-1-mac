"""身体动作图处理（docs/ch2-art-pipeline.md 第 2 节）。"""
from __future__ import annotations

import os
import numpy as np

import common


def process_body(cfg: dict, overrides: dict, report: list) -> dict:
	body_id = cfg["id"]
	has_rod = cfg.get("has_rod", True)
	# marker_point：绿色占位物是一个点状标记（比如铁骷髅马鞍上代表髋部接点的
	# 实心方块），不是杆，只取质心存成 "hip"，不做杆的直线拟合。
	has_marker = cfg.get("marker_point", False)
	raw_path = common.repo_path("build", "ch2_art", "raw", cfg["raw"])
	img = common.load_rgba(raw_path)
	rows, cols = cfg["rows"], cfg["cols"]
	cells = common.grid_cells(img, rows, cols)

	# 按 (row, col) 索引
	by_pos = {(r, c): cell for r, c, cell, _ in cells}

	rod_flip_overrides = overrides.get("rod_flip", {})
	tip_rule_overrides = overrides.get("tip_rule", {})
	row_to_action = {action["row"]: action["name"] for action in cfg["actions"]}

	# 第一步：在未清理的原图上取占位物像素，并求身体质心（排除占位物）
	# darth_lancer 这类没有绿杆占位物的身体图（has_rod=false），骑枪直接画在
	# 身体上，不走占位物流程。marker_point 的身体图（比如铁骷髅马）绿色占位物
	# 是个点，检测用同一个 rod_mask，但后面按质心取点而不是按直线拟合。
	raw_rod_masks = {}
	raw_disc_masks = {}
	centroids = {}
	for (r, c), cell in by_pos.items():
		rmask = common.rod_mask(cell) if (has_rod or has_marker) else np.zeros(cell.shape[:2], dtype=bool)
		dmask = common.disc_mask(cell) if cfg["has_disc"] else np.zeros(cell.shape[:2], dtype=bool)
		raw_rod_masks[(r, c)] = rmask
		raw_disc_masks[(r, c)] = dmask
		centroids[(r, c)] = common.body_centroid(cell, rmask | dmask)

	# 第二步：清理 + 第三/四步：杆/盘变换 + 第五步：抠占位物
	cleaned = {}
	rod_info = {}
	disc_info = {}
	marker_info = {}
	missing_rod_frames = 0
	for (r, c), cell in by_pos.items():
		placeholder = raw_rod_masks[(r, c)] | raw_disc_masks[(r, c)]
		clean = common.clean_cell(cell, placeholder)

		rmask = raw_rod_masks[(r, c)]
		if has_rod:
			ov_key = f"{body_id}/{r}/{c}"
			action_name = row_to_action.get(r)
			rule = tip_rule_overrides.get(f"{body_id}/{action_name}", "tip_far")
			ep = common.rod_endpoints(rmask, centroids[(r, c)], rule=rule)
			if ep is not None and rod_flip_overrides.get(ov_key) == "flip":
				ep = {"tip": ep["butt"], "butt": ep["tip"]}
			if ep is None:
				missing_rod_frames += 1
		else:
			ep = None
		rod_info[(r, c)] = ep
		marker_info[(r, c)] = common.marker_centroid(rmask) if has_marker else None

		dmask = raw_disc_masks[(r, c)]
		disc_info[(r, c)] = common.disc_params(dmask) if cfg["has_disc"] else None

		if has_rod or has_marker:
			clean = common.strip_placeholder(clean, rmask, "green")
		if cfg["has_disc"]:
			clean = common.strip_placeholder(clean, dmask, "blue")
		cleaned[(r, c)] = clean

	# 第六步：缩放。以 idle(row0) 第0帧（去占位物后）的身体高度为准
	ref_cell = cleaned[(0, 0)]
	ref_bbox = common.bbox_of_alpha(ref_cell)
	if ref_bbox is None:
		raise RuntimeError(f"{body_id}: idle 第 1 帧为空")
	ref_h = ref_bbox[3] - ref_bbox[1]
	target_h = cfg["logical_height"] * 2.0
	scale = target_h / ref_h

	scaled = {}
	rod_scaled = {}
	disc_scaled = {}
	marker_scaled = {}
	for (r, c), cell in cleaned.items():
		scaled[(r, c)] = common.resize_lanczos(cell, scale)
		mp = marker_info[(r, c)]
		marker_scaled[(r, c)] = (mp[0] * scale, mp[1] * scale) if mp is not None else None
		ep = rod_info[(r, c)]
		if ep is not None:
			rod_scaled[(r, c)] = {
				"tip": (ep["tip"][0] * scale, ep["tip"][1] * scale),
				"butt": (ep["butt"][0] * scale, ep["butt"][1] * scale),
			}
		else:
			rod_scaled[(r, c)] = None
		dp = disc_info[(r, c)]
		if dp is not None:
			disc_scaled[(r, c)] = {
				"center": (dp["center"][0] * scale, dp["center"][1] * scale),
				"axes": (dp["axes"][0] * scale, dp["axes"][1] * scale),
				"angle": dp["angle"],
			}
		else:
			disc_scaled[(r, c)] = None

	# 第七步：对齐。每行取质心 x 中位数作水平锚点，脚底基线为每帧最低不透明行
	actions = cfg["actions"]
	origins = {}
	max_w = 0
	max_h = 0
	max_jump = 0.0
	height_diffs = []
	for action in actions:
		row = action["row"]
		row_cells = [(row, c) for c in range(cols)]
		cents_x = []
		baselines = []
		heights = []
		for pos in row_cells:
			bbox = common.bbox_of_alpha(scaled[pos])
			if bbox is None:
				cents_x.append(None)
				baselines.append(None)
				heights.append(None)
				continue
			opaque = scaled[pos][..., 3] > 0
			ys, xs = np.nonzero(opaque)
			cents_x.append(float(xs.mean()))
			baselines.append(int(ys.max()) + 1)
			heights.append(bbox[3] - bbox[1])
		valid_cx = [v for v in cents_x if v is not None]
		anchor_x = float(np.median(valid_cx)) if valid_cx else 0.0
		prev_h = None
		for ci, pos in enumerate(row_cells):
			baseline = baselines[ci]
			if baseline is None:
				origins[pos] = (anchor_x, 0)
				continue
			origins[pos] = (anchor_x, baseline)
			bbox = common.bbox_of_alpha(scaled[pos])
			w = bbox[2] - bbox[0]
			h = bbox[3] - bbox[1]
			ox, oy = origins[pos]
			left = ox - bbox[0]
			max_w = max(max_w, w, int(ox - bbox[0]) + (bbox[2] - int(ox)))
			max_h = max(max_h, h)
			if prev_h is not None and heights[ci] is not None:
				diff_pct = abs(heights[ci] - prev_h) / prev_h * 100.0 if prev_h else 0.0
				height_diffs.append(diff_pct)
			if heights[ci] is not None:
				prev_h = heights[ci]
		# 原点 x 跳动（锚点本来就统一，这里记录质心的跳动供报告参考）
		xs_valid = [v for v in cents_x if v is not None]
		if len(xs_valid) > 1:
			max_jump = max(max_jump, max(xs_valid) - min(xs_valid))

	cell_w = max_w + 4  # 留 2px 间隙（左右各留出一点）
	cell_h = max_h + 4

	# 第八步：打包
	lance_tip_actions = set(cfg.get("lance_tip_actions", []))
	out_rows = len(actions)
	atlas = np.zeros((out_rows * cell_h, cols * cell_w, 4), dtype=np.float32)
	actions_json = {}
	for ai, action in enumerate(actions):
		row = action["row"]
		need_lance_tip = action["name"] in lance_tip_actions
		frames_json = []
		for c in range(cols):
			pos = (row, c)
			cell = scaled[pos]
			ox, oy = origins[pos]
			ch, cw = cell.shape[:2]
			# 粘贴位置：让原点落在格子的 (cell_w/2, cell_h - 2) 附近
			dest_origin_x = cell_w / 2.0
			dest_origin_y = cell_h - 2.0
			px = int(round(dest_origin_x - ox))
			py = int(round(dest_origin_y - oy))
			dx0, dy0 = ai * cell_h + max(py, 0), c * cell_w + max(px, 0)
			# 粘贴（裁剪越界部分）
			sy0 = max(0, -py)
			sx0 = max(0, -px)
			y0 = ai * cell_h + max(py, 0)
			x0 = c * cell_w + max(px, 0)
			y1 = min(atlas.shape[0], y0 + (ch - sy0))
			x1 = min(atlas.shape[1], x0 + (cw - sx0))
			h_cp = max(0, y1 - y0)
			w_cp = max(0, x1 - x0)
			if h_cp > 0 and w_cp > 0:
				atlas[y0:y1, x0:x1] = cell[sy0:sy0 + h_cp, sx0:sx0 + w_cp]
			region = [c * cell_w, ai * cell_h, cell_w, cell_h]
			origin_in_cell = [dest_origin_x, dest_origin_y]
			# rod / disc 坐标按 docs 要求存成相对原点的偏移（而不是格子内绝对坐标），
			# 这样与 padding/贴图位置无关，QA 脚本再加回 origin 得到绝对位置。
			ep = rod_scaled[pos]
			dp = disc_scaled[pos]
			rod_json = None
			if ep is not None:
				rod_json = {
					"butt": [ep["butt"][0] - ox, ep["butt"][1] - oy],
					"tip": [ep["tip"][0] - ox, ep["tip"][1] - oy],
				}
			disc_json = None
			if dp is not None:
				disc_json = {
					"center": [dp["center"][0] - ox, dp["center"][1] - oy],
					"axes": list(dp["axes"]),
					"angle": dp["angle"],
				}
			lance_tip_json = None
			if need_lance_tip:
				rp = common.rightmost_point(cell)
				if rp is not None:
					lance_tip_json = [rp[0] - ox, rp[1] - oy]
			hip_json = None
			if has_marker:
				mp = marker_scaled[pos]
				if mp is not None:
					hip_json = [mp[0] - ox, mp[1] - oy]
			frames_json.append({
				"region": region,
				"origin": origin_in_cell,
				"rod": rod_json,
				"disc": disc_json,
				"lance_tip": lance_tip_json,
				**({"hip": hip_json} if has_marker else {}),
			})
		actions_json[action["name"]] = {"row": ai, "frames": frames_json, "done": action["done"]}

	out_dir = common.repo_path("assets", "ch2", "units", body_id)
	common.save_rgba(atlas, os.path.join(out_dir, "atlas.png"))
	body_json = {
		"id": body_id,
		"scale_note": "2x, draw at 0.5",
		"logical_height": cfg["logical_height"],
		"cell": [cell_w, cell_h],
		"actions": actions_json,
	}
	common.save_json(os.path.join(out_dir, "body.json"), body_json)

	fringe_total = sum(common.fringe_pixel_count(cell) for cell in scaled.values())
	missing_marker = sum(1 for v in marker_scaled.values() if v is None) if has_marker else 0
	extra = f", 接点缺失帧数 {missing_marker}" if has_marker else ""
	report.append(f"[body] {body_id}: 相邻帧高度差最大 {max(height_diffs) if height_diffs else 0:.2f}%, "
		f"原点x最大跳动 {max_jump:.2f}px, 杆缺失帧数 {missing_rod_frames}, 毛边像素 {fringe_total}{extra}")

	return {
		"body_id": body_id,
		"body_json": body_json,
		"scaled": scaled,
		"origins": origins,
		"rod_scaled": rod_scaled,
		"disc_scaled": disc_scaled,
		"cell_size": (cell_w, cell_h),
	}


def run_all(report: list) -> dict:
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	overrides = common.load_overrides()
	results = {}
	for cfg in src["bodies"]:
		if cfg.get("unused"):
			report.append(f"[body] {cfg['id']}: unused，跳过（造型已被否决，仅保留来源记录）")
			continue
		results[cfg["id"]] = process_body(cfg, overrides, report)
	return results


if __name__ == "__main__":
	rep: list = []
	run_all(rep)
	for line in rep:
		print(line)
