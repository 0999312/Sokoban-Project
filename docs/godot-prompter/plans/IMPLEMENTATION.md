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
- [x] P1-07 `InputManager`：基于 Guide，绑定 move/undo/redo/restart（已在 Phase 5 完成 GUIDE 后端迁移）
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

## Phase 5 — 内容 + 音频 + 输入 + 抛光 ✅

> **v1.0 范围（修订）**：W1 原创 12 关 + W2 Microban 完整 155 关 + W3 XSB 精选 90 关 = **257 关**（原 W3 港口顺延为 v1.1 的 W4，13 关）。
> **执行顺序**：音频底座 → 视觉抛光 → 输入改造 → 内容铺量 → 收尾测试。

### A. 音频底座（P5-A）✅
- [x] P5-A1 `default_bus_layout.tres`：`Master → Music / SFX / UI` 四总线
- [x] P5-A2 `SettingsApplier` 修复 `get_bus_index() == -1` 静默失败 + 与新 bus 名对齐（含 UI 总线音量 API）
- [x] P5-A3 `Boot` 中配置 `SoundManager` 默认 bus（sfx→SFX / ui→UI / music→Music）

### B. 音效与音乐接入（P5-B）✅（不含 ui_hover，用户明确不做）
- [x] P5-B1 SFX 资产到位：`step.sfxr / push.sfxr / undo.mp3 / crate_done.sfxr / level_complete.sfxr / ui_click.mp3`
- [x] P5-B2 `autoload/sfx.gd`：名称 → AudioStream 索引；`Sfx.play(name)` / `Sfx.play_ui(name)` / `Sfx.play_bgm(key)` / `Sfx.attach_ui(root)`
- [x] P5-B3 信号接入：Board.moved/undone/redone → step|push|undo；`crate_complete` → crate_done；`level_completed` → level_complete
- [x] P5-B4 UI 全局：`Sfx.attach_ui()` 递归挂全部 Button 的 ui_click（不引入 hover）
- [x] P5-B5 BGM：MainMenu ↔ GameScene crossfade 1.0s（menu_music ↔ game_music）

### C. 视觉抛光（P5-C）✅
- [x] P5-C1 归位粒子：`BoardView._emit_complete_burst()`（`GPUParticles2D` 代码构建，受 `A11y.particles_enabled()` 门控）
- [x] P5-C2 走步抖动：`TweenMover.move_with_shake()`（±2px shake，落地回正）
- [x] P5-C3 校查"减弱动画"开关在 TweenMover/粒子上真生效（`A11y.scale_duration` × 0.3、粒子禁用）
- [x] P5-C4 校查"高对比度"开关切换主题/着色器参数（`BoardView._apply_high_contrast` 监听 `SaveManager.settings_changed`）

### D. 主菜单美化（P5-D）✅
- [x] P5-D1 Splash：Boot 阶段 1s 渐显 Logo
- [x] P5-D2 Logo：纯代码（Label + 阴影/光晕）+ 现有 crate 图标拼装
- [x] P5-D3 MainMenu 背景层：缓动浮动的 7 个箱子图，呼吸感（reduce_motion 时降幅减小）

### E. 输入改造：GUIDE 后端（P5-E）✅
- [x] P5-E1 8 个 GUIDEAction（move_up/down/left/right、undo/redo/restart/pause）由 `InputManager` 代码构建
- [x] P5-E2 gameplay GUIDEMappingContext：每动作绑定键鼠 + 手柄两套
- [x] P5-E3 通过 `InputManager.set_binding()` 暴露可重绑 slot（每动作 keyboard 1 + gamepad 1 + 副键 1）
- [x] P5-E4 `InputManager` 重写：以 GUIDE 为后端；`get_move_dir()` / `is_action_just_pressed()` / `current_device` + `device_changed` 信号
- [x] P5-E5 设备检测：监听原生 InputEvent 类型切换 KEYBOARD/GAMEPAD（鼠标归类 KEYBOARD）

### F. 输入改造：重绑 UI + 提示同步（P5-F）✅
- [x] P5-F1 `SettingsPanel` 重构为静态多 Tab（游戏/音量/按键），按键 Tab 含动作 / 键盘 / 手柄三列
- [x] P5-F2 RebindSlot 内联在 `SettingsPanel`：监听下一个 InputEvent → `InputManager.set_binding` → 冲突检测弹确认 → 持久化
- [x] P5-F3 重置默认按钮：`InputManager.reset_all_bindings()`
- [x] P5-F4 `core/input/input_hint.gd`：读 GUIDE 当前绑定 + 设备 → 输出文本（图标包后续可换）
- [x] P5-F5 HUD 按钮 tooltip 接入 InputHint；监听 `device_changed` 自动刷新
- [x] P5-F6 SaveManager schema v2：`input_bindings` 字段；Migrator 缺省=默认
- [x] P5-F7 i18n 扩展：`settings.tab.*` / `settings.input_col.*` / `input.action.*` / `input.rebind.listening|conflict|reset`（zh_CN/zh_TW/en）

### G. W1 教学关卡补完（P5-G）✅
- [x] P5-G1 在已有 7 关基础上补 5 关，覆盖：双箱协作 / 中性槽进阶 / 3 色组合
- [x] P5-G2 W1-08..12 的 `optimal_pushes / optimal_steps` 保持估算（用户明确决定不跑 solver 回填）
- [x] P5-G3 三语关卡名 + chapter.json 同步

### H. W2 Microban + W3 XSB 数据集导入（P5-H）✅
- [x] P5-H1 建立 `scripts/import_levelset.gd` 批量转换流程，支持多关卡 `.sok/.txt` 与目录式 `screen.*` 输入
- [x] P5-H2 完整导入 `docs/microban_levels/DavidWSkinner Microban.sok` → `levels/official/w2/`（155 关）
- [x] P5-H3 完整导入 `docs/xsb_levels/screen.*` → `levels/official/w3/`（90 关，原临时章节 `xsb-import` 提升为正式 W3）
- [x] P5-H4 导入时写入 `author`、`metadata.import_source`、`metadata.source_title/source_index`、`verified_by_solver=false`
- [x] P5-H5 对静态校验异常的原始关卡保留导入，并把问题写入 `metadata.import_validation`
- [x] P5-H6 W2 / W3 chapter.json 改为 i18n key 形式，三语 `chapter_names.official-w2/w3` 与 `chapter_descriptions.official-w2/w3` 已落
- [x] P5-H7 项目根 `LICENSES.md` 已含 Microban / XSB 导入来源说明
- [x] P5-H8 原计划的 v1.1 W3 港口关卡顺延为 W4（GDD §12 已同步）

### I. 收尾（P5-I）
- [x] P5-I1 扩展 `tests/smoke_test.gd`：音频 bus sanity、SoundManager 可调
- [x] P5-I2 输入链路人工确认：GUIDE context 加载、重绑往返、设备检测、提示同步
- [x] P5-I3 关卡回归范围人工确认：W1/W2/W3 当前内容按发布范围验收通过
- [x] P5-I4 手测 checklist：通关 W1-01/W2-01 听到所有 SFX；切语言/切设备后提示同步；高对比度/减弱动画切换有视觉反馈
- [x] P5-I5 IMPLEMENTATION 状态徽标更新 → ✅；文档同步

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

**验收**：W1(12) + W2(Microban 155) + W3 XSB 精选 90 已完整接入；音频、输入、抛光、编辑器与评分工作流已按发布范围落地，剩余收尾项已通过人工确认完成。

---

## 任务追踪规范

- 每完成一个子任务，把 `[ ]` 改为 `[x]` 并提交
- Phase 完成后更新该 Phase 的状态徽标（🟡 → ✅）
- 阻塞项：在条目尾部追加 `⛔ 原因 / 关联 issue`

## 当前活动 Phase

**Phase 5 — 内容 + 音频 + 输入 + 抛光** 已完成（v1.0 范围：W1 12 + W2 155 + W3 90 = 257 关；原 W3 港口顺延为 v1.1 的 W4）。
Phase 1 / 2 / 3 / 3.5 / 4 / 5 全部完成。
编辑器已可端到端运转：创建/编辑 → 验证 → 保存 → 在"我的关卡"游玩通关；并支持 JSON/XSB/分享码三向互通。
当前文档与实现已同步到：标准评分无 `optimal_steps` 时默认 3 星；W1-12 已修正为可通关关卡。
项目按当前范围已完整落地；最终确认以人工测试结论为准，不追加新的自动化测试要求。
