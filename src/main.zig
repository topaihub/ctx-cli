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
    const skill = @import("commands/skill.zig");
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
    .{ .name = "skill", .description = "安装/查看 Skill 模板", .run = commands.skill.run },
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
        const help_target = iter.next();
        try printCommandHelp(help_target);
        return;
    }
    if (std.mem.eql(u8, command_name, "-h")) {
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
    var app = App.init(allocator, args.environ, storage.asStorage(), markdown_formatter.asFormatter(), config);
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
    std.debug.print("error: unknown command '{s}'. try 'ctx help'.\n", .{command_name});
    try printUsage();
    return error.UnknownCommand;
}

fn printUsage() !void {
    log.plain(
        \\ctx-cli
        \\
        \\Usage:
        \\  ctx <command> [args]
        \\  ctx help
        \\  ctx help <command>
        \\
        \\Commands:
    , .{});
    inline for (command_list) |command| {
        log.plain("  {s:8} {s}\n", .{ command.name, command.description });
    }
    log.plain(
        \\
        \\Examples:
        \\  ctx init
        \\  ctx save demo --summary "first pass"
        \\  ctx load demo
        \\  ctx skill install --agent codex
    , .{});
}

fn printCommandHelp(command_name: ?[]const u8) !void {
    if (command_name == null) {
        try printUsage();
        return;
    }
    const name = command_name.?;
    if (std.mem.eql(u8, name, "save")) {
        log.plain("ctx save <project> --summary \"...\" [--pending \"...\"] [--files \"...\"] [--decisions \"...\"]\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "load")) {
        log.plain("ctx load <project>\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "append")) {
        log.plain("ctx append <project> --decision \"...\" | --progress \"...\" | --note \"...\" | --pending \"...\"\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "search")) {
        log.plain("ctx search <keyword>\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "delete")) {
        log.plain("ctx delete <project>\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "export")) {
        log.plain("ctx export <project>\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "init")) {
        log.plain("ctx init\n", .{});
        return;
    }
    if (std.mem.eql(u8, name, "skill")) {
        log.plain("ctx skill show\nctx skill install [--agent codex|claude|kiro|all] [--path PATH]\n", .{});
        return;
    }
    return error.UnknownCommand;
}

fn reportError(err: anyerror) void {
    if (err == error.UnknownCommand) {
        std.debug.print("error: unknown command. try 'ctx help'.\n", .{});
        return;
    }
    if (err == error.MissingProjectName) {
        std.debug.print("error: missing project name. usage: ctx <command> <project>\n", .{});
        return;
    }
    if (err == error.MissingQuery) {
        std.debug.print("error: missing query. usage: ctx search <keyword>\n", .{});
        return;
    }
    if (err == error.ProjectNotFound) {
        std.debug.print("error: project not found. run 'ctx list' to see available projects.\n", .{});
        return;
    }
    if (err == error.MissingSummary) {
        std.debug.print("error: missing summary. usage: ctx save <project> --summary \"...\"\n", .{});
        return;
    }
    if (err == error.MissingEntryContent) {
        std.debug.print("error: missing entry content. use one of --decision/--progress/--note/--pending.\n", .{});
        return;
    }
    if (err == error.UnknownSkillAction) {
        std.debug.print("error: unknown skill action. try 'ctx skill help'.\n", .{});
        return;
    }
    if (err == error.UnknownSkillAgent) {
        std.debug.print("error: unknown agent. use codex, claude, kiro, or all.\n", .{});
        return;
    }
    if (err == error.MissingSkillPath) {
        std.debug.print("error: missing --path value.\n", .{});
        return;
    }
    std.debug.print("error: {s}\n", .{@errorName(err)});
}
