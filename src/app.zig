const std = @import("std");
const Config = @import("config.zig").Config;
const Storage = @import("core/storage.zig").Storage;
const Formatter = @import("core/formatter_iface.zig").Formatter;

pub const App = struct {
    allocator: std.mem.Allocator,
    storage: Storage,
    formatter: Formatter,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, storage: Storage, formatter: Formatter, config: Config) App {
        return .{
            .allocator = allocator,
            .storage = storage,
            .formatter = formatter,
            .config = config,
        };
    }

    pub fn deinit(self: *App) void {
        _ = self;
    }
};
