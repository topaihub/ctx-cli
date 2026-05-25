const std = @import("std");
const ctx = @import("ctx");
const sqlite = ctx.sqlite_storage;

test "sqlite storage save load and search" {
    const allocator = std.heap.page_allocator;

    var storage = try sqlite.SqliteStorage.open(allocator, ":memory:");
    defer storage.deinit();
    const ctx_storage = storage.asStorage();

    try ctx_storage.saveProject(.{
        .id = "demo",
        .summary = "first pass",
        .pending = "[]",
        .files = "[]",
        .created_at = "",
        .updated_at = "",
    });
    try ctx_storage.appendEntry("demo", .decision, "use sqlite");
    try ctx_storage.appendEntry("demo", .progress, "skeleton ready");

    const loaded = try ctx_storage.loadProject("demo", allocator);
    try std.testing.expect(loaded != null);
    const project = loaded.?;
    defer project.deinit(allocator);
    try std.testing.expect(std.mem.eql(u8, project.summary, "first pass"));

    const entries = try ctx_storage.listEntries("demo", allocator);
    defer {
        for (entries) |entry| entry.deinit(allocator);
        allocator.free(entries);
    }
    try std.testing.expectEqual(@as(usize, 2), entries.len);

    const results = try ctx_storage.search(allocator, "sqlite");
    defer {
        for (results) |entry| entry.deinit(allocator);
        allocator.free(results);
    }
    try std.testing.expect(results.len >= 1);
}
