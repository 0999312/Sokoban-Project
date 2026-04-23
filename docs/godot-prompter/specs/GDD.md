# Sokoban — Game Design Document (GDD)

> 版本：v1.0｜状态：已批准进入实施｜负责人：项目所有者
> 引擎：Godot 4.6（Mobile renderer）｜语言：GDScript｜协议：MIT（代码）+ CC-BY 4.0（关卡数据）

---

## 1. 产品定位

| 维度 | 决策 |
|---|---|
| 类型 | 经典 2D 推箱子（Sokoban）+ 玩家关卡编辑器 |
| 平台 | PC（Windows / macOS / Linux） |
| 引擎/语言 | Godot 4.6，GDScript（重度复用 `mc_game_framework`） |
| 美术 | 复用现有 Kenney Sokoban 素材 |
| 商业模式 | 免费开源 |
| 语言 | 简中 / 繁中 / 英文 |
| 存档 | 本地 `user://` JSON + Steam Cloud 兼容路径 |
| 内容量 | 50 个官方关卡（4 章 × 12-13 关） |
| UGC | 阶段 1：玩家编辑器 + 本地保存 + 分享码（Base64+CRC） |
| 阶段 2 预留 | Steam Workshop 接入（GodotSteam，后置不阻塞 v1.0） |

## 2. 核心玩法

### 2.1 规则
- 网格世界（建议 6×6 ~ 20×20）
- 单角色，回合制：每次按方向键移动 1 格
- 遇墙不能走；遇箱子时若箱子后方为空则推动；不可拉
- 所有箱子位于目标点 → 关卡完成
- 全程支持 Undo/Redo（无限）、Restart

### 2.2 元素清单（v1.0）

| 实体 | XSB 字符 | 素材 | 行为 |
|---|---|---|---|
| 墙 | `#` | tilesheet wall tile | 阻挡 |
| 地板 | ` ` | tilesheet floor tile | 可通行 |
| 玩家 | `@` | `sokoban_player.png` | 主控 |
| 玩家在目标点 | `+` | 同上+holder | — |
| 箱子（颜色 1-5） | `$` / `a-d` | `crate_{n}.png` | 可推；按颜色匹配 |
| 箱子在目标点 | `*` / `A-D` | 同上+holder | 完成态（同色或中性槽） |
| 目标点（颜色 1-5） | `.` / `1-4` | `crate_holder_{n}.png` | 静态；颜色 0 为中性槽 |
| 外部空区 | `-` | 透明 | 网格边界 |

**多类型箱子规则（v1.0 启用）**：
- 共支持 5 种颜色（`color_id = 1..5`），第 0 色 holder 为"中性槽"，可接收任意颜色箱子
- 胜利条件：每个箱子所在 holder 满足 `holder.color == 0 或 holder.color == crate.color`，且全部 holder 被占据
- 关卡内每种颜色的"非中性 holder 数"必须等于"该色箱子数"（中性槽与中性箱不参与配对计数）
- XSB 扩展：箱子 `$ a b c d` 对应颜色 1..5；holder `. 1 2 3 4` 对应颜色 0(中性) 1..4（颜色 5 holder 用 JSON 显式表达，避免与已有 XSB 字符冲突）
- 单色关卡（仅 color 1）行为完全等同于经典 Sokoban，向后兼容旧关卡

### 2.3 评分与挑战
- 三星：`steps ≤ optimal` ★★★｜`≤ optimal × 1.25` ★★｜完成 ★
- 计步、计推、计时（仅显示）
- 全局统计：累计步数、累计游玩时长、关卡通过率

## 3. 架构总览

复用 `mc_game_framework`：`EventBus`、`I18NManager`、`UIManager`、`RegistryManager`、`Tag`、`SoundManager`、`Guide` 输入。

### 3.1 自动加载（Autoload）

| 名称 | 来源 | 职责 |
|---|---|---|
| `RegistryManager` | 框架 | 注册关卡包/组件类型 |
| `EventBus` | 框架 | 全局事件 |
| `I18NManager` | 框架 | 多语言切换 |
| `UIManager` | 框架 | 场景级 UI 栈 |
| `SoundManager` | 框架 | BGM/SFX 池 |
| `GameState` | 新增 | 当前关卡、设置缓存、运行时状态 |
| `LevelLibrary` | 新增 | 官方关卡 + 用户关卡索引 |
| `SaveManager` | 新增 | JSON 存档/读档/迁移 |
| `InputManager` | 新增（基于 Guide） | 行为绑定 |

### 3.2 顶层场景结构

```
res://scenes/
  boot/Boot.tscn
  main_menu/MainMenu.tscn
  level_select/LevelSelect.tscn
  game/GameScene.tscn
    └ GameBoard (Node2D)
    └ HUD (CanvasLayer)
  editor/EditorScene.tscn
    └ EditorBoard / EditorPalette / EditorMeta / EditorTopbar
  ui/  (Toast、ConfirmDialog、Settings)
```

### 3.3 运行时核心模块

```
res://core/
  level/
    Level.gd               # Resource 数据模型
    LevelLoader.gd         # JSON ↔ Level，XSB 文本互转
    LevelValidator.gd      # 静态校验
  board/
    Board.gd               # 状态机
    BoardCommand.gd        # MoveCommand
    UndoStack.gd
    Cell.gd                # 枚举
  solver/
    SokobanSolver.gd       # IDA* + Zobrist + 死格剪枝
    SolverWorker.gd        # WorkerThreadPool 包装
    DeadlockDetector.gd
  rendering/
    BoardView.gd
    TweenMover.gd
  game/
    GameController.gd
```

### 3.4 关键事件（EventBus）

```
level_loaded(level)
move_performed(cmd)
move_undone(cmd)
crate_placed(pos, color_id)        # color_id ∈ 1..5；holder 中性槽用 placed_on_neutral 区分
level_completed(stats)
solver_finished(level_id, optimal_steps)
settings_changed(key, value)
language_changed(locale)
```

## 4. 关卡数据格式（JSON）

`user://levels/<uuid>.json` 与 `res://levels/official/<world>/<idx>.json` 共用：

```json
{
  "format_version": 2,
  "id": "official-w1-l01",
  "name": { "zh_CN": "第一步", "zh_TW": "第一步", "en": "First Step" },
  "author": "Official",
  "width": 8, "height": 6,
  "tiles": [
    "########",
    "#@ $ . #",
    "#      #",
    "########"
  ],
  "color_overrides": {
    "crates": { "1,1": 2, "3,1": 3 },
    "holders": { "5,1": 2, "6,1": 0 }
  },
  "metadata": {
    "difficulty": 1,
    "optimal_steps": 7,
    "optimal_pushes": 3,
    "tags": ["tutorial", "movement", "multi_color"],
    "color_count": 3,
    "created_at": "2026-04-01T00:00:00Z",
    "verified_by_solver": true
  }
}
```

- 内部统一 JSON；导入/导出 XSB 文本两路互通。
- `color_overrides` 可选；缺省时所有箱子=color 1、所有 holder=color 1（=经典单色）
- XSB 内 `a b c d` / `1 2 3 4` 字符可直接表达颜色 1..4；颜色 5 仅 JSON `color_overrides` 表达
- `format_version: 2` 用于 SaveMigrator 识别新字段；旧 v1 关卡读入后等同单色
- 分享码 = `Base64URL( zlib( JSON ) ) + "-" + CRC32`，UI 一键复制/粘贴。

## 5. 关卡编辑器

### 5.1 工具（Palette）
- 选择/橡皮 / 墙 / 地板 / 目标点 / 箱子 / 玩家（单例）
- 颜色调色板（1-5 + 0 中性槽）：选中颜色后绘制的箱子/holder 携带该 `color_id`
- 矩形/直线绘制（Shift）
- 网格尺寸（4×4 ~ 32×32）
- Undo/Redo（共用核心 UndoStack）

### 5.2 顶栏
- 新建/打开/保存
- 测试播放（嵌入 GameScene）
- 导入（文件 / XSB / 分享码）
- 导出（JSON / XSB / 分享码 / 缩略图 PNG）
- 求解验证

### 5.3 元数据面板
- 名称（多语言可选）/ 作者 / 难度 / 标签
- 求解结果：可解性 / 最优步数 / 最优推数

### 5.4 保存前校验
- 玩家恰好 1
- 箱子数 = 目标点数 ≥ 1
- 对每种颜色 c ∈ {1..5}：`count(crate.color==c) == count(holder.color==c)`（中性槽不计入）
- 所有箱子可从初始可达区域被推到至少一个合法 holder
- 玩家与所有目标点 4-连通
- Solver 求解（超时 5s 标 "未验证"）

## 6. 求解器

| 项 | 决策 |
|---|---|
| 算法 | IDA* + Zobrist + 死格剪枝 |
| 启发式 | 按颜色分组的最小代价匹配（中性槽参与全色匹配） |
| 死格 | 按颜色独立构建静态角落表 + 动态冻结检测 |
| 执行 | WorkerThreadPool，可中断 |
| 超时 | 编辑器 5s（1-30 可调） |
| 输出 | optimal_steps / optimal_pushes / 首条 path |

> v1.0 用 GDScript；若大关卡过慢，预留 C# 重写口子。

## 7. 输入（Guide）

| Action | 默认键位 | 手柄 |
|---|---|---|
| `move_up/down/left/right` | WASD + 方向键 | DPad / 左摇杆 |
| `undo` | Z | LB |
| `redo` | Y / Ctrl+Shift+Z | RB |
| `restart` | R | Select |
| `pause` | Esc | Start |
| `editor_toggle_playtest` | F5 | — |

支持运行时重绑，保存到 `user://settings.json`。

## 8. UI / HUD

- `UIManager` 管理 Panel 栈
- 主题：1 套基础 Theme，深色为主
- HUD：关卡名 / 步数 / 推数 / 时间 / Undo / Redo / Restart / Pause
- 完成弹窗：星级动画、最佳记录对比
- 设置面板：语言、音量（Master/BGM/SFX）、键位、显示、辅助功能

## 9. 音频（sound_manager）

| 通道 | 用途 |
|---|---|
| Music | 主菜单 / 章节 BGM |
| SFX | 走步、推箱、归位、撤销、胜利、UI |
| Ambient | v1.1 |

总线：`Master → Music / SFX / Ambient`。

## 10. 本地化

- `I18NManager` + `res://locale/zh_CN.csv` / `zh_TW.csv` / `en.csv`
- 关卡名走 JSON 内嵌字典（fallback en）
- 字体：Noto Sans CJK 子集

## 11. 存档

`user://save/profile.json`：

```json
{
  "version": 1,
  "settings": {...},
  "progress": {
    "official-w1-l01": { "stars": 3, "best_steps": 7, "best_time_ms": 12340, "completed_at": "..." }
  },
  "stats": { "total_steps": 1234, "total_time_ms": 99999, "completed_levels": 12 },
  "user_levels_index": ["uuid1"]
}
```

- 原子写入（`.tmp` → rename）
- `SaveMigrator` 按 version 升级
- Steam Cloud：全部 `user://`

## 12. 关卡章节（首发 50 关）

| 世界 | 主题 | 关卡数 | 教学要点 |
|---|---|---|---|
| W1 仓库入门 | 教学 | 12 | 移动、推箱、目标、撤销、重玩 |
| W2 工厂 | 进阶 | 13 | 多箱协作、避免死锁 |
| W3 港口 | 精选 | 13 | 经典名题改编（致谢原作者） |
| W4 储藏所 | 挑战 | 12 | 大尺寸 + 长解 |

## 13. 非功能需求

| 项 | 目标 |
|---|---|
| 启动到主菜单 | < 2 s |
| 关卡加载 | < 200 ms |
| 内存 | < 200 MB |
| Solver 默认超时 | 5 s |
| 帧率 | 60 FPS |
| 包体 | < 80 MB |

## 14. 测试策略

- **单元测试**：GUT，覆盖 `Board.try_move`、`UndoStack`、`LevelValidator`、`LevelLoader (JSON↔XSB)`、Solver 小关基线
- **回归集**：50 个官方关卡的 "最优解 path 重放即胜利" 自动化
- **手动 QA**：章节 checklist；编辑器关键路径 15 用例

## 15. 目录结构

```
res://
  assets/             # 已存在
  addons/             # 已存在
  core/               # 新建（§3.3）
  scenes/             # 新建（§3.2）
  ui/                 # 通用面板与 Theme
  locale/             # CSV 翻译
  levels/official/w1..w4/*.json
  levels/templates/   # 关卡草图模板
  resources/          # Theme、ProjectSettings 资源
  tests/              # GUT 测试
docs/
  godot-prompter/
    specs/GDD.md
    plans/IMPLEMENTATION.md
```

## 16. 风险与对策

| 风险 | 对策 |
|---|---|
| Solver 大关卡超时 | 启发式优化 + "未验证"保存；后置 C# 重写 |
| Guide 插件学习曲线 | 早期最小集 + 保留 Godot InputMap fallback |
| JSON 多语言关卡名维护 | CSV 批量注入脚本 |
| Steam Cloud 路径冲突 | 全部 `user://` + 时间戳合并对话框 |
| 像素美术与矢量 UI 风格割裂 | UI 用扁平圆角，HUD 像素字体过渡 |
