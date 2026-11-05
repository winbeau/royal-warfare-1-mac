# Royal Warfare 1 — Mac

《Royal Warfare》一代的 Godot 4 原生 macOS 重写工程，独立于二代项目。游戏行为使用 GDScript，运行时不使用 SWF、Flash、Ruffle、Wine 或原版程序。

当前版本为 `0.1.0`：完整一代资源库和战役数据已进入工程，原生战斗、关卡事件与主要界面已可运行；**尚未完成与原作的逐关、逐技能等价验收，不能视为最终无损移植版。** 验证范围及差异见 [docs/verification.md](docs/verification.md)。

![原生 Godot 主菜单](docs/screenshots/menu.png)

## 在 Mac 上运行和开发

使用 `/Applications/Godot.app`，推荐 Godot **4.7.2**：

```sh
./dev/godot.sh editor
./dev/godot.sh run
./dev/godot.sh test
./dev/godot.sh export
```

也可以在 Godot 中导入根目录的 `project.godot`。运行整个工程用编辑器右上角 ▶，或 macOS 的 `⌘B`；键盘将 F5 用作系统功能时，使用 `Fn+F5`。主场景已配置为 `scenes/main.tscn`。

导出的 `build/Royal Warfare 1.app` 内含游戏和引擎，可离开工程目录独立运行，支持 Apple Silicon 与 Intel Mac。构建需要 Godot 的 macOS 导出模板；游戏运行不需要安装 Godot。

## 内容与编辑入口

| 路径 | 内容 |
| --- | --- |
| `game/` | 原生战斗、技能、关卡调度、存档、成就和界面逻辑 |
| `scenes/ui/` | 90 个原坐标拆分的可编辑 Godot 界面场景 |
| `assets/backgrounds/` | 一代 24 组关卡背景 |
| `assets/library/` | 角色与特效图集、动画、原矢量图、字体、声音和文字 |
| `assets/ui/` | 按钮状态及界面组件贴图 |
| `data/units.json` | 46 种单位、三档属性、动画、价格与技能关联 |
| `data/campaign.json` | 序章和 24 关，含 313 个原事件、对话与初始配置 |
| `data/story.json` | 六段章节漫画与解锁条件 |
| `data/special_parameters.json` | 技能等级参数、冷却和说明 |
| `data/geometry.json` | 原路线、地图元素变换及障碍多边形 |
| `data/bonuses.json` | 15 种可招募单位的星级加成 |
| `data/encyclopedia.json` | 26 种敌人说明及 48 项成就说明 |
| `data/xml/` | 完整一代的关卡和单位内容数据 |

角色和背景可直接替换 PNG/SVG；动画使用 Godot `SpriteFrames`。兵种、数值、对白与关卡可编辑 JSON。每个原资源编号在 `data/resources.json` 中都有对应文件。原始下载包、反编译源码、转换工具和过程日志仅留本地，不进入该仓库。

## 操作

左键选兵、拖框多选、双击选择同兵种；右键移动，点击敌人下达攻击。`Shift` 保持队形移动或追加选择。`Q/W/E/R/T` 分别选择战士、弓手、法师、牧师、盗贼；`Ctrl/⌘/Shift+数字` 保存编队，数字召回。

`A` 攻击移动、`S` 防守、按住 `Z` 显示射程、`X/C` 纵横队形；`Space/P` 暂停，`N` 选择可进阶单位，`U` 打开进阶选择。箭雨在相应关卡用 `F` 或原按钮选择落点。招募在关卡内完成；基础兵积满精英经验后可以选择两种进阶职业。星级升级在地图的 Upgrades 中设置。

存档保存在 Godot 的用户数据目录 `campaign.json`。测试使用隔离存档，不覆盖玩家进度。

原游戏内容、美术、音乐及角色的权利归原权利人所有；本仓库不授予这些内容的商业发行权。Steam 接入、商店配置和发行签名不在当前版本内。
