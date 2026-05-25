const std = @import("std");
const App = @import("../app.zig").App;
const skill_template = @import("../core/skill_template.zig");
const log = @import("../log.zig");

fn eq(text: []const u8, expected: []const u8) bool {
    return std.mem.eql(u8, text, expected);
}

fn optionValue(args: []const []const u8, name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + 1 < args.len) : (i += 1) {
        if (eq(args[i], name)) return args[i + 1];
    }
    return null;
}

fn hasFlag(args: []const []const u8, name: []const u8) bool {
    for (args) |arg| {
        if (eq(arg, name)) return true;
    }
    return false;
}

fn ensureParentDir(path: []const u8) !void {
    const dir = std.fs.path.dirname(path) orelse return error.InvalidSkillPath;
    if (dir.len == 0) return;

    if (!(dir.len >= 3 and dir[1] == ':' and (dir[2] == '\\' or dir[2] == '/'))) return error.InvalidSkillPath;

    var drive_root_buf: [3]u8 = undefined;
    drive_root_buf[0] = dir[0];
    drive_root_buf[1] = ':';
    drive_root_buf[2] = '\\';
    const root_dir = try std.Io.Dir.openDirAbsolute(std.Options.debug_io, drive_root_buf[0..], .{ .iterate = true });
    defer root_dir.close(std.Options.debug_io);
    const rel = dir[3..];
    if (rel.len != 0) try root_dir.createDirPath(std.Options.debug_io, rel);
}

fn writeSkillFile(allocator: std.mem.Allocator, path: []const u8) !void {
    try ensureParentDir(path);
    const rendered = try skill_template.render(allocator);
    defer allocator.free(rendered);

    const file = try std.Io.Dir.createFileAbsolute(std.Options.debug_io, path, .{ .truncate = true });
    defer file.close(std.Options.debug_io);
    try file.writeStreamingAll(std.Options.debug_io, rendered);
}

fn installForAgent(allocator: std.mem.Allocator, environ: std.process.Environ, agent: skill_template.Agent) ![]u8 {
    const path = try skill_template.defaultTargetPath(allocator, environ, agent);
    defer allocator.free(path);
    try writeSkillFile(allocator, path);
    return try allocator.dupe(u8, path);
}

fn printHelp() void {
    log.plain(
        \\ctx skill
        \\
        \\Usage:
        \\  ctx skill show
        \\  ctx skill install [--agent codex|claude|kiro|all] [--path PATH]
        \\
        \\Examples:
        \\  ctx skill install --agent codex
        \\  ctx skill install --agent all
        \\  ctx skill install --path C:\\Users\\you\\.codex\\skills\\context-manager\\SKILL.md
    , .{});
}

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len == 0 or eq(args[0], "help") or eq(args[0], "--help")) {
        printHelp();
        return;
    }

    const action = args[0];
    const rest = args[1..];

    if (eq(action, "show")) {
        const rendered = try skill_template.render(app.allocator);
        defer app.allocator.free(rendered);
        log.plain("{s}\n", .{rendered});
        return;
    }

    if (!eq(action, "install")) return error.UnknownSkillAction;

    if (hasFlag(rest, "--path")) {
        const path = optionValue(rest, "--path") orelse return error.MissingSkillPath;
        try writeSkillFile(app.allocator, path);
        log.infoFields("skill", "skill file installed", &.{ log.fieldText("path", path) });
        return;
    }

    const agent_text = optionValue(rest, "--agent") orelse "codex";
    if (eq(agent_text, "all")) {
        const codex = try installForAgent(app.allocator, app.environ, .codex);
        defer app.allocator.free(codex);
        const claude = try installForAgent(app.allocator, app.environ, .claude);
        defer app.allocator.free(claude);
        const kiro = try installForAgent(app.allocator, app.environ, .kiro);
        defer app.allocator.free(kiro);
        log.infoFields("skill", "skill files installed", &.{
            log.fieldText("codex", codex),
            log.fieldText("claude", claude),
            log.fieldText("kiro", kiro),
        });
        return;
    }

    const agent: skill_template.Agent = if (eq(agent_text, "codex")) .codex else if (eq(agent_text, "claude")) .claude else if (eq(agent_text, "kiro")) .kiro else return error.UnknownSkillAgent;
    const installed_path = try installForAgent(app.allocator, app.environ, agent);
    defer app.allocator.free(installed_path);
    log.infoFields("skill", "skill file installed", &.{ log.fieldText("path", installed_path) });
}
