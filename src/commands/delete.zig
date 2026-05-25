const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

pub fn run(app: *App, args: []const []const u8) !void {
    if (args.len == 0) return error.MissingProjectName;
    try app.storage.deleteProject(args[0]);
    log.infoFields("delete", "project deleted", &.{
        log.fieldText("project", args[0]),
    });
}