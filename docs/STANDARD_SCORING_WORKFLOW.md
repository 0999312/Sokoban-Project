# Standard Scoring Workflow

本文档说明本项目的“标准评分”如何计算，以及两种使用方式：

1. 开发者批量计算并写回关卡 JSON
2. 玩家在关卡编辑器中为自制关卡计算并导出带评分数据的关卡

## 1. 标准评分的定义

本项目运行时的星级评分只使用 `optimal_steps`。

代码位置：`core/game/game_controller.gd`

```gdscript
func _calc_stars(moves: int, optimal: int) -> int:
	if optimal <= 0:
		return 1
	if moves <= optimal:
		return 3
	if moves <= int(ceil(optimal * 1.25)):
		return 2
	return 1
```

含义如下：

- `3` 星：玩家实际步数 `moves <= optimal_steps`
- `2` 星：玩家实际步数 `moves <= ceil(optimal_steps * 1.25)`
- `1` 星：其余情况
- 如果关卡没有 `optimal_steps`，任意通关都按 `3` 星处理

注意：

- `optimal_pushes` 会被保存，但当前星级判定不直接使用它
- `optimal_steps` 来源于求解器先求出 push-optimal 解，再通过 `expand_to_moves()` 还原完整走步数

## 2. 评分数据字段

标准评分相关字段存放在关卡 JSON 的 `metadata` 中：

```json
{
	"metadata": {
		"optimal_steps": 13,
		"optimal_pushes": 4,
		"verified_by_solver": true
	}
}
```

字段说明：

- `optimal_steps`: 标准步数，运行时星级计算直接使用
- `optimal_pushes`: 标准推数，供设计和分析使用
- `verified_by_solver`: 是否由求解器验证得到

## 3. 求解器的实际计算方式

编辑器与批量脚本使用的是同一套求解器：`core/solver/sokoban_solver.gd`

流程：

1. 用 `SokobanSolver.solve()` 求出最少推箱次数的解
2. 读取返回结果中的 `pushes` 和 `push_solution`
3. 用 `SokobanSolver.expand_to_moves()` 将推箱解展开为完整移动序列
4. `moves.size()` 作为 `optimal_steps`

因此：

- `optimal_pushes` = push-optimal 解的推数
- `optimal_steps` = 该 push-optimal 解展开后的完整步数

这意味着当前“标准评分”是围绕求解器算出的标准步数建立的，不是人工填写。

## 4. 开发者批量计算标准评分

### 4.1 新增脚本

项目提供批量脚本：`scripts/calculate_standard_scores.gd`

用途：

- 扫描一个 JSON 文件或目录
- 对每个关卡做静态校验
- 调用求解器计算 `optimal_pushes / optimal_steps`
- 可选择写回原始 JSON 文件

### 4.2 命令格式

```text
godot4 --headless --script res://scripts/calculate_standard_scores.gd -- --input=<file-or-dir> [--write] [--max-pushes=200] [--node-limit=2000000]
```

参数说明：

- `--input`: 单个关卡 JSON 文件，或包含多个关卡 JSON 的目录
- `--write`: 可选。带上后会把结果写回文件；不带则只打印结果
- `--max-pushes`: 可选。求解器最大 push bound，默认 `200`
- `--node-limit`: 可选。求解器最大展开节点数，默认 `2000000`

### 4.3 常用示例

只查看结果，不写回：

```text
godot4 --headless --script res://scripts/calculate_standard_scores.gd -- --input="E:/godot_learning/projects/sokoban/levels/official/w1"
```

批量写回 W1：

```text
godot4 --headless --script res://scripts/calculate_standard_scores.gd -- --input="E:/godot_learning/projects/sokoban/levels/official/w1" --write
```

对大型 XSB 章节提高搜索预算：

```text
godot4 --headless --script res://scripts/calculate_standard_scores.gd -- --input="E:/godot_learning/projects/sokoban/levels/official/w3" --write --max-pushes=400 --node-limit=8000000
```

### 4.4 输出说明

脚本会输出三类结果：

- `[SOLVED]`: 成功算出标准推数和标准步数
- `[UNSOLVED]`: 在当前预算内未找到解
- `invalid level`: 关卡静态校验失败

示例：

```text
[SOLVED] E:/.../01.json pushes=1 steps=1 nodes=2
[UNSOLVED] E:/.../90.json nodes=2000000
[calculate_standard_scores] done solved=12 unsolved=3 invalid=0 write_back=True
```

### 4.5 适用场景

- 官方章节导入后，统一补齐标准评分
- 修正求解器后，重新批量刷新 `optimal_steps / optimal_pushes`
- 检查某批关卡是否已经有 `verified_by_solver = true`

## 5. 玩家在关卡编辑器中自行计算标准评分

### 5.1 操作步骤

在关卡编辑器中：

1. 打开或制作关卡
2. 点击顶部 `求解验证 / Verify with Solver`
3. 等待求解完成
4. 如果成功，编辑器会把结果写入当前模型：
   - `optimal_pushes`
   - `optimal_steps`
   - `verified_by_solver = true`
5. 点击 `保存`
6. 再点击 `导出`

代码位置：`scenes/editor/editor_scene.gd`

```gdscript
model.meta["optimal_pushes"] = pushes
model.meta["optimal_steps"] = moves_n
model.meta["verified_by_solver"] = true
```

### 5.2 导出方式

导出面板位置：`scenes/editor/dialogs/export_dialog.gd`

当前支持：

- `JSON`
- `XSB`
- `Share Code`
- `PNG 缩略图`

其中与标准评分关系如下：

#### JSON 导出

- 会导出完整 `LevelLoader.to_json(_level, true)`
- 现在会包含求解后写入的 `metadata.optimal_steps / optimal_pushes / verified_by_solver`
- 这是推荐的“带标准评分关卡”导出格式

#### XSB 导出

- 只导出棋盘文本布局
- 不包含 `metadata`
- 因此不会带出标准评分

#### Share Code 导出

- 底层也是对完整 JSON 编码
- 因此会包含标准评分字段

### 5.3 保存与再打开

编辑器保存走的是 `UserLevelStore.save_level(level)`，写入 `user://levels/<id>.json`

现在求解得到的评分字段会：

- 随保存一起写入 JSON
- 重新打开时再读回编辑器模型
- 可继续导出为 JSON 或分享码

## 6. 推荐工作流

### 6.1 官方关卡 / 开发者

推荐顺序：

1. 批量导入关卡
2. 跑 `tests/solver_test.gd` 做回归
3. 用 `scripts/calculate_standard_scores.gd --write` 批量写回标准评分
4. 抽样在游戏内验证星级表现是否符合预期

### 6.2 玩家自制关卡

推荐顺序：

1. 在编辑器中制作关卡
2. 先点 `测试游玩`
3. 再点 `求解验证`
4. 成功后点击 `保存`
5. 用 `导出 -> JSON` 或 `导出 -> Share Code` 分享

如果只是导出 `XSB`，评分数据不会被带出。

## 7. 批量测试与标准评分的关系

当前项目已有的开发者测试脚本：

- `tests/smoke_test.gd`
- `tests/solver_test.gd`
- `tests/solver_worker_test.gd`
- `tests/editor_test.gd`

这些脚本主要用于：

- 校验求解器是否还能找到解
- 校验解能否被 `Board` 正确重放
- 校验编辑器和分享码的往返正确性

它们不会自动把标准评分写回 JSON。

真正负责“批量计算并写回标准评分”的是：

- `scripts/calculate_standard_scores.gd`

## 8. 注意事项

1. 没有 `optimal_steps` 的关卡，运行时默认只能得到 `1` 星。
2. 当前星级只看 `optimal_steps`，不看 `optimal_pushes`。
3. `XSB` 是布局交换格式，不是完整评分存档格式。
4. 对大图或超难图，如果求解器在预算内未找到解，脚本会输出 `UNSOLVED`，不会强行写入伪标准分。
5. 若要分享“带标准评分”的用户关卡，请优先使用 `JSON` 或 `Share Code`。
