const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sqlite3_c_flags = &.{
        "-DSQLITE_THREADSAFE=1",
        "-DSQLITE_ENABLE_FTS5=1",
        "-DSQLITE_OMIT_LOAD_EXTENSION=1",
    };

    const zig_logging_dep = b.dependency("zig-logging", .{});
    const zig_logging_module = zig_logging_dep.module("zig-logging");

    const sqlite_module = b.createModule(.{
        .root_source_file = b.path("src/infra/sqlite_storage.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sqlite_module.addIncludePath(b.path("vendor/sqlite3"));
    sqlite_module.addCSourceFile(.{
        .file = b.path("vendor/sqlite3/sqlite3.c"),
        .flags = sqlite3_c_flags,
    });

    const ctx_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    ctx_module.addImport("zig-logging", zig_logging_module);
    ctx_module.addImport("sqlite_storage", sqlite_module);
    ctx_module.addIncludePath(b.path("vendor/sqlite3"));

    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    main_module.addImport("zig-logging", zig_logging_module);
    main_module.addImport("ctx", ctx_module);
    main_module.addImport("sqlite_storage", sqlite_module);
    main_module.addIncludePath(b.path("vendor/sqlite3"));
    main_module.addCSourceFile(.{
        .file = b.path("vendor/sqlite3/sqlite3.c"),
        .flags = sqlite3_c_flags,
    });

    const exe = b.addExecutable(.{
        .name = "ctx",
        .root_module = main_module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run ctx");
    run_step.dependOn(&run_cmd.step);

    const unit_test_module = b.createModule(.{
        .root_source_file = b.path("tests/storage_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    unit_test_module.addImport("ctx", ctx_module);
    unit_test_module.addIncludePath(b.path("vendor/sqlite3"));
    unit_test_module.addCSourceFile(.{
        .file = b.path("vendor/sqlite3/sqlite3.c"),
        .flags = &.{
            "-DSQLITE_THREADSAFE=1",
            "-DSQLITE_ENABLE_FTS5=1",
            "-DSQLITE_OMIT_LOAD_EXTENSION=1",
        },
    });
    const unit_test = b.addTest(.{ .root_module = unit_test_module });
    const unit_test_run = b.addRunArtifact(unit_test);

    const commands_test_module = b.createModule(.{
        .root_source_file = b.path("tests/commands_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    commands_test_module.addImport("ctx", ctx_module);
    const commands_test = b.addTest(.{ .root_module = commands_test_module });
    const commands_test_run = b.addRunArtifact(commands_test);

    const format_test_module = b.createModule(.{
        .root_source_file = b.path("tests/formatter_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    format_test_module.addImport("ctx", ctx_module);
    const format_test = b.addTest(.{ .root_module = format_test_module });
    const format_test_run = b.addRunArtifact(format_test);

    const skill_test_module = b.createModule(.{
        .root_source_file = b.path("tests/skill_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    skill_test_module.addImport("ctx", ctx_module);
    const skill_test = b.addTest(.{ .root_module = skill_test_module });
    const skill_test_run = b.addRunArtifact(skill_test);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&unit_test_run.step);
    test_step.dependOn(&commands_test_run.step);
    test_step.dependOn(&format_test_run.step);
    test_step.dependOn(&skill_test_run.step);

    const zig_release_dep = b.dependency("zig-release", .{});
    const zig_release = @import("zig-release");
    zig_release.addReleaseStep(b, zig_release_dep, .{});
}


