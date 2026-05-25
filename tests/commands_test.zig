const std = @import("std");
const ctx = @import("ctx");

const App = ctx.App;
const commands = ctx.commands;
const models = ctx.models;
const Storage = ctx.storage.Storage;
const Formatter = ctx.formatter_iface.Formatter;

const AppendCall = struct {
    project_id: []u8,
    entry_type: models.EntryType,
    content: []u8,
};

const MockStorage = struct {
    allocator: std.mem.Allocator,
    ensure_schema_calls: usize = 0,
    saved_project: ?models.Project = null,
    load_project_result: ?models.Project = null,
    list_projects_result: []const models.Project = &.{},
    append_calls: std.array_list.Managed(AppendCall),
    list_entries_result: []const models.Entry = &.{},
    search_result: []const models.Entry = &.{},
    deleted_project_id: ?[]u8 = null,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .append_calls = std.array_list.Managed(AppendCall).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        if (self.saved_project) |project| project.deinit(self.allocator);
        if (self.deleted_project_id) |id| self.allocator.free(id);
        for (self.append_calls.items) |call| {
            self.allocator.free(call.project_id);
            self.allocator.free(call.content);
        }
        self.append_calls.deinit();
    }

    fn cloneText(self: *Self, text: []const u8) ![]u8 {
        return try self.allocator.dupe(u8, text);
    }

    fn cloneProject(self: *Self, allocator: std.mem.Allocator, project: models.Project) !models.Project {
        _ = self;
        return .{
            .id = try allocator.dupe(u8, project.id),
            .summary = try allocator.dupe(u8, project.summary),
            .pending = try allocator.dupe(u8, project.pending),
            .files = try allocator.dupe(u8, project.files),
            .created_at = try allocator.dupe(u8, project.created_at),
            .updated_at = try allocator.dupe(u8, project.updated_at),
        };
    }

    fn cloneEntry(self: *Self, entry: models.Entry) !models.Entry {
        return .{
            .id = try self.cloneText(entry.id),
            .project_id = try self.cloneText(entry.project_id),
            .entry_type = entry.entry_type,
            .content = try self.cloneText(entry.content),
            .created_at = try self.cloneText(entry.created_at),
        };
    }

    fn cloneProjectSlice(self: *Self, source: []const models.Project, allocator: std.mem.Allocator) ![]models.Project {
        _ = self;
        var out = try allocator.alloc(models.Project, source.len);
        errdefer {
            for (out) |project| project.deinit(allocator);
            allocator.free(out);
        }
        for (source, 0..) |project, i| {
            out[i] = .{
                .id = try allocator.dupe(u8, project.id),
                .summary = try allocator.dupe(u8, project.summary),
                .pending = try allocator.dupe(u8, project.pending),
                .files = try allocator.dupe(u8, project.files),
                .created_at = try allocator.dupe(u8, project.created_at),
                .updated_at = try allocator.dupe(u8, project.updated_at),
            };
        }
        return out;
    }

    fn cloneEntrySlice(self: *Self, source: []const models.Entry, allocator: std.mem.Allocator) ![]models.Entry {
        _ = self;
        var out = try allocator.alloc(models.Entry, source.len);
        errdefer {
            for (out) |entry| entry.deinit(allocator);
            allocator.free(out);
        }
        for (source, 0..) |entry, i| {
            out[i] = .{
                .id = try allocator.dupe(u8, entry.id),
                .project_id = try allocator.dupe(u8, entry.project_id),
                .entry_type = entry.entry_type,
                .content = try allocator.dupe(u8, entry.content),
                .created_at = try allocator.dupe(u8, entry.created_at),
            };
        }
        return out;
    }

    fn asStorage(self: *Self) Storage {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn ensureSchemaImpl(self: *Self) !void {
        self.ensure_schema_calls += 1;
    }

    fn saveProjectImpl(self: *Self, project: models.Project) !void {
        if (self.saved_project) |old| old.deinit(self.allocator);
        self.saved_project = try self.cloneProject(self.allocator, project);
    }

    fn loadProjectImpl(self: *Self, id: []const u8, allocator: std.mem.Allocator) !?models.Project {
        _ = id;
        if (self.load_project_result) |project| {
            return try self.cloneProject(allocator, project);
        }
        return null;
    }

    fn listProjectsImpl(self: *Self, allocator: std.mem.Allocator) ![]models.Project {
        return try self.cloneProjectSlice(self.list_projects_result, allocator);
    }

    fn appendEntryImpl(self: *Self, project_id: []const u8, entry_type: models.EntryType, content: []const u8) !void {
        try self.append_calls.append(.{
            .project_id = try self.cloneText(project_id),
            .entry_type = entry_type,
            .content = try self.cloneText(content),
        });
    }

    fn listEntriesImpl(self: *Self, project_id: []const u8, allocator: std.mem.Allocator) ![]models.Entry {
        _ = project_id;
        return try self.cloneEntrySlice(self.list_entries_result, allocator);
    }

    fn searchImpl(self: *Self, allocator: std.mem.Allocator, query: []const u8) ![]models.Entry {
        _ = query;
        return try self.cloneEntrySlice(self.search_result, allocator);
    }

    fn deleteProjectImpl(self: *Self, id: []const u8) !void {
        if (self.deleted_project_id) |old| self.allocator.free(old);
        self.deleted_project_id = try self.cloneText(id);
    }

    fn asSelf(ptr: *anyopaque) *Self {
        return @ptrCast(@alignCast(ptr));
    }

    fn ensureSchemaV(ptr: *anyopaque) anyerror!void {
        return asSelf(ptr).ensureSchemaImpl();
    }

    fn saveProjectV(ptr: *anyopaque, project: models.Project) anyerror!void {
        return asSelf(ptr).saveProjectImpl(project);
    }

    fn loadProjectV(ptr: *anyopaque, id: []const u8, allocator: std.mem.Allocator) anyerror!?models.Project {
        return asSelf(ptr).loadProjectImpl(id, allocator);
    }

    fn listProjectsV(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]models.Project {
        return asSelf(ptr).listProjectsImpl(allocator);
    }

    fn appendEntryV(ptr: *anyopaque, project_id: []const u8, entry_type: models.EntryType, content: []const u8) anyerror!void {
        return asSelf(ptr).appendEntryImpl(project_id, entry_type, content);
    }

    fn listEntriesV(ptr: *anyopaque, project_id: []const u8, allocator: std.mem.Allocator) anyerror![]models.Entry {
        return asSelf(ptr).listEntriesImpl(project_id, allocator);
    }

    fn searchV(ptr: *anyopaque, allocator: std.mem.Allocator, query: []const u8) anyerror![]models.Entry {
        return asSelf(ptr).searchImpl(allocator, query);
    }

    fn deleteProjectV(ptr: *anyopaque, id: []const u8) anyerror!void {
        return asSelf(ptr).deleteProjectImpl(id);
    }

    const vtable = Storage.VTable{
        .ensure_schema = ensureSchemaV,
        .save_project = saveProjectV,
        .load_project = loadProjectV,
        .list_projects = listProjectsV,
        .append_entry = appendEntryV,
        .list_entries = listEntriesV,
        .search = searchV,
        .delete_project = deleteProjectV,
    };
};

const MockFormatter = struct {
    allocator: std.mem.Allocator,
    project_output: []const u8 = "PROJECT",
    list_output: []const u8 = "LIST",
    project_calls: usize = 0,
    list_calls: usize = 0,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *Self) void {
        _ = self;
    }

    fn asFormatter(self: *Self) Formatter {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn renderProjectMarkdownImpl(self: *Self, allocator: std.mem.Allocator, project: models.Project, entries: []const models.Entry) ![]u8 {
        _ = project;
        _ = entries;
        self.project_calls += 1;
        return try allocator.dupe(u8, self.project_output);
    }

    fn renderListMarkdownImpl(self: *Self, allocator: std.mem.Allocator, projects: []const models.Project) ![]u8 {
        _ = projects;
        self.list_calls += 1;
        return try allocator.dupe(u8, self.list_output);
    }

    fn asSelf(ptr: *anyopaque) *Self {
        return @ptrCast(@alignCast(ptr));
    }

    fn renderProjectMarkdownV(ptr: *anyopaque, allocator: std.mem.Allocator, project: models.Project, entries: []const models.Entry) anyerror![]u8 {
        return asSelf(ptr).renderProjectMarkdownImpl(allocator, project, entries);
    }

    fn renderListMarkdownV(ptr: *anyopaque, allocator: std.mem.Allocator, projects: []const models.Project) anyerror![]u8 {
        return asSelf(ptr).renderListMarkdownImpl(allocator, projects);
    }

    const vtable = Formatter.VTable{
        .render_project_markdown = renderProjectMarkdownV,
        .render_list_markdown = renderListMarkdownV,
    };
};

fn makeApp(storage: *MockStorage, formatter: *MockFormatter) App {
    return App.init(
        std.heap.page_allocator,
        std.process.Environ.empty,
        storage.asStorage(),
        formatter.asFormatter(),
        .{
            .db_path = ":memory:",
        },
    );
}

test "save command persists project and decisions" {
    const allocator = std.heap.page_allocator;
    var storage = MockStorage.init(allocator);
    defer storage.deinit();
    var fmt = MockFormatter.init(allocator);
    defer fmt.deinit();
    var app = makeApp(&storage, &fmt);

    try commands.save.run(&app, &.{
        "demo",
        "--summary",
        "first pass",
        "--pending",
        "alpha, beta",
        "--files",
        "src/main.zig, src/app.zig",
        "--decisions",
        "use sqlite, keep cli thin",
    });

    try std.testing.expect(storage.saved_project != null);
    const saved = storage.saved_project.?;
    try std.testing.expectEqualStrings("demo", saved.id);
    try std.testing.expectEqualStrings("first pass", saved.summary);
    try std.testing.expectEqualStrings("[\"alpha\",\"beta\"]", saved.pending);
    try std.testing.expectEqualStrings("[\"src/main.zig\",\"src/app.zig\"]", saved.files);
    try std.testing.expectEqual(@as(usize, 2), storage.append_calls.items.len);
    try std.testing.expectEqualStrings("use sqlite", storage.append_calls.items[0].content);
    try std.testing.expectEqualStrings("keep cli thin", storage.append_calls.items[1].content);
}

test "load list export init delete and search command flow" {
    const allocator = std.heap.page_allocator;
    var storage = MockStorage.init(allocator);
    defer storage.deinit();
    storage.load_project_result = .{
        .id = "demo",
        .summary = "loaded",
        .pending = "[]",
        .files = "[]",
        .created_at = "2026-05-25T00:00:00Z",
        .updated_at = "2026-05-25T00:00:00Z",
    };
    storage.list_projects_result = &.{
        .{
            .id = "demo",
            .summary = "loaded",
            .pending = "[]",
            .files = "[]",
            .created_at = "2026-05-25T00:00:00Z",
            .updated_at = "2026-05-25T00:00:00Z",
        },
    };
    storage.list_entries_result = &.{
        .{
            .id = "entry-1",
            .project_id = "demo",
            .entry_type = .progress,
            .content = "done",
            .created_at = "2026-05-25T00:00:00Z",
        },
    };
    storage.search_result = storage.list_entries_result;

    var fmt = MockFormatter.init(allocator);
    defer fmt.deinit();
    var app = makeApp(&storage, &fmt);

    try commands.init.run(&app, &.{});
    try commands.load.run(&app, &.{ "demo" });
    try commands.list.run(&app, &.{});
    try commands.export_cmd.run(&app, &.{ "demo" });
    try commands.search.run(&app, &.{ "done" });
    try commands.delete_cmd.run(&app, &.{ "demo" });

    try std.testing.expectEqual(@as(usize, 1), storage.ensure_schema_calls);
    try std.testing.expectEqual(@as(usize, 2), fmt.project_calls);
    try std.testing.expectEqual(@as(usize, 1), fmt.list_calls);
    try std.testing.expect(storage.deleted_project_id != null);
    try std.testing.expectEqualStrings("demo", storage.deleted_project_id.?);
}

test "commands reject missing required arguments" {
    const allocator = std.heap.page_allocator;
    var storage = MockStorage.init(allocator);
    defer storage.deinit();
    var fmt = MockFormatter.init(allocator);
    defer fmt.deinit();
    var app = makeApp(&storage, &fmt);

    try std.testing.expectError(error.MissingProjectName, commands.save.run(&app, &.{}));
    try std.testing.expectError(error.MissingProjectName, commands.load.run(&app, &.{}));
    try std.testing.expectError(error.MissingQuery, commands.search.run(&app, &.{}));
    try std.testing.expectError(error.MissingProjectName, commands.delete_cmd.run(&app, &.{}));
}
