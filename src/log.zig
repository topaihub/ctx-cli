const std = @import("std");
const builtin = @import("builtin");
const logging = @import("zig-logging");

pub const Field = logging.LogField;

var managed_logger: ?logging.ManagedLogger = null;

pub const Settings = struct {
    level: logging.LogLevel = .info,
    console_style: logging.ConsoleStyle = .pretty,
    console_color_mode: logging.ConsoleColorMode = .auto,
    console_stream_routing: logging.ConsoleStreamRouting = .split,
    trace_console: bool = false,
    trace_console_color_mode: logging.ConsoleColorMode = .auto,
    file_path: ?[]const u8 = null,
    trace_file_path: ?[]const u8 = null,
};

pub fn init(allocator: std.mem.Allocator, environ: std.process.Environ) !void {
    if (managed_logger != null) return;

    var settings = Settings{};
    var file_path: ?[]const u8 = null;
    var trace_file_path: ?[]const u8 = null;

    if (try envString(allocator, environ, "CTX_LOG_LEVEL")) |value| {
        defer allocator.free(value);
        settings.level = parseLevel(value) orelse settings.level;
    }
    if (try envString(allocator, environ, "CTX_LOG_STYLE")) |value| {
        defer allocator.free(value);
        settings.console_style = parseStyle(value) orelse settings.console_style;
    }
    if (try envString(allocator, environ, "CTX_LOG_COLOR")) |value| {
        defer allocator.free(value);
        settings.console_color_mode = parseColorMode(value) orelse settings.console_color_mode;
    }
    if (try envString(allocator, environ, "CTX_LOG_ROUTING")) |value| {
        defer allocator.free(value);
        settings.console_stream_routing = parseRouting(value) orelse settings.console_stream_routing;
    }
    settings.trace_console = try envBool(allocator, environ, "CTX_LOG_TRACE_CONSOLE") orelse false;
    if (try envString(allocator, environ, "CTX_LOG_TRACE_COLOR")) |value| {
        defer allocator.free(value);
        settings.trace_console_color_mode = parseColorMode(value) orelse settings.trace_console_color_mode;
    }
    file_path = try envString(allocator, environ, "CTX_LOG_FILE");
    trace_file_path = try envString(allocator, environ, "CTX_LOG_TRACE_FILE");

    defer if (file_path) |p| allocator.free(p);
    defer if (trace_file_path) |p| allocator.free(p);

    managed_logger = try logging.create(allocator, .{
        .level = settings.level,
        .console = .{
            .style = settings.console_style,
            .color_mode = settings.console_color_mode,
            .stream_routing = settings.console_stream_routing,
        },
        .trace_console = if (settings.trace_console) .{
            .color_mode = settings.trace_console_color_mode,
        } else null,
        .file = if (file_path) |path| .{ .path = path } else null,
        .trace_file = if (trace_file_path) |path| .{ .path = path } else null,
    });
}

pub fn deinit() void {
    if (managed_logger) |*managed| {
        managed.deinit();
        managed_logger = null;
    }
}

pub fn info(scope: []const u8, message: []const u8) void {
    infoFields(scope, message, &.{});
}

pub fn infoFields(scope: []const u8, message: []const u8, fields: []const Field) void {
    if (builtin.is_test) return;
    if (managed_logger) |*managed| {
        (&managed.logger).child(scope).info(message, fields);
        return;
    }
    std.log.info("[{s}] {s}", .{ scope, message });
}

pub fn warn(scope: []const u8, message: []const u8) void {
    warnFields(scope, message, &.{});
}

pub fn warnFields(scope: []const u8, message: []const u8, fields: []const Field) void {
    if (builtin.is_test) return;
    if (managed_logger) |*managed| {
        (&managed.logger).child(scope).warn(message, fields);
        return;
    }
    std.log.warn("[{s}] {s}", .{ scope, message });
}

pub fn err(scope: []const u8, message: []const u8) void {
    errFields(scope, message, &.{});
}

pub fn errFields(scope: []const u8, message: []const u8, fields: []const Field) void {
    if (builtin.is_test) return;
    if (managed_logger) |*managed| {
        (&managed.logger).child(scope).@"error"(message, fields);
        return;
    }
    std.log.err("[{s}] {s}", .{ scope, message });
}

pub fn fieldText(key: []const u8, value: []const u8) Field {
    return Field.string(key, value);
}

pub fn fieldInt(key: []const u8, value: i64) Field {
    return Field.int(key, value);
}

pub fn fieldBool(key: []const u8, value: bool) Field {
    return Field.boolean(key, value);
}

pub fn plain(comptime fmt: []const u8, args: anytype) void {
    if (builtin.is_test) return;
    std.debug.print(fmt, args);
}

fn envString(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) !?[]u8 {
    return environ.getAlloc(allocator, key) catch |e| switch (e) {
        error.EnvironmentVariableMissing => null,
        else => return e,
    };
}

fn envBool(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) !?bool {
    if (try envString(allocator, environ, key)) |value| {
        defer allocator.free(value);
        if (std.ascii.eqlIgnoreCase(value, "1") or std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "yes") or std.ascii.eqlIgnoreCase(value, "on")) return true;
        if (std.ascii.eqlIgnoreCase(value, "0") or std.ascii.eqlIgnoreCase(value, "false") or std.ascii.eqlIgnoreCase(value, "no") or std.ascii.eqlIgnoreCase(value, "off")) return false;
        return null;
    }
    return null;
}

fn parseLevel(text: []const u8) ?logging.LogLevel {
    if (std.mem.eql(u8, text, "trace")) return .trace;
    if (std.mem.eql(u8, text, "debug")) return .debug;
    if (std.mem.eql(u8, text, "info")) return .info;
    if (std.mem.eql(u8, text, "warn")) return .warn;
    if (std.mem.eql(u8, text, "error")) return .@"error";
    if (std.mem.eql(u8, text, "fatal")) return .fatal;
    return null;
}

fn parseStyle(text: []const u8) ?logging.ConsoleStyle {
    if (std.mem.eql(u8, text, "pretty")) return .pretty;
    if (std.mem.eql(u8, text, "compact")) return .compact;
    if (std.mem.eql(u8, text, "json")) return .json;
    return null;
}

fn parseColorMode(text: []const u8) ?logging.ConsoleColorMode {
    if (std.mem.eql(u8, text, "auto")) return .auto;
    if (std.mem.eql(u8, text, "always")) return .always;
    if (std.mem.eql(u8, text, "never")) return .never;
    return null;
}

fn parseRouting(text: []const u8) ?logging.ConsoleStreamRouting {
    if (std.mem.eql(u8, text, "split")) return .split;
    if (std.mem.eql(u8, text, "stdout")) return .stdout;
    if (std.mem.eql(u8, text, "stderr")) return .stderr;
    return null;
}

