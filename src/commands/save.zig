const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

fn appendFmt(list: *std.array_list.Managed(u8), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try list.appendSlice(text);
}

fn getFlag(args: []const []const u8, name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + 1 < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], name)) return args[i + 1];
    }
    return null;
}

fn csvToJsonArray(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    if (text.len == 0) return try allocator.dupe(u8, "[]");
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.appendSlice("[");
    var first = true;
    var it = std.mem.splitScalar(u8, text, ',');
    while (it.next()) |item| {
        const trimmed = std.mem.trim(u8, item, " \t\r\n");
        if (trimmed.len == 0) continue;
        if (!first) try out.appendSlice(",");
        first = false;
        try appendFmt(&out, allocator, "\"{s}\"", .{trimmed});
    }
    try out.appendSlice("]");
    return out.toOwnedSlice();
}

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len == 0) return error.MissingProjectName;
    const project_id = args[0];
    const summary = getFlag(args, "--summary") orelse return error.MissingSummary;
    const pending = try csvToJsonArray(app.allocator, getFlag(args, "--pending") orelse "");
    defer app.allocator.free(@constCast(pending));
    const files = try csvToJsonArray(app.allocator, getFlag(args, "--files") orelse "");
    defer app.allocator.free(@constCast(files));
    const decisions = getFlag(args, "--decisions");

    try app.storage.saveProject(.{
        .id = project_id,
        .summary = summary,
        .pending = pending,
        .files = files,
        .created_at = "",
        .updated_at = "",
    });

    if (decisions) |text| {
        var it = std.mem.splitScalar(u8, text, ',');
        while (it.next()) |item| {
            const trimmed = std.mem.trim(u8, item, " \t\r\n");
            if (trimmed.len == 0) continue;
            try app.storage.appendEntry(project_id, .decision, trimmed);
        }
    }

    log.infoFields("save", "project saved", &.{
        log.fieldText("project", project_id),
        log.fieldText("summary", summary),
    });
}
