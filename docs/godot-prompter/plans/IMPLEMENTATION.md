# Sokoban — 实施计划（Implementation Plan）

> 版本：v1.1｜配套 GDD：`../specs/GDD.md`
>
> 进度状态标记：⬜ 未开始 / 🟡 进行中 / ✅ 完成 / ⛔ 阻塞
>
> 备注：所有 Phase 不再标注预计落地时间——实际推进速度难以准确预估，按完成度推进即可。

---

## Phase 0 — 项目骨架 ✅

**目标：能在编辑器中打开，所有 Autoload 可加载，主菜单 → 占位关卡 → 退出 流程跑通。**

- [x] P0-01 落盘 GDD 与 IMPLEMENTATION 文档（本文件）
- [x] P0-02 创建关卡草图模板 + 5 关示例（`res://levels/templates/`、`res://levels/official/w1/`）
- [x] P0-03 创建目录骨架（core/scenes/ui/locale/levels/resources/tests）
- [x] P0-04 配置 `project.godot`：分辨率 1280×720，stretch=canvas_items+expand，像素吸附；输入动作占位
- [x] P0-05 新增 Autoload 占位脚本：`GameState`、`LevelLibrary`、`SaveManager`、`InputManager`
- [x] P0-06 `Boot.tscn`：注册资源、跳转主菜单
- [x] P0-07 `MainMenu.tscn`：开始 / 关卡选择 / 编辑器 / 选项 / 退出（占位按钮）
- [x] P0-08 README 快速入口（含会话恢复指南）

**验收**：F5 可启动 → 主菜单可见 → 控制台无报错。

> 加载技能：`godot-project-setup`、`scene-organization`

---

## Phase 1 — 核心玩法可玩 MVP ✅

**目标：用键盘玩通 1 关，含 Undo/Redo/Restart。**

- [x] P1-01 `core/level/Level.gd` Resource 模型（width/height/tiles/metadata/name dict）
- [x] P1-02 `core/level/LevelLoader.gd`：JSON ↔ Level，XSB ↔ Level
- [x] P1-03 `core/level/LevelValidator.gd`：玩家=1、箱子=目标、连通性
- [x] P1-04 `core/board/Cell.gd`、`BoardCommand.gd`、`UndoStack.gd`、`Board.gd`
- [x] P1-05 `core/rendering/BoardView.gd`：ColorRect 地形 + Sprite2D 实体（Phase 5 升级 TileMapLayer）
- [x] P1-06 `core/rendering/TweenMover.gd`：120ms 走/推动画
- [ ] P1-07 `InputManager`：基于 Guide，绑定 move/undo/redo/restart（Phase 1 仍用原生 InputMap，Phase 2 迁移）
- [x] P1-08 `core/game/GameController.gd`：输入→Board→Event→Win 检测
- [x] P1-09 `scenes/game/GameScene.tscn`：完整可玩
- [x] P1-10 加载 `levels/official/w1/01.json`，跑通胜利→HUD（已通过验收）
- [ ] P1-11 GUT 测试：Board / UndoStack / LevelLoader（提供独立 `tests/smoke_test.gd` 先用，GUT 安装后正式接入）

**附加（计划外完成）**：
- [x] 主题：`resources/themes/minimal_vector.tres`（沿用 minimal_vector 边框/圆角，按 Sokoban 木箱调色 + 阴影）
- [x] 项目默认主题已配置（`gui/theme/custom`）
- [x] HUD：步数/推数/时间 + Win 弹窗

**验收**：W1-01 可通关，Undo/Redo 行为正确；smoke_test 通过。

> 加载技能：`gdscript-patterns`、`input-handling`、`tween-animation`、`2d-essentials`、`godot-testing`

---

## Phase 2 — UI / 流程 / 存档 ✅

- [x] P2-01 `MainMenu`：联动 LevelSelect / Settings / Quit；Editor 按钮显示 "即将推出" Toast；i18n
- [x] P2-02 `LevelSelect`：章节 Tab + 关卡格栅，显示星级、最佳步数、章节进度；按钮入场跳转 GameScene
- [x] P2-03 HUD：完整四按钮（Undo/Redo/Restart/Pause），按钮可用性随 Board 状态联动；Win 弹窗带星级弹出动画；i18n
- [x] P2-04 PauseMenu（HUD 内置覆盖层）+ CompleteDialog（HUD 内置覆盖层，含三星动画）
- [x] P2-05 SettingsPanel：语言、主/音乐/SFX 三总线音量、全屏、高对比度、减弱动画；改动即时应用并保存；可在主菜单/暂停中打开
- [x] P2-06 SaveManager：原子写入 + Migrator 框架 + settings 读写 API + 合并默认值兼容老存档 + record_level_complete 含全局统计
- [x] P2-07 I18N：`zh_CN/zh_TW/en` JSON 三语；Boot 启动加载；UI 全程 `tr()`；切换语言事件触发各场景 _refresh_texts
- [x] P2-08 通用 UI：Toast 组件（`Toast.show_text(host, text)`）

**附加完成**：
- [x] `SettingsApplier`：把存档 settings 应用到 AudioServer / DisplayServer / I18N
- [x] `LevelLibrary` 增强：按 chapter.order 排序、`get_next_level_id()` 用于通关后自动衔接

**验收**：
- 主菜单 → 设置面板调语言：所有界面文案瞬时切换
- 主菜单 → 关卡选择：5 关示例可见；通关后 ★ 与"最佳：N 步"显示
- 通关 → 点 Next 自动进下一关；已是末关则回 LevelSelect
- 游戏中 Esc 弹出暂停面板；可调设置而不退出关卡

> 加载技能：`godot-ui`、`hud-system`、`save-load`、`localization`、`responsive-ui`

---

## Phase 3 — 求解器 ✅

- [x] P3-01 `SokobanSolver.gd`：IDA* on push-graph + 玩家可达区域归一化 + Manhattan 启发式 + 状态去重
- [x] P3-02 `DeadlockDetector.gd`：静态死格表（goal 反向 BFS）+ 简化冻结检测（双轴锁）
- [x] P3-03 `SolverWorker.gd`：WorkerThreadPool + 取消标志 + 主线程信号回放
- [x] P3-04 `tests/solver_test.gd` + `tests/solver_worker_test.gd`：W1 全 5 关 push-optimal 基线 + 解法 Board 重放校验

**实测基线（push-optimal）**：
| 关卡 | pushes | moves | nodes | 用时 |
|------|--------|-------|-------|------|
| W1-01 | 1 | 1 | 2 | 5 ms |
| W1-02 | 1 | 1 | 2 | 6 ms |
| W1-03 | 8 | 43 | 13 | 7 ms |
| W1-04 | 8 | 27 | 99 | 6 ms |
| W1-05 | 6 | 8 | 11 | 1 ms |

**已写回 W1 各关 metadata**：`optimal_pushes` / `optimal_steps` / `verified_by_solver=true`。

> Zobrist 随机表当前用 Vector2i hash 复合替代（性能足够 W1 / Phase 5 内容）。若 Phase 5 出现大图卡顿再补真随机表。

**验收**：W1 所有关卡 < 10ms 解出最优推数（远低于 5s 目标）；解法可在 Board 上重放至胜利。

---

## Phase 3.5 — 多类型（多色）箱子改造 ✅

**目标：核心系统升级到支持 5 种颜色 + 中性槽，向后兼容现有单色关卡，并产出测试关卡纳入 W1。**

### 数据层
- [x] P35-01 `Cell.gd` 扩展：新增 `NEUTRAL_COLOR=0 / DEFAULT_COLOR=1 / MAX_COLOR=5` 常量、`color_matches/sanitize_*` 辅助
- [x] P35-02 `Level.gd` 增加 `box_colors` / `goal_colors` 数组；`format_version` 升至 2；`used_colors()` / `is_multi_color()` 辅助
- [x] P35-03 `LevelLoader.gd`：
  - JSON v1 → v2 自动迁移（缺省所有 color=1）
  - XSB 解析支持 `a/b/c/d` 箱子、`1/2/3/4` holder、`,` 中性槽、`B/C/D` 复合字符；颜色 5 走 JSON `color_overrides`
  - 序列化时按需写出 `color_overrides`，单色关卡保持紧凑
- [x] P35-04 `LevelValidator.gd`：每色 `count(box) ≤ count(holder_same) + count(holder_neutral)`；中性 holder 可接收任意色

### 玩法层
- [x] P35-05 `Board.gd` 胜利判定：`holder.color == 0 或 holder.color == box.color` 且全部 box 在 GOAL 上；`boxes` 字典值由 bool 升级为 color_id
- [x] P35-06 `BoardCommand.gd`：携带 `box_color / holder_color_from / holder_color_to`，提供 `became_complete()` / `became_incomplete()` 辅助
- [x] P35-07 EventBus：当前 Board 信号已携带完整颜色信息（`moved/undone/redone(cmd)`），无需新增全局事件类型

### 渲染层
- [x] P35-08 `BoardView.gd`：从 `_board.boxes` 读取每个箱子颜色；从 `_board.holder_color()` 读取每个 GOAL 颜色；中性槽使用 holder_1 + 灰度 modulate(0.7)
- [x] P35-09 着色器 `complete` 参数改用 `Board.is_box_complete_at()`（颜色匹配判定，含中性槽）；非匹配占用不再亮起
  - 注：粒子/红色错位提示属于 Phase 5 抛光范畴，本阶段先在 BoardView 用着色器/灰度区分

### 求解器
- [x] P35-10 `DeadlockDetector.gd`：`compute_static_dead_squares()` 按颜色返回 `Dictionary[color_id -> Dictionary[Vector2i -> true]]`；颜色 c 的活格 = (同色 holder ∪ 中性 holder) 反向 BFS 可达
- [x] P35-11 `SokobanSolver.gd` 启发式：按颜色分组，每个箱子取 (同色 holder ∪ 中性 holder) 最近曼哈顿距离之和作为下界
- [x] P35-12 状态 key 加入颜色维度：`(color * 1_000_003) ^ pos_idx` 排序拼接（实测足够区分；真随机 Zobrist 留待大图卡顿时再补）

### 编辑器（与 Phase 4 联动）
- [x] P35-13 Palette 增加颜色选择器（1-5 + 中性槽 0）— Phase 4 已完成
- [x] P35-14 编辑器视图：箱子/holder 显示颜色边框 — Phase 4 已完成（颜色环 + 数字标号）

### 测试与内容
- [x] P35-15 单色关卡回归：W1 全 5 关 push-optimal 解法/步数/节点数与 Phase 3 完全一致
- [x] P35-16 smoke_test：扩展为 10 项，含同色匹配、错位不胜利、中性槽接受任意色、validator 颜色计数、XSB 颜色字符往返、BoardCommand 颜色信息
- [x] P35-17 W1 新增 2 关多色教学：
  - **W1-06「色彩配对」**：8×4，玩家两侧各一对（红/蓝），2 推 3 步，引入"必须颜色匹配"
  - **W1-07「中性之槽」**：7×5，红箱+蓝箱+红holder+中性槽，4 推 13 步，引入"中性槽接受任意色 + 需要分配"
  - 均已写入 metadata：`optimal_pushes` / `optimal_steps` / `verified_by_solver=true` / `color_count`
  - 三语 i18n 关卡名已落（zh_CN / zh_TW / en）；`chapter.json` levels 列表已扩
- [x] P35-18 solver_test 扩展：4 项多色测试（trivial / 2-color / neutral / per-color deadlock）全部 push-optimal 通过

**测试结果**：smoke 10/10 + solver 11/11 = **21/21 通过**

**验收**：
- ✅ 旧 v1 单色关卡 100% 兼容（W1-01..05 解法/星级/节点数完全不变）
- ✅ 新增多色关卡可通关且解器输出 push-optimal（W1-06 = 2 推、W1-07 = 4 推）
- ✅ 中性槽行为正确：任何颜色箱子放入即视为占据该 holder

> 加载技能：`resource-pattern`、`gdscript-patterns`、`godot-testing`、`2d-essentials`

---

## Phase 4 — 关卡编辑器 ✅

- [x] P4-01 `EditorScene` 骨架：Topbar / Palette / Board / Meta（代码动态构建，无复杂 .tscn）
- [x] P4-02 绘制工具：单格 / 矩形 / 直线 / 橡皮；支持鼠标右键= 临时橡皮
- [x] P4-03 复用 `UndoStack` 编辑命令（`EditCommand` before/after 快照，可逆 apply/revert）
- [x] P4-04 测试播放：嵌入 `Playtest`（复用 `Board` + `BoardView`），ESC / 按钮返回
- [x] P4-05 导入：JSON 文件 / XSB 粘贴 / 分享码粘贴（`ImportDialog` 三 Tab）
- [x] P4-06 导出：JSON / XSB / 分享码 / 缩略图 PNG（`ExportDialog` 四 Tab，SubViewport 截屏）
- [x] P4-07 集成 Solver 验证按钮 + 进度条 + 取消（`SolverDialog`，复用 `SolverWorker`）
- [x] P4-08 校验器集成：保存 / 测试 / 验证 前自动跑 `LevelValidator`，错误以对话框列出
- [x] P35-13 颜色调色板（0..5，与工具上下文联动启停）
- [x] P35-14 编辑器视图：箱子/holder 显示颜色环 + 数字标号

**附加完成**：
- [x] `EditorModel` — 可写关卡数据模型 + `EditCommand` + `ShareCode` + `UserLevelStore`
- [x] `LevelLibrary` 增强：扫描并索引 `user://levels/*.json`，提供 `refresh_user_levels()`
- [x] `LevelSelect` 新增"我的关卡"Tab；`MainMenu` 编辑器按钮已激活
- [x] `ShareCode`：Base64URL + GZIP + CRC32（尾部 8 hex），含篡改检测
- [x] 三语 i18n（`editor.*` + `level_select.user_*` + `common.error/info`，zh_CN/zh_TW/en）
- [x] `tests/editor_test.gd`：8 项自检（EditorModel ↔ Level、EditCommand 可逆、ShareCode 往返/篡改检测、ID 唯一、resize 保留）

**测试结果**：smoke 10/10 + solver 11/11 + editor 8/8 = **29/29 通过**

**验收**：
- ✅ 主菜单 → 编辑器：可见空白模板（外圈墙 + 内部地板）
- ✅ 工具栏：选择/橡皮/墙/地板/目标/箱子/玩家；颜色面板按工具自动启停 0..5
- ✅ 形状：单格流式绘制、矩形/直线拖拽预览 + 释放提交（一次 EditCommand）
- ✅ Undo/Redo：Ctrl+Z / Ctrl+Shift+Z / 顶栏按钮
- ✅ 测试播放：嵌入运行，键盘控制玩家，ESC 退出
- ✅ 导入/导出三种格式 + 缩略图（与编辑器视图一致）
- ✅ Solver 验证后把 `optimal_pushes / optimal_steps / verified_by_solver` 写入 metadata
- ✅ 保存 → user://levels/<id>.json + 写入 SaveManager 索引 + LevelLibrary 刷新
- ✅ LevelSelect "我的关卡"Tab 显示已保存关卡，点击进入游玩通关

> 加载技能：`godot-ui`、`scene-organization`、`resource-pattern`、`godot-testing`

---

## Phase 5 — 内容 + 音频 + 输入 + 抛光 🟡

> **v1.0 范围**：W1 12 关 + W2 13 关 = **25 关**（W3/W4 留 v1.1，对齐 GDD §12）。
> **执行顺序**：音频底座 → 视觉抛光 → 输入改造 → 内容铺量 → 收尾测试。

### A. 音频底座（P5-A）
- [ ] P5-A1 `default_bus_layout.tres`：`Master → Music / SFX / UI` 四总线
- [ ] P5-A2 `SettingsApplier` 修复 `get_bus_index() == -1` 静默失败 + 与新 bus 名对齐（含 UI 总线音量 API）
- [ ] P5-A3 `Boot` 中配置 `SoundManager` 默认 bus（sfx→SFX / ui→UI / music→Music）

### B. 音效与音乐接入（P5-B）
- [ ] P5-B1 用 gdfxr 生成 4 个占位 SFX：`push.sfxr` / `undo.sfxr` / `ui_click.sfxr` / `ui_hover.sfxr`
- [ ] P5-B2 `core/audio/sfx_catalog.gd`：名称 → AudioStream 索引；提供 `Sfx.play(name)` / `Sfx.play_ui(name)` 便捷接口
- [ ] P5-B3 信号接入：Board.moved/undone/redone → step|push|undo；`crate_complete` → crate_done；`level_completed` → level_complete
- [ ] P5-B4 UI 全局：所有 Button.pressed → ui_click，mouse_entered → ui_hover（统一封装在 `ui/components/sfx_button.gd` 或 mixin）
- [ ] P5-B5 BGM：MainMenu ↔ GameScene crossfade 1.0s（menu_music ↔ game_music）

### C. 视觉抛光（P5-C）
- [ ] P5-C1 归位粒子：`core/rendering/effects/box_complete_fx.tscn` (GPUParticles2D)；BoardView 监听 `Board.moved`/`undone` 在变完成时触发
- [ ] P5-C2 走步抖动：TweenMover 增加 ±2px shake 选项
- [ ] P5-C3 校查"减弱动画"开关在 TweenMover/粒子上真生效（duration ×0.3、粒子禁用）
- [ ] P5-C4 校查"高对比度"开关切换主题/着色器参数

### D. 主菜单美化（P5-D）
- [ ] P5-D1 Splash：Boot 阶段 1s 渐显 Logo
- [ ] P5-D2 Logo：纯代码（Label + 自定义 Font + 阴影/光晕）+ 现有 crate 图标拼装
- [ ] P5-D3 MainMenu 背景层：缓动浮动的几个箱子图，呼吸感

### E. 输入改造：GUIDE 后端（P5-E）
- [ ] P5-E1 `core/input/actions/`：每动作建 GUIDEAction 资源（`move_up/down/left/right`、`undo/redo/restart/pause`、`confirm/cancel`）
- [ ] P5-E2 `core/input/contexts/`：`gameplay.tres`、`ui.tres` GUIDEMappingContext，各动作绑定键鼠 + 手柄
- [ ] P5-E3 `core/input/remapping_config.tres`：声明可重绑 slot（每动作 keyboard 1 + gamepad 1）
- [ ] P5-E4 `InputManager` 重写：以 GUIDE 为后端；`get_move_dir()` / `is_action_just_pressed()` / `current_device` + `device_changed` 信号
- [ ] P5-E5 设备检测：监听原始 InputEvent 类型切换 KEYBOARD/GAMEPAD（鼠标归类 KEYBOARD）

### F. 输入改造：重绑 UI + 提示同步（P5-F）
- [ ] P5-F1 `SettingsPanel` 新增"键位"Tab：左列动作（i18n），右列两个 RebindSlot（键鼠/手柄）
- [ ] P5-F2 `RebindSlot.gd`：监听下一个 InputEvent → GUIDE remapper → 冲突检测弹确认 → 持久化
- [ ] P5-F3 重置默认按钮（按动作 / 全部）
- [ ] P5-F4 `core/input/input_hint.gd`：读 GUIDE 当前绑定 + 设备 → 输出图标（Kenney Input Prompts 图标集）或 i18n 键名
- [ ] P5-F5 HUD/PauseMenu/Win 按钮 tooltip 接入 InputHint；监听 `device_changed` 自动刷新
- [ ] P5-F6 SaveManager schema v2：`input_bindings` 字段；Migrator 缺省=默认
- [ ] P5-F7 i18n 扩展：`settings.tab.input` / `input.action.*` / `input.rebind.listening|conflict|reset` / `gamepad.button.*`（zh_CN/zh_TW/en）

### G. W1 教学关卡补完（P5-G）
- [ ] P5-G1 在已有 7 关基础上补 5 关，覆盖：推动入门强化 / 死锁意识 / 双箱协作 / 中性槽进阶 / 3 色组合
- [ ] P5-G2 全 12 关跑 solver 写 `optimal_pushes / optimal_steps / verified_by_solver`
- [ ] P5-G3 三语关卡名 + chapter.json 同步

### H. W2 致敬关卡（Microban）（P5-H）
- [ ] P5-H1 从 David Holland Microban (public domain) 选 13 关 XSB
- [ ] P5-H2 用编辑器/loader 批量导入 → JSON；每关 metadata 写 `author="David Holland"` + `source="Microban"`
- [ ] P5-H3 Solver 验证（5s 内不可解则标 `verified_by_solver=false` 但保留）
- [ ] P5-H4 三语关卡名（保留英文原名 + 中文意译）+ `levels/official/w2/chapter.json`
- [ ] P5-H5 LevelLibrary 索引扩展 W2；i18n `chapter.w2.title`
- [ ] P5-H6 项目根 `LICENSES.md` 增加致谢段（Microban + Kenney Input Prompts）

### I. 收尾（P5-I）
- [ ] P5-I1 扩展 `tests/smoke_test.gd`：音频 bus sanity、SoundManager 可调
- [ ] P5-I2 `tests/input_test.gd`：GUIDE context 加载、模拟输入、重绑往返、设备检测
- [ ] P5-I3 `solver_test` 扩展覆盖 W2 全部 13 关
- [ ] P5-I4 手测 checklist：通关 W1-01/W2-01 听到所有 SFX；切语言/切设备后提示同步；高对比度/减弱动画切换有视觉反馈
- [ ] P5-I5 IMPLEMENTATION 状态徽标更新 → ✅；文档同步

**Git 提交粒度**：9 次 commit
1. docs：Phase 5 范围调整 + GDD §12 同步（**本次**）
2. P5-A 音频底座
3. P5-B 音效/音乐接入
4. P5-C 视觉抛光
5. P5-D 主菜单美化
6. P5-E 输入 GUIDE 后端
7. P5-F 重绑 UI + 提示同步
8. P5-G W1 12 关补完
9. P5-H + P5-I W2 + 收尾

**验收**：25 关全部可通关；通关全程音频/特效齐全；玩家可在设置中重绑全部键位、提示文本随设备同步切换；高对比度/减弱动画真生效。

---

## 任务追踪规范

- 每完成一个子任务，把 `[ ]` 改为 `[x]` 并提交
- Phase 完成后更新该 Phase 的状态徽标（🟡 → ✅）
- 阻塞项：在条目尾部追加 `⛔ 原因 / 关联 issue`

## 当前活动 Phase

**Phase 5 — 内容 + 音频 + 输入 + 抛光** 进行中（v1.0 范围：W1+W2 = 25 关；W3/W4 留 v1.1）。
Phase 1 / 2 / 3 / 3.5 / 4 全部完成。
编辑器已可端到端运转：创建/编辑 → 验证 → 保存 → 在"我的关卡"游玩通关；并支持 JSON/XSB/分享码三向互通。
Phase 5 划分 9 组任务（A-I），对应 9 次 git 提交。
