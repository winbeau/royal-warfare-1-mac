"""检查图与质量报告（docs/ch2-art-pipeline.md 第 6 节）。"""
from __future__ import annotations

import math
import os
import numpy as np
from PIL import Image, ImageDraw

import common


WEAPON_FOR_BODY = {
	"warden_sword_shield": "dao",
	"musketeer_gun": "matchlock",
	"outrider_saber": "cavalry_saber",
	"elementalist_staff": "wind_staff",
	"exorcist_bell": "wood_bell",
	"warden_glaive": "great_glaive",
	# darth_lancer 没有绿杆，骑枪直接画在身体图里，不挂武器贴图。
}


def paste_rgba(dst: Image.Image, src: Image.Image, x: int, y: int):
	dst.alpha_composite(src, (int(round(x)), int(round(y))))


def contact_and_armed(body_id: str, body_json: dict, scale: int, report: list):
	atlas_path = common.repo_path("assets", "ch2", "units", body_id, "atlas.png")
	atlas = Image.open(atlas_path).convert("RGBA")
	cell_w, cell_h = body_json["cell"]
	action_names = list(body_json["actions"].keys())
	cols = max(len(a["frames"]) for a in body_json["actions"].values())

	weapon_id = WEAPON_FOR_BODY.get(body_id)
	weapon_img = None
	w_butt = w_tip = None
	if weapon_id:
		weapon_path = common.repo_path("assets", "ch2", "weapons", f"{weapon_id}.png")
		weapon_img = Image.open(weapon_path).convert("RGBA")
		weapons_meta = common.load_json(common.repo_path("assets", "ch2", "weapons", "weapons.json"))[weapon_id]
		w_butt = weapons_meta["butt"]
		w_tip = weapons_meta["tip"]

	shield_img = None
	shield_meta = None
	if body_json.get("id") == "warden_sword_shield":
		shield_img = Image.open(common.repo_path("assets", "ch2", "weapons", "round_shield.png")).convert("RGBA")
		shield_meta = common.load_json(common.repo_path("assets", "ch2", "weapons", "weapons.json"))["round_shield"]

	out_w = cols * cell_w * scale
	out_h = len(action_names) * cell_h * scale
	contact = Image.new("RGBA", (out_w, out_h), (40, 40, 40, 255))
	armed = Image.new("RGBA", (out_w, out_h), (40, 40, 40, 255))

	for ai, aname in enumerate(action_names):
		action = body_json["actions"][aname]
		for fi, frame in enumerate(action["frames"]):
			rx, ry, rw, rh = frame["region"]
			cell_img = atlas.crop((rx, ry, rx + rw, ry + rh))
			cell_big = cell_img.resize((rw * scale, rh * scale), Image.NEAREST)
			dst_x = fi * cell_w * scale
			dst_y = ai * cell_h * scale
			contact.alpha_composite(cell_big, (dst_x, dst_y))
			armed.alpha_composite(cell_big, (dst_x, dst_y))

			ox, oy = frame["origin"]
			draw_c = ImageDraw.Draw(contact)
			px, py = dst_x + ox * scale, dst_y + oy * scale
			draw_c.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(255, 0, 0, 255))

			lance_tip = frame.get("lance_tip")
			if lance_tip:
				ltx, lty = lance_tip[0] + ox, lance_tip[1] + oy
				lpx, lpy = dst_x + ltx * scale, dst_y + lty * scale
				draw_c.ellipse([lpx - 4, lpy - 4, lpx + 4, lpy + 4], outline=(0, 255, 0, 255), width=2)

			hip = frame.get("hip")
			if hip:
				hx, hy = hip[0] + ox, hip[1] + oy
				hpx, hpy = dst_x + hx * scale, dst_y + hy * scale
				draw_c.ellipse([hpx - 4, hpy - 4, hpx + 4, hpy + 4], outline=(255, 165, 0, 255), width=2)

			rod = frame.get("rod")
			if rod and weapon_img is not None:
				bx, by = rod["butt"][0] + ox, rod["butt"][1] + oy
				tx, ty = rod["tip"][0] + ox, rod["tip"][1] + oy
				bpx, bpy = dst_x + bx * scale, dst_y + by * scale
				tpx, tpy = dst_x + tx * scale, dst_y + ty * scale
				draw_c.line([bpx, bpy, tpx, tpy], fill=(255, 255, 0, 255), width=2)
				draw_c.ellipse([bpx - 3, bpy - 3, bpx + 3, bpy + 3], fill=(0, 100, 255, 255))
				draw_c.ellipse([tpx - 3, tpy - 3, tpx + 3, tpy + 3], fill=(255, 255, 0, 255))

				# 贴武器：以武器图自己的 butt 为旋转枢轴，直接绕这个点转到杆的角度，
				# 转完 butt 点保持原地不动，再整体平移到杆的 butt 绝对位置即可，
				# 不需要再对"旋转后 butt 落在哪"做任何额外换算（之前两次 bug 都出
				# 在这段手工换算上）。做法：先把武器图贴进一块足够大的方形画布，
				# 使 butt 正好落在画布中心，围绕画布中心旋转（expand=False，中心
				# 不会动），画布中心再对齐到杆的 butt 绝对坐标。
				angle = math.degrees(math.atan2(ty - by, tx - bx))
				wbx, wby = w_butt
				ww, wh = weapon_img.size
				corners = [(0.0, 0.0), (ww, 0.0), (0.0, wh), (ww, wh)]
				radius = max(math.hypot(cxp - wbx, cyp - wby) for cxp, cyp in corners)
				pad = int(math.ceil(radius)) + 2
				canvas_size = pad * 2
				pivot_canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
				pivot_canvas.alpha_composite(weapon_img, (int(round(pad - wbx)), int(round(pad - wby))))
				# PIL rotate(theta)：theta = -angle 能让武器局部 +x（butt->tip）
				# 转到目标像素方向 angle；center 用画布中心，butt 旋转前后都在这个点。
				w_rot = pivot_canvas.rotate(-angle, resample=Image.BICUBIC, center=(pad, pad), expand=False)
				w_scaled = w_rot.resize((canvas_size * scale, canvas_size * scale), Image.BICUBIC)
				paste_x = dst_x + bx * scale - pad * scale
				paste_y = dst_y + by * scale - pad * scale
				armed.alpha_composite(w_scaled, (int(round(paste_x)), int(round(paste_y))))

				# 自检：洋红画杆的 butt->tip，青色画武器图自己的 butt->tip（按同样的
				# 平移旋转变换过去），两条线应当重合。
				wtx, wty = w_tip
				# 同样按"rotate(theta) 在像素坐标里等价于用标准旋转矩阵、转角取
				# -theta"换算（theta=-angle，所以这里转角用 angle），纯粹用来画自
				# 检线，不参与实际贴图。
				rad = math.radians(angle)
				cosr, sinr = math.cos(rad), math.sin(rad)
				def _to_abs(px_, py_):
					dx_, dy_ = px_ - wbx, py_ - wby
					rx_ = dx_ * cosr - dy_ * sinr
					ry_ = dx_ * sinr + dy_ * cosr
					return (bx + rx_, by + ry_)
				w_butt_abs = _to_abs(wbx, wby)
				w_tip_abs = _to_abs(wtx, wty)
				draw_a = ImageDraw.Draw(armed)
				draw_a.line([
					dst_x + bx * scale, dst_y + by * scale,
					dst_x + tx * scale, dst_y + ty * scale,
				], fill=(255, 0, 255, 255), width=1)
				draw_a.line([
					dst_x + w_butt_abs[0] * scale, dst_y + w_butt_abs[1] * scale,
					dst_x + w_tip_abs[0] * scale, dst_y + w_tip_abs[1] * scale,
				], fill=(0, 255, 255, 255), width=1)

			disc = frame.get("disc")
			if disc and shield_img is not None:
				dcx, dcy = disc["center"][0] + ox, disc["center"][1] + oy
				dpx, dpy = dst_x + dcx * scale, dst_y + dcy * scale
				draw_c.ellipse([dpx - 4, dpy - 4, dpx + 4, dpy + 4], outline=(0, 255, 255, 255), width=2)
				s_meta = shield_meta
				s_cx, s_cy = s_meta["center"]
				s_scaled = shield_img.resize((int(shield_img.width * scale), int(shield_img.height * scale)), Image.BICUBIC)
				paste_x = dpx - s_cx * scale
				paste_y = dpy - s_cy * scale
				armed.alpha_composite(s_scaled, (int(round(paste_x)), int(round(paste_y))))

	qa_dir = common.repo_path("build", "ch2_art", "qa")
	os.makedirs(qa_dir, exist_ok=True)
	contact.convert("RGB").save(os.path.join(qa_dir, f"{body_id}_contact.png"))
	armed.convert("RGB").save(os.path.join(qa_dir, f"{body_id}_armed.png"))
	report.append(f"[qa] {body_id}: 生成 {body_id}_contact.png / {body_id}_armed.png")


def weapons_overview(report: list):
	"""武器精灵总览：每把武器的战场精灵和它的图标并排摆放，方便核对造型是否一致。"""
	meta = common.load_json(common.repo_path("assets", "ch2", "weapons", "weapons.json"))
	icons_meta = common.load_json(common.repo_path("assets", "ch2", "icons", "icons.json"))
	icon_paths = icons_meta.get("weapons", {})

	cell_w, cell_h = 220, 130
	cols = 4
	wids = list(meta.keys())
	rows = math.ceil(len(wids) / cols)
	sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (40, 40, 40, 255))
	draw = ImageDraw.Draw(sheet)
	for i, wid in enumerate(wids):
		r, c = divmod(i, cols)
		ox, oy = c * cell_w, r * cell_h

		sprite = Image.open(common.repo_path("assets", "ch2", "weapons", f"{wid}.png")).convert("RGBA")
		half_w = cell_w // 2
		scale = min((half_w - 16) / sprite.width, (cell_h - 30) / sprite.height)
		s2 = sprite.resize((max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale))), Image.LANCZOS)
		sheet.alpha_composite(s2, (ox + (half_w - s2.width) // 2, oy + (cell_h - 20 - s2.height) // 2))

		icon_rel = icon_paths.get(wid)
		if icon_rel:
			icon = Image.open(common.repo_path("assets", "ch2", "icons", icon_rel)).convert("RGBA")
			iscale = min((half_w - 16) / icon.width, (cell_h - 30) / icon.height)
			i2 = icon.resize((max(1, int(icon.width * iscale)), max(1, int(icon.height * iscale))), Image.LANCZOS)
			sheet.alpha_composite(i2, (ox + half_w + (half_w - i2.width) // 2, oy + (cell_h - 20 - i2.height) // 2))

		draw.line([ox + half_w, oy, ox + half_w, oy + cell_h], fill=(90, 90, 90, 255), width=1)
		draw.text((ox + 4, oy + cell_h - 16), wid, fill=(255, 255, 255, 255))
	qa_dir = common.repo_path("build", "ch2_art", "qa")
	sheet.convert("RGB").save(os.path.join(qa_dir, "weapons_overview.png"))
	report.append("[qa] weapons_overview.png（精灵/图标并排）")


def vfx_overview(report: list):
	meta = common.load_json(common.repo_path("assets", "ch2", "vfx", "vfx.json"))
	rows_imgs = []
	max_w = 0
	total_h = 0
	for name, info in meta.items():
		p = common.repo_path("assets", "ch2", "vfx", f"{name}.png")
		im = Image.open(p).convert("RGBA")
		rows_imgs.append((name, im))
		max_w = max(max_w, im.width)
		total_h += im.height + 20
	sheet = Image.new("RGBA", (max_w + 10, total_h), (0, 0, 0, 255))
	draw = ImageDraw.Draw(sheet)
	y = 0
	for name, im in rows_imgs:
		sheet.alpha_composite(im, (5, y))
		draw.text((5, y + im.height + 2), name, fill=(255, 255, 255, 255))
		y += im.height + 20
	qa_dir = common.repo_path("build", "ch2_art", "qa")
	sheet.convert("RGB").save(os.path.join(qa_dir, "vfx_overview.png"))
	report.append("[qa] vfx_overview.png")


def icons_overview(report: list):
	meta = common.load_json(common.repo_path("assets", "ch2", "icons", "icons.json"))
	cell = 110
	entries = [("portrait:" + k, common.repo_path("assets", "ch2", "icons", v))
		for k, v in meta["portraits"].items()]
	entries += [("skill:" + k, common.repo_path("assets", "ch2", "icons", v["path"]))
		for k, v in meta["skills"].items()]
	entries += [("weapon:" + k, common.repo_path("assets", "ch2", "icons", v))
		for k, v in meta.get("weapons", {}).items()]
	cols = 6
	rows = math.ceil(len(entries) / cols)
	sheet = Image.new("RGBA", (cols * cell, rows * cell), (60, 60, 60, 255))
	draw = ImageDraw.Draw(sheet)
	for i, (label, path) in enumerate(entries):
		r, c = divmod(i, cols)
		im = Image.open(path).convert("RGBA")
		scale = min((cell - 20) / im.width, (cell - 30) / im.height)
		im2 = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
		x = c * cell + (cell - im2.width) // 2
		y = r * cell + (cell - im2.height) // 2
		sheet.alpha_composite(im2, (x, y))
	qa_dir = common.repo_path("build", "ch2_art", "qa")
	sheet.convert("RGB").save(os.path.join(qa_dir, "icons_overview.png"))
	report.append("[qa] icons_overview.png")


def darth_mounted_contact(report: list):
	"""马 + 一代达思骑士上半身的拼合检查图（三行：form/charge 配 821，fight 配
	2311），每帧画红点标出骑手 hip 与马 hip/2 的重合点。"""
	import darth_rider

	body_json = common.load_json(common.repo_path("assets", "ch2", "units", "iron_skeleton_horse", "body.json"))
	atlas = Image.open(common.repo_path("assets", "ch2", "units", "iron_skeleton_horse", "atlas.png")).convert("RGBA")
	rider_meta = common.load_json(common.repo_path("assets", "ch2", "units", "darth_rider", "rider.json"))

	rows_spec = [
		("form", "821", 0),
		("charge", "821", 8),
		("fight", "2311", 0),
	]
	scale = 4
	cols = 8
	cell_w, cell_h = body_json["cell"]
	out_w = cols * cell_w * scale
	out_h = len(rows_spec) * cell_h * scale
	canvas = Image.new("RGBA", (out_w, out_h), (40, 40, 40, 255))
	draw = ImageDraw.Draw(canvas)

	sprite_cache = {}
	for action_name, sprite_id, frame_offset in rows_spec:
		png_path = common.repo_path("assets", "library", "sprites", sprite_id, "0.png")
		if sprite_id not in sprite_cache:
			sprite_cache[sprite_id] = (
				Image.open(png_path).convert("RGBA"),
				darth_rider.parse_regions(common.repo_path("assets", "library", "sprites", sprite_id, "frames.tres")),
			)

	for ri, (action_name, sprite_id, frame_offset) in enumerate(rows_spec):
		action = body_json["actions"][action_name]
		rider_sheet, regions = sprite_cache[sprite_id]
		for col in range(cols):
			frame = action["frames"][col]
			rx, ry, rw, rh = frame["region"]
			horse_cell = atlas.crop((rx, ry, rx + rw, ry + rh))
			# 马按 0.5 倍显示（与游戏一致），再乘检查图的放大倍数 scale
			horse_disp_scale = 0.5 * scale
			horse_big = horse_cell.resize(
				(max(1, int(rw * horse_disp_scale)), max(1, int(rh * horse_disp_scale))), Image.NEAREST
			)
			ox, oy = frame["origin"]
			dst_x = col * cell_w * scale
			dst_y = ri * cell_h * scale
			# 让马的原点落在格子里固定的位置（跟 contact_and_armed 一致）
			dest_origin_x = cell_w / 2.0 * scale
			dest_origin_y = (cell_h - 2.0) * scale
			horse_paste_x = dst_x + dest_origin_x - ox * horse_disp_scale
			horse_paste_y = dst_y + dest_origin_y - oy * horse_disp_scale
			canvas.alpha_composite(horse_big, (int(round(horse_paste_x)), int(round(horse_paste_y))))

			hip = frame.get("hip")
			if hip is None:
				continue
			horse_hip_x = ox + hip[0]
			horse_hip_y = oy + hip[1]
			# 马的 hip 是 2 倍图坐标，显示时按 0.5 倍（即 horse_disp_scale = 0.5*scale）
			# 换算成检查图像素，对应"骑手的 hip 与马该帧的 hip / 2 重合"。
			screen_hip_x = dst_x + dest_origin_x + (horse_hip_x - ox) * horse_disp_scale
			screen_hip_y = dst_y + dest_origin_y + (horse_hip_y - oy) * horse_disp_scale

			frame_idx = (frame_offset + col) % len(regions)
			rx2, ry2, rw2, rh2 = regions[frame_idx]
			rider_cut = rider_meta[sprite_id][frame_idx]
			cut_y = rider_cut["cut_y"]
			rider_hip_x, rider_hip_y = rider_cut["hip"]
			rider_cell = rider_sheet.crop((rx2, ry2, rx2 + rw2, ry2 + max(1, cut_y)))
			rider_big = rider_cell.resize((rider_cell.width * scale, rider_cell.height * scale), Image.NEAREST)
			rider_paste_x = screen_hip_x - rider_hip_x * scale
			rider_paste_y = screen_hip_y - rider_hip_y * scale
			canvas.alpha_composite(rider_big, (int(round(rider_paste_x)), int(round(rider_paste_y))))
			draw.ellipse([screen_hip_x - 3, screen_hip_y - 3, screen_hip_x + 3, screen_hip_y + 3],
				fill=(255, 0, 0, 255))

	qa_dir = common.repo_path("build", "ch2_art", "qa")
	os.makedirs(qa_dir, exist_ok=True)
	canvas.convert("RGB").save(os.path.join(qa_dir, "darth_mounted_contact.png"))
	report.append("[qa] darth_mounted_contact.png")


def run_all(report: list, build_report_lines: list):
	src = common.load_json(common.repo_path("dev", "ch2_art", "sources.json"))
	for cfg in src["bodies"]:
		if cfg.get("unused"):
			continue
		body_json = common.load_json(common.repo_path("assets", "ch2", "units", cfg["id"], "body.json"))
		contact_and_armed(cfg["id"], body_json, scale=4, report=report)
	weapons_overview(report)
	vfx_overview(report)
	icons_overview(report)
	darth_mounted_contact(report)

	qa_dir = common.repo_path("build", "ch2_art", "qa")
	os.makedirs(qa_dir, exist_ok=True)
	with open(os.path.join(qa_dir, "report.txt"), "w", encoding="utf-8") as f:
		f.write("\n".join(build_report_lines))
		f.write("\n\n")
		f.write("\n".join(report))
		f.write("\n")


if __name__ == "__main__":
	rep: list = []
	run_all(rep, [])
	for line in rep:
		print(line)
