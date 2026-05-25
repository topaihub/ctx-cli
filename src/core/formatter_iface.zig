const std = @import("std");
const models = @import("models.zig");

pub const Formatter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        render_project_markdown: *const fn (
            ptr: *anyopaque,
            allocator: std.mem.Allocator,
            project: models.Project,
            entries: []const models.Entry,
        ) anyerror![]u8,
        render_list_markdown: *const fn (
            ptr: *anyopaque,
            allocator: std.mem.Allocator,
            projects: []const models.Project,
        ) anyerror![]u8,
    };

    pub fn renderProjectMarkdown(
        self: Formatter,
        allocator: std.mem.Allocator,
        project: models.Project,
        entries: []const models.Entry,
    ) ![]u8 {
        return self.vtable.render_project_markdown(self.ptr, allocator, project, entries);
    }

    pub fn renderListMarkdown(self: Formatter, allocator: std.mem.Allocator, projects: []const models.Project) ![]u8 {
        return self.vtable.render_list_markdown(self.ptr, allocator, projects);
    }
};
