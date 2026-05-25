const std = @import("std");
const ctx = @import("ctx");
const formatter = ctx.formatter;
const models = ctx.models;

test "render list markdown" {
    const allocator = std.heap.page_allocator;

    const projects = [_]models.Project{
        .{
            .id = "demo",
            .summary = "working",
            .pending = "[]",
            .files = "[]",
            .created_at = "2026-05-22T00:00:00Z",
            .updated_at = "2026-05-22T00:00:00Z",
        },
    };
    const rendered = try formatter.renderListMarkdown(allocator, &projects);
    defer allocator.free(rendered);
    try std.testing.expect(std.mem.containsAtLeast(u8, rendered, 1, "demo"));
}
