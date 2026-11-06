# 第二章美术处理管线（WP-C）

把 imagegen 生成的原图（`build/ch2_art/raw/`，不入库）处理成游戏可用的资源，放进 `assets/ch2/`，并写出清单 JSON。

- 方案背景见 `docs/chapter-2-plan.md` 第 3.3 节“人物与武器分离”和第 4 节；
- 公共规则见 `docs/ch2-m0-spec.md` 第 0 节：禁令、headless、日志路径和导入锁，同样适用于本包。

## 0. 工具与归属

- **脚本**：放在 `dev/ch2_art/`，Python 3。用 uv 临时带依赖运行，不在仓库里建虚拟环境：
  ```
  uv run --with pillow --with numpy --with scipy python dev/ch2_art/<脚本>.py ...
  ```
- **文件归属**：`dev/ch2_art/`、`assets/ch2/units/`、`assets/ch2/weapons/`、`assets/ch2/vfx/`、`assets/ch2/icons/`，以及 `build/ch2_art/qa/`（检查图，不入库）。
- **不准动**：`build/ch2_art/raw/` 里的原图（只读），以及其他工作包的文件。
- **入口**：一键入口 `dev/ch2_art/build_all.py`，重复运行结果相同。所有来源到输出的映射写在 `dev/ch2_art/sources.json` 里，脚本里不写死文件名。
- **坐标约定**：输出的图都是 **2 倍分辨率**，游戏里缩放 0.5 显示。下文的“逻辑像素”指 700×600 画面里的像素。

## 1. 原图现状（处理时必须应对）

- **尺寸**：网关返回的尺寸与请求不同，例如请求 2048×1280，返回 1586×992。格子大小一律按实际宽高除以行列数计算。
- **背景**：大多数图已经是透明底，`portraits_weapons_v2.png` 的第 2 行仍是品红底，需要抠掉。
- **残留**：抠底留下的红、黄、绿、紫色毛边，以及零星噪点。例如 `exorcist_body_v1.png` 有大量红边，`elementalist_body_v1.png` 有绿色溢色。
- **越格**：人物可能稍微越出格子边界，倒地帧尤其明显。所以要先在整张图上求连通域，再按连通域质心归入所在格子，不能简单按格子裁切。

## 2. 身体动作图（5 套）

### 来源

| 输出 id | 原图 | 行列 | 逻辑身高（站立待机第 1 帧） |
| --- | --- | --- | --- |
| warden_sword_shield | warden_body_v1.png | 5×8 | 37 |
| musketeer_gun | musketeer_body_v1.png | 5×8 | 36 |
| outrider_saber | outrider_body_v1.png | 5×8 | 45（含马） |
| elementalist_staff | elementalist_body_v1.png | 5×8 | 37 |
| exorcist_bell | exorcist_body_v1.png | 5×8 | 35 |

每一行的动作名与 DONE 帧（命中或出手的那一帧，0 基）：

| body | row0 | row1 | row2 | row3 | row4 |
| --- | --- | --- | --- | --- | --- |
| warden_sword_shield | idle | walk | attack（DONE=4） | skill（DONE=4） | death |
| musketeer_gun | idle | walk | attack（DONE=4，开火帧） | reload | death |
| outrider_saber | idle | walk（小跑） | run（奔驰） | attack（DONE=4） | death |
| elementalist_staff | idle | walk | attack（DONE=4） | skill（DONE=4） | death |
| exorcist_bell | idle | walk | attack（DONE=4） | skill（DONE=4） | death |

death 行的前 2 帧同时用作受击（hit）。

### 处理步骤（在原图分辨率下进行，最后才缩放）

1. **取占位物**：先在未清理的原图上取出绿杆和蓝盘的像素，结果保留下来供后面使用。
   - 绿杆：`G ≥ 170`、`R ≤ 110`、`B ≤ 110`，且 `G − max(R, B) ≥ 90`；
   - 蓝盘：`B ≥ 170`、`R ≤ 110`、`G ≤ 110`，且 `B − max(R, G) ≥ 90`。
2. **清理**：
   - alpha 小于 128 的像素置为全透明；
   - 把 alpha 掩码腐蚀 1 px；
   - 删掉面积小于该格主体面积 0.4% 的连通域；
   - 边缘 3 px 内，红、品红、黄、绿色相明显偏离主体的像素做去溢色：把超出的通道压回另外两个通道的最大值；仍然突兀的就删掉。
3. **绿杆变换**：每帧对绿杆像素做 PCA，得到中心、主方向，以及沿主方向的最小、最大投影，由此求出两个端点。
   - **尖端**（tip）：离“身体质心”更远的那个端点，身体质心按去掉绿杆、蓝盘后的不透明像素计算；
   - **握端**（butt）：另一个端点；
   - 允许在 `dev/ch2_art/overrides.json` 里按 `body/row/frame` 手动翻转端点；
   - 某帧绿杆像素少于 30 个时，记为 `null`，表示这一帧不画武器。
4. **蓝盘变换**：对蓝盘像素做 PCA，得到中心、长轴与短轴的长度、长轴角度。像素少于 30 个时记为 `null`。
5. **抠掉占位物**：把绿杆、蓝盘的像素，以及它们周围 3 px 内偏绿或偏蓝的溢色像素，全部置为全透明。
6. **缩放**：以 idle 第 1 帧的身体高度（不含占位物）为准，缩放到“逻辑身高 × 2”像素。整套用同一个比例，用 Lanczos 缩放。
7. **对齐**：
   - **脚底基线**：每帧最低的不透明行；倒地帧同样适用；
   - **水平锚点**：每一行取各帧身体质心 x 的**中位数**，整行都用这一个值，避免走路时左右抖动；
   - **原点**：放在“水平锚点，脚底基线”这一点；
   - 绿杆、蓝盘的端点与中心按同一个缩放和平移换算，写成相对原点的坐标。
8. **打包**：输出 `assets/ch2/units/<id>/atlas.png`，每帧一格，格子大小取整套里的最大包围盒，留 2 px 间隙。

### 清单 `assets/ch2/units/<id>/body.json`

```json
{
  "id": "musketeer_gun", "scale_note": "2x, draw at 0.5",
  "logical_height": 36, "cell": [w, h],
  "actions": {
    "idle":   {"row": 0, "frames": [ {"region": [x,y,w,h], "origin": [ox,oy], "rod": {"butt": [x,y], "tip": [x,y]} | null, "disc": {"center": [x,y], "axes": [a,b], "angle": deg} | null }, ... ] , "done": null},
    "attack": {"row": 2, "frames": [...], "done": 4}
  }
}
```

- `origin`：该帧原点在格子内的坐标。
- `rod` 和 `disc` 的坐标都相对原点，单位为 2 倍像素。

## 3. 武器图

| 输出 id | 原图与格子（行，列，0 基） | 逻辑长度（握端到尖端） |
| --- | --- | --- |
| dao | weapons_v1.png (0,0)，4×4 网格 | 15 |
| round_shield | weapons_v1.png (0,1) | 直径 12 |
| matchlock | portraits_weapons_v2.png (1,0)，2×5 网格，品红底 | 30 |
| cavalry_saber | weapons_v1.png (2,0) | 17 |
| wind_staff | weapons_v1.png (2,2) | 38 |
| wood_bell | weapons_v1.png (3,1) | 9 |
| stone_staff | weapons_v1.png (2,3) | 38 |
| river_staff | weapons_v1.png (3,0) | 38 |
| bronze_bell | weapons_v1.png (3,2) | 11 |
| lotus_lantern | weapons_v1.png (3,3) | 22 |
| lance | weapons_v1.png (2,1) | 44 |
| horse_cleaver | portraits_weapons_v2.png (1,2) | 30 |
| heavy_musket | portraits_weapons_v2.png (1,3) | 34 |
| five_thunders | weapons_v1.png (1,1) | 22 |
| three_eyed | weapons_v1.png (1,3) | 30 |

陌刀（great_glaive）两版都不合格，本次跳过。

- **清理**：同上；品红底先按与 (255, 0, 255) 的距离抠掉，带渐变过渡。
- **轴线**：武器是水平朝右的。
  - 握端：最左侧不透明列，取该列不透明像素 y 的中点；
  - 尖端：最右侧那一列，同样取 y 的中点；
  - 圆盾没有轴线，只记中心与半径。
- **缩放**：按逻辑长度 × 2 缩放握端到尖端的距离。
- **输出**：`assets/ch2/weapons/<id>.png`，以及 `assets/ch2/weapons/weapons.json`，每把记：
  - `size`；
  - `butt`、`tip`：图内像素坐标；
  - 火铳类另记 `muzzle`，等于 `tip`；
  - 铃类另记 `head`：铃身中心，就是图内最右侧连通的大块的中心。

## 4. 特效图

- **原图**：`vfx_v1.png`，8 行 6 列，每行一个 6 帧动画，行序见 `build/ch2_art/prompts/vfx.txt`。
- **加色特效**（行 0、2、3、4、5、6、7：火光、曳光、命中、风障、裂风、铃波、封印）：
  - 先合成到纯黑底上，输出不透明的 RGB 帧；
  - 运行时用加色混合，所以不需要 alpha。
- **硝烟**（行 1）：alpha 取亮度（`max(R, G, B)`），颜色统一成中灰偏暖的 (200, 196, 188)，输出 RGBA。
- **每个特效**：
  - 6 帧共用一个最大包围盒，按中心对齐；
  - 火光与曳光的锚点在左侧中点，也就是它朝右发出的起点，其余特效的锚点在中心；
  - 输出 `assets/ch2/vfx/<name>.png` 横排条带；
  - `assets/ch2/vfx/vfx.json` 记录 `frame_size`、`frames`、`anchor`、`blend`（`add` 或 `alpha`）。
- **名字**：
  - `muzzle_flash`
  - `powder_smoke`
  - `ball_tracer`
  - `ball_impact`
  - `wind_wall`
  - `gale_blade`
  - `bell_wave`
  - `corpse_seal`
- 尺寸：按原图格子缩小到一半，以 2 倍图计。

## 5. 一代风格图标

- **原图**：`rw1style_icons_v1.png`，6 行 6 列。
  - 第 0 行是头像：warden、musketeer、outrider、elementalist、exorcist、captain；
  - 第 1–5 行是技能：每行一个职业，依次是镇戍卫、火铳卫、游骑、术师、随军僧。每行 6 个图标的顺序是：基础武器的技能 1、技能 2，高级 A 的技能 1、技能 2，高级 B 的技能 1、技能 2。
  - 技能英文名按 `data/ch2/text/glossary.json` 的 `weapons` 与 `skills` 顺序对应，输出文件名用 snake_case 英文名，例如 `hold_fast.png`、`wind_wall.png`。
- **清理**：
  - 抠底留下了紫色光晕。把 `min(R, B) − G > 40` 且 alpha 小于 230 的像素颜色改成 (24, 22, 26)，alpha 保持不变，使其变成一代那种暗色投影；
  - 主体内部的紫色像素不动（判断依据：alpha ≥ 230）。
- **尺寸**：对齐一代原图。
  - 头像：高 180 px（一代 unitIcons 为 173–186 px），宽按比例，输出到 `assets/ch2/icons/portraits/<id>.png`；
  - 技能：最大边 96 px（一代 eAbility 约 95 px），输出到 `assets/ch2/icons/skills/<name>.png`；
  - 另写 `assets/ch2/icons/icons.json` 作为索引。

## 6. 检查图（必须做）

- **身体动作**：每套出一张 `build/ch2_art/qa/<id>_contact.png`，4 倍放大，把 5 个动作排成 5 行：
  - 每帧画出原点（红点），以及绿杆的握端到尖端连线（握端蓝点、尖端黄点）；
  - 再把对应的基础武器按挂点贴上去，另出一份 `<id>_armed.png`。贴法：武器图的 butt 对准杆的 butt，按杆的角度旋转，长度用武器的逻辑长度，不随杆长伸缩；
  - 镇戍卫另贴圆盾，中心对准蓝盘中心。
- **武器、特效、图标**：各出一张总览图。
- **质量指标**：打印到控制台并写进 `build/ch2_art/qa/report.txt`：
  - 每行动作相邻帧之间的身体高度差（百分比）；
  - 原点 x 的最大跳动；
  - 杆缺失的帧数；
  - 毛边残留像素数：边缘 3 px 内高饱和红、绿、品红像素的数量。
- **自查**：生成后用 Read 看每张检查图。挂点明显错位，比如枪托没抵在肩上、刀没在手里，就调整算法或写 overrides，不要靠手修像素。

## 7. 交付

- 处理完成后拿导入锁执行一次 `--import`，让新 PNG 生成 .import 文件。
- 在 `export_presets.cfg` 的 `include_filter` 里加上 `assets/ch2/*/*.json`。注意 WP-A 也在改这个文件，你先 Read 再做最小编辑，只追加。
- 不提交。按 ch2-m0-spec 第 4 节的格式汇报，并附上全部检查图的路径。
