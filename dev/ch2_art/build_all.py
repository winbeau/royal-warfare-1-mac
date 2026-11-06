"""一键入口：生成第二章全部美术资源与检查图。

重复运行结果相同（幂等）。
	uv run --with pillow --with numpy --with scipy python dev/ch2_art/build_all.py
"""
from __future__ import annotations

import backgrounds
import body
import darth_rider
import icons
import qa
import vfx
import weapons


def main():
	report: list = []
	print("== body ==")
	body.run_all(report)
	print("== darth_rider ==")
	darth_rider.run_all(report)
	print("== weapons ==")
	weapons.run_all(report)
	print("== vfx ==")
	vfx.run_all(report)
	print("== backgrounds ==")
	backgrounds.run_all(report)
	print("== icons ==")
	icons_index = icons.run_all(report)
	icons.run_weapon_icons(icons_index, report)
	print("== qa ==")
	qa_report: list = []
	qa.run_all(qa_report, report)
	for line in report + qa_report:
		print(line)


if __name__ == "__main__":
	main()
