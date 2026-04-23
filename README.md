# Sokoban (Godot 4.6)

经典推箱子 + 玩家关卡编辑器。免费开源（代码 MIT，关卡数据 CC-BY 4.0）。

## 快速开始

1. Godot 4.6+ 打开本目录
2. F5 启动 → 看到 MainMenu 即代表 Phase 0 通过

## 文档

| 文档 | 用途 |
|---|---|
| [`docs/godot-prompter/specs/GDD.md`](docs/godot-prompter/specs/GDD.md) | **游戏设计文档（GDD）— 单一事实源** |
| [`docs/godot-prompter/plans/IMPLEMENTATION.md`](docs/godot-prompter/plans/IMPLEMENTATION.md) | **分阶段实施计划与任务清单** |
| [`docs/godot-prompter/specs/LEVEL_DESIGN_GUIDE.md`](docs/godot-prompter/specs/LEVEL_DESIGN_GUIDE.md) | 关卡设计规范（XSB 格式、难度梯度） |
| [`levels/templates/blank.xsb`](levels/templates/blank.xsb) | 关卡草图空白模板 |
| [`levels/official/w1/`](levels/official/w1/) | W1 章节（首发 5 关示例） |

## 目录结构

```
res://
├─ addons/                    # mc_game_framework / sound_manager / guide
├─ assets/                    # Kenney Sokoban 美术资源
├─ core/                      # 游戏核心模块（level / board / solver / rendering / game）
├─ scenes/                    # 顶层场景（boot / main_menu / level_select / game / editor）
├─ ui/                        # 通用 UI（Theme / Toast / Dialog）
├─ locale/                    # i18n CSV
├─ levels/
│  ├─ official/wN/            # 官方章节
│  └─ templates/              # 草图模板
├─ resources/                 # Theme、配置资源
└─ tests/                     # GUT 测试
docs/
└─ godot-prompter/
   ├─ specs/                  # GDD / 设计规范
   └─ plans/                  # 实施计划
```

## 当前状态

**Phase 2 — UI / 流程 / 存档：完成 ✅**。下一步进入 Phase 3（求解器）。

主要功能现已可用：
- 主菜单 / 关卡选择（带星级与最佳步数）
- 游戏 HUD：四按钮 + 暂停面板 + 通关弹窗（带 ★ 弹出动画）
- 设置面板：语言（中简/中繁/英）、三总线音量、全屏、高对比度、减弱动画
- 存档自动持久化，支持 Steam Cloud 路径
- 完整 i18n（运行时切换无需重启）

---

## 与 AI 助手协作（会话恢复指南）

本项目使用 OpenCode + GodotPrompter 技能集开发。**当你开启新对话时**，把以下内容粘贴给 AI 即可无缝继续：

```
项目：Godot 4.6 Sokoban（含关卡编辑器），免费开源，GDScript。
请阅读以下入口文件，按当前 Phase 继续工作：

1. docs/godot-prompter/specs/GDD.md         — 设计基线（不要改动决策，除非我明确要求）
2. docs/godot-prompter/plans/IMPLEMENTATION.md — 任务清单与进度（更新此文件勾选完成项）
3. docs/godot-prompter/specs/LEVEL_DESIGN_GUIDE.md — 关卡设计规范

工作约定：
- 重度复用 addons/mc_game_framework（EventBus/I18NManager/UIManager/RegistryManager/Tag）
- 输入走 addons/guide；音频走 addons/sound_manager
- 关卡数据格式：JSON（内部）+ XSB（导入/导出）
- 实施前先读 IMPLEMENTATION.md 找到当前活动 Phase 与未完成的最早一项
- 完成子任务后在 IMPLEMENTATION.md 中把 [ ] 改为 [x]
- 涉及 Godot 系统时，先 invoke 对应的 godot-prompter:* 技能
```

### 推荐技能（按 Phase）

| Phase | 技能 |
|---|---|
| 全程 | `godot-prompter:gdscript-patterns`、`godot-prompter:event-bus` |
| Phase 0 | `godot-project-setup`、`scene-organization` |
| Phase 1 | `input-handling`、`tween-animation`、`2d-essentials`、`godot-testing` |
| Phase 2 | `godot-ui`、`hud-system`、`save-load`、`localization`、`responsive-ui` |
| Phase 3 | `gdscript-patterns`（Worker） |
| Phase 4 | `godot-ui`、`scene-organization` |
| Phase 5 | `audio-system`、`particles-vfx`、`animation-system` |
| Phase 6 | `export-pipeline`、`godot-optimization` |

## 协议

- 代码：MIT
- 关卡数据：CC-BY 4.0
- 美术资源：见 `assets/` 内 LICENSE（Kenney CC0）
- 第三方插件：见各自 `addons/*/LICENSE`
