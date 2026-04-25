# 搬箱计划 / Sokoban Project

> 经典推箱子，焕新登场 —— 多色配对、内置编辑器、257 关挑战等你来解。

**搬箱计划** 是一款基于经典 Sokoban 规则的 2D 益智解谜游戏。它在保留传统「推箱子」核心乐趣的基础上，加入了**多色箱子与中性槽匹配机制**，让谜题不再只围绕位置，更围绕颜色分配与路线调度展开。

游戏内置**面向玩家开放的关卡编辑器**——你可以在游戏中直接绘制地形、配置多色内容、测试游玩、导入导出为 JSON/XSB/分享码，甚至用内置求解器验证关卡的可解性。

- **引擎**：Godot 4.6
- **类型**：2D 益智解谜 / Sokoban
- **平台**：Windows / macOS / Linux / Web
- **语言**：简体中文 / 繁體中文 / English
- **关卡数**：257 关（含 3 个章节 + 玩家自制关卡）
- **协议**：代码 `MIT`，关卡数据 `CC-BY 4.0`

## 核心特色

- 经典推箱子规则，支持撤销 / 重做 / 重玩
- **多色箱子和中性槽**机制——颜色不同，策略不同
- **内置关卡编辑器**——绘制、着色、测试、求解验证、导入导出、分享码
- 官方 257 关（教学 + Microban + XSB 精选），附带星级评分
- 玩家关卡接入主流程，制作、保存、游玩一气呵成
- 双输入系统（键盘 + 手柄），运行时按键重绑，动态按键提示
- 三语本地化，音量调节，高对比度 & 减弱动画辅助功能
- 求解器后台验证 IDA\*

## 关卡章节

| 章节 | 关卡数 | 说明 |
|------|--------|------|
| W1 · 仓库入门 | 12 关 | 原创教学章节，逐步引入推箱、多色、中性槽 |
| W2 · Microban | 155 关 | 完整收录 David W. Skinner 经典 Microban 关卡集 |
| W3 · XSB 精选 | 90 关 | 经典 XSB 题集精选，尺寸更大、解法更深 |

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

当前仓库提供 headless 自检脚本，GitHub Actions 已切换为基于 `godot-ci` 容器镜像的执行方式，后续会逐步补齐 `gdUnit4` 测试体系。

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

[![status](https://github.com/0999312/Sokoban-Project/actions/workflows/test.yml/badge.svg)](https://github.com/0999312/Sokoban-Project/actions)

## 协议与鸣谢

- 代码：`MIT`
- 关卡数据：`CC-BY 4.0`
- 美术资源：见 `assets/` 内许可证说明（Kenney CC0）
- 音乐（BGM）：[甘茶の音楽工房](https://amachamusic.chagasi.com/)（使用许可请参见该网站使用规约）
- 音效：gdfxr（sfxr 生成工具）产出的 .sfxr 文件
- 第三方插件：见各自 `addons/*/LICENSE`

## 构建与发布

### 导出预设

| 预设 | 平台 | 格式 |
|------|------|------|
| `Windows Desktop` | Windows (x86_64) | `.exe` |
| `Linux` | Linux (x86_64) | 可执行文件 |
| `macOS` | macOS (x86_64) | `.zip` |
| `Web` | HTML5 / WASM | `.zip` |

### 自动发布流程

打 tag 即触发 GitHub Actions 自动构建：

```bash
git tag v1.0.0
git push origin v1.0.0
```

构建流程（基于 `godot-ci`）：
1. ✅ 运行所有 headless 测试
2. 📦 导出 Windows / Linux / macOS / Web 四平台
3. 📋 自动生成 Release Notes（含 commit 列表）
4. 🚀 发布到 GitHub Releases 附加二进制文件
