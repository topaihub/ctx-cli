const std = @import("std");

pub const Project = struct {
    id: []const u8,
    summary: []const u8,
    pending: []const u8,
    files: []const u8,
    created_at: []const u8,
    updated_at: []const u8,

    pub fn deinit(self: Project, allocator: std.mem.Allocator) void {
        allocator.free(@constCast(self.id));
        allocator.free(@constCast(self.summary));
        allocator.free(@constCast(self.pending));
        allocator.free(@constCast(self.files));
        allocator.free(@constCast(self.created_at));
        allocator.free(@constCast(self.updated_at));
    }
};

pub const EntryType = enum {
    decision,
    progress,
    note,
    pending,

    pub fn toString(self: EntryType) []const u8 {
        return switch (self) {
            .decision => "decision",
            .progress => "progress",
            .note => "note",
            .pending => "pending",
        };
    }

    pub fn fromString(text: []const u8) !EntryType {
        if (std.mem.eql(u8, text, "decision")) return .decision;
        if (std.mem.eql(u8, text, "progress")) return .progress;
        if (std.mem.eql(u8, text, "note")) return .note;
        if (std.mem.eql(u8, text, "pending")) return .pending;
        return error.InvalidEntryType;
    }
};

pub const Entry = struct {
    id: []const u8,
    project_id: []const u8,
    entry_type: EntryType,
    content: []const u8,
    created_at: []const u8,

    pub fn deinit(self: Entry, allocator: std.mem.Allocator) void {
        allocator.free(@constCast(self.id));
        allocator.free(@constCast(self.project_id));
        allocator.free(@constCast(self.content));
        allocator.free(@constCast(self.created_at));
    }
};
