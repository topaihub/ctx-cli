# ctx-cli

Zig 版 AI Agent 持久化上下文 CLI。

## 当前状态
- 已搭建项目骨架
- 已接入 SQLite 存储实现
- 已提供 `save` / `load` / `append` / `list` / `search` / `delete` / `export`

## 运行
```bash
zig build run -- save "demo" --summary "first pass"
zig build run -- load "demo"
```

## 测试
```bash
zig build test
```

## 说明
- 日志层已独立封装，后续可直接替换为 `topaihub/zig-logging`
- 数据库存放在 `~/.ctx/contexts.db`
