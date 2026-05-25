const std = @import("std");
const App = @import("app.zig").App;
const Config = @import("config.zig").Config;
const formatter = @import("core/formatter.zig");
const log = @import("log.zig");
const sqlite = @import("infra/sqlite_storage.zig");
const commands = struct {
    const save = @import("commands/save.zig");
    const load = @import("commands/load.zig");
    const append = @import("commands/append.zig");
    const list = @import("commands/list.zig");
    const search = @import("commands/search.zig");
    const delete_cmd = @import("commands/delete.zig");
    const export_cmd = @import("commands/export.zig");
    const init = @import("commands/init.zig");
};

const Command = struct {
    name: []const u8,
    description: []const u8,
    run: *const fn (*App, []const []const u8) anyerror!void,
};

const command_list = [_]Command{
    .{ .name = "init", .description = "初始化数据库", .run = commands.init.run },
    .{ .name = "save", .description = "保存项目上下文", .run = commands.save.run },
    .{ .name = "load", .description = "读取项目上下文", .run = commands.load.run },
    .{ .name = "append", .description = "追加记录", .run = commands.append.run },
    .{ .name = "list", .description = "列出所有项目", .run = commands.list.run },
    .{ .name = "search", .description = "搜索上下文", .run = commands.search.run },
    .{ .name = "delete", .description = "删除项目", .run = commands.delete_cmd.run },
    .{ .name = "export", .description = "导出为 Markdown", .run = commands.export_cmd.run },
};

pub fn main(args: std.process.Init.Minimal) void {
    run(args) catch |err| {
        reportError(err);
        std.process.exit(1);
    };
}

fn run(args: std.process.Init.Minimal) !void {
    const allocator = std.heap.page_allocator;
    var iter = try std.process.Args.Iterator.initAllocator(args.args, allocator);
    defer iter.deinit();

    _ = iter.next();
    const command_name = iter.next() orelse {
        try printUsage();
        return;
    };
    if (std.mem.eql(u8, command_name, "help") or std.mem.eql(u8, command_name, "--help")) {
        try printUsage();
        return;
    }

    try log.init(allocator, args.environ);
    defer log.deinit();

    var config = try Config.load(allocator, args.environ);
    defer config.deinit(allocator);

    var storage = try sqlite.SqliteStorage.open(allocator, config.db_path);
    defer storage.deinit();

    var markdown_formatter = formatter.MarkdownFormatter{};
    var app = App.init(allocator, storage.asStorage(), markdown_formatter.asFormatter(), config);
    defer app.deinit();

    var rest = std.array_list.Managed([]const u8).init(allocator);
    defer rest.deinit();
    while (iter.next()) |arg| {
        try rest.append(arg[0..arg.len]);
    }

    inline for (command_list) |command| {
        if (std.mem.eql(u8, command.name, command_name)) {
            try command.run(&app, rest.items);
            return;
        }
    }

    log.warnFields("cli", "unknown command", &.{ log.fieldText("command", command_name[0..command_name.len]) });
    try printUsage();
    return error.UnknownCommand;
}

fn printUsage() !void {
    log.plain("ctx-cli\n\nCommands:\n", .{});
    inline for (command_list) |command| {
        log.plain("  {s:8} {s}\n", .{ command.name, command.description });
    }
}

fn reportError(err: anyerror) void {
    if (err == error.UnknownCommand) {
        std.debug.print("error: unknown command\n", .{});
        return;
    }
    if (err == error.MissingProjectName) {
        std.debug.print("error: missing project name\n", .{});
        return;
    }
    if (err == error.MissingQuery) {
        std.debug.print("error: missing query\n", .{});
        return;
    }
    if (err == error.ProjectNotFound) {
        std.debug.print("error: project not found\n", .{});
        return;
    }
    std.debug.print("error: {s}\n", .{@errorName(err)});
}
