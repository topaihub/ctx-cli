# ctx-cli 未实现项 Tasks

## Task 1: 抽出 Formatter 接口

目标：让格式化层和 `Storage` 一样可替换，便于命令测试。

步骤：

- 新增 `src/core/formatter_iface.zig`
- 定义 `Formatter` 接口和 `VTable`
- 把现有 Markdown 渲染逻辑接到默认实现里
- 让 `App` 持有 formatter 抽象
- 更新 `load/list/export` 等命令只依赖抽象

验收：

- 命令层不直接依赖具体渲染函数
- 代码里可以注入 mock formatter

## Task 2: 补 `commands_test.zig`

目标：覆盖命令参数解析和调用契约。

步骤：

- 新增 `tests/commands_test.zig`
- 实现 mock `Storage`
- 必要时实现 mock `Formatter`
- 覆盖 `save/load/append/list/search/delete/export/init`
- 验证错误分支，例如缺少 project 名称、缺少 query

验收：

- 命令测试不依赖真实 SQLite
- 关键命令都有最少一条回归测试

## Task 3: 存储测试改成临时数据库

目标：避免固定测试文件污染。

步骤：

- 把 `tests/storage_test.zig` 的固定文件改成临时路径或 `:memory:`
- 为每个测试创建独立数据库
- 测试结束自动释放和清理

验收：

- 跑完测试后工作区不再依赖 `ctx-test.db`
- 重跑测试不会因为旧数据失败

## Task 4: 统一 CLI 错误输出

目标：让用户可见错误稳定输出到 stderr。

步骤：

- 在 `main.zig` 增加统一错误捕获
- 把命令错误映射为用户可读文案
- 保留 usage/help 输出
- 区分普通错误和日志输出

验收：

- 命令失败时用户能在 stderr 看到明确提示
- 脚本调用能依赖稳定退出状态

## Task 5: 回补测试挂接

目标：确保新增测试自动进入 `zig build test`。

步骤：

- 在 `build.zig` 中挂接 `commands_test`
- 保持 `storage_test` 和 `formatter_test` 的执行
- 确保所有测试都在同一个 `test` step 下

验收：

- `zig build test` 会跑到新增命令测试
- 无需单独记忆额外测试命令

