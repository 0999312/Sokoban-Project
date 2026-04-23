# 搬箱计划 / Sokoban Project

经典推箱子玩法，加入多色箱子与中性槽机制，并内置面向玩家开放的关卡编辑器。

- 引擎：Godot 4.6
- 类型：2D 益智解谜 / Sokoban
- 平台基线：PC
- 语言：简体中文 / 繁体中文 / English
- 协议：代码 `MIT`，关卡数据 `CC-BY 4.0`

## 项目简介

`搬箱计划` 是一个以经典 Sokoban 为基础的成品游戏项目。

它保留了传统推箱子的清晰规则，同时引入了更有设计空间的扩展机制：

- 多色箱子
- 多色目标点
- 中性槽
- 内置关卡编辑器

玩家既可以直接游玩官方关卡，也可以在游戏内制作、验证、保存并分享自定义关卡。

## 当前版本内容

当前版本已接入 `257` 关：

- `W1` 原创教学章节：12 关
- `W2` Microban：155 关
- `W3` XSB 精选：90 关

当前版本的难度曲线仍可继续调整，但核心内容、主流程与编辑器能力已经完整可用。

## 核心特色

- 经典推箱子规则，支持 Undo / Redo / Restart
- 多色箱子与中性槽机制，扩展传统谜题设计空间
- 官方关卡与玩家关卡共存
- 内置关卡编辑器，支持测试游玩与求解验证
- 支持 JSON / XSB / 分享码导入导出
- 支持键盘与手柄，支持运行时按键重绑
- 支持本地化切换、音量设置、高对比度与减弱动画

## 快速开始

1. 使用 `Godot 4.6+` 打开项目目录
2. 运行主场景：`res://scenes/boot/Boot.tscn`
3. 或直接在编辑器中按 `F5` 启动项目

## 主要目录

```text
res://
├─ addons/        # 第三方插件与框架
├─ assets/        # 美术与音频资源
├─ autoload/      # 全局单例服务
├─ core/          # 核心玩法、关卡、求解器、渲染、输入
├─ levels/        # 官方关卡与模板
├─ locale/        # JSON 本地化资源
├─ scenes/        # Boot / Menu / LevelSelect / Game / Editor
├─ ui/            # 通用 UI 与设置面板
└─ tests/         # headless 自检脚本
```

## 开发与测试

当前仓库提供 headless 自检脚本，后续会逐步补齐 `gdUnit4` 测试体系。

可直接运行：

- `godot --headless --script res://tests/smoke_test.gd`
- `godot --headless --script res://tests/solver_test.gd`
- `godot --headless --script res://tests/editor_test.gd`

## 文档

- [`docs/godot-prompter/specs/PRODUCT_DESCRIPTION.md`](docs/godot-prompter/specs/PRODUCT_DESCRIPTION.md)：产品说明书
- [`docs/godot-prompter/specs/PROJECT_ANALYSIS.md`](docs/godot-prompter/specs/PROJECT_ANALYSIS.md)：项目分析与产品梳理
- [`docs/godot-prompter/specs/GDD.md`](docs/godot-prompter/specs/GDD.md)：游戏设计文档
- [`docs/godot-prompter/specs/LEVEL_DESIGN_GUIDE.md`](docs/godot-prompter/specs/LEVEL_DESIGN_GUIDE.md)：关卡设计规范
- [`docs/godot-prompter/plans/IMPLEMENTATION.md`](docs/godot-prompter/plans/IMPLEMENTATION.md)：实施计划与开发记录
- [`docs/STANDARD_SCORING_WORKFLOW.md`](docs/STANDARD_SCORING_WORKFLOW.md)：标准评分工作流

## 后续方向

- 继续打磨章节难度曲线
- 增强玩家向编辑器体验
- 统一并扩展社区翻译流程
- 补齐 `gdUnit4` 测试
- 评估移动端交互与界面适配

## 协议与鸣谢

- 代码：`MIT`
- 关卡数据：`CC-BY 4.0`
- 美术资源：见 `assets/` 内许可证说明（Kenney CC0）
- 第三方插件：见各自 `addons/*/LICENSE`
