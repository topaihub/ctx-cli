const std = @import("std");
const ctx = @import("ctx");

test "skill template contains ctx load and install paths" {
    const allocator = std.heap.page_allocator;
    const text = try ctx.skill_template.render(allocator);
    defer allocator.free(text);

    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "ctx load <project>"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "ctx skill install --agent codex"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "ctx skill install --agent claude"));
}
