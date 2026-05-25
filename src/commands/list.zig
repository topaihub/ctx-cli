const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

pub fn run(app: *App, args: []const []const u8) !void {
    _ = args;
    const projects = try app.storage.listProjects(app.allocator);
    defer {
        for (projects) |project| project.deinit(app.allocator);
        app.allocator.free(projects);
    }

    const rendered = try app.formatter.renderListMarkdown(app.allocator, projects);
    defer app.allocator.free(rendered);
    log.plain("{s}", .{rendered});
}
