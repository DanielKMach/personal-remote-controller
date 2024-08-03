const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const network = b.dependency("network", .{});

    // Steps
    const install_step = b.getInstallStep();
    const run_step = b.step("run", "Run the app");
    const test_step = b.step("test", "Run unit tests");

    // Build
    const exe = b.addExecutable(.{
        .name = "prc",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    linkDependencies(exe, .{ .network = network });

    install_step.dependOn(&b.addInstallArtifact(exe, .{}).step);

    // Run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(install_step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    run_step.dependOn(&run_cmd.step);

    // Test
    const tests = try listTestFiles(b, b.allocator, "src");
    for (tests) |test_path| {
        const exe_test = b.addTest(.{
            .root_source_file = test_path,
            .target = target,
            .optimize = optimize,
        });

        linkDependencies(exe_test, .{ .network = network });

        test_step.dependOn(&b.addRunArtifact(exe_test).step);
    }
}

pub fn linkDependencies(exe: *std.Build.Step.Compile, deps: anytype) void {
    exe.linkLibC();

    const info = @typeInfo(@TypeOf(deps));
    if (info != .Struct) {
        @compileError("deps must be a struct");
    }

    inline for (info.Struct.fields) |f| {
        if (f.type != *std.Build.Dependency) {
            @compileError("Invalid dependency type");
        }
        const mod_name = f.name;
        const mod = @field(deps, mod_name);
        exe.root_module.addImport(mod_name, mod.module(mod_name));
    }
}

pub fn listTestFiles(b: *std.Build, allocator: std.mem.Allocator, sub_path: []const u8) ![]std.Build.LazyPath {
    const trimmed_sub_path = std.mem.trimRight(u8, sub_path, std.fs.path.sep_str); // In case of trailing slash

    var dir = try std.fs.cwd().openDir(trimmed_sub_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var test_files = std.ArrayList(std.Build.LazyPath).init(allocator);

    while (true) {
        if (walker.next()) |entry| {
            if (entry == null) break;
            const e = entry.?;
            if (e.kind == .file) {
                if (std.mem.endsWith(u8, e.basename, ".test.zig")) {
                    const relative_path = try std.fmt.allocPrint(allocator, "{s}" ++ std.fs.path.sep_str ++ "{s}", .{ trimmed_sub_path, e.path });
                    try test_files.append(b.path(relative_path));
                }
            }
        } else |_| {}
    }

    return test_files.toOwnedSlice() catch unreachable;
}
