const std = @import("std");

pub const Config = struct {
    db_path: []const u8,

    pub fn load(allocator: std.mem.Allocator, environ: std.process.Environ) !Config {
        if (environ.getAlloc(allocator, "CTX_DB_PATH")) |override| {
            return .{ .db_path = override };
        } else |_| {}

        const home = environ.getAlloc(allocator, "USERPROFILE") catch environ.getAlloc(allocator, "HOME") catch return error.HomeDirectoryNotFound;
        const path = try std.fs.path.join(allocator, &.{ home, ".ctx", "contexts.db" });
        const dir = std.fs.path.dirname(path) orelse return error.InvalidDatabasePath;
        if (dir.len >= 3 and dir[1] == ':' and (dir[2] == '\\' or dir[2] == '/')) {
            var drive_root_buf: [3]u8 = undefined;
            drive_root_buf[0] = dir[0];
            drive_root_buf[1] = ':';
            drive_root_buf[2] = '\\';
            const root_dir = try std.Io.Dir.openDirAbsolute(std.Options.debug_io, drive_root_buf[0..], .{ .iterate = true });
            defer root_dir.close(std.Options.debug_io);
            const rel = dir[3..];
            if (rel.len != 0) try root_dir.createDirPath(std.Options.debug_io, rel);
        }
        allocator.free(home);
        return .{ .db_path = path };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(@constCast(self.db_path));
    }
};
