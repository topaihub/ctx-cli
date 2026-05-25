const std = @import("std");
const models = @import("models.zig");
const formatter_iface = @import("formatter_iface.zig");

pub const Formatter = formatter_iface.Formatter;

pub const MarkdownFormatter = struct {
    const Self = @This();

    pub fn asFormatter(self: *Self) Formatter {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn renderProjectMarkdownV(
        ptr: *anyopaque,
        allocator: std.mem.Allocator,
        project: models.Project,
        entries: []const models.Entry,
    ) anyerror![]u8 {
        _ = ptr;
        return renderProjectMarkdownImpl(allocator, project, entries);
    }

    fn renderListMarkdownV(ptr: *anyopaque, allocator: std.mem.Allocator, projects: []const models.Project) anyerror![]u8 {
        _ = ptr;
        return renderListMarkdownImpl(allocator, projects);
    }

    const vtable = Formatter.VTable{
        .render_project_markdown = renderProjectMarkdownV,
        .render_list_markdown = renderListMarkdownV,
    };
};

fn appendFmt(list: *std.array_list.Managed(u8), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try list.appendSlice(text);
}

fn writeSection(list: *std.array_list.Managed(u8), allocator: std.mem.Allocator, title: []const u8, body: []const u8) !void {
    try appendFmt(list, allocator, "## {s}\n", .{title});
    if (body.len == 0) {
        try list.appendSlice("(empty)\n\n");
    } else {
        try appendFmt(list, allocator, "{s}\n\n", .{body});
    }
}

fn renderProjectMarkdownImpl(allocator: std.mem.Allocator, project: models.Project, entries: []const models.Entry) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();

    try appendFmt(&out, allocator, "# 项目上下文：{s}\n\n", .{project.id});
    try writeSection(&out, allocator, "当前状态", project.summary);
    try writeSection(&out, allocator, "待做", project.pending);
    try writeSection(&out, allocator, "关键文件", project.files);

    try out.appendSlice("## 关键决策\n");
    var has_decision = false;
    for (entries) |entry| {
        if (entry.entry_type != .decision) continue;
        has_decision = true;
        try appendFmt(&out, allocator, "1. [{s}] {s}\n", .{ entry.created_at, entry.content });
    }
    if (!has_decision) try out.appendSlice("(empty)\n");
    try out.appendSlice("\n");

    try out.appendSlice("## 已完成\n");
    var has_progress = false;
    for (entries) |entry| {
        if (entry.entry_type != .progress) continue;
        has_progress = true;
        try appendFmt(&out, allocator, "- [{s}] {s}\n", .{ entry.created_at, entry.content });
    }
    if (!has_progress) try out.appendSlice("(empty)\n");
    try out.appendSlice("\n");

    try out.appendSlice("## 备注\n");
    var has_note = false;
    for (entries) |entry| {
        if (entry.entry_type != .note) continue;
        has_note = true;
        try appendFmt(&out, allocator, "- [{s}] {s}\n", .{ entry.created_at, entry.content });
    }
    if (!has_note) try out.appendSlice("(empty)\n");
    try out.appendSlice("\n");

    try out.appendSlice("## 待做记录\n");
    var has_pending = false;
    for (entries) |entry| {
        if (entry.entry_type != .pending) continue;
        has_pending = true;
        try appendFmt(&out, allocator, "- [{s}] {s}\n", .{ entry.created_at, entry.content });
    }
    if (!has_pending) try out.appendSlice("(empty)\n");

    return out.toOwnedSlice();
}

fn renderListMarkdownImpl(allocator: std.mem.Allocator, projects: []const models.Project) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.appendSlice("项目                 最后更新            状态摘要\n");
    try out.appendSlice("-------------------  ------------------  ----------------\n");
    for (projects) |project| {
        try appendFmt(&out, allocator, "{s:19}  {s:18}  {s}\n", .{ project.id, project.updated_at, project.summary });
    }
    return out.toOwnedSlice();
}

pub fn renderProjectMarkdown(allocator: std.mem.Allocator, project: models.Project, entries: []const models.Entry) ![]u8 {
    return renderProjectMarkdownImpl(allocator, project, entries);
}

pub fn renderListMarkdown(allocator: std.mem.Allocator, projects: []const models.Project) ![]u8 {
    return renderListMarkdownImpl(allocator, projects);
}
