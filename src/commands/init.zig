const std = @import("std");
const App = @import("../app.zig").App;
const log = @import("../log.zig");

pub fn run(app: *App, args: []const []const u8) !void {
    _ = args;
    try app.storage.ensureSchema();
    log.infoFields("init", "database initialized", &.{
        log.fieldText("database", app.config.db_path),
    });
}