const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

fn getFlag(args: []const []const u8, name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + 1 < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], name)) return args[i + 1];
    }
    return null;
}

fn countKinds(decision: ?[]const u8, progress: ?[]const u8, note: ?[]const u8, pending: ?[]const u8) usize {
    var count: usize = 0;
    if (decision != null) count += 1;
    if (progress != null) count += 1;
    if (note != null) count += 1;
    if (pending != null) count += 1;
    return count;
}

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len == 0) return error.MissingProjectName;
    const project_id = args[0];

    const decision = getFlag(args, "--decision");
    const progress = getFlag(args, "--progress");
    const note = getFlag(args, "--note");
    const pending = getFlag(args, "--pending");

    const kind_count = countKinds(decision, progress, note, pending);
    if (kind_count == 0) return error.MissingEntryContent;
    if (kind_count > 1) return error.MultipleEntryKinds;

    if (decision) |text| try app.storage.appendEntry(project_id, .decision, text);
    if (progress) |text| try app.storage.appendEntry(project_id, .progress, text);
    if (note) |text| try app.storage.appendEntry(project_id, .note, text);
    if (pending) |text| try app.storage.appendEntry(project_id, .pending, text);

    log.infoFields("append", "entry appended", &.{
        log.fieldText("project", project_id),
        log.fieldBool("has_decision", decision != null),
        log.fieldBool("has_progress", progress != null),
        log.fieldBool("has_note", note != null),
        log.fieldBool("has_pending", pending != null),
    });
}
