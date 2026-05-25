const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len == 0) return error.MissingQuery;
    const query = args[0];

    const entries = try app.storage.search(app.allocator, query);
    defer {
        for (entries) |entry| entry.deinit(app.allocator);
        app.allocator.free(entries);
    }

    for (entries) |entry| {
        log.plain("{s}\t{s}\t{s}\t{s}\n", .{
            entry.project_id,
            entry.entry_type.toString(),
            entry.created_at,
            entry.content,
        });
    }
}