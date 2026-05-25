const std = @import("std");
const models = @import("models.zig");

pub const Storage = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        ensure_schema: *const fn (ptr: *anyopaque) anyerror!void,
        save_project: *const fn (ptr: *anyopaque, project: models.Project) anyerror!void,
        load_project: *const fn (ptr: *anyopaque, id: []const u8, allocator: std.mem.Allocator) anyerror!?models.Project,
        list_projects: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]models.Project,
        append_entry: *const fn (ptr: *anyopaque, project_id: []const u8, entry_type: models.EntryType, content: []const u8) anyerror!void,
        list_entries: *const fn (ptr: *anyopaque, project_id: []const u8, allocator: std.mem.Allocator) anyerror![]models.Entry,
        search: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, query: []const u8) anyerror![]models.Entry,
        delete_project: *const fn (ptr: *anyopaque, id: []const u8) anyerror!void,
    };

    pub fn ensureSchema(self: Storage) !void {
        return self.vtable.ensure_schema(self.ptr);
    }

    pub fn saveProject(self: Storage, project: models.Project) !void {
        return self.vtable.save_project(self.ptr, project);
    }

    pub fn loadProject(self: Storage, id: []const u8, allocator: std.mem.Allocator) !?models.Project {
        return self.vtable.load_project(self.ptr, id, allocator);
    }

    pub fn listProjects(self: Storage, allocator: std.mem.Allocator) ![]models.Project {
        return self.vtable.list_projects(self.ptr, allocator);
    }

    pub fn appendEntry(self: Storage, project_id: []const u8, entry_type: models.EntryType, content: []const u8) !void {
        return self.vtable.append_entry(self.ptr, project_id, entry_type, content);
    }

    pub fn listEntries(self: Storage, project_id: []const u8, allocator: std.mem.Allocator) ![]models.Entry {
        return self.vtable.list_entries(self.ptr, project_id, allocator);
    }

    pub fn search(self: Storage, allocator: std.mem.Allocator, query: []const u8) ![]models.Entry {
        return self.vtable.search(self.ptr, allocator, query);
    }

    pub fn deleteProject(self: Storage, id: []const u8) !void {
        return self.vtable.delete_project(self.ptr, id);
    }
};
