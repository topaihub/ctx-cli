# ctx CLI — Zig 实现设计

## 技术栈

- 语言：Zig 0.16+
- 数据库：SQLite（C 库直接编译进二进制）
- 日志：zig-logging（和 mowen-cli 一致）
- 构建：build.zig + build.zig.zon
- 输出：单二进制 ~2MB，零运行时依赖

## 架构模式（对齐 mowen-cli）

### 面向接口：VTable 模式

```zig
// core/storage.zig — 存储接口
pub const Storage = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        save_project: *const fn (ptr: *anyopaque, project: Project) anyerror!void,
        load_project: *const fn (ptr: *anyopaque, id: []const u8) anyerror!?Project,
        list_projects: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]Project,
        append_entry: *const fn (ptr: *anyopaque, project_id: []const u8, entry: Entry) anyerror!void,
        search: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, query: []const u8) anyerror![]Entry,
        delete_project: *const fn (ptr: *anyopaque, id: []const u8) anyerror!void,
    };

    pub fn saveProject(self: Storage, project: Project) !void {
        return self.vtable.save_project(self.ptr, project);
    }
    pub fn loadProject(self: Storage, id: []const u8) !?Project {
        return self.vtable.load_project(self.ptr, id);
    }
    // ... 其他方法同理
};
```

```zig
// infra/sqlite_storage.zig — SQLite 实现
pub const SqliteStorage = struct {
    db: *c.sqlite3,
    allocator: std.mem.Allocator,

    pub fn asStorage(self: *SqliteStorage) Storage {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    const vtable = Storage.VTable{
        .save_project = saveProjectImpl,
        .load_project = loadProjectImpl,
        .list_projects = listProjectsImpl,
        .append_entry = appendEntryImpl,
        .search = searchImpl,
        .delete_project = deleteProjectImpl,
    };
    // ... 实现
};
```

### 命令注册表（和 mowen-cli 一致）

```zig
// main.zig
const CommandEntry = struct {
    name: []const u8,
    description: []const u8,
    run: *const fn (*App, *std.process.Args.Iterator) anyerror!void,
};

const commands = [_]CommandEntry{
    .{ .name = "save", .description = "保存项目上下文", .run = commands_save.run },
    .{ .name = "load", .description = "读取项目上下文", .run = commands_load.run },
    .{ .name = "append", .description = "追加记录", .run = commands_append.run },
    .{ .name = "list", .description = "列出所有项目", .run = commands_list.run },
    .{ .name = "search", .description = "搜索上下文", .run = commands_search.run },
    .{ .name = "delete", .description = "删除项目", .run = commands_delete.run },
    .{ .name = "export", .description = "导出为 Markdown", .run = commands_export.run },
};
```

### App 上下文（和 mowen-cli 一致）

```zig
// app.zig
pub const App = struct {
    allocator: std.mem.Allocator,
    storage: Storage,
    log: logging.SubsystemLogger,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, storage: Storage) App {
        return .{
            .allocator = allocator,
            .storage = storage,
            .log = log.child("app"),
            .config = Config.load(allocator) catch Config.defaults(),
        };
    }
};
```

## 目录结构

```
ctx-cli/
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig              ← 入口：参数解析 + 命令分发
│   ├── app.zig               ← App 上下文（storage + log + config）
│   ├── config.zig            ← 配置（数据库路径等）
│   ├── log.zig               ← 日志初始化（zig-logging）
│   ├── core/
│   │   ├── storage.zig       ← Storage 接口（VTable）
│   │   ├── models.zig        ← 数据模型（Project, Entry）
│   │   └── formatter.zig     ← 输出格式化（Markdown 结构）
│   ├── infra/
│   │   └── sqlite_storage.zig ← SQLite 实现
│   └── commands/
│       ├── save.zig
│       ├── load.zig
│       ├── append.zig
│       ├── list.zig
│       ├── search.zig
│       ├── delete.zig
│       └── export.zig
├── tests/
│   ├── storage_test.zig
│   └── commands_test.zig
├── AGENTS.md                  ← 编码规范
└── README.md
```

## 数据模型

```zig
// core/models.zig
pub const Project = struct {
    id: []const u8,           // 项目名
    summary: []const u8,      // 当前状态
    pending: []const u8,      // JSON array
    files: []const u8,        // JSON array
    created_at: []const u8,   // ISO 8601
    updated_at: []const u8,
};

pub const Entry = struct {
    id: []const u8,           // UUID
    project_id: []const u8,
    entry_type: EntryType,
    content: []const u8,
    created_at: []const u8,
};

pub const EntryType = enum {
    decision,
    progress,
    note,
    pending,

    pub fn toString(self: EntryType) []const u8 {
        return switch (self) {
            .decision => "decision",
            .progress => "progress",
            .note => "note",
            .pending => "pending",
        };
    }
};
```

## 日志规范

```zig
// 使用 zig-logging，和 mowen-cli 一致
const log = @import("log.zig");

// 在命令中使用
log.info("save", "project saved", &.{
    .{ .key = "project", .value = project_id },
    .{ .key = "entries", .value = entry_count },
});

log.err("load", "project not found", &.{
    .{ .key = "project", .value = project_id },
});
```

日志输出到 `ctx-cli.log`，支持 trace/pretty/compact 三种风格。

## 编码规范（AGENTS.md）

```markdown
# ctx-cli 编码规范

## 接口
- 所有外部依赖通过 VTable 接口抽象（Storage, Formatter）
- 测试时可以替换为 mock 实现

## 命令
- 每个命令一个文件，导出 `pub fn run(*App, *Args.Iterator) anyerror!void`
- 命令只做参数解析 + 调用 App/Storage，不直接操作 SQLite

## 错误处理
- 用 Zig 的 error union（`anyerror!T`）
- 用户可见的错误输出到 stderr
- 内部错误记录到日志文件

## 内存
- 所有分配通过 allocator 参数传递
- 命令结束时 defer 释放
- 不使用全局分配器

## 测试
- `zig build test` 跑所有测试
- Storage 测试用内存 SQLite（`:memory:`）
- 命令测试用 mock Storage
```

## 依赖

```zig
// build.zig.zon
.dependencies = .{
    .@"zig-logging" = .{ ... },   // 日志（和 mowen-cli 共用）
    .sqlite = .{ ... },            // SQLite C 库绑定
},
```

SQLite 推荐用 [zig-sqlite](https://github.com/vrischmann/zig-sqlite) 或直接 `@cImport` sqlite3.h。

## 构建与分发

```bash
# 开发
zig build run -- load "msgflow重构"

# 测试
zig build test

# 发布（交叉编译）
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux
zig build -Doptimize=ReleaseSafe -Dtarget=aarch64-macos
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows

# 安装到 PATH
cp zig-out/bin/ctx ~/.local/bin/
```

输出单文件 ~2MB，任何机器直接跑，不需要安装运行时。
