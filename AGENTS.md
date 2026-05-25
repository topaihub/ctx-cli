# ctx-cli 编码规范

## 接口
- 所有外部依赖通过 VTable 接口抽象
- 测试可替换为 mock 实现

## 命令
- 每个命令一个文件
- 命令只做参数解析 + 调用 App/Storage

## 错误处理
- 使用 Zig error union
- 用户可见错误输出到 stderr

## 内存
- 所有分配通过 allocator 传递
- 命令结束时 defer 释放

## 测试
- `zig build test` 跑所有测试
- Storage 测试使用临时 SQLite 数据库
- 命令测试用 mock Storage
