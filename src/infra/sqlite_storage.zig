const std = @import("std");
const models = @import("../core/models.zig");
const Storage = @import("../core/storage.zig").Storage;

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const SqliteStorage = struct {
    allocator: std.mem.Allocator,
    db: ?*c.sqlite3,

    const Self = @This();

    pub fn open(allocator: std.mem.Allocator, db_path: []const u8) !Self {
        var result: Self = .{ .allocator = allocator, .db = null };
        try result.openDb(db_path);
        try result.ensureSchema();
        return result;
    }

    pub fn deinit(self: *Self) void {
        if (self.db) |db| _ = c.sqlite3_close(db);
        self.db = null;
    }

    pub fn asStorage(self: *Self) Storage {
        return .{ .ptr = self, .vtable = &vtable };
    }

    pub fn ensureSchema(self: *Self) !void {
        return self.ensureSchemaImpl();
    }

    fn openDb(self: *Self, db_path: []const u8) !void {
        var db: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open_v2(db_path.ptr, &db, c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE | c.SQLITE_OPEN_FULLMUTEX, null);
        if (rc != c.SQLITE_OK) {
            if (db) |handle| _ = c.sqlite3_close(handle);
            return error.DatabaseOpenFailed;
        }
        self.db = db;
    }

    fn ensureDb(self: *Self) !*c.sqlite3 {
        return self.db orelse error.DatabaseNotOpen;
    }

    fn exec(self: *Self, sql: []const u8) !void {
        const db = try self.ensureDb();
        var errmsg: [*c]u8 = null;
        const rc = c.sqlite3_exec(db, sql.ptr, null, null, &errmsg);
        if (rc != c.SQLITE_OK) {
            if (errmsg != null) c.sqlite3_free(errmsg);
            return error.SqliteExecFailed;
        }
    }

    fn ensureSchemaImpl(self: *Self) !void {
        try self.exec(
            \\PRAGMA journal_mode=WAL;
            \\PRAGMA foreign_keys=ON;
            \\CREATE TABLE IF NOT EXISTS projects (
            \\  id TEXT PRIMARY KEY,
            \\  summary TEXT NOT NULL DEFAULT '',
            \\  pending TEXT DEFAULT '[]',
            \\  files TEXT DEFAULT '[]',
            \\  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
            \\  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            \\);
            \\CREATE TABLE IF NOT EXISTS entries (
            \\  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
            \\  project_id TEXT NOT NULL,
            \\  type TEXT NOT NULL CHECK(type IN ('decision', 'progress', 'note', 'pending')),
            \\  content TEXT NOT NULL,
            \\  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
            \\  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
            \\);
            \\CREATE INDEX IF NOT EXISTS idx_entries_project ON entries(project_id, created_at DESC);
            \\CREATE INDEX IF NOT EXISTS idx_entries_type ON entries(project_id, type);
            \\CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
            \\  content,
            \\  content=entries,
            \\  content_rowid=rowid,
            \\  tokenize='unicode61'
            \\);
            \\CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
            \\  INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
            \\END;
            \\CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
            \\  INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
            \\END;
            \\CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
            \\  INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
            \\  INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
            \\END;
        );
    }

    fn prepare(self: *Self, sql: []const u8) !*c.sqlite3_stmt {
        const db = try self.ensureDb();
        var stmt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(db, sql.ptr, @as(c_int, @intCast(sql.len)), &stmt, null);
        if (rc != c.SQLITE_OK) return error.SqlitePrepareFailed;
        return stmt orelse error.SqlitePrepareFailed;
    }

    fn bindText(stmt: *c.sqlite3_stmt, index: c_int, text: []const u8) !void {
        const rc = c.sqlite3_bind_text(stmt, index, text.ptr, @as(c_int, @intCast(text.len)), null);
        if (rc != c.SQLITE_OK) return error.SqliteBindFailed;
    }

    fn stepDone(stmt: *c.sqlite3_stmt) !void {
        const rc = c.sqlite3_step(stmt);
        if (rc != c.SQLITE_DONE) return error.SqliteStepFailed;
    }

    fn readText(allocator: std.mem.Allocator, stmt: *c.sqlite3_stmt, column: c_int) ![]const u8 {
        const ptr = c.sqlite3_column_text(stmt, column) orelse return error.SqliteNullValue;
        const len = c.sqlite3_column_bytes(stmt, column);
        return try allocator.dupe(u8, ptr[0..@as(usize, @intCast(len))]);
    }

    fn loadProjectImpl(self: *Self, id: []const u8, allocator: std.mem.Allocator) !?models.Project {
        const stmt = try self.prepare(
            \\SELECT id, summary, pending, files, created_at, updated_at
            \\FROM projects
            \\WHERE id = ?1
        );
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, id);
        const rc = c.sqlite3_step(stmt);
        if (rc == c.SQLITE_DONE) return null;
        if (rc != c.SQLITE_ROW) return error.SqliteStepFailed;

        return .{
            .id = try readText(allocator, stmt, 0),
            .summary = try readText(allocator, stmt, 1),
            .pending = try readText(allocator, stmt, 2),
            .files = try readText(allocator, stmt, 3),
            .created_at = try readText(allocator, stmt, 4),
            .updated_at = try readText(allocator, stmt, 5),
        };
    }

    fn listProjectsImpl(self: *Self, allocator: std.mem.Allocator) ![]models.Project {
        const stmt = try self.prepare(
            \\SELECT id, summary, pending, files, created_at, updated_at
            \\FROM projects
            \\ORDER BY updated_at DESC
        );
        defer _ = c.sqlite3_finalize(stmt);

        var items = std.array_list.Managed(models.Project).init(allocator);
        errdefer {
            for (items.items) |project| project.deinit(allocator);
            items.deinit();
        }

        while (true) {
            const rc = c.sqlite3_step(stmt);
            if (rc == c.SQLITE_DONE) break;
            if (rc != c.SQLITE_ROW) return error.SqliteStepFailed;

            try items.append(.{
                .id = try readText(allocator, stmt, 0),
                .summary = try readText(allocator, stmt, 1),
                .pending = try readText(allocator, stmt, 2),
                .files = try readText(allocator, stmt, 3),
                .created_at = try readText(allocator, stmt, 4),
                .updated_at = try readText(allocator, stmt, 5),
            });
        }

        return items.toOwnedSlice();
    }

    fn saveProjectImpl(self: *Self, project: models.Project) !void {
        const stmt = try self.prepare(
            \\INSERT INTO projects(id, summary, pending, files)
            \\VALUES(?1, ?2, ?3, ?4)
            \\ON CONFLICT(id) DO UPDATE SET
            \\  summary = excluded.summary,
            \\  pending = excluded.pending,
            \\  files = excluded.files,
            \\  updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
        );
        defer _ = c.sqlite3_finalize(stmt);

        try bindText(stmt, 1, project.id);
        try bindText(stmt, 2, project.summary);
        try bindText(stmt, 3, project.pending);
        try bindText(stmt, 4, project.files);
        try stepDone(stmt);
    }

    fn appendEntryImpl(self: *Self, project_id: []const u8, entry_type: models.EntryType, content: []const u8) !void {
        const stmt = try self.prepare(
            \\INSERT INTO projects(id) VALUES(?1)
            \\ON CONFLICT(id) DO NOTHING;
        );
        defer _ = c.sqlite3_finalize(stmt);
        try bindText(stmt, 1, project_id);
        _ = c.sqlite3_step(stmt);

        const insert = try self.prepare(
            \\INSERT INTO entries(project_id, type, content)
            \\VALUES(?1, ?2, ?3)
        );
        defer _ = c.sqlite3_finalize(insert);

        try bindText(insert, 1, project_id);
        try bindText(insert, 2, entry_type.toString());
        try bindText(insert, 3, content);
        try stepDone(insert);
    }

    fn listEntriesImpl(self: *Self, project_id: []const u8, allocator: std.mem.Allocator) ![]models.Entry {
        const stmt = try self.prepare(
            \\SELECT id, project_id, type, content, created_at
            \\FROM entries
            \\WHERE project_id = ?1
            \\ORDER BY created_at DESC
        );
        defer _ = c.sqlite3_finalize(stmt);
        try bindText(stmt, 1, project_id);

        var items = std.array_list.Managed(models.Entry).init(allocator);
        errdefer {
            for (items.items) |entry| entry.deinit(allocator);
            items.deinit();
        }

        while (true) {
            const rc = c.sqlite3_step(stmt);
            if (rc == c.SQLITE_DONE) break;
            if (rc != c.SQLITE_ROW) return error.SqliteStepFailed;

            const entry_type_text = try readText(allocator, stmt, 2);
            defer allocator.free(@constCast(entry_type_text));

            try items.append(.{
                .id = try readText(allocator, stmt, 0),
                .project_id = try readText(allocator, stmt, 1),
                .entry_type = try models.EntryType.fromString(entry_type_text),
                .content = try readText(allocator, stmt, 3),
                .created_at = try readText(allocator, stmt, 4),
            });
        }

        return items.toOwnedSlice();
    }

    fn searchImpl(self: *Self, allocator: std.mem.Allocator, query: []const u8) ![]models.Entry {
        const stmt = try self.prepare(
            \\SELECT e.id, e.project_id, e.type, e.content, e.created_at
            \\FROM entries_fts f
            \\JOIN entries e ON e.rowid = f.rowid
            \\WHERE entries_fts MATCH ?1
            \\ORDER BY e.created_at DESC
        );
        defer _ = c.sqlite3_finalize(stmt);
        try bindText(stmt, 1, query);

        var items = std.array_list.Managed(models.Entry).init(allocator);
        errdefer {
            for (items.items) |entry| entry.deinit(allocator);
            items.deinit();
        }

        while (true) {
            const rc = c.sqlite3_step(stmt);
            if (rc == c.SQLITE_DONE) break;
            if (rc != c.SQLITE_ROW) return error.SqliteStepFailed;

            const entry_type_text = try readText(allocator, stmt, 2);
            defer allocator.free(@constCast(entry_type_text));

            try items.append(.{
                .id = try readText(allocator, stmt, 0),
                .project_id = try readText(allocator, stmt, 1),
                .entry_type = try models.EntryType.fromString(entry_type_text),
                .content = try readText(allocator, stmt, 3),
                .created_at = try readText(allocator, stmt, 4),
            });
        }

        return items.toOwnedSlice();
    }

    fn deleteProjectImpl(self: *Self, id: []const u8) !void {
        const stmt = try self.prepare(
            \\DELETE FROM projects WHERE id = ?1
        );
        defer _ = c.sqlite3_finalize(stmt);
        try bindText(stmt, 1, id);
        try stepDone(stmt);
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
