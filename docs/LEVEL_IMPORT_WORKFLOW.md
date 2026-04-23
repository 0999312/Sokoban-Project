# Level Import Workflow

`LevelLoader` 已经支持单关 XSB 文本转本项目 `Level` JSON。
本工作流补上两类批量来源的转换方式：

1. 单个多关卡文本集：`.sok` / `.txt`
2. 目录式逐关文本集：例如 `docs/xsb_levels/screen.*`

## Script

使用 `scripts/import_levelset.gd`。

命令格式：

```text
godot4 --headless --script res://scripts/import_levelset.gd -- --input=<file-or-dir> --output=<dir> [--chapter=<chapter-id>] [--prefix=<level-id-prefix>] [--name-prefix=<i18n-prefix>] [--chapter-name=<display-name>] [--chapter-description=<text>] [--world=<order>] [--start=<first-index>] [--source-type=auto|file|dir]
```

参数说明：

- `--input`: 源文件或源目录的绝对路径
- `--output`: 输出目录的绝对路径
- `--chapter`: 生成的 `chapter.json` 的章节 id
- `--prefix`: 关卡 id 前缀，默认等于 `chapter`
- `--name-prefix`: 关卡名 i18n key 前缀；留空时直接使用源标题作为关卡名
- `--chapter-name`: 章节显示名
- `--chapter-description`: 章节说明文本
- `--world`: 写入 `chapter.order` 和关卡 `metadata.world`
- `--start`: 生成编号的起始值
- `--skip`: 跳过前 N 个源关卡，便于分批导入
- `--count`: 只导入接下来的 N 个源关卡，默认 `-1` 表示全部
- `--source-type`: `file` 表示多关卡文本，`dir` 表示目录，`auto` 自动判断

## Current Sources

### 1. Microban `.sok`

源文件：`docs/microban_levels/DavidWSkinner Microban.sok`

示例：

```text
godot4 --headless --script res://scripts/import_levelset.gd -- --input="E:/godot_learning/projects/sokoban/docs/microban_levels/DavidWSkinner Microban.sok" --output="E:/godot_learning/projects/sokoban/levels/official/w2" --chapter=official-w2 --prefix=official-w2 --chapter-name="Chapter 2 · Microban" --chapter-description="Imported full Microban set by David W Skinner." --world=2 --source-type=file
```

脚本会：

- 自动拆分每一关
- 读取 `Title:` 与 `Author:`
- 复用 `LevelLoader.parse_xsb()` 转本项目 JSON
- 复用 `LevelValidator.validate()` 做基础合法性检查
- 对静态校验不通过的关卡保留导入，并把结果写到 `metadata.import_validation`
- 输出 `01.json`, `02.json` ... 以及 `chapter.json`

### 2. Directory-style XSB set

源目录：`docs/xsb_levels/`

示例：

```text
godot4 --headless --script res://scripts/import_levelset.gd -- --input="E:/godot_learning/projects/sokoban/docs/xsb_levels" --output="E:/godot_learning/projects/sokoban/levels/official/w3" --chapter=official-w3 --prefix=official-w3 --chapter-name="Chapter 3 · XSB Classics" --chapter-description="Imported directory-style XSB reference set." --world=3 --source-type=dir
```

目录模式下：

- 每个文件视为一关
- 文件名作为 `source_title`
- 按自然顺序排序，例如 `screen.2` 会排在 `screen.10` 前面

## Output Conventions

每个导入关卡会写入：

- `id`
- `name`
- `author`
- `metadata.world`
- `metadata.index`
- `metadata.source_title`
- `metadata.source_index`
- `metadata.import_source`
- `metadata.verified_by_solver = false`

目前导入脚本只负责格式转换、基础静态校验与章节清单生成，不负责：

- 最优步数/推数
- 难度评级
- 标签与概念文案
- locale 文本补全

这些内容需要在导入后按目标章节再做人工筛选和补充。

## Current Full Imports

当前仓库已接入两套完整来源：

1. `docs/microban_levels/DavidWSkinner Microban.sok`
2. `docs/xsb_levels/screen.*`

导入结果：

1. `levels/official/w2/`：155 关完整 Microban 导入
2. `levels/official/w3/`：90 关目录式 XSB 参考导入（已正式提升为 Chapter 3）
