# ctx-cli 未实现项补充设计

## 范围

这份设计只覆盖当前仓库里仍未完全落地的部分，不重复已实现的主流程：

- `save/load/append/list/search/delete/export/init` 命令
- SQLite 存储实现
- `zig build test` 构建入口

## 已实现基线

- `Storage` 已经是 VTable 接口
- `sqlite_storage` 已经可用
- `main.zig` 已有命令分发
- `formatter.zig` 已有 Markdown 渲染逻辑

## 仍需补齐的设计

### 1. Formatter 接口抽象

当前 `formatter.zig` 还是直接导出渲染函数，命令层也直接依赖具体模块。
这会让命令测试只能走真实渲染逻辑，无法像 `Storage` 一样替换成 mock。

设计目标：

- 把格式化能力抽成和 `Storage` 类似的接口
- 命令层只依赖抽象，不直接依赖具体渲染函数
- 测试时可注入 mock formatter，验证命令参数和输出流程

建议形态：

- 新增 `src/core/formatter_iface.zig`
- 定义 `Formatter` + `VTable`
- 保留现有 Markdown 渲染实现作为默认实现

### 2. 命令级测试桩

当前缺少 `tests/commands_test.zig`。
这意味着命令参数解析、错误分支、storage 调用顺序都没有回归保护。

设计目标：

- 为每个命令提供最小可测入口
- 使用 mock `Storage`
- 必要时使用 mock `Formatter`
- 重点验证“参数解析 + 调用契约”，不重复测 SQLite

建议测试点：

- `save` 能正确解析 `--summary/--pending/--files/--decisions`
- `load` 会先查项目，再查 entries，再渲染输出
- `append` 只追加记录，不改写项目主体
- `list/search/delete/export/init` 的关键分支都能被覆盖

### 3. 存储测试隔离

当前 storage 测试使用固定文件 `ctx-test.db`。
这会带来两个问题：

- 测试之间可能互相污染
- 运行失败后容易留下脏文件

设计目标：

- 改为每个测试使用独立的临时数据库
- 优先支持 `:memory:`，如果某些 SQLite 行为需要文件句柄，再使用临时目录文件
- 测试结束自动清理

建议原则：

- 纯 CRUD/FTS 行为优先 `:memory:`
- 需要验证文件路径或 WAL 行为时再落临时文件

### 4. CLI 错误输出契约

当前命令多是 `error union`，但“用户可见错误输出到 stderr”的边界还不够清晰。

设计目标：

- 主入口统一捕获命令错误
- 用户可见错误走 stderr
- 日志和错误提示分离
- 退出码保持稳定，便于脚本调用

建议规则：

- 命令层只返回错误，不直接打印通用错误文案
- `main.zig` 负责把错误翻译成用户可见提示
- usage/help 仍可正常输出

## 不做的事

- 不把当前实现改成 Python 方案
- 不在这一步补 Skill 目录包装
- 不重写现有 SQLite schema
- 不调整现有命令语义

