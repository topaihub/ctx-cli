const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len == 0) return error.MissingProjectName;
    const project_id = args[0];

    const project = try app.storage.loadProject(project_id, app.allocator) orelse return error.ProjectNotFound;
    defer project.deinit(app.allocator);
    const entries = try app.storage.listEntries(project_id, app.allocator);
    defer {
        for (entries) |entry| entry.deinit(app.allocator);
        app.allocator.free(entries);
    }

    const rendered = try app.formatter.renderProjectMarkdown(app.allocator, project, entries);
    defer app.allocator.free(rendered);
    log.plain("{s}\n", .{rendered});
}
